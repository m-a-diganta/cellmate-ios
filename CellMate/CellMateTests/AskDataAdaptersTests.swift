import XCTest
@testable import CellMate

@MainActor
final class AskDataAdaptersTests: XCTestCase {

    private let charger = Charger(name: "Stock charger", brand: "InMotion")

    private func makeBattery(retired: Bool = false) -> Battery {
        Battery(
            name: "Main pack",
            brand: "InMotion",
            capacityWh: 500,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            chargerID: charger.id,
            status: retired ? .retired(reason: "Swollen case") : .active
        )
    }

    private func makeAssessment(
        level: BatteryAdviceLevel,
        symptoms: Set<BatterySymptom>,
        id: UUID = UUID()
    ) -> BatteryAssessment {
        BatteryAssessment(
            id: id,
            date: Date(),
            symptoms: symptoms,
            level: level,
            source: .rules,
            rulesVersion: "test",
            needsQuickCheck: false,
            batteryID: nil
        )
    }

    private func makeLogger(battery: Battery) -> (InspectionAskLogger, InMemoryInspectionRepository) {
        let garage = InMemoryGarageRepository(batteries: [battery], chargers: [charger])
        let inspections = InMemoryInspectionRepository(garageRepository: garage)
        return (InspectionAskLogger(inspections: inspections), inspections)
    }

    func testBatteryProviderListsGarageBatteries() async throws {
        let active = makeBattery()
        let retired = makeBattery(retired: true)
        let garage = InMemoryGarageRepository(batteries: [active, retired], chargers: [charger])

        let list = try await GarageAskBatteryProvider(garage: garage).batteries()

        XCTAssertEqual(list.map(\.id), [active.id, retired.id])
        XCTAssertEqual(list.map(\.isRetired), [false, true])
    }

    func testStopUsingResultIsSavedAsAFailedAssistantInspection() async throws {
        let battery = makeBattery()
        let (logger, inspections) = makeLogger(battery: battery)
        let assessment = makeAssessment(level: .stopUsing, symptoms: [.swelling, .excessiveHeat])

        try await logger.log(assessment, for: battery.id)

        let saved = try await inspections.fetchInspections(for: battery.id)
        XCTAssertEqual(saved.count, 1)
        XCTAssertEqual(saved.first?.id, assessment.id)
        XCTAssertEqual(saved.first?.source, .assistant)
        XCTAssertEqual(saved.first?.result, .fail)
        XCTAssertEqual(Set(saved.first?.items.map(\.kind) ?? []), [.swelling, .heat])
        XCTAssertTrue(saved.first?.items.allSatisfy { $0.finding == .problem } ?? false)
    }

    func testAnInfoResultIsNeverSavedAsAPass() async throws {
        let battery = makeBattery()
        let (logger, inspections) = makeLogger(battery: battery)

        try await logger.log(makeAssessment(level: .info, symptoms: [.unknown]), for: battery.id)

        let saved = try await inspections.fetchInspections(for: battery.id)
        XCTAssertEqual(saved.first?.result, .caution)
        XCTAssertNotEqual(saved.first?.result, .pass)
    }

    func testSavingTheSameResultTwiceDoesNotDuplicateOrFail() async throws {
        let battery = makeBattery()
        let (logger, inspections) = makeLogger(battery: battery)
        let assessment = makeAssessment(level: .caution, symptoms: [.chargerConcern])

        try await logger.log(assessment, for: battery.id)
        try await logger.log(assessment, for: battery.id)

        let saved = try await inspections.fetchInspections(for: battery.id)
        XCTAssertEqual(saved.count, 1)
    }

    func testSavingForAnUnknownBatteryFails() async {
        let (logger, _) = makeLogger(battery: makeBattery())

        do {
            try await logger.log(makeAssessment(level: .caution, symptoms: [.swelling]), for: UUID())
            XCTFail("Expected batteryNotFound.")
        } catch {
            XCTAssertEqual(error as? InspectionRepositoryError, .batteryNotFound)
        }
    }

    func testAnAskResultFlagsTheBatteryAsNeedingAttention() async throws {
        let battery = makeBattery()
        let (logger, inspections) = makeLogger(battery: battery)
        try await logger.log(makeAssessment(level: .stopUsing, symptoms: [.swelling]), for: battery.id)

        let latest = try await inspections.fetchInspections(for: battery.id).first
        let status = try EvaluateInspectionDue().execute(battery: battery, latestInspection: latest)

        XCTAssertEqual(status, .needsAttention)
    }
}
