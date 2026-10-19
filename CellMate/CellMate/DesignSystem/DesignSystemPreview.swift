import SwiftUI

/// Open this file's canvas to check every colour and component in Light and Dark Mode.
struct DesignSystemPreview: View {
    private struct Swatch: Identifiable {
        let name: String
        let color: Color
        var id: String { name }
    }

    private let swatches: [Swatch] = [
        Swatch(name: "background", color: AppColor.background),
        Swatch(name: "card", color: AppColor.card),
        Swatch(name: "textPrimary", color: AppColor.textPrimary),
        Swatch(name: "textSecondary", color: AppColor.textSecondary),
        Swatch(name: "brand", color: AppColor.brand),
        Swatch(name: "accent", color: AppColor.accent),
        Swatch(name: "brandTint", color: AppColor.brandTint),
        Swatch(name: "track", color: AppColor.track),
        Swatch(name: "destructive", color: AppColor.destructive)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                Text("Design system")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColor.textPrimary)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: Spacing.sm)], spacing: Spacing.sm) {
                    ForEach(swatches) { swatch in
                        VStack(alignment: .leading, spacing: Spacing.xs) {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(swatch.color)
                                .frame(height: 44)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColor.track))
                            Text(swatch.name)
                                .font(.caption2)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                    }
                }

                HStack {
                    RiskChip(level: .low)
                    RiskChip(level: .medium)
                    RiskChip(level: .high)
                }

                VStack(spacing: Spacing.sm) {
                    Button("Primary") {}.buttonStyle(.appPrimary)
                    Button("Secondary") {}.buttonStyle(.appSecondary)
                    Button("Retire battery") {}.buttonStyle(.appDestructive)
                    Button("Not now") {}.buttonStyle(.appText)
                }

                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("Card title")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Card text in the secondary colour")
                        .foregroundStyle(AppColor.textSecondary)
                }
                .card()

                InfoNote(text: "Reminder only. Charging won't stop automatically.")
            }
            .padding(Spacing.md)
        }
        .screenBackground()
    }
}

#Preview("Light") { DesignSystemPreview() }
#Preview("Dark") { DesignSystemPreview().preferredColorScheme(.dark) }
