import SwiftUI

// Design: 06 Start charge
struct StartChargeView: View {
    @ObservedObject var viewModel: ChargeViewModel

    private let durationChoices = [1, 2, 3, 4, 5, 6, 8]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                if viewModel.availableBatteries.isEmpty {
                    emptyState
                } else {
                    pickersCard
                    if !viewModel.chargerMatchesSelectedBattery {
                        AlertBanner(text: "This is not the charger saved with this battery.")
                    }
                    placeSection
                    durationCard
                    checklistSection
                    RiskSummaryCard(
                        title: "Risk check",
                        level: viewModel.liveRisk.level,
                        flags: viewModel.liveRisk.flags
                    )
                    startSection
                }
            }
            .padding(Spacing.md)
        }
        .screenBackground()
        .navigationTitle("Start charge")
    }

    // MARK: Battery and charger

    private var pickersCard: some View {
        VStack(spacing: Spacing.md) {
            menuRow(icon: "battery.100", title: "Battery", value: batteryText) {
                ForEach(viewModel.availableBatteries) { battery in
                    Button("\(battery.name) · \(battery.brand)") {
                        viewModel.selectBattery(battery.id)
                    }
                }
            }
            Divider()
            menuRow(icon: "powerplug", title: "Charger", value: chargerText) {
                ForEach(viewModel.chargers) { charger in
                    Button("\(charger.name) · \(charger.brand)") {
                        viewModel.selectCharger(charger.id)
                    }
                }
            }
        }
        .card()
    }

    private var batteryText: String {
        guard let battery = viewModel.selectedBattery else { return "Select" }
        return battery.name
    }

    private var chargerText: String {
        guard let charger = viewModel.selectedCharger else { return "Select" }
        return charger.name
    }

    private func menuRow<MenuItems: View>(
        icon: String,
        title: String,
        value: String,
        @ViewBuilder items: () -> MenuItems
    ) -> some View {
        Menu {
            items()
        } label: {
            IconRow(icon: icon, title: title) {
                HStack(spacing: Spacing.xs) {
                    Text(value)
                        .foregroundStyle(AppColor.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
    }

    // MARK: Place

    private var placeSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Where will you charge?").sectionTitle()
            Picker("Where will you charge?", selection: $viewModel.place) {
                ForEach(ChargePlace.allCases) { place in
                    Text(place.displayName).tag(place)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: Duration

    private var durationCard: some View {
        Menu {
            ForEach(durationChoices, id: \.self) { hours in
                Button("\(hours) h") { viewModel.plannedDurationMinutes = hours * 60 }
            }
        } label: {
            IconRow(
                icon: "timer",
                title: "Plan to unplug after",
                subtitle: "Unplug by \(viewModel.plannedUnplugPreview.formatted(date: .omitted, time: .shortened))"
            ) {
                HStack(spacing: Spacing.xs) {
                    Text("\(viewModel.plannedDurationMinutes / 60) h")
                        .foregroundStyle(AppColor.textSecondary)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
        }
        .card()
    }

    // MARK: Checklist

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Before you plug in").sectionTitle()
            VStack(spacing: Spacing.md) {
                ForEach($viewModel.checklist) { $item in
                    Button {
                        item.ticked.toggle()
                    } label: {
                        HStack(spacing: Spacing.md) {
                            Image(systemName: item.ticked ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundStyle(item.ticked ? AppColor.accent : AppColor.textSecondary)
                            Text(item.label)
                                .foregroundStyle(AppColor.textPrimary)
                                .multilineTextAlignment(.leading)
                            Spacer(minLength: 0)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(item.ticked ? .isSelected : [])
                    if item.id != viewModel.checklist.last?.id { Divider() }
                }
            }
            .card()
        }
    }

    // MARK: Start

    private var startSection: some View {
        VStack(spacing: Spacing.sm) {
            Button("Start") {
                Task { await viewModel.startChargeTapped() }
            }
            .buttonStyle(.appPrimary)
            .disabled(!viewModel.canStart)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(AppColor.highText)
            }

            InfoNote(text: "Starts a reminder, not the charger. It can’t cut power.")
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Add a battery first")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text("Open Garage and add a battery and its charger. Then you can start a charge.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .card()
    }
}
