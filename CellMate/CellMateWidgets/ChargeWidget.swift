import SwiftUI
import WidgetKit

// Design: Widget
/// Home Screen widget, small (2×2) and medium (full width).
struct ChargeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "ChargeWidget", provider: ChargeProvider()) { entry in
            ChargeWidgetView(entry: entry)
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
    static let overdue = ChargeEntry(
        date: .now,
        charge: Charge(batteryName: "Commuter e-bike", startedAt: .now.addingTimeInterval(-200 * 60), unplugAt: .now.addingTimeInterval(-12 * 60)),
        lastChargedAt: .now.addingTimeInterval(-26 * 3600),
        nextInspectionDue: .now.addingTimeInterval(12 * 86400)
    )
    static let empty = ChargeEntry(date: .now, charge: nil, lastChargedAt: nil, nextInspectionDue: nil)
}

nonisolated extension ChargeEntry {
    /// Reads what the app last saved to the App Group.
    init(snapshot: WidgetSnapshot, date: Date = .now) {
        self.init(
            date: date,
            charge: snapshot.charge.map {
                Charge(batteryName: $0.batteryName, startedAt: $0.startedAt, unplugAt: $0.unplugAt)
            },
            lastChargedAt: snapshot.lastChargedAt,
            nextInspectionDue: snapshot.nextInspectionDue
        )
    }
}

/// The app saves a snapshot and reloads the widget whenever its data changes, so the timeline never refreshes on its own.
nonisolated struct ChargeProvider: TimelineProvider {
    func placeholder(in context: Context) -> ChargeEntry { .charging }

    /// The widget gallery shows sample data. On the Home Screen it shows the real snapshot.
    func getSnapshot(in context: Context, completion: @escaping (ChargeEntry) -> Void) {
        completion(context.isPreview ? .charging : ChargeEntry(snapshot: WidgetSnapshotStore.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ChargeEntry>) -> Void) {
        let snapshot = WidgetSnapshotStore.load()
        var entries = [ChargeEntry(snapshot: snapshot)]
        // A second entry at the unplug time switches the widget to "Unplug now".
        if let unplugAt = snapshot.charge?.unplugAt, unplugAt > .now {
            entries.append(ChargeEntry(snapshot: snapshot, date: unplugAt))
        }
        completion(Timeline(entries: entries, policy: .never))
    }
}

struct ChargeWidgetView: View {
    let entry: ChargeEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let charge = entry.charge {
            ChargingWidgetView(charge: charge, isOverdue: entry.date >= charge.unplugAt, isMedium: family == .systemMedium)
                .widgetURL(AppLink.charge)
        } else {
            IdleWidgetView(entry: entry, isMedium: family == .systemMedium)
                .widgetURL(entry.hasBattery ? AppLink.charge : AppLink.garage)
        }
    }
}

nonisolated extension ChargeEntry {
    /// Every active battery has a next check date, so no date means no battery yet.
    var hasBattery: Bool { nextInspectionDue != nil }
}

