//
//  RiskRuleEngine.swift
//  CellMate
//
//  Versioned safety-rules engine (brief: Person 3 — "Risk rules: versioned engine
//  (bedtime, unattended, place, unmatched charger, too long); save level and flags").
//
//  Rules come from Fire and Rescue NSW advice and are fixed in code — the
//  assistant feature can never rewrite them. Flag wording is fixed here too.
//  Aggregation: any High → High; two or more Medium flags → High; one Medium →
//  Medium; otherwise Low.
//

import Foundation

struct RiskRulesVersion {
    /// Bump when a rule or threshold changes; the version used is saved with every charge.
    static let current = "v1.0"

    /// Grace window after the planned unplug before the "too long" flag fires.
    static let tooLongGraceMinutes: Int = 30

    /// Minutes around bedtime that count as "near bedtime".
    static let bedtimeWindowMinutes: Int = 60

    /// A planned charge longer than this is scored as "too long" up front.
    /// Matches the Live Activity 8-hour limit in the brief.
    static let maxPlannedDurationHours: Int = 8

    /// Extra minutes past bedtime before the overnight flag is upgraded to High.
    static let deepNightMinutesAfterBedtime: Int = 120
}

/// Everything the engine needs to score one charge.
struct ChargeRiskContext {
    var startedAt: Date
    var plannedUnplug: Date
    var plannedDurationMinutes: Int
    var place: ChargePlace
    /// Checklist — all three ticks are expected.
    var checklistTicks: [Bool]
    /// True when the user said nobody will be around (or charge runs while asleep).
    var unattended: Bool
    /// Charger belongs to this battery (matched pair from the Garage)?
    var chargerMatchesBattery: Bool
    /// User's bedtime from Settings (default 10:30 pm).
    var bedtime: Date

    init(startedAt: Date,
         plannedUnplug: Date,
         plannedDurationMinutes: Int,
         place: ChargePlace,
         checklistTicks: [Bool],
         unattended: Bool,
         chargerMatchesBattery: Bool,
         bedtime: Date = BedtimeSetting.date(fromMinutes: BedtimeSetting.defaultMinutes)) {
        self.startedAt = startedAt
        self.plannedUnplug = plannedUnplug
        self.plannedDurationMinutes = plannedDurationMinutes
        self.place = place
        self.checklistTicks = checklistTicks
        self.unattended = unattended
        self.chargerMatchesBattery = chargerMatchesBattery
        self.bedtime = bedtime
    }
}

/// Pure, deterministic rules engine — no UI, no database, fully unit-testable.
struct RiskRuleEngine {

    /// Scores a charge from its context.
    /// - Parameter referenceDate: "now" for evaluation (injectable for tests).
    func evaluate(_ context: ChargeRiskContext,
                  referenceDate: Date = Date()) -> RiskAssessment {
        var flags: [RiskFlag] = []
        flags += bedtimeFlag(context, referenceDate: referenceDate)
        flags += unattendedFlag(context)
        flags += placeFlag(context)
        flags += unmatchedChargerFlag(context)
        flags += tooLongFlags(context, referenceDate: referenceDate)

        return RiskAssessment(level: aggregate(flags), flags: flags)
    }

    // MARK: - Rules

    /// Rule 1 — Bedtime / overnight. Charging into or past bedtime is a risk;
    /// deep into the night (2h+ past bedtime) is worse.
    private func bedtimeFlag(_ c: ChargeRiskContext, referenceDate: Date) -> [RiskFlag] {
        let bedtimeToday = CellMateDates.bedtime(on: c.startedAt, bedtime: c.bedtime)
        guard c.plannedUnplug > bedtimeToday.addingTimeInterval(0) else { return [] }

        let minutesIntoNight = Calendar.current.dateComponents([.minute],
            from: bedtimeToday, to: c.plannedUnplug).minute ?? 0

        // Unattended + overnight is the classic e-bike fire scenario.
        let severity: RiskLevel = minutesIntoNight >= RiskRulesVersion.deepNightMinutesAfterBedtime
            ? .high
            : .medium
        var message = "Charging runs \(minutesIntoNight) min past bedtime (\(formatted(c.bedtime)))"
        if c.unattended {
            message += " and will be unattended overnight"
        }
        var flag = RiskFlag(type: .nearBedtime, severity: severity, message: message)
        if minutesIntoNight > 0 && c.unattended { flag.severity = max(severity, .medium) }
        return [flag]
    }

