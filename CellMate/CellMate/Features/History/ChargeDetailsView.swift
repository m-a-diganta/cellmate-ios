import SwiftUI

// Design: 17 Charge details
struct ChargeDetailsView: View {
    let session: ChargeSession
    let batteryName: String
    let chargerName: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                summaryCard
                flagsSection
                timelineSection

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    InfoNote(text: "Times are logged reminders and your entries, not readings from the charger or battery.")
                    InfoNote(text: FixedWording.cantTellSafe)
                    Text("Risk rules version \(session.rulesVersion)")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .padding(Spacing.md)
        }
        .screenBackground()
        .navigationTitle("Charge details")
    }

    // MARK: Summary

    private var summaryCard: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack(alignment: .firstTextBaseline) {
                Text(batteryName)
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                if let level = session.riskLevel {
                    RiskChip(level: level)
                }
            }
            Text("\(session.startedAt.formatted(date: .abbreviated, time: .omitted)) · \(session.timeRangeText)")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
            Text("\(session.durationText) · \(session.place.displayName) · \(chargerName)")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .card()
    }

    // MARK: Flags

    private var flagsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Risk flags").sectionTitle()
            if session.riskFlags.isEmpty {
                Text("No flags. Everything logged for this charge looked fine.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .card()
            } else {
                ForEach(session.riskFlags) { flag in
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Label(flag.type.displayName, systemImage: flag.severity.symbol)
                            .font(.subheadline.weight(.semibold))
                        Text(flag.message)
                            .font(.footnote)
                    }
                    .foregroundStyle(flag.severity.textColor)
                    .padding(Spacing.md)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(flag.severity.backgroundColor, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
            }
        }
    }

    // MARK: Timeline

    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Timeline").sectionTitle()
            VStack(spacing: 0) {
                TimelineRow(
                    time: session.startedAt,
                    title: "Charge reminder started",
                    detail: session.checklistTicks.allSatisfy { $0 } ? "Pre-charge checklist completed" : "Checklist not completed",
                    isLast: false
                )
                TimelineRow(
                    time: session.plannedUnplug,
                    title: "Unplug reminder due",
                    detail: session.overnight ? "Past bedtime" : "Planned unplug time",
                    isLast: session.endedAt == nil
                )
                if let end = session.endedAt {
                    TimelineRow(
                        time: end,
                        title: "Marked as unplugged",
                        detail: "Session saved to History",
                        isLast: true
                    )
                }
            }
            .card()
        }
    }
}

private struct TimelineRow: View {
    let time: Date
    let title: String
    let detail: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            VStack(spacing: 0) {
                Circle()
                    .fill(AppColor.accent)
                    .frame(width: 10, height: 10)
                    .padding(.top, 5)
                if !isLast {
                    Rectangle()
                        .fill(AppColor.accent.opacity(0.4))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(time.formatted(date: .omitted, time: .shortened))
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .padding(.bottom, isLast ? 0 : Spacing.md)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
    }
}

extension RiskFlagType {
    var displayName: String {
        switch self {
        case .nearBedtime: "Bedtime"
        case .unattended: "Unattended"
        case .place: "Place"
        case .unmatchedCharger: "Unmatched charger"
        case .tooLong: "Too long"
        }
    }
}
