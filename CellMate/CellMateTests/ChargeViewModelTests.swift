import XCTest
@testable import CellMate

@MainActor
final class ChargeViewModelTests: XCTestCase {

    private func makeViewModel() -> (ChargeViewModel, InMemoryChargeRepository, Battery, Charger) {
        let charger = Charger(name: "Stock charger", brand: "InMotion")
        let battery = Battery(
            name: "Main pack",
            brand: "InMotion",
            capacityWh: 500,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            chargerID: charger.id
        )
        let garage = InMemoryGarageRepository(batteries: [battery], chargers: [charger])
        let charges = InMemoryChargeRepository()
        let viewModel = ChargeViewModel(
            chargeRepository: charges,
            garageRepository: garage,
            notifications: MockNotificationScheduler(),
            activity: MockChargeActivityController(),
            bedtimeProvider: { CellMateDates.makeTime(hour: 23, minute: 59) }
        )
        return (viewModel, charges, battery, charger)
    }

    func testLoadPicksTheFirstBatteryAndItsCharger() async {
        let (viewModel, _, battery, charger) = makeViewModel()
        await viewModel.load()

        XCTAssertEqual(viewModel.selectedBatteryID, battery.id)
        XCTAssertEqual(viewModel.selectedChargerID, charger.id)
        XCTAssertTrue(viewModel.chargerMatchesSelectedBattery)
    }

    func testCannotStartUntilAllThreeChecksAreTicked() async {
        let (viewModel, _, _, _) = makeViewModel()
        await viewModel.load()
        XCTAssertFalse(viewModel.canStart)

        viewModel.checklist[0].ticked = true
        viewModel.checklist[1].ticked = true
        XCTAssertFalse(viewModel.canStart)

        viewModel.checklist[2].ticked = true
        XCTAssertTrue(viewModel.canStart)
    }

    func testFullFlowFromStartToDone() async {
        let (viewModel, charges, _, _) = makeViewModel()
        await viewModel.load()
        for index in viewModel.checklist.indices { viewModel.checklist[index].ticked = true }

        await viewModel.startChargeTapped()
        XCTAssertEqual(viewModel.phase, .charging)
        XCTAssertNotNil(charges.anyRunningSession())

        await viewModel.unpluggedTapped()
        XCTAssertEqual(viewModel.phase, .complete)
        XCTAssertNotNil(viewModel.completedAssessment)
        XCTAssertNil(charges.anyRunningSession())

        viewModel.doneTapped()
        XCTAssertEqual(viewModel.phase, .form)
        XCTAssertFalse(viewModel.canStart)
    }

    func testStartingWithoutTicksShowsAnError() async {
        let (viewModel, charges, _, _) = makeViewModel()
        await viewModel.load()

        await viewModel.startChargeTapped()

        XCTAssertEqual(viewModel.phase, .form)
        XCTAssertNotNil(viewModel.errorMessage)
        XCTAssertNil(charges.anyRunningSession())
    }

    func testBatteryChosenBeforeLoadKeepsItsCharger() async {
        let (viewModel, _, battery, charger) = makeViewModel()
        // This is what tapping "Start charge" on a battery in Garage does.
        viewModel.selectBattery(battery.id)
        XCTAssertNil(viewModel.selectedChargerID)

        await viewModel.load()

        XCTAssertEqual(viewModel.selectedBatteryID, battery.id)
        XCTAssertEqual(viewModel.selectedChargerID, charger.id)
        XCTAssertTrue(viewModel.chargerMatchesSelectedBattery)
    }
}