    /// Rule 2 — Unattended (during waking hours). Overnight unattended is already
    /// covered by rule 1; this catches daytime "nobody home" charges.
    private func unattendedFlag(_ c: ChargeRiskContext) -> [RiskFlag] {
        let bedtimeToday = CellMateDates.bedtime(on: c.startedAt, bedtime: c.bedtime)
        // If the charge is overnight, rule 1 already carries the unattended risk.
        guard c.plannedUnplug <= bedtimeToday else { return [] }
        guard c.unattended else { return [] }
        return [RiskFlag(type: .unattended,
                         severity: .medium,
                         message: "Battery will be charging unattended")]
    }

    /// Rule 3 — Place. Outside is what FRNSW recommends; a garage away from exits
    /// is acceptable; anything else (living space, unclear) is a Medium flag.
    private func placeFlag(_ c: ChargeRiskContext) -> [RiskFlag] {
        switch c.place {
        case .outside, .garage:
            return []
        case .other:
            return [RiskFlag(type: .place,
                             severity: .medium,
                             message: "Charging in an unspecified place — keep it away from exits and living spaces")]
        }
    }

    /// Rule 4 — Unmatched charger. Wrong charger is the single highest-risk factor.
    private func unmatchedChargerFlag(_ c: ChargeRiskContext) -> [RiskFlag] {
        guard !c.chargerMatchesBattery else { return [] }
        return [RiskFlag(type: .unmatchedCharger,
                         severity: .high,
                         message: "Charger is not the matched charger for this battery")]
    }

    /// Rule 5 — Too long. Fires up front if the plan exceeds 8 hours, and again
    /// (on re-evaluation) if the charge is still running past planned unplug + grace.
    private func tooLongFlags(_ c: ChargeRiskContext, referenceDate: Date) -> [RiskFlag] {
        var flags: [RiskFlag] = []

        let plannedHours = Double(c.plannedDurationMinutes) / 60.0
        if plannedHours > Double(RiskRulesVersion.maxPlannedDurationHours) {
            flags.append(RiskFlag(type: .tooLong,
                                  severity: .medium,
                                  message: "Planned charge is \(formattedHours(plannedHours)) — longer than the \(RiskRulesVersion.maxPlannedDurationHours)-hour limit"))
        }

        let grace = TimeInterval(RiskRulesVersion.tooLongGraceMinutes * 60)
        if referenceDate > c.plannedUnplug.addingTimeInterval(grace) {
            let overtimeMinutes = Calendar.current.dateComponents([.minute],
                from: c.plannedUnplug, to: referenceDate).minute ?? 0
            flags.append(RiskFlag(type: .tooLong,
                                  severity: .high,
                                  message: "Charge is still running \(overtimeMinutes) min after the planned unplug"))
        }
        return flags
    }

    // MARK: - Aggregation

    /// any High → High · ≥2 Medium → High · 1 Medium → Medium · else Low.
    func aggregate(_ flags: [RiskFlag]) -> RiskLevel {
        let highs = flags.filter { $0.severity == .high }.count
        let mediums = flags.filter { $0.severity == .medium }.count
        if highs > 0 || mediums >= 2 { return .high }
        if mediums == 1 { return .medium }
        return .low
    }

    // MARK: - Formatting

    private func formatted(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func formattedHours(_ hours: Double) -> String {
        String(format: "%.1f h", hours)
    }
}
