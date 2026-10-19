import SwiftUI

/// First launch shows Welcome. After that the app opens on the tab bar.
/// Later: Welcome -> Permissions -> Garage, and the flag moves into SafetyProfile.
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some View {
        if hasCompletedOnboarding {
            RootTabView()
        } else {
            WelcomeView { hasCompletedOnboarding = true }
        }
    }
}
