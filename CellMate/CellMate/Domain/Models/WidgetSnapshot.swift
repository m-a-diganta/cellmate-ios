import Foundation

/// What the Home Screen widget shows. The app saves it, the widget reads it.
/// Shared with the widget target.
nonisolated struct WidgetSnapshot: Codable, Equatable {
    struct Charge: Codable, Equatable {
        var batteryName: String
        var startedAt: Date
        var unplugAt: Date
    }

    /// The charge running now, if any.
    var charge: Charge?
    /// When the last finished charge was unplugged.
    var lastChargedAt: Date?
    /// The soonest inspection due across active batteries. Nil when there are none.
    var nextInspectionDue: Date?

    static let empty = WidgetSnapshot(charge: nil, lastChargedAt: nil, nextInspectionDue: nil)
}
