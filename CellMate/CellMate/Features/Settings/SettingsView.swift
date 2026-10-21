import SwiftUI
import UIKit

// Design: 18 Settings
struct SettingsView: View {
    @AppStorage(AppStorageKey.bedtimeMinutes) private var bedtimeMinutes = BedtimeSetting.defaultMinutes
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = true
    @Environment(\.openURL) private var openURL
    @State private var viewModel = SettingsViewModel(records: PlaceholderRecordsManager())
    @State private var showBedtimePicker = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        List {
            chargingSection
            permissionsSection
            dataSection
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .screenBackground()
        .navigationTitle("Settings")
        .safeAreaInset(edge: .bottom) { footer }
        .sheet(isPresented: $showBedtimePicker) {
            BedtimePickerSheet(minutes: $bedtimeMinutes)
        }
        .sheet(item: $viewModel.exportFile) { file in
            ShareSheet(items: [file.url])
        }
        .confirmationDialog("Delete all data?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete everything", role: .destructive) {
                Task {
                    if await viewModel.deleteAll() {
                        bedtimeMinutes = BedtimeSetting.defaultMinutes
                        hasCompletedOnboarding = false
                    }
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes every battery, charge and inspection from this iPhone. It can't be undone.")
        }
        .alert("Something went wrong", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: Sections

    private var chargingSection: some View {
        Section {
            Button {
                showBedtimePicker = true
            } label: {
                IconRow(icon: "moon", title: "Bedtime") {
                    HStack(spacing: Spacing.sm) {
                        Text(BedtimeSetting.displayText(minutes: bedtimeMinutes))
                            .foregroundStyle(AppColor.textSecondary)
                        RowChevron()
                    }
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(AppColor.card)
        } header: {
            Text("Charging").sectionTitle()
        } footer: {
            Text("We'll flag charge plans that run close to bedtime. Reminders never switch off power.")
        }
    }

    private var permissionsSection: some View {
        Section {
            Button(action: openSystemSettings) {
                IconRow(icon: "bell", title: "Notifications", subtitle: "Manage reminder access") {
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(AppColor.card)

            Button(action: openSystemSettings) {
                IconRow(icon: "camera", title: "Camera", subtitle: "Asked when you add a photo") {
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(AppColor.card)
        } header: {
            Text("Permissions").sectionTitle()
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                Task { await viewModel.export() }
            } label: {
                IconRow(icon: "square.and.arrow.up", title: "Export records", subtitle: "Save a copy of your logs") {
                    if viewModel.isWorking {
                        ProgressView()
                    } else {
                        RowChevron()
                    }
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(AppColor.card)

            Button {
                showDeleteConfirmation = true
            } label: {
                IconRow(icon: "trash", title: "Delete data", subtitle: "Remove all records from this iPhone", isDestructive: true) {
                    RowChevron()
                }
            }
            .buttonStyle(.plain)
            .listRowBackground(AppColor.card)
        } header: {
            Text("Your data").sectionTitle()
        }
    }

    private var footer: some View {
        VStack(spacing: Spacing.xs) {
            Label("Your records stay on your iPhone.", systemImage: "lock")
            Text("CellMate · Version \(appVersion)")
        }
        .font(.footnote)
        .foregroundStyle(AppColor.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: Helpers

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )
    }

    private func openSystemSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }
}

#Preview("Light") { NavigationStack { SettingsView() } }
#Preview("Dark") { NavigationStack { SettingsView() }.preferredColorScheme(.dark) }

/// Wheel picker for bedtime, shown as a half-height sheet.
private struct BedtimePickerSheet: View {
    @Binding var minutes: Int
    @Environment(\.dismiss) private var dismiss

    private var selection: Binding<Date> {
        Binding(
            get: { BedtimeSetting.date(fromMinutes: minutes) },
            set: { minutes = BedtimeSetting.minutes(from: $0) }
        )
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: Spacing.md) {
                DatePicker("Bedtime", selection: selection, displayedComponents: .hourAndMinute)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                Text("We'll flag charging plans that run close to bedtime.")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .screenBackground()
            .navigationTitle("Bedtime")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// The standard iOS share sheet.
private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
