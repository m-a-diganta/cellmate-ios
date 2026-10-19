import SwiftUI

/// Risk is always shown with an icon, a word and a colour. Never colour alone.
extension RiskLevel {
    var title: String {
        switch self {
        case .low: "Low risk"
        case .medium: "Medium risk"
        case .high: "High risk"
        }
    }

    var symbol: String {
        switch self {
        case .low: "checkmark.shield"
        case .medium, .high: "exclamationmark.triangle"
        }
    }

    var textColor: Color {
        switch self {
        case .low: AppColor.lowText
        case .medium: AppColor.mediumText
        case .high: AppColor.highText
        }
    }

    var backgroundColor: Color {
        switch self {
        case .low: AppColor.lowBackground
        case .medium: AppColor.mediumBackground
        case .high: AppColor.highBackground
        }
    }
}

struct RiskChip: View {
    let level: RiskLevel

    var body: some View {
        Label(level.title, systemImage: level.symbol)
            .font(.caption.weight(.semibold))
            .foregroundStyle(level.textColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(level.backgroundColor, in: Capsule())
    }
}

#Preview {
    HStack {
        RiskChip(level: .low)
        RiskChip(level: .medium)
        RiskChip(level: .high)
    }
    .padding()
}
