import SwiftUI

// Design: 16 History
@MainActor
struct HistoryView: View {
    @StateObject private var viewModel: HistoryViewModel

    init() {
        self.init(container: .shared)
    }

    init(container: AppContainer) {
        _viewModel = StateObject(wrappedValue: container.makeHistoryViewModel())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    Picker("Show", selection: $viewModel.filter) {
                        ForEach(HistoryFilter.allCases) { filter in
                            Text(filter.rawValue).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)

                    if viewModel.groups.isEmpty {
                        emptyState
                    } else {
                        ForEach(viewModel.groups) { group in
                            daySection(group)
                        }
                        InfoNote(text: "Risk reflects the information recorded at the time.")
                    }
                }
                .padding(Spacing.md)
            }
            .screenBackground()
            .navigationTitle("History")
            .task { await viewModel.load() }
        }
    }

    // MARK: Day section

    private func daySection(_ group: DayGroup) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(HistoryViewModel.dayLabel(for: group.day).uppercased())
                .font(.footnote)
                .foregroundStyle(AppColor.textSecondary)

            VStack(spacing: Spacing.md) {
                ForEach(group.entries) { entry in
                    row(entry)
                    if entry.id != group.entries.last?.id { Divider() }
                }
            }
            .card()
        }
    }

    @ViewBuilder
    private func row(_ entry: HistoryEntry) -> some View {
        if let session = entry.chargeSession {
            NavigationLink {
                ChargeDetailsView(
                    session: session,
                    batteryName: viewModel.batteryName(for: session.batteryID),
                    chargerName: viewModel.chargerName(for: session.chargerID)
                )
            } label: {
                rowContent(entry, showsChevron: true)
            }
            .buttonStyle(.plain)
        } else {
            rowContent(entry, showsChevron: false)
        }
    }

    private func rowContent(_ entry: HistoryEntry, showsChevron: Bool) -> some View {
        let isCharge = entry.chargeSession != nil
        return IconRow(
            icon: isCharge ? "bolt" : "checklist",
            title: entry.title,
            subtitle: entry.subtitle
        ) {
            HStack(spacing: Spacing.sm) {
                if let level = entry.riskLevel {
                    RiskChip(level: level)
                }
                if showsChevron { RowChevron() }
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Nothing here yet")
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text("Charges and inspections will appear here.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
        .card()
    }
}
