import SwiftUI

/// The footer: Home, Garage, History, Ask.
struct RootTabView: View {
    @State private var router = AppRouter()

    var body: some View {
        TabView(selection: $router.selectedTab) {
            Tab("Home", systemImage: "house", value: AppTab.home) { HomeView() }
            Tab("Garage", systemImage: "battery.100.bolt", value: AppTab.garage) { GarageView(repository: AppContainer.shared.garage) }
            Tab("History", systemImage: "clock", value: AppTab.history) { HistoryView() }
            Tab("Ask", systemImage: "bubble.left", value: AppTab.ask) { AskView() }
        }
        .tint(AppColor.accent)
        .environment(router)
    }
}

#Preview("Light") { RootTabView() }
#Preview("Dark") { RootTabView().preferredColorScheme(.dark) }
