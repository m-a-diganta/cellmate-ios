import SwiftUI

enum HomeRoute: Hashable {
    case settings
    case startCharge
    case charging
}

// Design: 05 Home (Not on Charge and On Charge), 20 Home dark
@MainActor
struct HomeView: View {
    @Environment(AppRouter.self) private var router
    @State private var viewModel: HomeViewModel
    @State private var path: [HomeRoute] = []

    init() {
        self.init(viewModel: HomeViewModel(provider: AppContainer.shared.homeSummaryProvider))
    }

    init(viewModel: HomeViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    private var summary: HomeSummary { viewModel.summary }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    ChargeStatusCard(state: summary.chargeState) { path.append(.charging) }

                    QuickActionsRow(
                        isCharging: summary.isCharging,
                        onChargeAction: { path.append(summary.isCharging ? .charging : .startCharge) },
                        onInspect: { router.selectedTab = .garage },
                        onAsk: { router.selectedTab = .ask }
                    )

                    attentionSection
                    batteriesSection
                }
                .padding(Spacing.md)
            }
            .screenBackground()
            .navigationTitle("Home")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        path.append(.settings)
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .navigationDestination(for: HomeRoute.self) { route in
                destination(for: route)
            }
            .task { await viewModel.load() }
            .onChange(of: path) { _, newPath in
                if newPath.isEmpty {
                    Task { await viewModel.load() }
                }
            }
        }
    }

    @ViewBuilder
    private func destination(for route: HomeRoute) -> some View {
        switch route {
        case .settings:
            SettingsView()
        case .startCharge, .charging:
            // One flow decides what to show: the form, the countdown or the result.
            ChargeFlowView(viewModel: AppContainer.shared.chargeViewModel) {
                path.removeAll()
            }
        }
    }

    // MARK: Needs attention

    private var attentionSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Needs attention").sectionTitle()
            VStack(spacing: Spacing.md) {
                if summary.attention.isEmpty {
                    IconRow(icon: "checkmark.circle", title: "Nothing needs attention", subtitle: "Your checks are up to date", showsTile: false)
                } else {
                    ForEach(summary.attention) { item in
                        Button {
                            router.selectedTab = .garage
                        } label: {
                            IconRow(icon: "calendar.badge.clock", title: item.title, subtitle: item.subtitle, showsTile: false) {
                                RowChevron()
                            }
                        }
                        .buttonStyle(.plain)
                        if item.id != summary.attention.last?.id { Divider() }
                    }
                }
            }
            .card()
        }
    }

    // MARK: Your batteries

    @ViewBuilder
    private var batteriesSection: some View {
        if summary.batteries.isEmpty {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                Text("Your batteries").sectionTitle()
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("Add your first battery")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Give your e-bike or e-scooter battery a home for charge logs, checks and reminders.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                    Button("Add battery") { router.selectedTab = .garage }
                        .buttonStyle(.appPrimary)
                }
                .card()
            }
        } else {
            VStack(alignment: .leading, spacing: Spacing.sm) {
                HStack {
                    Text("Your batteries").sectionTitle()
                    Spacer()
                    Button("See all") { router.selectedTab = .garage }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.accent)
                }
                VStack(spacing: Spacing.md) {
                    ForEach(summary.batteries) { battery in
                        Button {
                            router.selectedTab = .garage
                        } label: {
                            IconRow(icon: "battery.100", title: battery.name, subtitle: battery.detail, showsTile: false) {
                                RiskChip(level: battery.risk)
                            }
                        }
                        .buttonStyle(.plain)
                        if battery.id != summary.batteries.last?.id { Divider() }
                    }
                }
                .card()
                Text("Low risk reflects logged checks, not a safety guarantee.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
    }
}

#Preview("Charging") {
    HomeView(viewModel: HomeViewModel(provider: MockHomeSummaryProvider(scenario: .charging)))
        .environment(AppRouter())
}

#Preview("Not on charge") {
    HomeView(viewModel: HomeViewModel(provider: MockHomeSummaryProvider(scenario: .idle)))
        .environment(AppRouter())
}

#Preview("Dark") {
    HomeView(viewModel: HomeViewModel(provider: MockHomeSummaryProvider(scenario: .charging)))
        .environment(AppRouter())
        .preferredColorScheme(.dark)
}

#Preview("No batteries") {
    HomeView(viewModel: HomeViewModel(provider: MockHomeSummaryProvider(scenario: .empty)))
        .environment(AppRouter())
}
