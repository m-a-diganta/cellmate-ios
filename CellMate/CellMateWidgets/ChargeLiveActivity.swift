import ActivityKit
import SwiftUI
import WidgetKit

// Design: Live Activity
/// Lock Screen banner and Dynamic Island countdown while a charge runs.
struct ChargeLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: ChargeActivityAttributes.self) { context in
            // The Lock Screen picks its own light or dark look, so text uses .primary/.secondary
            // instead of AppColor text colours, which would clash with the system background.
            ChargeLockScreenView(batteryName: context.attributes.batteryName, state: context.state, isStale: context.isStale)
                .widgetURL(AppLink.charge)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "bolt.fill")
                        .font(.title2)
                        .foregroundStyle(AppColor.accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Countdown(state: context.state, isStale: context.isStale)
                        .font(.title3.bold())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text(context.attributes.batteryName)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)
                        ChargeProgress(state: context.state)
                        Text("Unplug at \(context.state.unplugAt, style: .time)")
                            .font(.caption)
                        Text("Reminder only · charging won't stop automatically")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, Spacing.sm)
                }
            } compactLeading: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(AppColor.accent)
            } compactTrailing: {
                Countdown(state: context.state, isStale: context.isStale)
                    .frame(maxWidth: 56)
            } minimal: {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(AppColor.accent)
            }
            .widgetURL(AppLink.charge)
        }
    }
}

private struct ChargeLockScreenView: View {
    let batteryName: String
    let state: ChargeActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label(batteryName, systemImage: "bolt.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.accent)
                    .lineLimit(1)
                Spacer()
                Countdown(state: state, isStale: isStale)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
            }
            ChargeProgress(state: state)
            Text("Unplug at \(state.unplugAt, style: .time)")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text("Reminder only · charging won't stop automatically")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(Spacing.md)
    }
}

/// Live "1:24:00" countdown to the unplug time. iOS updates it without the app running.
/// The activity goes stale at the unplug time, and then it reads "Unplug now".
private struct Countdown: View {
    let state: ChargeActivityAttributes.ContentState
    let isStale: Bool

    var body: some View {
        Group {
            if isStale || state.unplugAt <= .now {
                Text("Unplug now")
            } else {
                Text(timerInterval: Date.now...state.unplugAt, countsDown: true)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

private struct ChargeProgress: View {
    let state: ChargeActivityAttributes.ContentState

    var body: some View {
        ProgressView(timerInterval: state.startedAt...max(state.unplugAt, state.startedAt), countsDown: false) {
            EmptyView()
        } currentValueLabel: {
            EmptyView()
        }
        .tint(AppColor.accent)
    }
}

#Preview("Lock Screen", as: .content, using: ChargeActivityAttributes.preview) {
    ChargeLiveActivity()
} contentStates: {
    ChargeActivityAttributes.ContentState.preview
}

#Preview("Island expanded", as: .dynamicIsland(.expanded), using: ChargeActivityAttributes.preview) {
    ChargeLiveActivity()
} contentStates: {
    ChargeActivityAttributes.ContentState.preview
}

#Preview("Island compact", as: .dynamicIsland(.compact), using: ChargeActivityAttributes.preview) {
    ChargeLiveActivity()
} contentStates: {
    ChargeActivityAttributes.ContentState.preview
}
