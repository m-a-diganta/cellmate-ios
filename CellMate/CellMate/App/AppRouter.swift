import SwiftUI
import Observation

enum AppTab: Hashable {
    case home
    case garage
    case history
    case ask
}

/// Lets any screen switch tabs, for example Home -> Ask.
/// Created once in RootTabView and read with @Environment(AppRouter.self).
@Observable
final class AppRouter {
    var selectedTab: AppTab = .home
    /// Set when a widget or the Live Activity asks for the charge screen. Home opens it and clears it.
    var opensCharge = false

    func open(_ url: URL) {
        switch url {
        case AppLink.charge:
            selectedTab = .home
            opensCharge = true
        case AppLink.garage:
            selectedTab = .garage
        default:
            break
        }
    }
}
