import SwiftUI

// Design: 11 Inspect, 12 Stop using
import SwiftUI

@MainActor
struct InspectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    @State private var viewModel: InspectionViewModel?

    private let batteryName: String
    private let backTitle: String
    private let onAddPhoto: (() -> Void)?
    private let onFinish: (Inspection) -> Void

    // Keeps the existing Home screen's InspectView() call compiling.
    // A real inspection requires a selected battery and view model.
    init() {
        _viewModel = State(initialValue: nil)
        batteryName = ""
        backTitle = "Home"
        onAddPhoto = nil
        onFinish = { _ in }
    }

    init(
        batteryName: String,
        viewModel: InspectionViewModel,
        backTitle: String = "Battery",
        onAddPhoto: (() -> Void)? = nil,
        onFinish: @escaping (Inspection) -> Void
    ) {
        self.batteryName = batteryName
        self.backTitle = backTitle
        self.onAddPhoto = onAddPhoto
        self.onFinish = onFinish
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if let viewModel {
                inspectionContent(viewModel)
            } else {
                ContentUnavailableView(
                    "Choose a battery",
                    systemImage: "battery.100",
                    description: Text(
                        "Open a battery in Garage to start an inspection."
                    )
                )
            }
        }
        .screenBackground()
        .toolbar(.hidden, for: .navigationBar)
        .interactiveDismissDisabled(viewModel?.isSaving == true)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                dismiss()
            } label: {
                Label(backTitle, systemImage: "chevron.left")
                    .font(.body)
                    .foregroundStyle(AppColor.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(viewModel?.isSaving == true)
            .accessibilityLabel("Back to \(backTitle)")

            Text("Inspect")
                .font(.largeTitle.bold())
                .foregroundStyle(AppColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
        }
        .padding(.horizontal, Spacing.md)
    }

    private func inspectionContent(
        _ model: InspectionViewModel
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(batteryName)
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)

                    Text(
                        "Look only. Don't touch a hot or swollen battery, "
                        + "or get close to smell it."
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                }

                checklist(model)
                photoSection(model)
            }
            .padding(Spacing.md)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            finishSection(model)
        }
        .alert(
            "Could not save inspection",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: {
                    if !$0 {
                        model.errorMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                model.errorMessage = nil
            }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private func checklist(
        _ model: InspectionViewModel
    ) -> some View {
        VStack(spacing: 0) {
            ForEach(Inspection.Item.Kind.allCases, id: \.self) { kind in
                checkRow(kind, model: model)

                if kind != Inspection.Item.Kind.allCases.last {
                    Divider()
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.xs)
        .background(
            AppColor.card,
            in: RoundedRectangle(cornerRadius: Radius.card)
        )
    }

    private func checkRow(
        _ kind: Inspection.Item.Kind,
        model: InspectionViewModel
    ) -> some View {
        let copy = checkCopy(for: kind)

        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(
                VStackLayout(
                    alignment: .leading,
                    spacing: Spacing.sm
                )
            )
            : AnyLayout(
                HStackLayout(spacing: Spacing.sm)
            )

        return layout {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                Text(copy.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)

                Text(copy.subtitle)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: Spacing.xs) {
                answerButton(
                    "OK",
                    finding: .ok,
                    kind: kind,
                    model: model
                )

                answerButton(
                    "Problem",
                    finding: .problem,
                    kind: kind,
                    model: model
                )
            }
            .padding(Spacing.xs)
            .background(
                AppColor.background,
                in: RoundedRectangle(cornerRadius: 10)
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, Spacing.xs)
    }

    private func answerButton(
        _ title: String,
        finding: Inspection.Item.Finding,
        kind: Inspection.Item.Kind,
        model: InspectionViewModel
    ) -> some View {
        let selected = model.finding(for: kind) == finding
        let isProblem = finding == .problem

        return Button {
            model.setFinding(finding, for: kind)
        } label: {
            Text(title)
                .font(
                    .subheadline.weight(selected ? .semibold : .regular)
                )
                .foregroundStyle(
                    selected && isProblem
                        ? AppColor.highText
                        : AppColor.textPrimary
                )
                .padding(.horizontal, Spacing.xs)
                .padding(.vertical, Spacing.xs)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    selected
                        ? (isProblem ? AppColor.highBackground : AppColor.card)
                        : Color.clear,
                    in: RoundedRectangle(cornerRadius: 8)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isSaving || model.savedInspection != nil)
        .accessibilityLabel("\(checkCopy(for: kind).title): \(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func photoSection(
        _ model: InspectionViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text("Photos")
                        .font(.subheadline.weight(.semibold))

                    Spacer()

                    Text("Optional · 1 photo")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Photos")
                        .font(.subheadline.weight(.semibold))

                    Text("Optional · 1 photo")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            .foregroundStyle(AppColor.textPrimary)

            if model.photo != nil {
                Label("Photo attached", systemImage: "photo")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Button {
                onAddPhoto?()
            } label: {
                Label(
                    model.photo == nil ? "Add photo" : "Change photo",
                    systemImage: "camera"
                )
                .padding(.horizontal, Spacing.sm)
                .padding(.vertical, Spacing.xs)
            }
            .buttonStyle(.appSecondary)
            .disabled(
                onAddPhoto == nil ||
                model.isSaving ||
                model.savedInspection != nil
            )
        }
        .card()
    }

    private func finishSection(
        _ model: InspectionViewModel
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            if model.hasReportedProblem {
                Text(
                    "A problem is flagged. "
                    + "Stop using the battery and keep clear."
                )
                .font(.footnote)
                .foregroundStyle(AppColor.highText)
                .fixedSize(horizontal: false, vertical: true)
            } else if !model.isComplete {
                Text("\(model.answeredCount) of 5 checks completed")
                    .font(.footnote)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Button {
                Task {
                    if let inspection = await model.save() {
                        onFinish(inspection)
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    if model.isSaving {
                        ProgressView()
                            .tint(AppColor.onBrand)
                    }

                    Text(model.isSaving ? "Saving…" : "Finish")
                }
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.sm)
            }
            .buttonStyle(.appPrimary)
            .disabled(!model.canSave)
        }
        .padding(Spacing.md)
        .background(AppColor.background)
    }

    private func checkCopy(
        for kind: Inspection.Item.Kind
    ) -> (title: String, subtitle: String) {
        switch kind {
        case .swelling:
            return ("Swelling", "Bulges or shape changes")
        case .heat:
            return ("Heat", "Unusual heat noticed")
        case .smell:
            return ("Smell", "Odour noticed nearby")
        case .damage:
            return ("Damage", "Cracks, leaks, or dents")
        case .charger:
            return ("Charger", "Damage or wrong match")
        }
    }
}

#Preview("Checklist") {
    let charger = Charger(name: "Bosch 4A", brand: "Bosch")

    let battery = Battery(
        name: "Battery A",
        brand: "Bosch",
        capacityWh: 720,
        purchaseDate: Date(),
        chargerID: charger.id
    )

    let garage = InMemoryGarageRepository(
        batteries: [battery],
        chargers: [charger]
    )

    let inspections = InMemoryInspectionRepository(
        garageRepository: garage
    )

    let model = InspectionViewModel(
        batteryID: battery.id,
        logInspection: LogInspection(
            garageRepository: garage,
            inspectionRepository: inspections
        )
    )

    NavigationStack {
        InspectView(
            batteryName: battery.name,
            viewModel: model,
            onFinish: { _ in }
        )
    }
}
