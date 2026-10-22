//
//  EvaluateInspectionDueTests.swift
//  CellMateTests
//
//  Created by Yufan on 22/10/2026.
//

import Foundation
import XCTest
@testable import CellMate

@MainActor
final class EvaluateInspectionDueTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(
            identifier: "Australia/Sydney"
        )!
        return calendar
    }

    func testBatteryWithoutInspectionNeedsFirstInspection() throws {
        let battery = makeBattery()
        let evaluator = makeEvaluator(now: date(2026, 10, 22))

        let status = try evaluator.execute(
            battery: battery,
            latestInspection: nil
        )

        XCTAssertEqual(status, .neverInspected)
    }

    func testEightDaysBeforeDeadlineIsUpToDate() throws {
        let battery = makeBattery()
        let inspection = makeInspection(
            battery: battery,
            inspectedAt: date(2026, 10, 1)
        )

        let status = try makeEvaluator(
            now: date(2026, 10, 23)
        ).execute(
            battery: battery,
            latestInspection: inspection
        )

        XCTAssertEqual(
            status,
            .upToDate(nextDueDate: date(2026, 10, 31))
        )
    }

    func testSevenDaysBeforeDeadlineIsDueSoon() throws {
        let battery = makeBattery()
        let inspection = makeInspection(
            battery: battery,
            inspectedAt: date(2026, 10, 1)
        )

        let status = try makeEvaluator(
            now: date(2026, 10, 24)
        ).execute(
            battery: battery,
            latestInspection: inspection
        )

        XCTAssertEqual(
            status,
            .dueSoon(dueDate: date(2026, 10, 31))
        )
    }

    func testThirtyDaysAfterInspectionIsDueToday() throws {
        let battery = makeBattery()
        let inspection = makeInspection(
            battery: battery,
            inspectedAt: date(2026, 10, 1, hour: 15)
        )

        let status = try makeEvaluator(
            now: date(2026, 10, 31, hour: 9)
        ).execute(
            battery: battery,
            latestInspection: inspection
        )

        XCTAssertEqual(
            status,
            .dueToday(dueDate: date(2026, 10, 31))
        )
    }

    func testDayAfterDeadlineIsOverdue() throws {
        let battery = makeBattery()
        let inspection = makeInspection(
            battery: battery,
            inspectedAt: date(2026, 10, 1)
        )

        let status = try makeEvaluator(
            now: date(2026, 11, 1)
        ).execute(
            battery: battery,
            latestInspection: inspection
        )

        XCTAssertEqual(
            status,
            .overdue(dueDate: date(2026, 10, 31))
        )
    }

    func testFailedOrCautionInspectionNeedsAttention() throws {
        let battery = makeBattery()

        for result in [Inspection.Result.fail, .caution] {
            let inspection = makeInspection(
                battery: battery,
                inspectedAt: date(2026, 10, 21),
                result: result
            )

            let status = try makeEvaluator(
                now: date(2026, 10, 22)
            ).execute(
                battery: battery,
                latestInspection: inspection
            )

            XCTAssertEqual(status, .needsAttention)
        }
    }

    func testReportedProblemOverridesPassingResult() throws {
        let battery = makeBattery()

        // Defensive check for inconsistent imported or stored data.
        let inspection = makeInspection(
            battery: battery,
            inspectedAt: date(2026, 10, 21),
            result: .pass,
            hasProblem: true
        )

        let status = try makeEvaluator(
            now: date(2026, 10, 22)
        ).execute(
            battery: battery,
            latestInspection: inspection
        )

        XCTAssertEqual(status, .needsAttention)
    }

    func testRetiredBatteryDoesNotNeedRoutineInspection() throws {
        let battery = makeBattery(
            status: .retired(reason: "No longer in use")
        )

        let status = try makeEvaluator(
            now: date(2026, 10, 22)
        ).execute(
            battery: battery,
            latestInspection: nil
        )

        XCTAssertEqual(status, .notRequired)
    }

    func testInspectionForDifferentBatteryIsRejected() throws {
        let battery = makeBattery()
        let otherBattery = makeBattery()

        let inspection = makeInspection(
            battery: otherBattery,
            inspectedAt: date(2026, 10, 21)
        )

        XCTAssertThrowsError(
            try makeEvaluator(now: date(2026, 10, 22)).execute(
                battery: battery,
                latestInspection: inspection
            )
        ) { error in
            XCTAssertEqual(
                error as? EvaluateInspectionDue.EvaluationError,
                .wrongBattery
            )
        }
    }

    func testFutureInspectionIsRejected() throws {
        let battery = makeBattery()

        let inspection = makeInspection(
            battery: battery,
            inspectedAt: date(2026, 10, 22, hour: 13)
        )

        XCTAssertThrowsError(
            try makeEvaluator(
                now: date(2026, 10, 22, hour: 12)
            ).execute(
                battery: battery,
                latestInspection: inspection
            )
        ) { error in
            XCTAssertEqual(
                error as? EvaluateInspectionDue.EvaluationError,
                .futureInspectionDate
            )
        }
    }

    func testDeadlineUsesCalendarDaysAcrossDaylightSaving() throws {
        let battery = makeBattery()

        let inspection = makeInspection(
            battery: battery,
            inspectedAt: date(2026, 9, 20, hour: 14)
        )

        let status = try makeEvaluator(
            now: date(2026, 10, 20, hour: 12)
        ).execute(
            battery: battery,
            latestInspection: inspection
        )

        // Sydney's clock changes during this interval.
        // The deadline must still be midnight on 20 October.
        XCTAssertEqual(
            status,
            .dueToday(dueDate: date(2026, 10, 20))
        )
    }

    private func makeEvaluator(
        now: Date
    ) -> EvaluateInspectionDue {
        EvaluateInspectionDue(
            calendar: calendar,
            now: { now }
        )
    }

    private func makeBattery(
        status: Battery.Status = .active
    ) -> Battery {
        Battery(
            name: "Battery A",
            brand: "Bosch",
            capacityWh: 720,
            purchaseDate: date(2026, 1, 1),
            chargerID: UUID(),
            status: status
        )
    }

    private func makeInspection(
        battery: Battery,
        inspectedAt: Date,
        result: Inspection.Result = .pass,
        hasProblem: Bool = false
    ) -> Inspection {
        let items = Inspection.Item.Kind.allCases.map { kind in
            Inspection.Item(
                kind: kind,
                finding: hasProblem && kind == .swelling
                    ? .problem
                    : .ok
            )
        }

        return Inspection(
            batteryID: battery.id,
            inspectedAt: inspectedAt,
            source: .manual,
            result: result,
            items: items
        )
    }

    private func date(
        _ year: Int,
        _ month: Int,
        _ day: Int,
        hour: Int = 0
    ) -> Date {
        calendar.date(
            from: DateComponents(
                year: year,
                month: month,
                day: day,
                hour: hour
            )
        )!
    }
}
