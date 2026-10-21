//
//  GarageEmptyView.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import SwiftUI

struct GarageEmptyView: View {
    let onAddBattery: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            introductionCard
            informationNote
        }
        .padding(.horizontal, Spacing.md)
    }

    private var introductionCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "battery.0")
                .font(.system(size: 30, weight: .regular))
                .foregroundStyle(AppColor.accent)
                .frame(width: 88, height: 88)
                .background(
                    AppColor.brandTint,
                    in: RoundedRectangle(
                        cornerRadius: 24,
                        style: .continuous
                    )
                )
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppColor.accent)
                }
                .accessibilityHidden(true)
                .padding(.top, Spacing.lg)

            Text("Add your first battery")
                .font(.title2.bold())
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(
                "Give your e-bike or e-scooter battery a home "
                + "for charge logs, checks and reminders."
            )
            .font(.subheadline)
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button(action: onAddBattery) {
                Label("Add battery", systemImage: "plus")
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.appPrimary)
            .padding(.top, Spacing.md)
        }
        .frame(maxWidth: .infinity)
        .card()
    }

    private var informationNote: some View {
        HStack(alignment: .top, spacing: Spacing.sm) {
            Image(systemName: "info.circle")
                .font(.subheadline)
                .accessibilityHidden(true)

            Text(
                "Start with the details on your battery label. "
                + "You can update them later."
            )
            .font(.footnote)
            .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(AppColor.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Light") {
    GarageEmptyView(onAddBattery: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
}

#Preview("Dark") {
    GarageEmptyView(onAddBattery: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .preferredColorScheme(.dark)
}
