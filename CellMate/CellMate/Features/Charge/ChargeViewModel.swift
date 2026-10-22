import Foundation
import SwiftUI
import Combine

enum ChargeFlowPhase: Equatable {
    case form        // Start charge screen
    case charging    // Charging screen
    case complete    // Charge complete screen
}

/// 3-point checklist on the Start charge screen.
struct ChecklistItem: Identifiable, Equatable {
    var id = UUID()
    var label: String
    var ticked: Bool

    static let defaultItems: [ChecklistItem] = [
        ChecklistItem(label: "Battery is cool, dry and undamaged", ticked: false),
        ChecklistItem(label: "Hard surface, away from exits", ticked: false),
        ChecklistItem(label: "I’ll stay awake and nearby", ticked: false)
    ]
}

/// View model for Start charge -> Charging -> Charge complete.
/// Screens never touch storage. Everything goes through the use cases.
@MainActor
final class ChargeViewModel: ObservableObject {

    // MARK: Form state

    @Published var selectedBatteryID: UUID?
    @Published var selectedChargerID: UUID?
    @Published var place: ChargePlace = .garage { didSet { recomputeLiveRisk() } }
    @Published var checklist: [ChecklistItem] = ChecklistItem.defaultItems { didSet { recomputeLiveRisk() } }
    @Published var plannedDurationMinutes: Int = 180 { didSet { recomputeLiveRisk() } }
    /// True when nobody will be around. The screen has no switch for this yet.
    @Published var unattended: Bool = false { didSet { recomputeLiveRisk() } }

    // MARK: Flow state

    @Published var phase: ChargeFlowPhase = .form
    @Published var activeSession: ChargeSession?
    @Published var completedAssessment: RiskAssessment?
    @Published var errorMessage: String?

    /// Ticks every second while charging to move the countdown ring.
    @Published var now: Date = Date()

    /// Live risk warning on the Start charge screen.
    @Published private(set) var liveRisk = RiskAssessment(level: .low, flags: [])

    @Published private(set) var batteries: [Battery] = []
    @Published private(set) var chargers: [Charger] = []

    // MARK: Dependencies

    private let chargeRepository: any ChargeRepository
    private let garageRepository: any GarageRepository
    private let startCharge: StartChargeSession
    private let endCharge: EndChargeSession
    private let evaluateRisk: EvaluateChargeRisk
    private var ticker: AnyCancellable?

    init(
        chargeRepository: any ChargeRepository,
        garageRepository: any GarageRepository,
        notifications: any NotificationScheduling,
        activity: any ChargeActivityControlling,
        bedtimeProvider: @escaping () -> Date = { BedtimeSetting.current() }
    ) {
        self.chargeRepository = chargeRepository
        self.garageRepository = garageRepository
        self.startCharge = StartChargeSession(
            chargeRepository: chargeRepository,
            garageRepository: garageRepository,
            notifications: notifications,
            activity: activity,
            bedtimeProvider: bedtimeProvider
        )
        self.endCharge = EndChargeSession(
            chargeRepository: chargeRepository,
            garageRepository: garageRepository,
            notifications: notifications,
            activity: activity,
            bedtimeProvider: bedtimeProvider
        )
        self.evaluateRisk = EvaluateChargeRisk(bedtimeProvider: bedtimeProvider)

        // Pick up a charge that was already running.
        if let running = chargeRepository.anyRunningSession() {
            activeSession = running
            phase = .charging
            startTicker()
        }
        recomputeLiveRisk()
    }

    // MARK: Loading and pickers

    /// Loads the batteries and chargers from the Garage and picks sensible defaults.
    func load() async {
        batteries = (try? await garageRepository.fetchBatteries()) ?? []
        chargers = (try? await garageRepository.fetchChargers()) ?? []

        if let chosen = availableBatteries.first(where: { $0.id == selectedBatteryID }) {
            // Keep a battery chosen earlier (for example from Garage) and make sure its charger is set too.
            if selectedChargerID == nil { selectedChargerID = chosen.chargerID }
        } else {
            selectBattery(availableBatteries.first?.id)
        }
        recomputeLiveRisk()
    }

    var availableBatteries: [Battery] { batteries.filter { !$0.isRetired } }

    var selectedBattery: Battery? {
        batteries.first { $0.id == selectedBatteryID }
    }

    var selectedCharger: Charger? {
        chargers.first { $0.id == selectedChargerID }
    }

