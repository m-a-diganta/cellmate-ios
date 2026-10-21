import SwiftUI

// Design: 03 Garage empty, 09 Garage, 04 Add battery, 10 Battery detail

import SwiftUI

@MainActor
struct GarageView: View {
    @State private var viewModel: GarageViewModel
    @State private var activeSheet: GarageSheet?
    @State private var showingChargerRequired = false

    private enum GarageSheet: String, Identifiable {
        case addBattery
        case addCharger

        var id: String { rawValue }
    }

    init() {
        self.init(repository: InMemoryGarageRepository())
    }

    init(repository: any GarageRepository) {
        _viewModel = State(
            initialValue: GarageViewModel(repository: repository)
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                content
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.load()
            }
            .sheet(item: $activeSheet) { sheet in
                form(for: sheet)
            }
            .confirmationDialog(
                "Add a charger first",
                isPresented: $showingChargerRequired,
                titleVisibility: .visible
            ) {
                Button("Add charger") {
                    activeSheet = .addCharger
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text(
                    "A battery needs a matched charger. "
                    + "Add your charger, then add your battery."
                )
            }
            .alert(
                "Something went wrong",
                isPresented: screenErrorBinding
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }

                Button("Retry") {
                    Task {
                        await viewModel.load()
                    }
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var header: some View {
        HStack(spacing: Spacing.md) {
            Text("Garage")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Spacing.sm)

            Menu {
                Button("Add battery", systemImage: "battery.100") {
                    openAddBattery()
                }

                Button("Add charger", systemImage: "powerplug") {
                    activeSheet = .addCharger
                }
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(AppColor.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .disabled(viewModel.isBusy)
            .accessibilityLabel("Add battery or charger")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    @ViewBuilder
    private var content: some View {
        if viewModel.isLoading &&
            viewModel.batteries.isEmpty &&
            viewModel.chargers.isEmpty {
            ProgressView("Loading Garage")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if viewModel.batteries.isEmpty &&
                    viewModel.chargers.isEmpty {
            GeometryReader { geometry in
                ScrollView {
                    GarageEmptyView(onAddBattery: openAddBattery)
                        .padding(.vertical, Spacing.lg)
                        .frame(
                            minHeight: geometry.size.height,
                            alignment: .center
                        )
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    batteriesSection
                    chargersSection
                }
                .padding(Spacing.md)
            }
        }
    }

    private var batteriesSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Batteries")
                        .sectionTitle()

                    Spacer()

                    batteryCount
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Batteries")
                        .sectionTitle()

                    batteryCount
                }
            }

            if viewModel.batteries.isEmpty {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Your charger is ready")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)

                    Text("Now add your first battery and select its charger.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)

                    Button(action: openAddBattery) {
                        Label("Add battery", systemImage: "plus")
                    }
                    .buttonStyle(.appPrimary)
                }
                .card()
            } else {
                VStack(spacing: Spacing.sm) {
                    ForEach(viewModel.batteries) { battery in
                        batteryRow(battery)
                    }
                }
            }
        }
    }

    private var batteryCount: some View {
        Text(
            viewModel.batteries.count == 1
                ? "1 battery"
                : "\(viewModel.batteries.count) batteries"
        )
        .font(.subheadline)
        .foregroundStyle(AppColor.accent)
    }

    private func batteryRow(_ battery: Battery) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            IconRow(
                icon: "battery.100",
                title: battery.name,
                subtitle: "\(battery.brand) · "
                    + "\(battery.capacityWh.formatted()) Wh"
            )

            if battery.isRetired {
                Label("Retired", systemImage: "archivebox")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.horizontal, Spacing.sm)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        AppColor.background,
                        in: RoundedRectangle(cornerRadius: 6)
                    )

                Text("Do not use or charge")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .card()
    }

    private var chargersSection: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack {
                Text("Chargers")
                    .sectionTitle()

                Spacer()

                Button("Add") {
                    activeSheet = .addCharger
                }
                .font(.subheadline)
                .foregroundStyle(AppColor.accent)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityLabel("Add charger")
            }

            if viewModel.chargers.isEmpty {
                Text("No chargers added yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .card()
            } else {
                VStack(spacing: Spacing.md) {
                    ForEach(viewModel.chargers) { charger in
                        IconRow(
                            icon: "powerplug",
                            title: charger.name,
                            subtitle: matchingDescription(for: charger)
                        )

                        if charger.id != viewModel.chargers.last?.id {
                            Divider()
                        }
                    }
                }
                .card()
            }
        }
    }

    private func matchingDescription(for charger: Charger) -> String {
        let matches = viewModel.batteries.filter {
            $0.chargerID == charger.id
        }

        if matches.isEmpty {
            return "Not matched to a battery"
        }

        if matches.count == 1, let battery = matches.first {
            return "Matched to \(battery.name)"
        }

        return "Matched to \(matches.count) batteries"
    }

    private func openAddBattery() {
        if viewModel.chargers.isEmpty {
            showingChargerRequired = true
        } else {
            activeSheet = .addBattery
        }
    }

    private func form(for sheet: GarageSheet) -> some View {
        NavigationStack {
            Group {
                switch sheet {
                case .addBattery:
                    AddBatteryView(
                        chargers: viewModel.chargers.map {
                            AddBatteryView.ChargerOption(
                                id: $0.id,
                                name: $0.name
                            )
                        }
                    ) { draft in
                        Task {
                            let saved = await viewModel.addBattery(
                                RegisterBattery.Input(
                                    name: draft.name,
                                    brand: draft.brand,
                                    capacityWh: draft.capacityWh,
                                    purchaseDate: draft.purchaseDate,
                                    chargerID: draft.chargerID
                                )
                            )

                            if saved {
                                activeSheet = nil
                            }
                        }
                    }

                case .addCharger:
                    AddChargerView { draft in
                        Task {
                            let saved = await viewModel.addCharger(
                                RegisterCharger.Input(
                                    name: draft.name,
                                    brand: draft.brand
                                )
                            )

                            if saved {
                                activeSheet = nil
                            }
                        }
                    }
                }
            }
            .disabled(viewModel.isSaving)
            .overlay {
                if viewModel.isSaving {
                    ProgressView("Saving")
                        .padding(Spacing.lg)
                        .background(
                            AppColor.card,
                            in: RoundedRectangle(
                                cornerRadius: Radius.card
                            )
                        )
                        .accessibilityAddTraits(.updatesFrequently)
                }
            }
            .interactiveDismissDisabled(viewModel.isSaving)
            .alert(
                "Could not save",
                isPresented: formErrorBinding
            ) {
                Button("OK", role: .cancel) {
                    viewModel.errorMessage = nil
                }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
    }

    private var screenErrorBinding: Binding<Bool> {
        Binding(
            get: {
                activeSheet == nil && viewModel.errorMessage != nil
            },
            set: { presented in
                if !presented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }

    private var formErrorBinding: Binding<Bool> {
        Binding(
            get: {
                activeSheet != nil && viewModel.errorMessage != nil
            },
            set: { presented in
                if !presented {
                    viewModel.errorMessage = nil
                }
            }
        )
    }
}

#Preview("Garage — Light") {
    TabView {
        Tab("Garage", systemImage: "battery.100.bolt") {
            GarageView()
        }
    }
    .tint(AppColor.accent)
}

#Preview("Garage — Dark") {
    TabView {
        Tab("Garage", systemImage: "battery.100.bolt") {
            GarageView()
        }
    }
    .tint(AppColor.accent)
    .preferredColorScheme(.dark)
}
