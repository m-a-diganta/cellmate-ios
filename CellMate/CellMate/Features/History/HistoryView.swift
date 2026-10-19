import SwiftUI

// Design: 16 History, 17 Charge details
struct HistoryView: View {
    var body: some View {
        NavigationStack {
            PlaceholderScreen(title: "History")
                .navigationTitle("History")
        }
    }
}
