//
//  StopUsingView.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import SwiftUI

struct StopUsingView: View {
    let batteryName: String
    let reportedProblems: [Inspection.Item.Kind]
    let isRetired: Bool
    let onRetire: () -> Void

    @Environment(\.dismiss) private var dismiss

    init(
        batteryName: String,
        reportedProblems: [Inspection.Item.Kind],
        isRetired: Bool = false,
        onRetire: @escaping () -> Void
    ) {
        self.batteryName = batteryName
        self.reportedProblems = reportedProblems
        self.isRetired = isRetired
        self.onRetire = onRetire
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    warningCard
                    adviceCard
                    emergencyCard
                }
                .padding(Spacing.md)
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            retirementAction
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Label("Inspection", systemImage: "chevron.left")
                    .font(.body)
                    .foregroundStyle(AppColor.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to inspection")

            Text("Stop using")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var warningCard: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "exclamationmark.octagon")
                .font(.largeTitle)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("\(batteryName) · \(problemSummary)")
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Do not use or charge this battery.")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(AppColor.highText)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.highBackground,
            in: RoundedRectangle(cornerRadius: Radius.card)
        )
        .accessibilityElement(children: .combine)
    }

    private var adviceCard: some View {
        VStack(alignment: .leading, spacing: Spacing.lg) {
            adviceStep(
                number: 1,
                title: "Stop use. Keep clear.",
                detail:
                    "Don't touch or move a hot, swollen or smoking "
                    + "battery. Keep others away."
            )

            adviceStep(
                number: 2,
                title: "Disconnect only if safe",
                detail:
                    "Switch off power at the wall only if you can do "
                    + "so without approaching the battery."
            )

            adviceStep(
                number: 3,
                title: "Arrange professional advice",
                detail:
                    "Contact the maker or a qualified battery service. "
                    + "Never put it in household bins."
            )
        }
        .card()
    }

    private func adviceStep(
        number: Int,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(AppColor.highText)
                .padding(Spacing.sm)
                .background(
                    AppColor.highBackground,
                    in: Circle()
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var emergencyCard: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "phone")
                .font(.title2)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text("Smoke or flames?")
                    .font(.headline)

                Text("Leave the area. Stay clear. Call Triple Zero (000).")
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(AppColor.highText)
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            AppColor.highBackground,
            in: RoundedRectangle(cornerRadius: Radius.card)
        )
        .accessibilityElement(children: .combine)
    }

    private var retirementAction: some View {
        VStack(spacing: Spacing.sm) {
            if isRetired {
                Label("Battery retired", systemImage: "archivebox")
                    .font(.headline)
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 50)
            } else {
                Button(action: onRetire) {
                    Text("Retire Battery")
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                }
                .buttonStyle(.appDestructive)
            }

            Text(
                "Retiring logs this battery as not for use. "
                + "It does not arrange disposal."
            )
            .font(.footnote)
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Spacing.md)
        .background(AppColor.background)
    }

    private var problemSummary: String {
        let names = Inspection.Item.Kind.allCases
            .filter { reportedProblems.contains($0) }
            .map { kind in
                switch kind {
                case .swelling:
                    return "swelling"
                case .heat:
                    return "heat"
                case .smell:
                    return "smell"
                case .damage:
                    return "damage"
                case .charger:
                    return "charger"
                }
            }

        return names.isEmpty
            ? "problem reported"
            : names.joined(separator: ", ")
    }
}

#Preview("Light") {
    NavigationStack {
        StopUsingView(
            batteryName: "Battery A",
            reportedProblems: [.swelling],
            onRetire: {}
        )
    }
}

#Preview("Dark") {
    NavigationStack {
        StopUsingView(
            batteryName: "Battery A",
            reportedProblems: [.swelling, .heat],
            onRetire: {}
        )
    }
    .preferredColorScheme(.dark)
}
