import SwiftUI

/// Small grey note with an info icon, like "Reminder only. Charging won't stop automatically."
struct InfoNote: View {
    let text: String

    var body: some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: "info.circle")
        }
        .font(.footnote)
        .foregroundStyle(AppColor.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
