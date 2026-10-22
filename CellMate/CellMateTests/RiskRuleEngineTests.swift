//
//  RiskRuleEngineTests.swift
//  CellMateTests
//
//  Unit tests for the versioned risk-rules engine (Person 3).
//  The engine is pure — dates are injected so tests are deterministic.
//

import XCTest
@testable import CellMate

@MainActor
final class RiskRuleEngineTests: XCTestCase {

    private let engine = RiskRuleEngine()

    // A test "now": 2026-10-20 09:00 local.
    private var morning: Date { CellMateDates.makeTime(hour: 9, minute: 0) }
    private var bedtime: Date { CellMateDates.makeTime(hour: 22, minute: 30) }

    /// Convenience: a benign daytime charge with matched charger.
    private func safeContext(start: Date? = nil,
                             plannedMinutes: Int = 120,
                             place: ChargePlace = .garage,
                             unattended: Bool = false,
                             matched: Bool = true) -> ChargeRiskContext {
        let start = start ?? morning
        return ChargeRiskContext(
            startedAt: start,
            plannedUnplug: start.addingTimeInterval(TimeInterval(plannedMinutes * 60)),
            plannedDurationMinutes: plannedMinutes,
            place: place,
            checklistTicks: [true, true, true],
            unattended: unattended,
            chargerMatchesBattery: matched,
            bedtime: bedtime)
    }

    // MARK: - Rule tests

    /// Rule: unmatched charger alone → High.
    func testUnmatchedChargerScoresHigh() {
        let result = engine.evaluate(safeContext(matched: false), referenceDate: morning)
        XCTAssertEqual(result.level, .high)
        XCTAssertTrue(result.flags.contains { $0.type == .unmatchedCharger })
    }

    /// Rule: unattended daytime charge → Medium.
    func testUnattendedScoresMedium() {
        let result = engine.evaluate(safeContext(unattended: true), referenceDate: morning)
        XCTAssertEqual(result.level, .medium)
        XCTAssertTrue(result.flags.contains { $0.type == .unattended })
    }

    /// Rule: "Other" place → Medium; Outside and Garage → no place flag.
    func testPlaceRule() {
        let other = engine.evaluate(safeContext(place: .other), referenceDate: morning)
        XCTAssertEqual(other.level, .medium)
        XCTAssertTrue(other.flags.contains { $0.type == .place })

        for cleanPlace in [ChargePlace.garage, .outside] {
            let r = engine.evaluate(safeContext(place: cleanPlace), referenceDate: morning)
            XCTAssertFalse(r.flags.contains { $0.type == .place }, "\(cleanPlace) should not flag")
        }
    }

    /// Rule: planned unplug crossing bedtime into deep night → High with bedtime flag.
    func testBedtimeCrossingScoresHigh() {
        // Start 21:30, planned 3h → unplug 00:30, crosses 22:30 bedtime by 2h → High actually.
        let start = CellMateDates.makeTime(hour: 21, minute: 30)
        let result = engine.evaluate(
            safeContext(start: start, plannedMinutes: 180),
            referenceDate: start)
        XCTAssertTrue(result.flags.contains { $0.type == .nearBedtime })
        // 120 min past bedtime + unattended overnight → High aggregation expected.
        XCTAssertEqual(result.level, .high)
    }

    /// Rule: planned duration > 8 hours → "too long" Medium flag up front.
    func testTooLongPlannedScoresMedium() {
        let result = engine.evaluate(safeContext(plannedMinutes: 540), referenceDate: morning)
        XCTAssertTrue(result.flags.contains { $0.type == .tooLong })
        XCTAssertEqual(result.level, .medium)
    }

    /// Rule: still running > 30 min past planned unplug → "too long" High flag.
    func testStillRunningPastPlanScoresHigh() {
        let context = safeContext(plannedMinutes: 120) // unplug at 11:00
        let lateRef = morning.addingTimeInterval(TimeInterval((120 + 45) * 60)) // 11:45
        let result = engine.evaluate(context, referenceDate: lateRef)
        XCTAssertTrue(result.flags.contains { $0.type == .tooLong && $0.severity == .high })
        XCTAssertEqual(result.level, .high)
    }

    // MARK: - Aggregation tests

    /// Two Medium flags → High.
    func testTwoMediumsAggregateToHigh() {
        let result = engine.evaluate(safeContext(place: .other, unattended: true),
                                     referenceDate: morning)
        let mediums = result.flags.filter { $0.severity == .medium }
        XCTAssertGreaterThanOrEqual(mediums.count, 2)
        XCTAssertEqual(result.level, .high)
    }

    /// Everything benign → Low with no flags.
    func testCleanChargeScoresLow() {
        let result = engine.evaluate(safeContext(), referenceDate: morning)
        XCTAssertEqual(result.level, .low)
        XCTAssertTrue(result.flags.isEmpty)
    }

    /// The engine version is recorded so charges can be traced to the rules that scored them.
    func testRulesVersionIsSet() {
        XCTAssertEqual(RiskRulesVersion.current, "v1.0")
        XCTAssertEqual(RiskRulesVersion.maxPlannedDurationHours, 8)
    }
}
