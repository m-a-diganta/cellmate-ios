import SwiftUI

struct CardStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.card, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
    }
}

extension View {
    /// White card (dark grey in Dark Mode) with 16 pt padding and corners.
    func card() -> some View { modifier(CardStyle()) }

    /// The grey screen background. Put it on the outermost view of every screen.
    func screenBackground() -> some View {
        background(AppColor.background.ignoresSafeArea())
    }
}
