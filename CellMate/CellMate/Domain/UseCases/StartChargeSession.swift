import Foundation

struct StartChargeInput {
    var batteryID: UUID
    var chargerID: UUID
    var place: ChargePlace
    /// 3-point checklist ticks. All must be true to start.
    var checklistTicks: [Bool]
    var checklistLabels: [String]
    var plannedDurationMinutes: Int
    /// The user said nobody will be around while it charges.
    var unattended: Bool
    var startedAt: Date = Date()
}

enum StartChargeError: Error, Equatable {
    case checklistIncomplete
    case batteryNotFound
    case batteryRetired
    case chargerNotFound
    case batteryAlreadyCharging
}

struct StartChargeResult {
    var session: ChargeSession
    var assessment: RiskAssessment
}

/// Start charge screen -> ChargeViewModel -> StartChargeSession -> ChargeRepository,
/// then the Live Activity and the alerts.
final class StartChargeSession {
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

    /// Validates the input, scores the risk, saves the session and arms the
    /// Live Activity and the alerts.
    func execute(_ input: StartChargeInput) async throws -> StartChargeResult {
        // 1. Validate.
        guard input.checklistTicks.count == 3, input.checklistTicks.allSatisfy({ $0 }) else {
            throw StartChargeError.checklistIncomplete
        }
        let foundBattery = await garageRepository.findBattery(id: input.batteryID)
        guard let battery = foundBattery else {
            throw StartChargeError.batteryNotFound
        }
        guard !battery.isRetired else {
            throw StartChargeError.batteryRetired
        }
        let foundCharger = await garageRepository.findCharger(id: input.chargerID)
        guard foundCharger != nil else {
            throw StartChargeError.chargerNotFound
        }
        guard chargeRepository.runningSession(forBatteryID: input.batteryID) == nil,
              chargeRepository.anyRunningSession() == nil else {
            throw StartChargeError.batteryAlreadyCharging
        }

        // 2. Score the risk. The live warning on the screen uses the same engine.
        let bedtime = bedtimeProvider()
        let plannedUnplug = input.startedAt
            .addingTimeInterval(TimeInterval(input.plannedDurationMinutes * 60))
        let context = ChargeRiskContext(
            startedAt: input.startedAt,
            plannedUnplug: plannedUnplug,
            plannedDurationMinutes: input.plannedDurationMinutes,
            place: input.place,
            checklistTicks: input.checklistTicks,
            unattended: input.unattended,
            chargerMatchesBattery: battery.chargerID == input.chargerID,
            bedtime: bedtime
        )
        let assessment = engine.evaluate(context, referenceDate: input.startedAt)

        // 3. Save.
        let bedtimeToday = CellMateDates.bedtime(on: input.startedAt, bedtime: bedtime)
        let session = ChargeSession(
            batteryID: input.batteryID,
            chargerID: input.chargerID,
            startedAt: input.startedAt,
            plannedUnplug: plannedUnplug,
            plannedDurationMinutes: input.plannedDurationMinutes,
            place: input.place,
            checklistTicks: input.checklistTicks,
            checklistLabels: input.checklistLabels,
            overnight: plannedUnplug > bedtimeToday,
            riskLevel: assessment.level,
            riskFlags: assessment.flags,
            rulesVersion: RiskRulesVersion.current
        )
        chargeRepository.save(session)

        // 4. Live Activity and alerts. If Live Activities are off the alerts still arrive.
        do {
            try activity.start(
                batteryName: battery.name,
                startedAt: session.startedAt,
                unplugAt: plannedUnplug
            )
        } catch {
            // Turned off or could not start. Notifications carry every alert.
        }
        notifications.scheduleUnplugAlert(for: session, at: plannedUnplug)
        notifications.scheduleBedtimeWarning(for: session, at: bedtimeToday)
        let tooLongAt = plannedUnplug
            .addingTimeInterval(TimeInterval(RiskRulesVersion.tooLongGraceMinutes * 60))
        notifications.scheduleTooLongAlert(for: session, at: tooLongAt)

        return StartChargeResult(session: session, assessment: assessment)
    }
}
