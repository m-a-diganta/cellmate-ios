import Foundation

/// Scores a charge without saving anything. Used for the live warning on the
/// Start charge screen and to re-score a saved session.
struct EvaluateChargeRisk {
    private let engine: RiskRuleEngine
    private let bedtimeProvider: () -> Date

    init(
        engine: RiskRuleEngine = RiskRuleEngine(),
        bedtimeProvider: @escaping () -> Date = { BedtimeSetting.current() }
    ) {
        self.engine = engine
        self.bedtimeProvider = bedtimeProvider
    }

    /// Live warning for the Start charge form.
    func evaluate(
        battery: Battery?,
        chargerID: UUID?,
        place: ChargePlace,
        checklistTicks: [Bool],
        plannedDurationMinutes: Int,
        unattended: Bool,
        now: Date = Date()
    ) -> RiskAssessment {
        let context = ChargeRiskContext(
            startedAt: now,
            plannedUnplug: now.addingTimeInterval(TimeInterval(plannedDurationMinutes * 60)),
            plannedDurationMinutes: plannedDurationMinutes,
            place: place,
            checklistTicks: checklistTicks,
            unattended: unattended,
            chargerMatchesBattery: battery?.chargerID == chargerID,
            bedtime: bedtimeProvider()
        )
        return engine.evaluate(context, referenceDate: now)
    }

    /// Scores a session that is already saved.
    func evaluate(session: ChargeSession, battery: Battery?, now: Date = Date()) -> RiskAssessment {
        let context = ChargeRiskContext(
            startedAt: session.startedAt,
            plannedUnplug: session.plannedUnplug,
            plannedDurationMinutes: session.plannedDurationMinutes,
            place: session.place,
            checklistTicks: session.checklistTicks,
            unattended: session.overnight,
            chargerMatchesBattery: battery?.chargerID == session.chargerID,
            bedtime: bedtimeProvider()
        )
        return engine.evaluate(context, referenceDate: session.endedAt ?? now)
    }
}
