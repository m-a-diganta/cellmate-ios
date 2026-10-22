import SwiftUI

// Design: 07 Charging
struct ChargingView: View {
    @ObservedObject var viewModel: ChargeViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: Spacing.lg) {
                ring

                if viewModel.isOverdue {
                    AlertBanner(text: "Past the planned unplug. Unplug it now.")
                }

                if let session = viewModel.activeSession {
                    VStack(spacing: Spacing.md) {
                        KeyValueRow(title: viewModel.activeBatteryName, value: viewModel.activeChargerName)
                        Divider()
                        KeyValueRow(title: "Started", value: session.startedAt.formatted(date: .omitted, time: .shortened))
                        Divider()
                        KeyValueRow(title: "Unplug by", value: session.plannedUnplug.formatted(date: .omitted, time: .shortened))
                        Divider()
                        KeyValueRow(title: "Place", value: session.place.displayName)
                    }
                    .card()

                    RiskSummaryCard(
                        title: "Risk so far",
                        level: session.riskLevel ?? .low,
                        flags: session.riskFlags,
                        emptyMessage: "Stay nearby and unplug on time."
                    )
                }

                VStack(spacing: Spacing.sm) {
                    Button("I’ve unplugged") {
                        Task { await viewModel.unpluggedTapped() }
                    }
                    .buttonStyle(.appPrimary)

                    Button("Add 30 minutes") {
                        Task { await viewModel.addThirtyMinutesTapped() }
                    }
                    .buttonStyle(.appSecondary)

                    if let error = viewModel.errorMessage {
                        Text(error)
                            .font(.footnote)
                            .foregroundStyle(AppColor.highText)
                    }
                }

                InfoNote(text: FixedWording.reminderOnly)
            }
            .padding(Spacing.md)
        }
        .screenBackground()
        .navigationTitle("Charging")
    }

    // MARK: Countdown ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(AppColor.track, lineWidth: 16)
            Circle()
                .trim(from: 0, to: viewModel.progress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: viewModel.progress)
            VStack(spacing: Spacing.xs) {
                Text(timeText)
                    .font(.system(size: 48, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(AppColor.textPrimary)
                Text(viewModel.isOverdue ? "past the plan" : "left on plan")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(width: 240, height: 240)
        .padding(.top, Spacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(timeText) \(viewModel.isOverdue ? "past the plan" : "left on plan")")
    }

    private var timeText: String {
        let minutes = viewModel.minutesRemaining
        return String(format: "%d:%02d", minutes / 60, minutes % 60)
    }

    private var ringColor: Color {
        viewModel.isOverdue ? AppColor.highText : AppColor.accent
    }
}
