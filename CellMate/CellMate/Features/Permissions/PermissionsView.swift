import SwiftUI

// Design: 02 Permissions
struct PermissionsView: View {
    var onFinish: () -> Void

    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel: PermissionsViewModel

    init(viewModel: PermissionsViewModel = PermissionsViewModel(permissions: SystemPermissionService()), onFinish: @escaping () -> Void) {
        _viewModel = State(initialValue: viewModel)
        self.onFinish = onFinish
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Stay on top of every charge")
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppColor.textPrimary)
                    Text("CellMate can remind you to unplug and tell you when a battery check is due.")
                        .foregroundStyle(AppColor.textSecondary)
                }

                VStack(spacing: Spacing.md) {
                    IconRow(icon: "bell", title: "Notifications", subtitle: "Unplug reminders, bedtime warnings and monthly checks") {
                        PermissionAction(status: viewModel.notifications, onAllow: {
                            Task { await viewModel.allowNotifications() }
                        }, onOpenSettings: openSettings)
                    }
                    Divider()
                    IconRow(icon: "camera", title: "Camera", subtitle: "Optional. Add a photo to an inspection.") {
                        PermissionAction(status: viewModel.camera, onAllow: {
                            Task { await viewModel.allowCamera() }
                        }, onOpenSettings: openSettings)
                    }
                }
                .card()

                InfoNote(text: "Reminder only · charging won't stop automatically")
            }
            .padding(Spacing.md)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: Spacing.xs) {
                Button("Continue") {
                    Task {
                        await viewModel.continueTapped()
                        onFinish()
                    }
                }
                .buttonStyle(.appPrimary)
                Button("Not now", action: onFinish)
                    .buttonStyle(.appText)
            }
            .padding(Spacing.md)
            .background(AppColor.background)
        }
        .screenBackground()
        .task { await viewModel.load() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await viewModel.load() }
            }
        }
    }

    private func openSettings() {
        if let url = SystemSettings.url {
            openURL(url)
        }
    }
}

/// The end of a permission row: Allow, On, or a link to Settings when it was turned off.
private struct PermissionAction: View {
    let status: PermissionStatus
    let onAllow: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        switch status {
        case .notDetermined:
            Button("Allow", action: onAllow)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.accent)
                .frame(minWidth: 44, minHeight: 44)
        case .granted:
            Label("On", systemImage: "checkmark.circle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.lowText)
        case .denied:
            Button("Settings", action: onOpenSettings)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.accent)
                .frame(minWidth: 44, minHeight: 44)
                .accessibilityHint("Turned off. Opens Settings to turn it on.")
        }
    }
}

#Preview("Light") {
    PermissionsView(viewModel: PermissionsViewModel(permissions: MockPermissionService())) {}
}

#Preview("Dark, camera off") {
    PermissionsView(viewModel: PermissionsViewModel(permissions: MockPermissionService(notifications: .granted, camera: .denied))) {}
        .preferredColorScheme(.dark)
}
