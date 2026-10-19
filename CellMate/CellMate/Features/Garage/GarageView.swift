import SwiftUI

// Design: 03 Garage empty, 09 Garage, 04 Add battery, 10 Battery detail
struct GarageView: View {
    var body: some View {
        NavigationStack {
            PlaceholderScreen(title: "Garage")
                .navigationTitle("Garage")
        }
    }
}
