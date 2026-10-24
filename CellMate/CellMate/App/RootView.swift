import SwiftUI

/// First launch shows Welcome, then Permissions. After that the app opens on the tab bar.
/// The Light, Dark or System choice from Home is applied here, so it covers every screen.
struct RootView: View {
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @AppStorage(AppStorageKey.appearance) private var appearance = AppAppearance.system.rawValue
    @State private var showsPermissions = false

    var body: some View {
        Group {
            if hasCompletedOnboarding {
                RootTabView()
            } else if showsPermissions {
                PermissionsView { hasCompletedOnboarding = true }
            } else {
                WelcomeView { showsPermissions = true }
            }
        }
        .preferredColorScheme(AppAppearance(stored: appearance).colorScheme)
    }
}
