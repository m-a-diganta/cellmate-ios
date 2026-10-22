import XCTest
@testable import CellMate

@MainActor
final class HistoryAndHomeDataTests: XCTestCase {

    private let charger = Charger(name: "Stock charger", brand: "InMotion")

    private func makeBattery(name: String = "Main pack", retired: Bool = false) -> Battery {
        Battery(
            name: name,
            brand: "InMotion",
            capacityWh: 500,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            chargerID: charger.id,
            status: retired ? .retired(reason: "Swollen case") : .active
        )
    }

    private func makeSession(
        battery: Battery,
        start: Date,
        end: Date? = nil,
        level: RiskLevel = .low
    ) -> ChargeSession {
        ChargeSession(
            batteryID: battery.id,
            chargerID: charger.id,
            startedAt: start,
            endedAt: end,
            plannedUnplug: start.addingTimeInterval(7200),
            plannedDurationMinutes: 120,
            place: .garage,
            checklistTicks: [true, true, true],
            checklistLabels: ChecklistItem.defaultItems.map(\.label),
            overnight: false,
            status: end == nil ? .running : .completed,
            riskLevel: level,
            riskFlags: [],
            rulesVersion: RiskRulesVersion.current
        )
    }

    private func makeInspection(battery: Battery, at date: Date, result: Inspection.Result) -> Inspection {
        Inspection(
            batteryID: battery.id,
            inspectedAt: date,
            source: .manual,
            result: result,
            items: Inspection.Item.Kind.allCases.map {
                Inspection.Item(kind: $0, finding: result == .pass ? .ok : .problem)
            }
        )
    }

    // MARK: - History

    func testHistoryGroupsChargesAndInspectionsByDay() async {
        let battery = makeBattery()
        let garage = InMemoryGarageRepository(batteries: [battery], chargers: [charger])
        let charges = InMemoryChargeRepository(sessions: [
            makeSession(battery: battery, start: Date(), end: Date().addingTimeInterval(3600))
        ])
        let inspections = InMemoryInspectionRepository(
            garageRepository: garage,
            inspections: [makeInspection(battery: battery, at: Date(), result: .pass)]
        )
        let viewModel = HistoryViewModel(
            chargeRepository: charges,
            garageRepository: garage,
            inspectionRepository: inspections
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.groups.count, 1)
        XCTAssertEqual(viewModel.groups.first?.entries.count, 2)
        XCTAssertEqual(HistoryViewModel.dayLabel(for: Date()), "Today")
    }

    func testHistoryFilterShowsOnlyWhatWasAskedFor() async {
        let battery = makeBattery()
        let garage = InMemoryGarageRepository(batteries: [battery], chargers: [charger])
        let charges = InMemoryChargeRepository(sessions: [
            makeSession(battery: battery, start: Date(), end: Date().addingTimeInterval(3600))
        ])
        let inspections = InMemoryInspectionRepository(
            garageRepository: garage,
            inspections: [makeInspection(battery: battery, at: Date(), result: .fail)]
        )
        let viewModel = HistoryViewModel(
            chargeRepository: charges,
            garageRepository: garage,
            inspectionRepository: inspections
        )
        await viewModel.load()

        viewModel.filter = .charges
        XCTAssertEqual(viewModel.groups.flatMap(\.entries).count, 1)
        XCTAssertNotNil(viewModel.groups.first?.entries.first?.chargeSession)

        viewModel.filter = .inspections
        XCTAssertEqual(viewModel.groups.flatMap(\.entries).count, 1)
        XCTAssertEqual(viewModel.groups.first?.entries.first?.riskLevel, .high)
    }

    // MARK: - Home

    func testHomeShowsARunningChargeAsChargingNow() async {
        let battery = makeBattery()
        let garage = InMemoryGarageRepository(batteries: [battery], chargers: [charger])
        let charges = InMemoryChargeRepository(sessions: [makeSession(battery: battery, start: Date())])

        let summary = await LiveHomeSummaryProvider(
            garage: garage,
            charges: charges,
            inspections: InMemoryInspectionRepository(garageRepository: garage)
        ).loadSummary()

        XCTAssertTrue(summary.isCharging)
        XCTAssertEqual(summary.batteries.count, 1)
    }

    func testHomeShowsLastChargeAndHidesRetiredBatteries() async {
        let active = makeBattery(name: "Active pack")
        let retired = makeBattery(name: "Old pack", retired: true)
        let garage = InMemoryGarageRepository(batteries: [active, retired], chargers: [charger])
        let charges = InMemoryChargeRepository(sessions: [
            makeSession(battery: active, start: Date().addingTimeInterval(-7200), end: Date().addingTimeInterval(-3600), level: .medium)
        ])

        let summary = await LiveHomeSummaryProvider(
            garage: garage,
            charges: charges,
            inspections: InMemoryInspectionRepository(garageRepository: garage)
        ).loadSummary()

        XCTAssertFalse(summary.isCharging)
        XCTAssertEqual(summary.batteries.map(\.name), ["Active pack"])
        XCTAssertEqual(summary.batteries.first?.risk, .medium)
    }

    func testHomeAsksForAFirstCheckWhenABatteryWasNeverInspected() async {
        let battery = makeBattery()
        let garage = InMemoryGarageRepository(batteries: [battery], chargers: [charger])

        let summary = await LiveHomeSummaryProvider(
            garage: garage,
            charges: InMemoryChargeRepository(),
            inspections: InMemoryInspectionRepository(garageRepository: garage)
        ).loadSummary()

        XCTAssertEqual(summary.attention.count, 1)
        XCTAssertTrue(summary.attention[0].title.contains("first check needed"))
    }

    func testHomeFlagsNothingAfterARecentPassingInspection() async {
        let battery = makeBattery()
        let garage = InMemoryGarageRepository(batteries: [battery], chargers: [charger])
        let inspections = InMemoryInspectionRepository(
            garageRepository: garage,
            inspections: [makeInspection(battery: battery, at: Date().addingTimeInterval(-86_400), result: .pass)]
        )

        let summary = await LiveHomeSummaryProvider(
            garage: garage,
            charges: InMemoryChargeRepository(),
            inspections: inspections
        ).loadSummary()

        XCTAssertTrue(summary.attention.isEmpty)
    }
}
