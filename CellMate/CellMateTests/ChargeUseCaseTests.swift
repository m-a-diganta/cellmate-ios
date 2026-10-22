import XCTest
@testable import CellMate

/// Everything the Start and End use cases need, built fresh for each test.
@MainActor
private struct ChargeFixture {
    let charges = InMemoryChargeRepository()
    let notifications = MockNotificationScheduler()
    let activity = MockChargeActivityController()
    let charger: Charger
    let battery: Battery
    let garage: InMemoryGarageRepository
    let bedtime = CellMateDates.makeTime(hour: 22, minute: 30)
    let morning = CellMateDates.makeTime(hour: 9, minute: 0)

    init() {
        let charger = Charger(name: "Stock charger", brand: "InMotion")
        let battery = Battery(
            name: "Main pack",
            brand: "InMotion",
            capacityWh: 500,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            chargerID: charger.id
        )
        self.charger = charger
        self.battery = battery
        self.garage = InMemoryGarageRepository(batteries: [battery], chargers: [charger])
    }

    func startCase() -> StartChargeSession {
        let bedtime = self.bedtime
        return StartChargeSession(
            chargeRepository: charges,
            garageRepository: garage,
            notifications: notifications,
            activity: activity,
            bedtimeProvider: { bedtime }
        )
    }

    func endCase() -> EndChargeSession {
        let bedtime = self.bedtime
        return EndChargeSession(
            chargeRepository: charges,
            garageRepository: garage,
            notifications: notifications,
            activity: activity,
            bedtimeProvider: { bedtime }
        )
    }

    func validInput(plannedMinutes: Int = 120, chargerID: UUID? = nil) -> StartChargeInput {
        StartChargeInput(
            batteryID: battery.id,
            chargerID: chargerID ?? charger.id,
            place: .garage,
            checklistTicks: [true, true, true],
            checklistLabels: ChecklistItem.defaultItems.map(\.label),
            plannedDurationMinutes: plannedMinutes,
            unattended: false,
            startedAt: morning
        )
    }
}

@MainActor
final class ChargeUseCaseTests: XCTestCase {

    // MARK: - StartChargeSession

    func testStartFailsWhenChecklistIncomplete() async {
        let fixture = ChargeFixture()
        var input = fixture.validInput()
        input.checklistTicks = [true, true, false]

        do {
            _ = try await fixture.startCase().execute(input)
            XCTFail("Expected checklistIncomplete.")
        } catch {
            XCTAssertEqual(error as? StartChargeError, .checklistIncomplete)
        }
        XCTAssertNil(fixture.charges.anyRunningSession())
    }

    func testStartSavesSessionWithRiskAndSchedulesAlerts() async throws {
        let fixture = ChargeFixture()
        let result = try await fixture.startCase().execute(fixture.validInput())

        let saved = try XCTUnwrap(fixture.charges.session(withID: result.session.id))
        XCTAssertEqual(saved.rulesVersion, RiskRulesVersion.current)
        XCTAssertNotNil(saved.riskLevel)
        XCTAssertEqual(saved.status, .running)
        XCTAssertEqual(saved.plannedUnplug, fixture.morning.addingTimeInterval(120 * 60))

        XCTAssertEqual(fixture.activity.startedBatteryNames, ["Main pack"])
        let unplug = fixture.notifications.scheduled.first { $0.kind == "unplug" }
        XCTAssertEqual(unplug?.date, saved.plannedUnplug)
    }

    func testStartWithUnmatchedChargerScoresHigh() async throws {
        let fixture = ChargeFixture()
        let other = Charger(name: "Random charger", brand: "Generic")
        try await fixture.garage.addCharger(other)

        let result = try await fixture.startCase().execute(fixture.validInput(chargerID: other.id))

        XCTAssertEqual(result.assessment.level, .high)
        XCTAssertTrue(result.assessment.flags.contains { $0.type == .unmatchedCharger })
    }

    func testStartFailsWhenAlreadyCharging() async throws {
        let fixture = ChargeFixture()
        let useCase = fixture.startCase()
        _ = try await useCase.execute(fixture.validInput())

        do {
            _ = try await useCase.execute(fixture.validInput())
            XCTFail("Expected batteryAlreadyCharging.")
        } catch {
            XCTAssertEqual(error as? StartChargeError, .batteryAlreadyCharging)
        }
    }

