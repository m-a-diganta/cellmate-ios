import SwiftUI

/// Small rounded square with an icon, used in list rows.
struct IconTile: View {
    let systemName: String
    var tint: Color = AppColor.accent
    var background: Color = AppColor.brandTint

    var body: some View {
        Image(systemName: systemName)
            .font(.body.weight(.semibold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(background, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .accessibilityHidden(true)
    }
}

/// The small arrow at the end of a row that opens something.
struct RowChevron: View {
    var body: some View {
        Image(systemName: "chevron.right")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(AppColor.textSecondary)
            .accessibilityHidden(true)
    }
}

/// Icon, title, optional second line and optional trailing content.
struct IconRow<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let showsTile: Bool
    let isDestructive: Bool
    let trailing: Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        showsTile: Bool = true,
        isDestructive: Bool = false,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.showsTile = showsTile
        self.isDestructive = isDestructive
        self.trailing = trailing()
    }

    var body: some View {
        HStack(spacing: Spacing.md) {
            if showsTile {
                IconTile(
                    systemName: icon,
                    tint: isDestructive ? AppColor.highText : AppColor.accent,
                    background: isDestructive ? AppColor.highBackground : AppColor.brandTint
                )
            } else {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 36)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(isDestructive ? AppColor.highText : AppColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer(minLength: Spacing.sm)
            trailing
        }
        .contentShape(Rectangle())
    }
}

extension IconRow where Trailing == EmptyView {
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        showsTile: Bool = true,
        isDestructive: Bool = false
    ) {
        self.init(icon: icon, title: title, subtitle: subtitle, showsTile: showsTile, isDestructive: isDestructive) {
            EmptyView()
        }
    }
}

extension Text {
    /// Bold heading above a card or a list section, like "Needs attention".
    func sectionTitle() -> some View {
        self.font(.title3.bold())
            .foregroundStyle(AppColor.textPrimary)
            .textCase(nil)
    }
}
