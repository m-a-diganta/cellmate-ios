import Foundation

enum PermissionStatus: Equatable {
    /// iOS hasn't asked yet, so asking shows the system alert.
    case notDetermined
    case granted
    /// Turned off. Only the Settings app can turn it back on.
    case denied
}

/// What screens need to know about iOS permissions.
/// The real one asks iOS. Previews and tests use MockPermissionService.
protocol PermissionChecking {
    func notificationStatus() async -> PermissionStatus
    /// Shows the system alert the first time. Returns the status afterwards.
    func requestNotifications() async -> PermissionStatus

    func cameraStatus() -> PermissionStatus
    /// Shows the system alert the first time. Returns the status afterwards.
    func requestCamera() async -> PermissionStatus

    /// Live Activities have no alert. They are on unless the user turns them off in Settings.
    func liveActivitiesEnabled() -> Bool
}
