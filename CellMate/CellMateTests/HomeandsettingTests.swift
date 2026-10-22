import XCTest
@testable import CellMate


@MainActor
final class BedtimeSettingTests: XCTestCase {

    func testDefaultIsTenThirtyPM() {
        XCTAssertEqual(BedtimeSetting.defaultMinutes, 22 * 60 + 30)
    }

    func testMinutesSurviveARoundTrip() {
        let date = BedtimeSetting.date(fromMinutes: 23 * 60 + 5)
        XCTAssertEqual(BedtimeSetting.minutes(from: date), 23 * 60 + 5)
    }

    func testMidnightIsZeroMinutes() {
        let date = BedtimeSetting.date(fromMinutes: 0)
        XCTAssertEqual(BedtimeSetting.minutes(from: date), 0)
    }
}


@MainActor
final class HomeFormattersTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testHoursAndMinutes() {
        XCTAssertEqual(TimeLeftFormatter.text(until: now.addingTimeInterval(84 * 60), now: now), "1h 24m left")
    }

    func testWholeHours() {
        XCTAssertEqual(TimeLeftFormatter.text(until: now.addingTimeInterval(120 * 60), now: now), "2h left")
    }

    func testMinutesOnly() {
        XCTAssertEqual(TimeLeftFormatter.text(until: now.addingTimeInterval(30 * 60), now: now), "30m left")
    }

    func testPartialMinuteRoundsUp() {
        XCTAssertEqual(TimeLeftFormatter.text(until: now.addingTimeInterval(30), now: now), "1m left")
    }

    func testPastTimeSaysUnplugNow() {
        XCTAssertEqual(TimeLeftFormatter.text(until: now.addingTimeInterval(-60), now: now), "Unplug now")
    }

    func testLastChargedToday() {
        XCTAssertEqual(LastChargedFormatter.text(for: now, now: now), "Last charged today")
    }

    func testLastChargedYesterday() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: now)!
        XCTAssertEqual(LastChargedFormatter.text(for: yesterday, now: now), "Last charged yesterday")
    }
}


@MainActor
final class HomeViewModelTests: XCTestCase {

    func testStartsEmpty() async {
        let viewModel = HomeViewModel(provider: MockHomeSummaryProvider(scenario: .charging))
        XCTAssertFalse(viewModel.summary.isCharging)
        XCTAssertTrue(viewModel.summary.batteries.isEmpty)
    }

    func testLoadShowsTheChargingState() async {
        let viewModel = HomeViewModel(provider: MockHomeSummaryProvider(scenario: .charging))
        await viewModel.load()
        XCTAssertTrue(viewModel.summary.isCharging)
        XCTAssertFalse(viewModel.summary.batteries.isEmpty)
    }

    func testLoadShowsTheIdleState() async {
        let viewModel = HomeViewModel(provider: MockHomeSummaryProvider(scenario: .idle))
        await viewModel.load()
        XCTAssertFalse(viewModel.summary.isCharging)
    }
}
