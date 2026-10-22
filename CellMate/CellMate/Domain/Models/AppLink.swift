import Foundation

/// Links the widget and the Live Activity use to open a screen in the app.
/// Shared with the widget target.
nonisolated enum AppLink {
    /// Opens the charge flow, which shows the Start charge form or the running charge.
    static let charge = URL(string: "cellmate://charge")!
    /// Opens the Garage tab, where batteries and chargers are added.
    static let garage = URL(string: "cellmate://garage")!
}
