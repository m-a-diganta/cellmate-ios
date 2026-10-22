/// Shared by the rules engine, History chips and the widget.
/// Comparable so the rules can ask "which is the higher level?".
enum RiskLevel: String, CaseIterable, Codable, Comparable {
    case low
    case medium
    case high

    private var rank: Int {
        switch self {
        case .low: 0
        case .medium: 1
        case .high: 2
        }
    }

    static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }

    /// "Low", "Medium" or "High".
    var displayName: String {
        switch self {
        case .low: "Low"
        case .medium: "Medium"
        case .high: "High"
        }
    }
}
