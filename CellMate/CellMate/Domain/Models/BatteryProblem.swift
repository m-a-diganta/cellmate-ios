import Foundation

nonisolated enum BatterySymptom: String, CaseIterable, Identifiable, Codable, Sendable {
    case smokeOrFlames, hissingOrPopping, swelling, excessiveHeat, unusualSmell
    case leaking, physicalDamage, chargerConcern, unsafeCharging, unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .smokeOrFlames: "Smoke or flames"
        case .hissingOrPopping: "Hissing or popping"
        case .swelling: "Swollen or bulging"
        case .excessiveHeat: "Unusually hot"
        case .unusualSmell: "Unusual smell"
        case .leaking: "Leaking liquid"
        case .physicalDamage: "Cracked or damaged"
        case .chargerConcern: "Charger concern"
        case .unsafeCharging: "Charging unattended or overnight"
        case .unknown: "Something else / unsure"
        }
    }
}

nonisolated enum BatteryAdviceLevel: Int, Comparable, Codable, Sendable {
    case info, caution, stopUsing, emergency

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    var title: String {
        switch self {
        case .info: "Info"
        case .caution: "Caution"
        case .stopUsing: "Stop using"
        case .emergency: "Emergency"
        }
    }
}

/// A read-only projection of Person 1/4's battery record, not a second database model.
nonisolated struct AskBattery: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let brand: String
    let isRetired: Bool
}

nonisolated struct BatteryAssessment: Identifiable, Equatable, Sendable {
    let id: UUID
    let date: Date
    let symptoms: Set<BatterySymptom>
    let level: BatteryAdviceLevel
    let source: Source
    let rulesVersion: String
    let needsQuickCheck: Bool
    let batteryID: UUID?

    enum Source: String, Sendable { case rules, assistant, quickCheck }
}

nonisolated enum BatteryAssistantAvailability: Equatable, Sendable {
    case available
    case unavailable(String)
}

nonisolated enum BatteryProblemError: LocalizedError {
    case emptyInput, inputTooLong, incompleteCheck, batteryRequired, integrationUnavailable

    var errorDescription: String? {
        switch self {
        case .emptyInput: "Describe a concern or choose a symptom."
        case .inputTooLong: "Please keep your description under 1,000 characters."
        case .incompleteCheck: "Select any signs you noticed, or confirm that none of the listed signs were noticed."
        case .batteryRequired: "Choose the battery this assessment belongs to."
        case .integrationUnavailable: "Inspection saving is not available in this build yet. Your result has not been saved."
        }
    }
}
