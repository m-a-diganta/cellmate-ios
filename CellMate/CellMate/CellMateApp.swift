import SwiftUI

@main
struct CellMateApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let widgetSync = WidgetSync(container: .shared)

    var body: some Scene {
        WindowGroup {
            RootView()
                .task { await widgetSync.refresh() }
        }
        // The widget is only on screen when the app isn't, so refresh it on the way out.
        .onChange(of: scenePhase) { _, phase in
            if phase != .active {
                Task { await widgetSync.refresh() }
            }
        }
    }
}
