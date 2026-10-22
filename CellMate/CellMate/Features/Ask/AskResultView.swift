import SwiftUI

struct AskResultView: View {
    @Bindable var model: AskViewModel
    let assessment: BatteryAssessment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var colour: Color {
        switch assessment.level {
        case .emergency, .stopUsing: AppColor.highText
        case .caution: AppColor.mediumText
        case .info: AppColor.accent
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    if dynamicTypeSize.isAccessibilitySize {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Image(systemName: symbol).font(.title2).accessibilityHidden(true)
                            Text(assessment.level.title).font(.headline.bold())
                                .accessibilityIdentifier("ask.result.level")
                        }
                        .foregroundStyle(colour)
                    } else {
                        Label(assessment.level.title, systemImage: symbol)
                            .font(.title.bold())
                            .foregroundStyle(colour)
                            .accessibilityIdentifier("ask.result.level")
                    }
                    Text("CellMate can’t tell you a battery is safe")
                        .foregroundStyle(AppColor.textSecondary)
                    if !assessment.symptoms.isEmpty {
                        Text(assessment.symptoms.sorted { $0.rawValue < $1.rawValue }.map(\.title).joined(separator: " · "))
                            .font(.subheadline)
                    }
                }
                .card()

                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("What to do next").font(.headline)
                    ForEach(Array(BatteryProblemRules.steps(for: assessment.level).enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: Spacing.md) {
                            Text("\(index + 1)").font(.headline).foregroundStyle(colour)
                            Text(step).fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .card()

                if assessment.needsQuickCheck {
                    Text("The description could not be fully classified. Complete Quick check before saving an inspection.")
                        .foregroundStyle(AppColor.textSecondary)
                    Button("Continue with Quick check") { model.openQuickCheck(preserveResult: true) }
                        .buttonStyle(.appPrimary)
                } else {
                    Button(model.saved ? "Inspection saved" : "Log as inspection") {
                        Task { await model.requestSave() }
                    }
                    .buttonStyle(.appPrimary)
                    .disabled(model.saved || model.isSaving)
                    .accessibilityIdentifier("ask.log")
                    if model.isSaving { ProgressView("Saving…") }
                }
                InfoNote(text: "Guidance can be wrong. Follow the maker’s advice.")
                Link("Fire and Rescue NSW · Battery safety", destination: BatteryProblemRules.sourceURL)
                    .font(.footnote)
                    .foregroundStyle(AppColor.accent)
                Text("Rules \(assessment.rulesVersion) · \(assessment.date.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(Spacing.md)
        }
        .screenBackground()
        .navigationTitle("Your guidance")
        .navigationBarTitleDisplayMode(.inline)
        .askErrorAlert(model, active: !model.showQuickCheck && !model.showBatteryPicker)
    }

    private var symbol: String {
        assessment.level >= .stopUsing ? "exclamationmark.triangle.fill" : "info.circle.fill"
    }
}
