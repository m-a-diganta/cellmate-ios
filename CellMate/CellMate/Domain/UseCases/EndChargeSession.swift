import Foundation

enum EndChargeError: Error, Equatable {
    case sessionNotFound
    case alreadyEnded
}

struct EndChargeResult {
    var session: ChargeSession
    var assessment: RiskAssessment
}

/// Called from the Charging screen ("I've unplugged") and from "Add 30 minutes".
final class EndChargeSession {
    private let chargeRepository: any ChargeRepository
    private let garageRepository: any GarageRepository
    private let notifications: any NotificationScheduling
    private let activity: any ChargeActivityControlling
    private let engine: RiskRuleEngine
    private let bedtimeProvider: () -> Date

    init(
        chargeRepository: any ChargeRepository,
        garageRepository: any GarageRepository,
        notifications: any NotificationScheduling,
        activity: any ChargeActivityControlling,
        engine: RiskRuleEngine = RiskRuleEngine(),
        bedtimeProvider: @escaping () -> Date = { BedtimeSetting.current() }
    ) {
        self.chargeRepository = chargeRepository
        self.garageRepository = garageRepository
        self.notifications = notifications
        self.activity = activity
        self.engine = engine
        self.bedtimeProvider = bedtimeProvider
    }

    /// Ends the charge at `unpluggedAt` and saves the final risk.
    func execute(sessionID: UUID, unpluggedAt: Date = Date()) async throws -> EndChargeResult {
        guard var session = chargeRepository.session(withID: sessionID) else {
            throw EndChargeError.sessionNotFound
        }
        guard session.status == .running else {
            throw EndChargeError.alreadyEnded
        }

        // Score again with the real end time. Unplugging far past the plan adds the "too long" flag.
        let battery = await garageRepository.findBattery(id: session.batteryID)
        let bedtime = bedtimeProvider()
        let bedtimeOnStartDay = CellMateDates.bedtime(on: session.startedAt, bedtime: bedtime)
        let context = ChargeRiskContext(
            startedAt: session.startedAt,
            plannedUnplug: session.plannedUnplug,
            plannedDurationMinutes: session.plannedDurationMinutes,
            place: session.place,
            checklistTicks: session.checklistTicks,
            unattended: unpluggedAt > session.plannedUnplug || unpluggedAt > bedtimeOnStartDay,
            chargerMatchesBattery: battery?.chargerID == session.chargerID,
            bedtime: bedtime
        )
        let assessment = engine.evaluate(context, referenceDate: unpluggedAt)

        session.endedAt = unpluggedAt
        session.status = .completed
        session.riskLevel = assessment.level
        session.riskFlags = assessment.flags
        chargeRepository.update(session)

        await activity.end()
        notifications.cancelAlerts(forSessionID: session.id)

        return EndChargeResult(session: session, assessment: assessment)
    }

    /// "Add 30 minutes": moves the planned unplug and re-arms the alert and the Live Activity.
    func extend(sessionID: UUID, byMinutes minutes: Int = 30, now: Date = Date()) async throws -> ChargeSession {
        guard var session = chargeRepository.session(withID: sessionID) else {
            throw EndChargeError.sessionNotFound
        }
        guard session.status == .running else {
            throw EndChargeError.alreadyEnded
        }
        let newUnplug = max(session.plannedUnplug, now)
            .addingTimeInterval(TimeInterval(minutes * 60))
        session.plannedUnplug = newUnplug
        session.plannedDurationMinutes += minutes
        chargeRepository.update(session)

        await activity.update(unplugAt: newUnplug)
        notifications.updateUnplugAlert(for: session, at: newUnplug)
        return session
    }
}
