import Foundation

/// Builds the Home summary from the real repositories.
/// "Needs attention" stays empty until the inspection data is shared with Home.
struct LiveHomeSummaryProvider: HomeSummaryProviding {
    let garage: any GarageRepository
    let charges: any ChargeRepository

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

        let summaries = batteries
            .filter { !$0.isRetired }
            .map { battery in
                BatterySummary(
                    name: battery.name,
                    detail: "\(battery.brand) · \(Int(battery.capacityWh)) Wh",
                    risk: latestRisk(for: battery.id, in: sessions)
                )
            }

        return HomeSummary(chargeState: chargeState, attention: [], batteries: summaries)
    }

    /// The risk of the battery's most recent completed charge, or low when it has none.
    private func latestRisk(for batteryID: UUID, in sessions: [ChargeSession]) -> RiskLevel {
        sessions
            .first { $0.batteryID == batteryID && $0.status == .completed }?
            .riskLevel ?? .low
    }
}
