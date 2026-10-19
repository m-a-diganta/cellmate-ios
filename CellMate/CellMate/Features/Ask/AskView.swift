import SwiftUI

// Design: 13 Ask, 14 Ask result, 15 Quick check
struct AskView: View {
    var body: some View {
        NavigationStack {
            PlaceholderScreen(title: "Ask")
                .navigationTitle("Ask")
        }
    }
}
