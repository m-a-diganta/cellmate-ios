import ActivityKit
import Foundation

/// What the charge Live Activity shows. Shared by the app and the widget extension.
nonisolated struct ChargeActivityAttributes: ActivityAttributes {
    /// The parts that can change while charging, e.g. "Add 30 minutes" moves `unplugAt`.
    nonisolated struct ContentState: Codable, Hashable {
        var startedAt: Date
        var unplugAt: Date
    }

    var batteryName: String
}

extension ChargeActivityAttributes {
    static let preview = ChargeActivityAttributes(batteryName: "Commuter e-bike")
}

extension ChargeActivityAttributes.ContentState {
    static let preview = ChargeActivityAttributes.ContentState(
        startedAt: .now.addingTimeInterval(-36 * 60),
        unplugAt: .now.addingTimeInterval(84 * 60)
    )
}
