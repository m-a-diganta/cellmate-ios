import ActivityKit
import AVFoundation
import UIKit
import UserNotifications

/// Asks iOS for permissions. Each request shows Apple's own alert the first time only.
struct SystemPermissionService: PermissionChecking {
    private let center = UNUserNotificationCenter.current()

    func notificationStatus() async -> PermissionStatus {
        switch await center.notificationSettings().authorizationStatus {
        case .authorized, .provisional, .ephemeral: .granted
        case .denied: .denied
        case .notDetermined: .notDetermined
        @unknown default: .denied
        }
    }

    func requestNotifications() async -> PermissionStatus {
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        return await notificationStatus()
    }

    func cameraStatus() -> PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: .granted
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    func requestCamera() async -> PermissionStatus {
        _ = await AVCaptureDevice.requestAccess(for: .video)
        return cameraStatus()
    }

    func liveActivitiesEnabled() -> Bool {
        ActivityAuthorizationInfo().areActivitiesEnabled
    }
}

/// Opens CellMate's page in the Settings app, the only place a denied permission can be turned back on.
enum SystemSettings {
    static let url = URL(string: UIApplication.openSettingsURLString)
}
