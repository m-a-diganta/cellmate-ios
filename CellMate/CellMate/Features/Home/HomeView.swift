import SwiftUI

// Design: 05 Home (Not on Charge and On Charge), 20 Home dark
struct HomeView: View {
    var body: some View {
        NavigationStack {
            PlaceholderScreen(title: "Home")
                .navigationTitle("Home")
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        NavigationLink {
                            SettingsView()
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel("Settings")
                    }
                }
        }
    }
}

#Preview("Light") { HomeView() }
#Preview("Dark") { HomeView().preferredColorScheme(.dark) }
