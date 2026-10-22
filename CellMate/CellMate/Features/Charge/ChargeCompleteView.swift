import SwiftUI

// Design: 08 Charge result
struct ChargeCompleteView: View {
    @ObservedObject var viewModel: ChargeViewModel
    let onDone: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(AppColor.lowText)
                    .padding(.top, Spacing.md)
                    .accessibilityHidden(true)

                VStack(spacing: Spacing.xs) {
                    Text("\(viewModel.activeBatteryName) is unplugged")
                        .font(.title2.bold())
                        .foregroundStyle(AppColor.textPrimary)
                        .multilineTextAlignment(.center)
                    if let session = viewModel.activeSession {
                        Text("Today · \(session.timeRangeText) · \(session.durationText)")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                }

                if let assessment = viewModel.completedAssessment {
                    RiskSummaryCard(
                        title: "Based on what you logged",
                        level: assessment.level,
                        flags: assessment.flags,
                        emptyMessage: "No warning signs from the safety rules."
                    )

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        if assessment.level == .low {
                            InfoNote(text: FixedWording.lowRiskDisclaimer)
                        }
                        InfoNote(text: FixedWording.cantTellSafe)
                    }
                }

                Button("Done") {
                    viewModel.doneTapped()
                    onDone()
                }
                .buttonStyle(.appPrimary)
            }
            .padding(Spacing.md)
        }
        .screenBackground()
        .navigationTitle("Charge complete")
        .navigationBarBackButtonHidden(true)
    }
}