/// Brand-coloured card with the countdown. Turns red once the planned unplug time has passed.
private struct ChargingWidgetView: View {
    let charge: ChargeEntry.Charge
    let isOverdue: Bool
    let isMedium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: isOverdue ? "exclamationmark.triangle.fill" : "bolt.fill")
                Text(isOverdue ? "Unplug now" : "Charging")
                Spacer(minLength: 0)
                if isMedium {
                    Text("Unplug at \(charge.unplugAt, style: .time)")
                        .opacity(0.85)
                }
            }
            .font(.caption.weight(.semibold))

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    timer
                    Text(isOverdue ? "over plan · \(charge.batteryName)" : charge.batteryName)
                        .font(.caption)
                        .lineLimit(1)
                        .opacity(0.85)
                    if !isMedium && !isOverdue {
                        Text("Unplug at \(charge.unplugAt, style: .time)")
                            .font(.caption2)
                            .opacity(0.85)
                    }
                }
                if isMedium {
                    Spacer(minLength: 0)
                    WidgetButton(
                        destination: AppLink.charge,
                        title: "Unplug",
                        icon: "powerplug.fill",
                        foreground: isOverdue ? AppColor.destructive : AppColor.brand,
                        background: AppColor.onBrand
                    )
                }
            }

            if !isOverdue {
                ProgressView(timerInterval: charge.startedAt...max(charge.unplugAt, charge.startedAt), countsDown: false) {
                    EmptyView()
                } currentValueLabel: {
                    EmptyView()
                }
                .tint(AppColor.onBrand)
            }
        }
        .foregroundStyle(AppColor.onBrand)
        .containerBackground((isOverdue ? AppColor.destructive : AppColor.brand).gradient, for: .widget)
    }

    /// Counts down to the unplug time, then counts up how long it has run over.
    private var timer: some View {
        Group {
            if isOverdue {
                Text(timerInterval: charge.unplugAt...Date.distantFuture, countsDown: false)
            } else {
                Text(timerInterval: Date.now...max(charge.unplugAt, .now), countsDown: true)
            }
        }
        .font(.system(size: isMedium ? 34 : 28, weight: .bold, design: .rounded))
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

/// Plain card with the last charge, the next check and a way to start a charge.
private struct IdleWidgetView: View {
    let entry: ChargeEntry
    let isMedium: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "battery.100.bolt")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 32, height: 32)
                    .background(AppColor.brandTint, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                VStack(alignment: .leading, spacing: 0) {
                    Text("Not charging")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: Spacing.md) {
                WidgetFact(title: "Last charge", date: entry.lastChargedAt, empty: "None yet")
                WidgetFact(title: "Next check", date: entry.nextInspectionDue, empty: "–", isDueDate: true)
                if isMedium {
                    Spacer(minLength: 0)
                    WidgetButton(
                        destination: entry.hasBattery ? AppLink.charge : AppLink.garage,
                        title: entry.hasBattery ? "Start charge" : "Add battery",
                        icon: entry.hasBattery ? "bolt.fill" : "plus",
                        foreground: AppColor.onBrand,
                        background: AppColor.brand
                    )
                }
            }
        }
        .containerBackground(AppColor.card, for: .widget)
    }

    private var subtitle: String {
        if !entry.hasBattery { return "Add a battery to begin" }
        return isMedium ? "Plug in, then start a timer" : "Tap to start a charge"
    }
}

/// A capsule button that opens a screen in the app.
private struct WidgetButton: View {
    let destination: URL
    let title: String
    let icon: String
    let foreground: Color
    let background: Color

    var body: some View {
        Link(destination: destination) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(foreground)
                .padding(.horizontal, Spacing.md)
                .frame(minHeight: 44)
                .background(background, in: Capsule())
        }
    }
}

/// A small "title, then date" pair, e.g. "Next check · 2 Nov".
private struct WidgetFact: View {
    let title: String
    let date: Date?
    let empty: String
    /// Due dates in the past read "Overdue" instead of the date.
    var isDueDate = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppColor.textSecondary)
            Group {
                if let date, Calendar.current.isDateInToday(date) {
                    Text("Today")
                } else if let date, isDueDate, date < .now {
                    Text("Overdue")
                } else if let date {
                    Text(date, format: .dateTime.day().month())
                } else {
                    Text(empty)
                }
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(isDueDate && (date ?? .distantFuture) < .now ? AppColor.mediumText : AppColor.textPrimary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }
}

#Preview("Small", as: .systemSmall) {
    ChargeWidget()
} timeline: {
    ChargeEntry.charging
    ChargeEntry.overdue
    ChargeEntry.idle
    ChargeEntry.empty
}

#Preview("Medium", as: .systemMedium) {
    ChargeWidget()
} timeline: {
    ChargeEntry.charging
    ChargeEntry.overdue
    ChargeEntry.idle
    ChargeEntry.empty
}
