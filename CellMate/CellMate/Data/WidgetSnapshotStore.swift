import Foundation

/// Keeps the widget snapshot in the App Group, the one place the app and the widget can both read.
/// Shared with the widget target.
nonisolated enum WidgetSnapshotStore {
    static let appGroupID = "group.com.diganta.CellMate"
    private static let key = "widgetSnapshot"

    /// Falls back to the app's own defaults if the App Group is missing, so nothing crashes.
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return snapshot
    }

    static func save(_ snapshot: WidgetSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        defaults.set(data, forKey: key)
    }
}
