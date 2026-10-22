import Foundation

/// The one place that builds the shared repositories and services, so every
/// screen sees the same data. The in-memory repositories are swapped for
/// Core Data ones here later, and no screen needs to change.
@MainActor
final class AppContainer {
    static let shared = AppContainer()

    let garage: InMemoryGarageRepository
    let charges: InMemoryChargeRepository
    let inspections: InMemoryInspectionRepository
    let notifications: any NotificationScheduling
    let activity: any ChargeActivityControlling

    /// One charge flow for the whole app, so Home and the Charge screens stay in step.
    private(set) lazy var chargeViewModel: ChargeViewModel = ChargeViewModel(
        chargeRepository: charges,
        garageRepository: garage,
        notifications: notifications,
        activity: activity
    )

    init() {
        let garage = InMemoryGarageRepository()
        self.garage = garage
        self.charges = InMemoryChargeRepository()
        self.inspections = InMemoryInspectionRepository(garageRepository: garage)
        self.notifications = ChargeAlertScheduler()
        self.activity = SystemChargeActivityService()
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
