import SwiftUI

/// Person 5: Ask, result and the offline Quick check.
struct AskView: View {
    @State private var model: AskViewModel
    @Environment(\.scenePhase) private var scenePhase

    init() {
        self.init(dependencies: .pendingIntegration())
    }

    init(dependencies: AskDependencies) {
        _model = State(initialValue: AskViewModel(dependencies: dependencies))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("What have you noticed?").font(.title2.bold())
                        Text("Choose a symptom or describe your concern.")
                            .foregroundStyle(AppColor.textSecondary)
                        InfoNote(text: "CellMate can’t tell you a battery is safe")
                    }

                    if case .unavailable(let reason) = model.availability {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Label("Chat is unavailable", systemImage: "bubble.left.and.exclamationmark.bubble.right")
                                .font(.headline)
                            Text(reason + " Quick check works without AI.").font(.subheadline)
                        }
                        .card()
                        .accessibilityIdentifier("ask.unavailable")
                    }

                    if !model.batteries.isEmpty {
                        Picker("Battery", selection: $model.selectedBatteryID) {
                            Text("Choose a battery (optional)").tag(UUID?.none)
                            ForEach(model.batteries) { battery in
                                Text(battery.name + (battery.isRetired ? " · Retired" : ""))
                                    .tag(Optional(battery.id))
                            }
                        }
                        .disabled(model.isAssessing)
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 145), spacing: Spacing.sm)], spacing: Spacing.sm) {
                        ForEach([BatterySymptom.swelling, .excessiveHeat, .unusualSmell, .chargerConcern]) { symptom in
                            Button {
                                if model.selectedSymptoms.contains(symptom) { model.selectedSymptoms.remove(symptom) }
                                else { model.selectedSymptoms.insert(symptom) }
                            } label: {
                                Text(symptom.title)
                                    .font(.subheadline.weight(.semibold))
                                    .frame(maxWidth: .infinity, minHeight: 44)
                                    .padding(.horizontal, Spacing.sm)
                                    .background(model.selectedSymptoms.contains(symptom) ? AppColor.brandTint : AppColor.card,
                                                in: RoundedRectangle(cornerRadius: Radius.button))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: Radius.button)
                                            .stroke(model.selectedSymptoms.contains(symptom) ? AppColor.accent : .clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(AppColor.accent)
                            .accessibilityAddTraits(model.selectedSymptoms.contains(symptom) ? [.isSelected] : [])
                            .disabled(model.isAssessing)
                        }
                    }

                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        TextField("Describe the battery or charger concern", text: $model.text, axis: .vertical)
                            .lineLimit(3...6)
                            .accessibilityIdentifier("ask.description")
                            .disabled(model.isAssessing)
                        Text("\(model.text.count)/1,000 characters")
                            .font(.caption)
                            .foregroundStyle(model.text.count > 1_000 ? AppColor.highText : AppColor.textSecondary)
                    }
                    .card()

                    if model.isAssessing {
                        ProgressView("Checking your description…").frame(maxWidth: .infinity)
                        Button("Use Quick check instead") { model.openQuickCheck() }
                            .buttonStyle(.appSecondary)
                    } else {
                        Button("Get guidance") { model.submit() }
                            .buttonStyle(.appPrimary)
                            .disabled(!model.canAsk || model.text.count > 1_000)
                            .accessibilityIdentifier("ask.submit")
                        Button("Quick check") { model.openQuickCheck() }
                            .buttonStyle(.appSecondary)
                            .accessibilityIdentifier("ask.quickCheck")
                    }

                    Text("Smoke, flames or hissing? Move away, get everyone out and call 000 from a safe place.")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(AppColor.highText)
                        .card()
                    InfoNote(text: "Guidance can be wrong. Follow the maker’s advice.")
                }
                .padding(Spacing.md)
            }
            .scrollDismissesKeyboard(.interactively)
            .screenBackground()
            .navigationTitle("Ask CellMate")
            .navigationDestination(isPresented: $model.showResult) {
                if let assessment = model.assessment { AskResultView(model: model, assessment: assessment) }
            }
            .sheet(isPresented: $model.showQuickCheck) { QuickCheckView(model: model) }
            .sheet(isPresented: $model.showBatteryPicker) {
                NavigationStack {
                    List(model.batteries) { battery in
                        Button(battery.name + (battery.isRetired ? " · Retired" : "")) { Task { await model.save(for: battery.id) } }
                            .disabled(model.isSaving)
                    }
                    .navigationTitle("Choose a battery")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar { ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { model.showBatteryPicker = false }
                    } }
                }
                .askErrorAlert(model)
            }
            .askErrorAlert(model, active: !model.showResult && !model.showQuickCheck && !model.showBatteryPicker)
            .task { await model.refresh() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.refresh() } }
                else { model.cancelAssessment() }
            }
        }
        #if DEBUG
        // Deterministic UI-test appearance; production follows the device's colour scheme.
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("--ask-ui-dark") ? .dark : nil)
        #endif
    }
}

#Preview("Ask · Light") { AskView() }
#Preview("Ask · Dark") { AskView().preferredColorScheme(.dark) }

/// Present errors on the visible screen, including navigation destinations and sheets.
private struct AskErrorAlert: ViewModifier {
    @Bindable var model: AskViewModel
    let active: Bool

    func body(content: Content) -> some View {
        content.alert("Ask CellMate", isPresented: Binding(
            get: { active && model.errorMessage != nil },
            set: { if !$0 && active { model.errorMessage = nil } }
        )) {
            Button("OK") { model.errorMessage = nil }
        } message: { Text(model.errorMessage ?? "") }
    }
}

extension View {
    func askErrorAlert(_ model: AskViewModel, active: Bool = true) -> some View {
        modifier(AskErrorAlert(model: model, active: active))
    }
}
