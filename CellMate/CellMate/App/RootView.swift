import SwiftUI

/// First launch shows Welcome, then Permissions. After that the app opens on the tab bar.
/// Later: Welcome -> Permissions -> Garage, and the flag moves into SafetyProfile.
struct RootView: View {
    @AppStorage(AppStorageKey.hasCompletedOnboarding) private var hasCompletedOnboarding = false
    @State private var showsPermissions = false

    var body: some View {
        if hasCompletedOnboarding {
            RootTabView()
        } else if showsPermissions {
            PermissionsView { hasCompletedOnboarding = true }
        } else {
            WelcomeView { showsPermissions = true }
        }
    }
}
