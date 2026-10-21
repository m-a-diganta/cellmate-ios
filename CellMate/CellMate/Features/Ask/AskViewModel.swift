import Foundation
import Observation

@MainActor
@Observable
final class AskViewModel {
    var text = ""
    var selectedSymptoms: Set<BatterySymptom> = []
    var selectedBatteryID: UUID?
    var checkSymptoms: Set<BatterySymptom> = []
    var noneNoticed = false
    var showQuickCheck = false
    var showResult = false
    var showBatteryPicker = false
    var errorMessage: String?

    private(set) var batteries: [AskBattery] = []
    private(set) var availability: BatteryAssistantAvailability
    private(set) var assessment: BatteryAssessment?
    private(set) var isAssessing = false
    private(set) var isSaving = false
    private(set) var saved = false
    @ObservationIgnored private let dependencies: AskDependencies
    @ObservationIgnored private let assess: AssessBatteryProblem
    @ObservationIgnored private var assessmentTask: Task<Void, Never>?
    @ObservationIgnored private var requestID = UUID()

    init(dependencies: AskDependencies) {
        self.dependencies = dependencies
        self.assess = AssessBatteryProblem(assistant: dependencies.assistant)
        self.availability = dependencies.assistant.availability
    }

    var selectedBattery: AskBattery? { batteries.first { $0.id == selectedBatteryID } }
    var canAsk: Bool {
        !isAssessing && (!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !selectedSymptoms.isEmpty)
    }

    func refresh() async {
        availability = dependencies.assistant.availability
        do {
            batteries = try await dependencies.batteries.batteries()
            if let selectedBatteryID, !batteries.contains(where: { $0.id == selectedBatteryID }) { self.selectedBatteryID = nil }
            if batteries.count == 1 { selectedBatteryID = batteries[0].id }
        } catch { errorMessage = "Could not load batteries. You can still use Quick check. Please try again later." }
    }

    func submit() {
        guard !isAssessing else { return }
        saved = false
        errorMessage = nil
        isAssessing = true
        let id = UUID()
        requestID = id
        let input = text
        let symptoms = selectedSymptoms
        let battery = selectedBattery
        assessmentTask = Task { [weak self] in
            guard let self else { return }
            defer { if requestID == id { isAssessing = false } }
            do {
                let result = try await assess(text: input, selected: symptoms, battery: battery)
                guard !Task.isCancelled, requestID == id else { return }
                assessment = result
                showResult = true
            } catch is CancellationError {
                // The person can switch to Quick check immediately without waiting for the model.
            } catch { if requestID == id { errorMessage = error.localizedDescription } }
        }
    }

    func cancelAssessment() {
        requestID = UUID()
        assessmentTask?.cancel()
        assessmentTask = nil
        isAssessing = false
    }

    func openQuickCheck(preserveResult: Bool = false) {
        cancelAssessment()
        if !preserveResult { assessment = nil }
        checkSymptoms = assessment?.symptoms ?? selectedSymptoms.union(BatteryProblemRules.mentionedSymptoms(in: text))
        noneNoticed = false
        saved = false
        showQuickCheck = true
    }

    func finishQuickCheck() {
        do {
            assessment = try assess.quickCheck(selected: checkSymptoms, noneNoticed: noneNoticed,
                                               prior: assessment, battery: selectedBattery)
            showQuickCheck = false
            showResult = true
        } catch { errorMessage = error.localizedDescription }
    }

    func requestSave() async {
        guard !saved, !isSaving, let assessment else { return }
        if assessment.needsQuickCheck {
            openQuickCheck(preserveResult: true)
            return
        }
        if let batteryID = assessment.batteryID {
            await save(for: batteryID)
        } else if batteries.count == 1, let battery = batteries.first {
            await save(for: battery.id)
        } else if batteries.count > 1 {
            showBatteryPicker = true
        } else {
            errorMessage = "No battery records are available. Add a battery in Garage when that feature is connected. Your result has not been saved."
        }
    }

    func save(for batteryID: UUID) async {
        guard !saved, !isSaving, let assessment else { return }
        guard !assessment.needsQuickCheck else {
            openQuickCheck(preserveResult: true)
            return
        }
        guard let battery = batteries.first(where: { $0.id == batteryID }),
              assessment.batteryID == nil || assessment.batteryID == batteryID else {
            errorMessage = BatteryProblemError.batteryRequired.localizedDescription
            return
        }
        isSaving = true
        defer { isSaving = false }
        let record = BatteryAssessment(id: assessment.id, date: assessment.date, symptoms: assessment.symptoms,
            level: max(assessment.level, battery.isRetired ? .stopUsing : .info), source: assessment.source,
            rulesVersion: assessment.rulesVersion, needsQuickCheck: false, batteryID: batteryID)
        self.assessment = record
        do {
            try await dependencies.inspections.log(record, for: batteryID)
            saved = true
            showBatteryPicker = false
        } catch { errorMessage = "Could not save the inspection. \(error.localizedDescription)" }
    }
}
