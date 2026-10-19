import Foundation

/// Everything the Home screen shows. Later, a use case builds this from the database.
struct HomeSummary {
    enum ChargeState {
        case charging(ActiveCharge)
        case idle(lastCharge: CompletedCharge?)
    }

    var chargeState: ChargeState
    var attention: [AttentionItem]
    var batteries: [BatterySummary]

    var isCharging: Bool {
        if case .charging = chargeState { return true }
        return false
    }

    static let empty = HomeSummary(chargeState: .idle(lastCharge: nil), attention: [], batteries: [])
}

struct ActiveCharge {
    let batteryName: String
    let startedAt: Date
    let unplugBy: Date
}

struct CompletedCharge {
    let batteryName: String
    let unpluggedAt: Date
}

struct AttentionItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
}

struct BatterySummary: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let risk: RiskLevel
}

// MARK: - Sample data for previews and the first run

extension HomeSummary {
    private static var sampleBatteries: [BatterySummary] {
        [
            BatterySummary(name: "Battery A", detail: "Bosch · 720 Wh", risk: .low),
            BatterySummary(name: "Battery B", detail: "Segway · 551 Wh", risk: .low)
        ]
    }

    private static var sampleAttention: [AttentionItem] {
        [AttentionItem(title: "Battery B · check due soon", subtitle: "Last inspected 18 Sep · check by 18 Oct")]
    }

    static var sampleCharging: HomeSummary {
        let now = Date()
        let charge = ActiveCharge(
            batteryName: "Battery A",
            startedAt: now.addingTimeInterval(-36 * 60),
            unplugBy: now.addingTimeInterval(84 * 60)
        )
        return HomeSummary(chargeState: .charging(charge), attention: sampleAttention, batteries: sampleBatteries)
    }

    static var sampleIdle: HomeSummary {
        let last = CompletedCharge(
            batteryName: "Battery A",
            unpluggedAt: Date().addingTimeInterval(-3 * 24 * 60 * 60)
        )
        return HomeSummary(chargeState: .idle(lastCharge: last), attention: sampleAttention, batteries: sampleBatteries)
    }
}

/// Where Home gets its data. Replace the mock with a use case that reads the database.
protocol HomeSummaryProviding {
    func loadSummary() async -> HomeSummary
}

/// Fake data so Home runs before the database exists.
/// Change `scenario` to see the other states: .charging, .idle or .empty.
struct MockHomeSummaryProvider: HomeSummaryProviding {
    enum Scenario {
        case charging
        case idle
        case empty
    }

    var scenario: Scenario = .charging

    func loadSummary() async -> HomeSummary {
        switch scenario {
        case .charging: return .sampleCharging
        case .idle: return .sampleIdle
        case .empty: return .empty
        }
    }
}
