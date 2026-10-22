import SwiftUI

// Design: 03 Garage empty, 09 Garage, 04 Add battery, 10 Battery detail

import SwiftUI

@MainActor
struct GarageView: View {
    @Environment(\.scenePhase) private var scenePhase
    
    @State private var viewModel: GarageViewModel
    @State private var activeSheet: GarageSheet?
    @State private var showingChargerRequired = false
    @State private var retirementReason = ""
    @State private var path: [GarageRoute] = []
    @State private var photoStorageError: String?

    @State private var inspectionSessions: [
        UUID: InspectionViewModel
    ] = [:]

    private enum GarageRoute: Hashable {
        case battery(UUID)
        case checklist(UUID)
        case stopUsing(UUID)
    }
    
    private enum GarageSheet: Identifiable {
        case addBattery
        case addCharger
        case retireBattery(UUID)

        var id: String {
            switch self {
            case .addBattery:
                return "addBattery"
            case .addCharger:
                return "addCharger"
            case .retireBattery(let id):
                return "retire-\(id.uuidString)"
            }
        }
    }

    init() {
        self.init(repository: InMemoryGarageRepository())
    }

    init(repository: any GarageRepository) {
        let photoStore: (any InspectionPhotoStoring)?
        let storageError: String?

        do {
            photoStore = try LocalInspectionPhotoStore()
            storageError = nil
        } catch {
            photoStore = nil
            storageError =
                "Photo storage could not be opened. "
                + "You can still complete inspections without a photo. "
                + "Try restarting the app."
        }

        _viewModel = State(
            initialValue: GarageViewModel(
                repository: repository,
                photoStore: photoStore
            )
        )

        _photoStorageError = State(initialValue: storageError)
    }

