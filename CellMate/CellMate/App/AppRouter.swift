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
}
