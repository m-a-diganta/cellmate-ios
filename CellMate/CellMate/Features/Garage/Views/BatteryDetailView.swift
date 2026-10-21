//
//  BatteryDetailView.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import SwiftUI

struct BatteryDetailView: View {
    let battery: Battery
    let chargerName: String

    let chargeCount: Int?
    let overnightCount: Int?
    let riskLevel: RiskLevel?
    let lastInspectionText: String?

    let onStartCharge: () -> Void
    let onInspect: () -> Void
    let onRetire: () -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var showingRetirementConfirmation = false

    init(
        battery: Battery,
        chargerName: String,
        chargeCount: Int? = nil,
        overnightCount: Int? = nil,
        riskLevel: RiskLevel? = nil,
        lastInspectionText: String? = nil,
        onStartCharge: @escaping () -> Void,
        onInspect: @escaping () -> Void,
        onRetire: @escaping () -> Void
    ) {
        self.battery = battery
        self.chargerName = chargerName
        self.chargeCount = chargeCount
        self.overnightCount = overnightCount
        self.riskLevel = riskLevel
        self.lastInspectionText = lastInspectionText
        self.onStartCharge = onStartCharge
        self.onInspect = onInspect
        self.onRetire = onRetire
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    batterySummary
                    statistics

                    Text("Battery records")
                        .sectionTitle()
                        .accessibilityAddTraits(.isHeader)

                    records

                    Text(
                        "A low risk record doesn't certify battery health. "
                        + "Inspect again if anything changes."
                    )
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Spacing.md)
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .safeAreaInset(edge: .bottom, spacing: 0) {
            actions
        }
        .confirmationDialog(
            "Retire this battery?",
            isPresented: $showingRetirementConfirmation,
            titleVisibility: .visible
        ) {
            Button("Retire battery", role: .destructive) {
                onRetire()
            }

            Button("Cancel", role: .cancel) {}
        } message: {
            Text(
                "Retired batteries cannot start new charges. "
                + "Their existing records are kept."
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Label("Garage", systemImage: "chevron.left")
                    .font(.body)
                    .foregroundStyle(AppColor.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to Garage")

            Text(battery.name)
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Spacing.md)
    }

    private var batterySummary: some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            Image(systemName: "battery.100.bolt")
                .font(.title2)
                .foregroundStyle(AppColor.accent)
                .frame(width: 64, height: 64)
                .background(
                    AppColor.brandTint,
                    in: RoundedRectangle(
                        cornerRadius: Radius.card
                    )
                )
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text(
                    "\(battery.brand) · "
                    + "\(battery.capacityWh.formatted()) Wh"
                )
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)

                Text(
                    "Bought "
                    + battery.purchaseDate.formatted(
                        date: .abbreviated,
                        time: .omitted
                    )
                )
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)

                if battery.isRetired {
                    Label("Retired", systemImage: "archivebox")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                } else if let riskLevel {
                    RiskChip(level: riskLevel)
                } else {
                    Text("No charge risk assessment available")
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .card()
    }

    private var statistics: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.sm))

        return layout {
            statisticCard(
                count: chargeCount,
                title: "charges",
                tint: AppColor.textPrimary
            )

            statisticCard(
                count: overnightCount,
                title: "overnight",
                tint: AppColor.mediumText
            )
        }
    }

    private func statisticCard(
        count: Int?,
        title: String,
        tint: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.xs) {
            Text(count.map { $0.formatted() } ?? "—")
                .font(.largeTitle.bold())
                .foregroundStyle(tint)

            Text(title)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .card()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(
            count.map { $0.formatted() } ?? "Not available yet"
        )
    }

    private var records: some View {
        VStack(spacing: Spacing.md) {
            IconRow(
                icon: "checklist",
                title: "Last inspection",
                subtitle: lastInspectionText ?? "Not available yet"
            )

            IconRow(
                icon: "powerplug",
                title: "Charger",
                subtitle: chargerName
            )
        }
        .card()
    }

    @ViewBuilder
    private var actions: some View {
        if battery.isRetired {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Label(
                    "Do not use or charge",
                    systemImage: "exclamationmark.triangle"
                )
                .font(.headline)
                .foregroundStyle(AppColor.highText)

                if let reason = battery.retirementReason {
                    Text(reason)
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Spacing.md)
            .background(AppColor.background)
        } else {
            VStack(spacing: Spacing.sm) {
                primaryActions

                Button("Retire", role: .destructive) {
                    showingRetirementConfirmation = true
                }
                .font(.body)
                .foregroundStyle(AppColor.highText)
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .padding(Spacing.md)
            .background(AppColor.background)
        }
    }

    private var primaryActions: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: Spacing.sm))
            : AnyLayout(HStackLayout(spacing: Spacing.sm))

        return layout {
            Button(action: onStartCharge) {
                Text("Start charge")
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.appPrimary)

            Button(action: onInspect) {
                Text("Inspect")
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.appSecondary)
        }
    }
}

#Preview("Light") {
    NavigationStack {
        BatteryDetailView(
            battery: Battery(
                name: "Battery A",
                brand: "Bosch",
                capacityWh: 720,
                purchaseDate: Date(),
                chargerID: UUID()
            ),
            chargerName: "Bosch 4A",
            chargeCount: 24,
            overnightCount: 3,
            riskLevel: .low,
            lastInspectionText: "12 Oct · no warning signs reported",
            onStartCharge: {},
            onInspect: {},
            onRetire: {}
        )
    }
}

#Preview("Dark — Retired") {
    NavigationStack {
        BatteryDetailView(
            battery: Battery(
                name: "Battery C",
                brand: "Generic",
                capacityWh: 360,
                purchaseDate: Date(),
                chargerID: UUID(),
                status: .retired(reason: "No longer in use")
            ),
            chargerName: "Original charger",
            onStartCharge: {},
            onInspect: {},
            onRetire: {}
        )
    }
    .preferredColorScheme(.dark)
}
