import SwiftUI

struct QuickCheckView: View {
    @Bindable var model: AskViewModel

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select the signs you have noticed. Do not touch or approach the battery to check.")
                    Text("Smoke, flames or hissing? Get out and call 000 now.")
                        .foregroundStyle(AppColor.highText)
                        .fontWeight(.semibold)
                }
                Section("Signs noticed") {
                    ForEach(BatterySymptom.allCases) { symptom in
                        Toggle(symptom.title, isOn: Binding(
                            get: { model.checkSymptoms.contains(symptom) },
                            set: { enabled in
                                if enabled { model.checkSymptoms.insert(symptom); model.noneNoticed = false }
                                else { model.checkSymptoms.remove(symptom) }
                            }
                        ))
                        .accessibilityIdentifier("check.\(symptom.rawValue)")
                    }
                }
                Section {
                    Toggle("None of these signs noticed", isOn: Binding(
                        get: { model.noneNoticed },
                        set: { model.noneNoticed = $0; if $0 { model.checkSymptoms = [] } }
                    ))
                    .accessibilityIdentifier("check.none")
                    InfoNote(text: "CellMate can’t tell you a battery is safe")
                }
            }
            .tint(AppColor.accent)
            .safeAreaInset(edge: .bottom) {
                Button("Show guidance") { model.finishQuickCheck() }
                    .buttonStyle(.appPrimary)
                    .disabled(model.checkSymptoms.isEmpty && !model.noneNoticed)
                    .padding(Spacing.md)
                    .background(AppColor.background)
                    .accessibilityIdentifier("check.finish")
            }
            .navigationTitle("Quick check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { model.showQuickCheck = false }
            } }
        }
        .askErrorAlert(model)
    }
}
