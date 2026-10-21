import Foundation

@MainActor
struct AssessBatteryProblem {
    let assistant: any BatteryAssistant

    func callAsFunction(text: String, selected: Set<BatterySymptom>, battery: AskBattery? = nil) async throws -> BatteryAssessment {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !selected.isEmpty else { throw BatteryProblemError.emptyInput }
        guard text.count <= 1_000 else { throw BatteryProblemError.inputTooLong }

        let baseline = selected.union(BatteryProblemRules.mentionedSymptoms(in: text))
        // Urgent advice is immediate, even with an unavailable or slow model.
        if BatteryProblemRules.level(for: baseline, retired: battery?.isRetired == true) >= .stopUsing || text.isEmpty {
            return make(baseline, source: .rules, battery: battery)
        }
        guard assistant.availability == .available else {
            return make(baseline.union([.unknown]), source: .rules, needsQuickCheck: true, battery: battery)
        }
        do {
            let extracted = try await assistant.classify(text, battery: battery)
            try Task.checkCancellation()
            let combined = baseline.union(extracted)
            let incomplete = extracted.isEmpty || extracted.contains(.unknown)
            return make(incomplete ? combined.union([.unknown]) : combined, source: .assistant,
                        needsQuickCheck: incomplete, battery: battery)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            return make(baseline.union([.unknown]), source: .rules, needsQuickCheck: true, battery: battery)
        }
    }

    func quickCheck(selected: Set<BatterySymptom>, noneNoticed: Bool, prior: BatteryAssessment? = nil,
                    battery: AskBattery? = nil) throws -> BatteryAssessment {
        guard !selected.isEmpty || noneNoticed else { throw BatteryProblemError.incompleteCheck }
        // A follow-up check may add concerns but cannot erase an earlier warning.
        let combined = selected.union(prior?.symptoms ?? [])
        return make(combined, source: .quickCheck, battery: battery, minimumLevel: prior?.level ?? .info)
    }

    private func make(_ symptoms: Set<BatterySymptom>, source: BatteryAssessment.Source,
                      needsQuickCheck: Bool = false, battery: AskBattery?, minimumLevel: BatteryAdviceLevel = .info) -> BatteryAssessment {
        BatteryAssessment(id: UUID(), date: Date(), symptoms: symptoms,
                          level: max(minimumLevel, BatteryProblemRules.level(for: symptoms, retired: battery?.isRetired == true)),
                          source: source, rulesVersion: BatteryProblemRules.version,
                          needsQuickCheck: needsQuickCheck, batteryID: battery?.id)
    }
}
