import Foundation
import Observation

@Observable
final class PermissionsViewModel {
    private(set) var notifications: PermissionStatus = .notDetermined
    private(set) var camera: PermissionStatus = .notDetermined

    private let permissions: any PermissionChecking

    init(permissions: any PermissionChecking) {
        self.permissions = permissions
    }

    /// Reads the current statuses. Also called when the user comes back from Settings.
    func load() async {
        notifications = await permissions.notificationStatus()
        camera = permissions.cameraStatus()
    }

    func allowNotifications() async {
        notifications = await permissions.requestNotifications()
    }

    func allowCamera() async {
        camera = await permissions.requestCamera()
    }

    /// Continue asks for notifications if iOS hasn't asked yet. Camera stays optional,
    /// so it is only asked for when the user taps Allow on its row.
    func continueTapped() async {
        if notifications == .notDetermined {
            await allowNotifications()
        }
    }
}
