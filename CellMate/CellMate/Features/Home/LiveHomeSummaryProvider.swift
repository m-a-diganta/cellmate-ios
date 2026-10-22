import Foundation

/// Builds the Home summary from the real repositories.
struct LiveHomeSummaryProvider: HomeSummaryProviding {
    let garage: any GarageRepository
    let charges: any ChargeRepository
    var inspections: (any InspectionRepository)? = nil

    func loadSummary() async -> HomeSummary {
        let batteries = (try? await garage.fetchBatteries()) ?? []
        let sessions = charges.allSessions()

        var names: [UUID: String] = [:]
        for battery in batteries { names[battery.id] = battery.name }

        let chargeState: HomeSummary.ChargeState
        if let running = charges.anyRunningSession() {
            chargeState = .charging(ActiveCharge(
                batteryName: names[running.batteryID] ?? "Battery",
                startedAt: running.startedAt,
                unplugBy: running.plannedUnplug
            ))
        } else if let last = sessions.first(where: { $0.status == .completed }) {
            chargeState = .idle(lastCharge: CompletedCharge(
                batteryName: names[last.batteryID] ?? "Battery",
                unpluggedAt: last.endedAt ?? last.startedAt
            ))
        } else {
            chargeState = .idle(lastCharge: nil)
        }

        let activeBatteries = batteries.filter { !$0.isRetired }

        let evaluateDue = EvaluateInspectionDue()
        var attention: [AttentionItem] = []
        for battery in activeBatteries {
            guard let inspections else { break }
            let latest = (try? await inspections.fetchInspections(for: battery.id))?.first
            guard let status = try? evaluateDue.execute(battery: battery, latestInspection: latest),
                  let item = Self.attentionItem(for: battery, status: status) else { continue }
            attention.append(item)
        }

        let summaries = activeBatteries.map { battery in
            BatterySummary(
                name: battery.name,
                detail: "\(battery.brand) · \(Int(battery.capacityWh)) Wh",
                risk: latestRisk(for: battery.id, in: sessions)
            )
        }

        return HomeSummary(chargeState: chargeState, attention: attention, batteries: summaries)
    }

    /// What Home says about a battery whose check needs doing. Nil when it needs nothing.
    static func attentionItem(for battery: Battery, status: EvaluateInspectionDue.Status) -> AttentionItem? {
        switch status {
        case .notRequired, .upToDate:
            return nil
        case .neverInspected:
            return AttentionItem(title: "\(battery.name) · first check needed", subtitle: "Not inspected yet")
        case .needsAttention:
            return AttentionItem(title: "\(battery.name) · needs attention", subtitle: "The last check reported a problem")
        case .overdue(let due):
            return AttentionItem(title: "\(battery.name) · check overdue", subtitle: "Was due \(shortDate(due))")
        case .dueToday:
            return AttentionItem(title: "\(battery.name) · check due today", subtitle: "Do a quick inspection")
        case .dueSoon(let due):
            return AttentionItem(title: "\(battery.name) · check due soon", subtitle: "Check by \(shortDate(due))")
        }
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }

    /// The risk of the battery's most recent completed charge, or low when it has none.
    private func latestRisk(for batteryID: UUID, in sessions: [ChargeSession]) -> RiskLevel {
        sessions
            .first { $0.batteryID == batteryID && $0.status == .completed }?
            .riskLevel ?? .low
    }
}
