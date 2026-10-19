import SwiftUI

// Design: 01 Welcome
struct WelcomeView: View {
    var onFinish: () -> Void

    var body: some View {
        VStack(spacing: Spacing.md) {
            Spacer()
            Text("CellMate")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
            Text("Small habits. Safer charging.")
                .foregroundStyle(AppColor.textSecondary)
            Spacer()
            Button("Get started", action: onFinish)
                .buttonStyle(.appPrimary)
        }
        .padding(Spacing.md)
        .screenBackground()
    }
}

#Preview("Light") { WelcomeView {} }
#Preview("Dark") { WelcomeView {}.preferredColorScheme(.dark) }
