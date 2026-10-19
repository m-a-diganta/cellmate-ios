import SwiftUI

/// The teal card at the top of Home. Two states: charging now, and not on charge.
struct ChargeStatusCard: View {
    let state: HomeSummary.ChargeState
    let onTapCharging: () -> Void

    var body: some View {
        switch state {
        case .charging(let charge):
            Button(action: onTapCharging) {
                chargingContent(charge)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the charging screen")
        case .idle(let lastCharge):
            idleContent(lastCharge)
        }
    }

    private func chargingContent(_ charge: ActiveCharge) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Label("Charging now", systemImage: "bolt")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
            }
            Text(charge.batteryName)
                .font(.title.bold())
            HStack(alignment: .firstTextBaseline) {
                Text("unplug by \(charge.unplugBy.formatted(date: .omitted, time: .shortened))")
                Spacer()
                TimelineView(.periodic(from: Date(), by: 30)) { context in
                    Text(TimeLeftFormatter.text(until: charge.unplugBy, now: context.date))
                        .font(.title2.bold())
                }
            }
            Text("Reminder only · charging won't stop automatically")
                .font(.footnote)
                .opacity(0.85)
        }
        .foregroundStyle(AppColor.onBrand)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.brand, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }

    private func idleContent(_ last: CompletedCharge?) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Label("Not on charge", systemImage: "bolt")
                .font(.subheadline.weight(.semibold))
            if let last {
                Text(last.batteryName)
                    .font(.title.bold())
                Text(LastChargedFormatter.text(for: last.unpluggedAt))
                    .font(.title2.bold())
                Text("Unplugged at \(last.unpluggedAt.formatted(date: .omitted, time: .shortened))")
                    .font(.footnote)
                    .opacity(0.85)
            } else {
                Text("No charges yet")
                    .font(.title.bold())
                Text("Start a charge when you plug in. CellMate will remind you to unplug.")
                    .font(.subheadline)
                    .opacity(0.9)
            }
        }
        .foregroundStyle(AppColor.onBrand)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.brand, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// Three tiles under the status card: Start charge (or Unplug now), Inspect, Ask.
struct QuickActionsRow: View {
    let isCharging: Bool
    let onChargeAction: () -> Void
    let onInspect: () -> Void
    let onAsk: () -> Void

    var body: some View {
        HStack(spacing: Spacing.sm) {
            tile(
                title: isCharging ? "Unplug now" : "Start charge",
                systemImage: isCharging ? "bolt.slash" : "powerplug",
                action: onChargeAction
            )
            tile(title: "Inspect", systemImage: "viewfinder", action: onInspect)
            tile(title: "Ask", systemImage: "bubble.left", action: onAsk)
        }
    }

    private func tile(title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: Spacing.sm) {
                Image(systemName: systemImage)
                    .font(.title3)
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(AppColor.accent)
            .frame(maxWidth: .infinity, minHeight: 84)
            .background(AppColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
