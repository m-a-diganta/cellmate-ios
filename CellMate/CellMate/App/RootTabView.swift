import SwiftUI

/// The footer: Home, Garage, History, Ask.
struct RootTabView: View {
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { HomeView() }
            Tab("Garage", systemImage: "battery.100.bolt") { GarageView() }
            Tab("History", systemImage: "clock") { HistoryView() }
            Tab("Ask", systemImage: "bubble.left") { AskView() }
        }
        .tint(AppColor.accent)
    }
}

#Preview("Light") { RootTabView() }
#Preview("Dark") { RootTabView().preferredColorScheme(.dark) }