    var body: some View {
        NavigationStack (path: $path){
            VStack(spacing: 0) {
                header
                content
            }
            .screenBackground()
            .navigationDestination(for: GarageRoute.self) { route in
                inspectionDestination(for: route)
            }
            .navigationDestination(for: GarageRoute.self) { route in
                inspectionDestination(for: route)
            }
            .onChange(of: path) { _, _ in
                Task {
                    await releaseUnusedInspectionSessions()
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await viewModel.load()

                if let photoStorageError,
                   viewModel.errorMessage == nil {
                    viewModel.errorMessage = photoStorageError
                    self.photoStorageError = nil
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    Task {
                        await releaseUnusedInspectionSessions()
                        guard !viewModel.isBusy else {
                            return
                        }

                        await viewModel.refreshInspectionStatuses()
                    }
                }
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
                        NavigationLink(value: GarageRoute.battery(battery.id)) {
                            batteryRow(battery)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens battery details")
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
            ) {
                RowChevron()
            }

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
            } else {
                inspectionStatusRow(for: battery)
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
                    
                case .retireBattery(let batteryID):
                    retirementForm(for: batteryID)
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
    
    @ViewBuilder
    private func batteryDestination(for id: UUID) -> some View {
        if let battery = viewModel.batteries.first(where: {
            $0.id == id
        }) {
            BatteryDetailView(
                battery: battery,
                chargerName: viewModel.chargerName(for: battery),
                lastInspectionText: viewModel.inspectionSummaries[id],
                onStartCharge: {
                    viewModel.errorMessage =
                        "Charging is not connected to Garage yet."
                },
                onInspect: {
                    openInspection(for: id)
                },
                onRetire: {
                    retirementReason = ""
                    activeSheet = .retireBattery(id)
                }
            )
            .task {
                await viewModel.loadInspectionSummary(for: id)
            }
        } else {
            ContentUnavailableView(
                "Battery unavailable",
                systemImage: "battery.0",
                description: Text(
                    "Return to Garage and reload your records."
                )
            )
            .screenBackground()
        }
    }
    
    private func retirementForm(for batteryID: UUID) -> some View {
        Form {
            Section {
                TextField(
                    "For example, no longer in use",
                    text: $retirementReason,
                    axis: .vertical
                )
                .lineLimit(3...6)
                .accessibilityLabel("Retirement reason")
            } header: {
                Text("Reason")
            } footer: {
                Text(
                    "The battery and its existing records will be kept."
                )
            }

            Section {
                Button("Retire battery", role: .destructive) {
                    Task {
                        let saved = await viewModel.retireBattery(
                            id: batteryID,
                            reason: retirementReason
                        )

                        if saved {
                            activeSheet = nil
                        }
                    }
                }
                .disabled(
                    retirementReason.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
                )
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Retire battery")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") {
                    activeSheet = nil
                }
                .disabled(viewModel.isSaving)
            }
        }
    }
    
    private func openInspection(for batteryID: UUID) {
        let sessionID = UUID()

        inspectionSessions[sessionID] =
            viewModel.makeInspectionViewModel(for: batteryID)

        path.append(GarageRoute.checklist(sessionID))
    }

    @ViewBuilder
    private func inspectionDestination(
        for route: GarageRoute
    ) -> some View {
        switch route {
        case .battery(let batteryID):
            batteryDestination(for: batteryID)
            
        case .checklist(let sessionID):
            if let model = inspectionSessions[sessionID],
               let battery = viewModel.batteries.first(where: {
                   $0.id == model.batteryID
               }) {
                InspectView(
                    batteryName: battery.name,
                    viewModel: model,
                    backTitle: "Battery",
                    onFinish: { inspection in
                        viewModel.inspectionDidSave(inspection)

                        if inspection.result == .fail ||
                            inspection.hasReportedProblem {
                            path.append(
                                GarageRoute.stopUsing(sessionID)
                            )
                        } else {
                            // Return to Battery detail after a successful save.
                            if !path.isEmpty {
                                path.removeLast()
                            }
                        }
                    }
                )
            } else {
                inspectionUnavailable
            }

        case .stopUsing(let sessionID):
            if let model = inspectionSessions[sessionID],
               let inspection = model.savedInspection,
               let battery = viewModel.batteries.first(where: {
                   $0.id == model.batteryID
               }) {
                StopUsingView(
                    batteryName: battery.name,
                    reportedProblems: inspection.items
                        .filter { $0.finding == .problem }
                        .map(\.kind),
                    isRetired: battery.isRetired,
                    onRetire: {
                        let problems = inspection.items
                            .filter { $0.finding == .problem }
                            .map { $0.kind.rawValue }
                            .joined(separator: ", ")

                        retirementReason = problems.isEmpty
                            ? "Problem reported during inspection"
                            : "Inspection reported: \(problems)"

                        activeSheet = .retireBattery(battery.id)
                    }
                )
            } else {
                inspectionUnavailable
            }
        }
    }

    private var inspectionUnavailable: some View {
        VStack(spacing: Spacing.md) {
            ContentUnavailableView(
                "Inspection unavailable",
                systemImage: "checklist",
                description: Text(
                    "Return to the battery and start a new inspection."
                )
            )

            Button("Back") {
                if !path.isEmpty {
                    path.removeLast()
                }
            }
            .buttonStyle(.appSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.bottom, Spacing.md)
        }
        .screenBackground()
    }
    
    @ViewBuilder
    private func inspectionStatusRow(
        for battery: Battery
    ) -> some View {
        if let status = viewModel.inspectionStatuses[battery.id] {
            switch status {
            case .notRequired:
                EmptyView()

            case .neverInspected:
                inspectionStatus(
                    title: "Inspection due",
                    icon: "checklist",
                    detail: "No inspections yet",
                    foreground: AppColor.mediumText,
                    background: AppColor.mediumBackground
                )

            case .needsAttention:
                inspectionStatus(
                    title: "Needs attention",
                    icon: "exclamationmark.triangle",
                    detail: "Review the inspection",
                    foreground: AppColor.highText,
                    background: AppColor.highBackground
                )

            case .upToDate(let dueDate):
                inspectionStatus(
                    title: "Inspection current",
                    icon: "calendar",
                    detail: "Next check \(inspectionDate(dueDate))",
                    foreground: AppColor.textSecondary,
                    background: AppColor.background
                )

            case .dueSoon(let dueDate):
                inspectionStatus(
                    title: "Due soon",
                    icon: "calendar.badge.clock",
                    detail: "Inspect by \(inspectionDate(dueDate))",
                    foreground: AppColor.mediumText,
                    background: AppColor.mediumBackground
                )

            case .dueToday:
                inspectionStatus(
                    title: "Inspection due",
                    icon: "calendar.badge.exclamationmark",
                    detail: "Inspect today",
                    foreground: AppColor.mediumText,
                    background: AppColor.mediumBackground
                )

            case .overdue(let dueDate):
                inspectionStatus(
                    title: "Overdue",
                    icon: "calendar.badge.exclamationmark",
                    detail: "Due \(inspectionDate(dueDate))",
                    foreground: AppColor.highText,
                    background: AppColor.highBackground
                )
            }
        } else {
            Text("Inspection status unavailable")
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func inspectionStatus(
        title: String,
        icon: String,
        detail: String,
        foreground: Color,
        background: Color
    ) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Spacing.sm) {
                inspectionBadge(
                    title: title,
                    icon: icon,
                    foreground: foreground,
                    background: background
                )

                Spacer(minLength: Spacing.sm)

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: true, vertical: false)
            }

            VStack(alignment: .leading, spacing: Spacing.sm) {
                inspectionBadge(
                    title: title,
                    icon: icon,
                    foreground: foreground,
                    background: background
                )

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func inspectionBadge(
        title: String,
        icon: String,
        foreground: Color,
        background: Color
    ) -> some View {
        Label(title, systemImage: icon)
            .font(.caption.weight(.semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(
                background,
                in: RoundedRectangle(cornerRadius: 6)
            )
    }

    private func inspectionDate(_ date: Date) -> String {
        date.formatted(
            .dateTime.day().month(.abbreviated)
        )
    }
    
    private var activeInspectionSessionIDs: Set<UUID> {
        Set(
            path.compactMap { route -> UUID? in
                switch route {
                case .battery:
                    return nil

                case .checklist(let sessionID),
                     .stopUsing(let sessionID):
                    return sessionID
                }
            }
        )
    }

    private func releaseUnusedInspectionSessions() async {
        let unusedIDs = Set(inspectionSessions.keys)
            .subtracting(activeInspectionSessionIDs)

        for sessionID in unusedIDs {
            guard !activeInspectionSessionIDs.contains(sessionID),
                  let model = inspectionSessions[sessionID] else {
                continue
            }

            // Keep busy sessions until a later cleanup attempt.
            guard !model.isBusy else {
                continue
            }

            let cleanedUp = await model.discardDraft()

            guard cleanedUp else {
                viewModel.errorMessage = model.errorMessage
                    ?? "An unused inspection photo could not be removed."
                continue
            }

            // Navigation may have changed while cleanup was running.
            guard !activeInspectionSessionIDs.contains(sessionID) else {
                continue
            }

            inspectionSessions.removeValue(forKey: sessionID)
        }
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
