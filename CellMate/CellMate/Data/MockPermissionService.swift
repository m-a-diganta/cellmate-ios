/// Stand-in for SystemPermissionService in previews and tests.
/// A request turns notDetermined into whatever `answer` says, like tapping Allow or Don't Allow.
final class MockPermissionService: PermissionChecking {
    var notifications: PermissionStatus
    var camera: PermissionStatus
    var liveActivities: Bool
    var answer: PermissionStatus
    private(set) var notificationRequests = 0
    private(set) var cameraRequests = 0

    init(
        notifications: PermissionStatus = .notDetermined,
        camera: PermissionStatus = .notDetermined,
        liveActivities: Bool = true,
        answer: PermissionStatus = .granted
    ) {
        self.notifications = notifications
        self.camera = camera
        self.liveActivities = liveActivities
        self.answer = answer
    }

    func notificationStatus() async -> PermissionStatus { notifications }

    func requestNotifications() async -> PermissionStatus {
        notificationRequests += 1
        if notifications == .notDetermined { notifications = answer }
        return notifications
    }

    func cameraStatus() -> PermissionStatus { camera }

    func requestCamera() async -> PermissionStatus {
        cameraRequests += 1
        if camera == .notDetermined { camera = answer }
        return camera
    }

    func liveActivitiesEnabled() -> Bool { liveActivities }
}
