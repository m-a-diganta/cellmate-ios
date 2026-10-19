import SwiftUI

/// Use: Button("Start") { }.buttonStyle(.appPrimary)
/// Full width, 50 pt tall (above the 44 pt minimum touch target).
struct PrimaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppColor.onBrand)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppColor.brand, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppColor.accent)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppColor.brandTint, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

struct DestructiveButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(AppColor.destructive, in: RoundedRectangle(cornerRadius: Radius.button, style: .continuous))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
    }
}

/// Plain text button, like "Not now" or "Retire".
struct TextOnlyButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(AppColor.accent)
            .frame(maxWidth: .infinity, minHeight: 44)
            .opacity(configuration.isPressed ? 0.6 : 1)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var appPrimary: PrimaryButtonStyle { PrimaryButtonStyle() }
}
extension ButtonStyle where Self == SecondaryButtonStyle {
    static var appSecondary: SecondaryButtonStyle { SecondaryButtonStyle() }
}
extension ButtonStyle where Self == DestructiveButtonStyle {
    static var appDestructive: DestructiveButtonStyle { DestructiveButtonStyle() }
}
extension ButtonStyle where Self == TextOnlyButtonStyle {
    static var appText: TextOnlyButtonStyle { TextOnlyButtonStyle() }
}
