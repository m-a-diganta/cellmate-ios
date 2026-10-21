import SwiftUI

// Design: 03 Garage empty, 09 Garage, 04 Add battery, 10 Battery detail

struct GarageView: View {
    @State private var showingAddBatteryNotice = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header

                GeometryReader { geometry in
                    ScrollView {
                        GarageEmptyView(onAddBattery: addBattery)
                            .padding(.vertical, Spacing.lg)
                            .frame(
                                minHeight: geometry.size.height,
                                alignment: .center
                            )
                    }
                    .scrollBounceBehavior(.basedOnSize)
                }
            }
            .screenBackground()
            .toolbar(.hidden, for: .navigationBar)
            .alert(
                "Add battery",
                isPresented: $showingAddBatteryNotice
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The Add battery form will be connected next.")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: Spacing.md) {
            Text("Garage")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)

            Spacer(minLength: Spacing.sm)

            Button(action: addBattery) {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(AppColor.accent)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Add battery")
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
    }

    private func addBattery() {
        showingAddBatteryNotice = true
    }
}

#Preview("Garage — Light") {
    TabView {
        Tab("Garage", systemImage: "battery.100.bolt") {
            GarageView()
        }
    }
    .tint(AppColor.accent)
}

#Preview("Garage — Dark") {
    TabView {
        Tab("Garage", systemImage: "battery.100.bolt") {
            GarageView()
        }
    }
    .tint(AppColor.accent)
    .preferredColorScheme(.dark)
}
