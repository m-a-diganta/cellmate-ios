//
//  GarageEmptyView.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import SwiftUI

struct GarageEmptyView: View {
    /// A battery has to be matched to a charger, so an empty Garage starts with the charger.
    let onAddCharger: () -> Void

    var body: some View {
        VStack(spacing: Spacing.lg) {
            introductionCard
            informationNote
        }
        .padding(.horizontal, Spacing.md)
    }

    private var introductionCard: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "powerplug")
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
                .accessibilityHidden(true)
                .padding(.top, Spacing.lg)

            Text("Add your first charger")
                .font(.title2.bold())
                .foregroundStyle(AppColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)

            Text(
                "Each battery is matched to the charger it uses, "
                + "so start with your charger. Your battery comes next."
            )
            .font(.subheadline)
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            Button(action: onAddCharger) {
                Label("Add charger", systemImage: "plus")
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
                "Use the details on your charger label. "
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
    GarageEmptyView(onAddCharger: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
}

#Preview("Dark") {
    GarageEmptyView(onAddCharger: {})
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
        .preferredColorScheme(.dark)
}
