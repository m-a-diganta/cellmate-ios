import Foundation

// MARK: - Risk

enum RiskFlagType: String, Codable, CaseIterable {
    case nearBedtime       // charging past or close to bedtime
    case unattended        // charging while nobody is around
    case place             // risky place (living space or unclear)
    case unmatchedCharger  // charger is not the battery's matched charger
    case tooLong           // charge runs (or is planned) too long
}

/// One rule outcome saved with the charge: type, severity, message.
struct RiskFlag: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var type: RiskFlagType
    var severity: RiskLevel
    var message: String
}

/// Full result of a rules-engine run.
struct RiskAssessment: Equatable {
    var level: RiskLevel
    var flags: [RiskFlag]
}

// MARK: - Charge

/// Place picker on the Start charge screen.
enum ChargePlace: String, Codable, CaseIterable, Identifiable {
    case garage
    case outside
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .garage: "Garage"
        case .outside: "Outside"
        case .other: "Other"
        }
    }
}

enum ChargeSessionStatus: String, Codable {
    case running
    case completed
}

/// One charge: start, end, planned unplug, place, checklist ticks, overnight,
/// risk level and the rules version that scored it.
struct ChargeSession: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var batteryID: UUID
    var chargerID: UUID
    var startedAt: Date
    var endedAt: Date?
    /// The moment the user said they would unplug (start + planned duration).
    var plannedUnplug: Date
    var plannedDurationMinutes: Int
    var place: ChargePlace
    /// 3-point checklist ticks, in display order.
    var checklistTicks: [Bool]
    var checklistLabels: [String]
    /// True when the planned unplug crosses the user's bedtime.
    var overnight: Bool
    var status: ChargeSessionStatus = .running
    /// Saved when the session starts and again when it ends.
    var riskLevel: RiskLevel?
    var riskFlags: [RiskFlag] = []
    /// Version of the rules engine used (for example "v1.0"), saved with the charge.
    var rulesVersion: String
}

// MARK: - Date helpers

enum CellMateDates {
    /// A Date on `date`'s day with the given hour and minute (local time).
    static func makeTime(hour: Int, minute: Int, on date: Date = Date()) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: date) ?? date
    }

    /// Same wall-clock time as `bedtime`, placed on the day of `date`.
    static func bedtime(on date: Date, bedtime: Date) -> Date {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: bedtime)
        return Calendar.current.date(
            bySettingHour: parts.hour ?? 22,
            minute: parts.minute ?? 30,
            second: 0,
            of: date
        ) ?? date
    }
}
