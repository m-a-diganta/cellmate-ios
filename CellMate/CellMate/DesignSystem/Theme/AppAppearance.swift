import SwiftUI

/// The colour scheme picked from the Home screen. "System" follows the iPhone setting.
/// RootView applies it to the whole app, and the choice is remembered between launches.
nonisolated enum AppAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: "System"
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    /// Icon for the menu rows and for the Home button.
    var symbol: String {
        switch self {
        case .system: "circle.lefthalf.filled"
        case .light: "sun.max"
        case .dark: "moon"
        }
    }

    /// Nil lets the app follow the device.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    /// Reads the saved text. Anything unknown falls back to System.
    init(stored: String) {
        self = AppAppearance(rawValue: stored) ?? .system
    }
}
