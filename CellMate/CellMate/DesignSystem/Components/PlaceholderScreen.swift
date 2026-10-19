import SwiftUI

/// Temporary content for a screen that is not built yet. Remove it when you build the real screen.
struct PlaceholderScreen: View {
    let title: String

    var body: some View {
        VStack(spacing: Spacing.sm) {
            Image(systemName: "hammer")
                .font(.largeTitle)
                .foregroundStyle(AppColor.accent)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(AppColor.textPrimary)
            Text("Not built yet")
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}
