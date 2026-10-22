import Foundation
import UserNotifications

/// Schedules the unplug, bedtime and too-long alerts as local notifications.
/// A working stand-in until the extensions work ships its own version.
/// To swap it, change `notifications` in AppContainer.
@MainActor
final class ChargeAlertScheduler: NSObject, NotificationScheduling, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func scheduleUnplugAlert(for session: ChargeSession, at date: Date) {
        schedule(
            id: identifier(session.id, "unplug"),
            title: "Time to unplug",
            body: "Your planned unplug time has arrived. Unplug the battery now.",
            at: date
        )
    }

    func scheduleTooLongAlert(for session: ChargeSession, at date: Date) {
        schedule(
            id: identifier(session.id, "tooLong"),
            title: "Still charging",
            body: "This charge is running past the plan. Unplug it now to stay safe.",
            at: date
        )
    }

    func scheduleBedtimeWarning(for session: ChargeSession, at date: Date) {
        schedule(
            id: identifier(session.id, "bedtime"),
            title: "Still charging at bedtime",
            body: "Don’t leave a battery charging while you sleep.",
            at: date
        )
    }

    func cancelAlerts(forSessionID sessionID: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: [
            identifier(sessionID, "unplug"),
            identifier(sessionID, "tooLong"),
            identifier(sessionID, "bedtime")
        ])
    }

    /// "Add 30 minutes": moves the unplug alert and the too-long alert.
    func updateUnplugAlert(for session: ChargeSession, at date: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [
            identifier(session.id, "unplug"),
            identifier(session.id, "tooLong")
        ])
        scheduleUnplugAlert(for: session, at: date)
        scheduleTooLongAlert(
            for: session,
            at: date.addingTimeInterval(TimeInterval(RiskRulesVersion.tooLongGraceMinutes * 60))
        )
    }

    // MARK: - Helpers

    private func identifier(_ sessionID: UUID, _ kind: String) -> String {
        "\(sessionID.uuidString)-\(kind)"
    }

    private func schedule(id: String, title: String, body: String, at date: Date) {
        let seconds = date.timeIntervalSinceNow
        guard seconds > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: id,
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        )
        center.add(request) { _ in }
    }

    /// Show the alert as a banner even while the app is open.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