    func testStartFailsForRetiredBattery() async throws {
        let fixture = ChargeFixture()
        let retired = Battery(
            id: fixture.battery.id,
            name: fixture.battery.name,
            brand: fixture.battery.brand,
            capacityWh: fixture.battery.capacityWh,
            purchaseDate: fixture.battery.purchaseDate,
            chargerID: fixture.battery.chargerID,
            status: .retired(reason: "Swollen case")
        )
        try await fixture.garage.updateBattery(retired)

        do {
            _ = try await fixture.startCase().execute(fixture.validInput())
            XCTFail("Expected batteryRetired.")
        } catch {
            XCTAssertEqual(error as? StartChargeError, .batteryRetired)
        }
    }

    func testStartStillWorksWhenLiveActivitiesAreOff() async throws {
        let fixture = ChargeFixture()
        fixture.activity.startError = .turnedOff

        let result = try await fixture.startCase().execute(fixture.validInput())

        XCTAssertEqual(result.session.status, .running)
        XCTAssertTrue(fixture.activity.startedBatteryNames.isEmpty)
        XCTAssertTrue(fixture.notifications.scheduled.contains { $0.kind == "unplug" })
    }

    // MARK: - EndChargeSession

    func testEndCompletesAndCancelsAlerts() async throws {
        let fixture = ChargeFixture()
        let started = try await fixture.startCase().execute(fixture.validInput())

        let unpluggedAt = fixture.morning.addingTimeInterval(100 * 60)
        let ended = try await fixture.endCase().execute(sessionID: started.session.id, unpluggedAt: unpluggedAt)

        XCTAssertEqual(ended.session.status, .completed)
        XCTAssertEqual(ended.session.endedAt, unpluggedAt)
        XCTAssertEqual(ended.session.riskLevel, .low)
        XCTAssertTrue(fixture.notifications.cancelled.contains(started.session.id))
        XCTAssertEqual(fixture.activity.endCount, 1)
    }

    func testEndTooLateScoresHigh() async throws {
        let fixture = ChargeFixture()
        let started = try await fixture.startCase().execute(fixture.validInput(plannedMinutes: 120))

        let lateUnplug = fixture.morning.addingTimeInterval(TimeInterval((120 + 60) * 60))
        let ended = try await fixture.endCase().execute(sessionID: started.session.id, unpluggedAt: lateUnplug)

        XCTAssertEqual(ended.assessment.level, .high)
        XCTAssertTrue(ended.assessment.flags.contains { $0.type == .tooLong })
    }

    func testExtendMovesPlannedUnplug() async throws {
        let fixture = ChargeFixture()
        let started = try await fixture.startCase().execute(fixture.validInput())

        let updated = try await fixture.endCase().extend(
            sessionID: started.session.id,
            byMinutes: 30,
            now: fixture.morning
        )

        XCTAssertEqual(updated.plannedUnplug, started.session.plannedUnplug.addingTimeInterval(30 * 60))
        XCTAssertEqual(updated.plannedDurationMinutes, 150)
        XCTAssertEqual(fixture.activity.updatedUnplugTimes, [updated.plannedUnplug])
        XCTAssertTrue(fixture.notifications.scheduled.contains { $0.kind == "unplug-update" })
    }

    func testEndingTwiceOrUnknownSessionThrows() async throws {
        let fixture = ChargeFixture()
        let started = try await fixture.startCase().execute(fixture.validInput())
        let endCase = fixture.endCase()
        _ = try await endCase.execute(
            sessionID: started.session.id,
            unpluggedAt: fixture.morning.addingTimeInterval(60 * 60)
        )

        do {
            _ = try await endCase.execute(sessionID: started.session.id)
            XCTFail("Expected alreadyEnded.")
        } catch {
            XCTAssertEqual(error as? EndChargeError, .alreadyEnded)
        }

        do {
            _ = try await endCase.execute(sessionID: UUID())
            XCTFail("Expected sessionNotFound.")
        } catch {
            XCTAssertEqual(error as? EndChargeError, .sessionNotFound)
        }
    }
}
