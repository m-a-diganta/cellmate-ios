import SwiftUI

/// Card tinted by the risk level, with the chip and the reasons.
struct RiskSummaryCard: View {
    let title: String
    let level: RiskLevel
    let flags: [RiskFlag]
    var emptyMessage = "No flags from the safety rules."

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(level.textColor)
                Spacer()
                RiskChip(level: level)
            }
            if flags.isEmpty {
                Text(emptyMessage)
                    .font(.subheadline)
                    .foregroundStyle(level.textColor)
            } else {
                ForEach(flags) { flag in
                    Label {
                        Text(flag.message)
                            .font(.subheadline)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: flag.severity.symbol)
                    }
                    .foregroundStyle(level.textColor)
                }
            }
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(level.backgroundColor, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// A short warning line in the colour of a risk level.
struct AlertBanner: View {
    let text: String
    var level: RiskLevel = .high

    var body: some View {
        Label(text, systemImage: level.symbol)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(level.textColor)
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(level.backgroundColor, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

/// "Battery   Battery A" style row inside a card.
struct KeyValueRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: Spacing.md)
            Text(value)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.trailing)
        }
        .font(.body)
    }
}

extension ChargeSession {
    /// "8:30–9:06 pm", or "Started 8:30 pm" while it is still running.
    var timeRangeText: String {
        let start = startedAt.formatted(date: .omitted, time: .shortened)
        guard let endedAt else { return "Started \(start)" }
        return "\(start)–\(endedAt.formatted(date: .omitted, time: .shortened))"
    }

    /// "36 min", "2 h", or "2 h 12 min". Uses the planned unplug while it is still running.
    var durationText: String {
        let end = endedAt ?? plannedUnplug
        let minutes = max(0, Int(end.timeIntervalSince(startedAt) / 60))
        let hours = minutes / 60
        let rest = minutes % 60
        if hours == 0 { return "\(rest) min" }
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }
}
