import SwiftUI
import WidgetKit

// Design: Widget
/// Home Screen widget, small (2×2) and medium (full width).
struct ChargeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChargeWidget", provider: ChargeProvider()) { entry in
            ChargeWidgetView(entry: entry)
                .containerBackground(AppColor.card, for: .widget)
        }
        .configurationDisplayName("Charge")
        .description("Your charge timer, last charge and next battery check.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

nonisolated struct ChargeEntry: TimelineEntry {
    struct Charge {
        let batteryName: String
        let startedAt: Date
        let unplugAt: Date
    }

    let date: Date
    let charge: Charge?
    let lastChargedAt: Date?
    let nextInspectionDue: Date?
}

nonisolated extension ChargeEntry {
    static let charging = ChargeEntry(
        date: .now,
        charge: Charge(batteryName: "Commuter e-bike", startedAt: .now.addingTimeInterval(-36 * 60), unplugAt: .now.addingTimeInterval(84 * 60)),
        lastChargedAt: .now.addingTimeInterval(-26 * 3600),
        nextInspectionDue: .now.addingTimeInterval(12 * 86400)
    )
    static let idle = ChargeEntry(
        date: .now,
        charge: nil,
        lastChargedAt: .now.addingTimeInterval(-26 * 3600),
        nextInspectionDue: .now.addingTimeInterval(12 * 86400)
    )
    static let empty = ChargeEntry(date: .now, charge: nil, lastChargedAt: nil, nextInspectionDue: nil)
}

nonisolated struct ChargeProvider: TimelineProvider {
    // TODO: read the running charge, last charge and next inspection from the App Group store
    // once it exists, and reload with WidgetCenter when they change. Sample data until then.
    func placeholder(in context: Context) -> ChargeEntry { .charging }

    func getSnapshot(in context: Context, completion: @escaping (ChargeEntry) -> Void) {
        completion(.charging)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargeEntry>) -> Void) {
        completion(Timeline(entries: [.charging], policy: .never))
    }
}

struct ChargeWidgetView: View {
    let entry: ChargeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if family == .systemMedium {
            HStack(alignment: .top, spacing: Spacing.md) {
                status
                Divider()
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    WidgetFact(icon: "clock.arrow.circlepath", title: "Last charge", date: entry.lastChargedAt, empty: "None yet")
                    WidgetFact(icon: "checklist", title: "Next check", date: entry.nextInspectionDue, empty: "Add a battery")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            status
        }
    }

    @ViewBuilder private var status: some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            if let charge = entry.charge {
                Label("Charging", systemImage: "bolt.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.accent)
                Spacer(minLength: 0)
                Text(timerInterval: Date.now...max(charge.unplugAt, .now), countsDown: true)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .foregroundStyle(AppColor.textPrimary)
                Text(charge.batteryName)
                    .font(.caption)
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Text("Unplug at \(charge.unplugAt, style: .time)")
                    .font(.caption2)
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                Label("Not charging", systemImage: "battery.100")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.accent)
                Spacer(minLength: 0)
                if family == .systemSmall {
                    WidgetFact(icon: nil, title: "Last charge", date: entry.lastChargedAt, empty: "None yet")
                    WidgetFact(icon: nil, title: "Next check", date: entry.nextInspectionDue, empty: "Add a battery")
                } else {
                    Text(entry.lastChargedAt == nil ? "Start a charge in CellMate" : "Plug in and start a timer")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A small "title, then date" pair, e.g. "Next check · 2 Nov".
private struct WidgetFact: View {
    let icon: String?
    let title: String
    let date: Date?
    let empty: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            if let icon {
                Label(title, systemImage: icon)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            } else {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(AppColor.textSecondary)
            }
            Group {
                if let date {
                    Text(date, format: .dateTime.day().month())
                } else {
                    Text(empty)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColor.textPrimary)
        }
    }
}

#Preview("Small", as: .systemSmall) {
    ChargeWidget()
} timeline: {
    ChargeEntry.charging
    ChargeEntry.idle
    ChargeEntry.empty
}

#Preview("Medium", as: .systemMedium) {
    ChargeWidget()
} timeline: {
    ChargeEntry.charging
    ChargeEntry.idle
    ChargeEntry.empty
}