    /// Choosing a battery also picks the charger saved with it.
    func selectBattery(_ id: UUID?) {
        selectedBatteryID = id
        if let battery = batteries.first(where: { $0.id == id }) {
            selectedChargerID = battery.chargerID
        } else {
            selectedChargerID = nil
        }
        recomputeLiveRisk()
    }

    func selectCharger(_ id: UUID?) {
        selectedChargerID = id
        recomputeLiveRisk()
    }

    var chargerMatchesSelectedBattery: Bool {
        guard let battery = selectedBattery, let chargerID = selectedChargerID else { return true }
        return battery.chargerID == chargerID
    }

    var canStart: Bool {
        selectedBatteryID != nil
            && selectedChargerID != nil
            && checklist.allSatisfy(\.ticked)
    }

    var plannedUnplugPreview: Date {
        Date().addingTimeInterval(TimeInterval(plannedDurationMinutes * 60))
    }

    func recomputeLiveRisk() {
        liveRisk = evaluateRisk.evaluate(
            battery: selectedBattery,
            chargerID: selectedChargerID,
            place: place,
            checklistTicks: checklist.map(\.ticked),
            plannedDurationMinutes: plannedDurationMinutes,
            unattended: unattended
        )
    }

    // MARK: Start

    func startChargeTapped() async {
        guard let batteryID = selectedBatteryID, let chargerID = selectedChargerID else { return }
        do {
            let result = try await startCharge.execute(StartChargeInput(
                batteryID: batteryID,
                chargerID: chargerID,
                place: place,
                checklistTicks: checklist.map(\.ticked),
                checklistLabels: checklist.map(\.label),
                plannedDurationMinutes: plannedDurationMinutes,
                unattended: unattended
            ))
            activeSession = result.session
            completedAssessment = nil
            phase = .charging
            errorMessage = nil
            now = Date()
            startTicker()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    // MARK: Charging screen

    var activeBatteryName: String {
        guard let session = activeSession else { return "Battery" }
        return batteries.first { $0.id == session.batteryID }?.name ?? "Battery"
    }

    var activeChargerName: String {
        guard let session = activeSession else { return "Charger" }
        return chargers.first { $0.id == session.chargerID }?.name ?? "Charger"
    }

    /// 0 at the start, 1 at the planned unplug time.
    var progress: Double {
        guard let session = activeSession else { return 0 }
        let total = session.plannedUnplug.timeIntervalSince(session.startedAt)
        guard total > 0 else { return 1 }
        let elapsed = now.timeIntervalSince(session.startedAt)
        return min(max(elapsed / total, 0), 1)
    }

    var minutesRemaining: Int {
        guard let session = activeSession else { return 0 }
        return max(0, Int(session.plannedUnplug.timeIntervalSince(now) / 60))
    }

    var isOverdue: Bool {
        guard let session = activeSession else { return false }
        return now > session.plannedUnplug
    }

    /// "Add 30 minutes".
    func addThirtyMinutesTapped() async {
        guard let session = activeSession else { return }
        do {
            activeSession = try await endCharge.extend(sessionID: session.id)
            errorMessage = nil
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// "I've unplugged" -> Charge complete.
    func unpluggedTapped() async {
        guard let session = activeSession else { return }
        do {
            let result = try await endCharge.execute(sessionID: session.id)
            completedAssessment = result.assessment
            activeSession = result.session
            phase = .complete
            errorMessage = nil
            stopTicker()
        } catch {
            errorMessage = Self.message(for: error)
        }
    }

    /// Leaves the complete screen and resets the form.
    func doneTapped() {
        phase = .form
        activeSession = nil
        completedAssessment = nil
        checklist = ChecklistItem.defaultItems
        errorMessage = nil
        recomputeLiveRisk()
    }

    // MARK: Private

    private func startTicker() {
        ticker = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] date in self?.now = date }
    }

    private func stopTicker() {
        ticker?.cancel()
        ticker = nil
    }

    private static func message(for error: Error) -> String {
        switch error {
        case StartChargeError.checklistIncomplete:
            return "Tick all three checks before starting."
        case StartChargeError.batteryAlreadyCharging:
            return "A charge is already running. Unplug it first."
        case StartChargeError.batteryRetired:
            return "This battery is retired and can’t be charged."
        case StartChargeError.batteryNotFound, StartChargeError.chargerNotFound:
            return "Pick a battery and charger from your Garage."
        case EndChargeError.sessionNotFound:
            return "This charge no longer exists."
        case EndChargeError.alreadyEnded:
            return "This charge was already completed."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
