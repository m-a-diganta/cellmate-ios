import Foundation
import WidgetKit

/// The one place that builds the shared repositories and services, so every
/// screen sees the same data. Records are saved in Core Data (see `PersistenceController`).
/// The in-memory repositories in Data/Mocks are kept for previews and tests.
@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let persistence: PersistenceController
    let garage: CoreDataGarageRepository
    let charges: CoreDataChargeRepository
    let inspections: CoreDataInspectionRepository
    let notifications: any NotificationScheduling
    let activity: any ChargeActivityControlling
    let records: any RecordsManaging

    /// One charge flow for the whole app, so Home and the Charge screens stay in step.
    private(set) lazy var chargeViewModel: ChargeViewModel = ChargeViewModel(
        chargeRepository: charges,
        garageRepository: garage,
        notifications: notifications,
        activity: activity
    )

    /// - Parameter persistence: Pass `PersistenceController(inMemory: true)` for previews and tests.
    ///   Nil uses the app's shared store.
    init(persistence: PersistenceController? = nil) {
        let store = persistence ?? PersistenceController.shared
        self.persistence = store
        self.garage = CoreDataGarageRepository(persistence: store)
        self.charges = CoreDataChargeRepository(persistence: store)
        self.inspections = CoreDataInspectionRepository(persistence: store)

        let notifications = ChargeAlertScheduler()
        let activity = SystemChargeActivityService()
        self.notifications = notifications
        self.activity = activity

        // After "Delete all data": stop the alerts, the Live Activity and the widget for the removed charges.
        self.records = CoreDataRecordsManager(persistence: store) { sessionIDs in
            for id in sessionIDs { notifications.cancelAlerts(forSessionID: id) }
            WidgetSnapshotStore.save(.empty)
            WidgetCenter.shared.reloadAllTimelines()
            await activity.end()
        }
    }

    var homeSummaryProvider: any HomeSummaryProviding {
        LiveHomeSummaryProvider(garage: garage, charges: charges, inspections: inspections)
    }

    /// Ask reads the Garage and saves its results as inspections. Built once.
    private(set) lazy var askDependencies: AskDependencies = AskDependencies(
        assistant: FoundationBatteryAssistant(),
        batteries: GarageAskBatteryProvider(garage: garage),
        inspections: InspectionAskLogger(inspections: inspections)
    )

    func makeHistoryViewModel() -> HistoryViewModel {
        HistoryViewModel(
            chargeRepository: charges,
            garageRepository: garage,
            inspectionRepository: inspections
        )
    }
}
