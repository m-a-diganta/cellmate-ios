import Foundation

/// Used until the real notification scheduler exists. Schedules nothing.
@MainActor
final class NoOpNotificationScheduler: NotificationScheduling {
    func scheduleUnplugAlert(for session: ChargeSession, at date: Date) {}
    func scheduleTooLongAlert(for session: ChargeSession, at date: Date) {}
    func scheduleBedtimeWarning(for session: ChargeSession, at date: Date) {}
    func cancelAlerts(forSessionID sessionID: UUID) {}
    func updateUnplugAlert(for session: ChargeSession, at date: Date) {}
}

/// Records every call so tests can check what was scheduled.
@MainActor
final class MockNotificationScheduler: NotificationScheduling {
    private(set) var scheduled: [(sessionID: UUID, kind: String, date: Date)] = []
    private(set) var cancelled: [UUID] = []

    func scheduleUnplugAlert(for session: ChargeSession, at date: Date) {
        scheduled.append((session.id, "unplug", date))
    }

    func scheduleTooLongAlert(for session: ChargeSession, at date: Date) {
        scheduled.append((session.id, "tooLong", date))
    }

    func scheduleBedtimeWarning(for session: ChargeSession, at date: Date) {
        scheduled.append((session.id, "bedtime", date))
    }

    func cancelAlerts(forSessionID sessionID: UUID) {
        cancelled.append(sessionID)
    }

    func updateUnplugAlert(for session: ChargeSession, at date: Date) {
        scheduled.append((session.id, "unplug-update", date))
    }
}

/// Stands in for the Live Activity in tests and previews.
@MainActor
final class MockChargeActivityController: ChargeActivityControlling {
    /// Set this to make `start` fail, for example `.turnedOff`.
    var startError: ChargeActivityError?
    private(set) var startedBatteryNames: [String] = []
    private(set) var updatedUnplugTimes: [Date] = []
    private(set) var endCount = 0

    func start(batteryName: String, startedAt: Date, unplugAt: Date) throws {
        if let startError { throw startError }
        startedBatteryNames.append(batteryName)
    }

    func update(unplugAt: Date) async {
        updatedUnplugTimes.append(unplugAt)
    }

    func end() async {
        endCount += 1
    }
}
