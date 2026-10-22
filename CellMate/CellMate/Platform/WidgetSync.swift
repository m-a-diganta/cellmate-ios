import Foundation
import WidgetKit

/// Copies the running charge, last charge and next inspection into the widget snapshot,
/// then asks the widget to redraw. Runs at launch and whenever the app leaves the screen.
@MainActor
struct WidgetSync {
    let garage: any GarageRepository
    let charges: any ChargeRepository
    let inspections: any InspectionRepository
    let activity: any ChargeActivityControlling

    init(container: AppContainer) {
        garage = container.garage
        charges = container.charges
        inspections = container.inspections
        activity = container.activity
    }

    func refresh() async {
        let snapshot = await makeSnapshot()
        WidgetSnapshotStore.save(snapshot)
        WidgetCenter.shared.reloadAllTimelines()

        // A Live Activity left over from an earlier launch has no charge behind it, so remove it.
        if snapshot.charge == nil {
            await activity.end()
        }
    }

    private func makeSnapshot() async -> WidgetSnapshot {
        let batteries = (try? await garage.fetchBatteries()) ?? []
        let names = Dictionary(batteries.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })

        let charge = charges.anyRunningSession().map {
            WidgetSnapshot.Charge(
                batteryName: names[$0.batteryID] ?? "Battery",
                startedAt: $0.startedAt,
                unplugAt: $0.plannedUnplug
            )
        }
        let lastCharge = charges.allSessions().first { $0.status == .completed }

        return WidgetSnapshot(
            charge: charge,
            lastChargedAt: lastCharge.map { $0.endedAt ?? $0.startedAt },
            nextInspectionDue: await nextInspectionDue(for: batteries.filter { !$0.isRetired })
        )
    }

    /// The soonest due date. A battery never checked, or with a reported problem, is due today.
    private func nextInspectionDue(for batteries: [Battery]) async -> Date? {
        let evaluateDue = EvaluateInspectionDue()
        let today = Calendar.current.startOfDay(for: .now)
        var dates: [Date] = []
        for battery in batteries {
            let latest = (try? await inspections.fetchInspections(for: battery.id))?.first
            switch try? evaluateDue.execute(battery: battery, latestInspection: latest) {
            case .neverInspected, .needsAttention:
                dates.append(today)
            case .upToDate(let date), .dueSoon(let date), .dueToday(let date), .overdue(let date):
                dates.append(date)
            case .notRequired, nil:
                break
            }
        }
        return dates.min()
    }
}
