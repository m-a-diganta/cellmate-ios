import Foundation

/// Schedules the unplug, bedtime and too-long alerts for a charge.
/// The real UserNotifications version belongs with the extensions work.
/// Until it exists the app uses NoOpNotificationScheduler.
@MainActor
protocol NotificationScheduling: AnyObject {
    /// "Unplug now" alert at the planned unplug time.
    func scheduleUnplugAlert(for session: ChargeSession, at date: Date)
    /// "Charge too long" alert after the grace window.
    func scheduleTooLongAlert(for session: ChargeSession, at date: Date)
    /// Bedtime warning if the charge will still be running at bedtime.
    func scheduleBedtimeWarning(for session: ChargeSession, at date: Date)
    /// Cancels every alert that belongs to a session (called when the charge ends).
    func cancelAlerts(forSessionID sessionID: UUID)
    /// Moves the unplug alert (used by "Add 30 minutes").
    func updateUnplugAlert(for session: ChargeSession, at date: Date)
}
