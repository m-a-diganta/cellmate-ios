

// Design: 11 Inspect, 12 Stop using
import SwiftUI
import PhotosUI
import UIKit

@MainActor
struct InspectView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.openURL) private var openURL

    @State private var viewModel: InspectionViewModel?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    
    @State private var showingPhotoChoices = false
    @State private var showingPhotoLibrary = false
    @State private var showingCamera = false

    @State private var capturedPhotoData: Data?
    @State private var cameraError: String?
    @State private var offeringCameraSettings = false

    private let batteryName: String
    private let backTitle: String
    private let onFinish: (Inspection) -> Void

    // Keeps the existing Home screen's InspectView() call compiling.
    // A real inspection requires a selected battery and view model.
    init() {
        _viewModel = State(initialValue: nil)
        batteryName = ""
        backTitle = "Home"
        onFinish = { _ in }
    }

    init(
        batteryName: String,
        viewModel: InspectionViewModel,
        backTitle: String = "Battery",
        onFinish: @escaping (Inspection) -> Void
    ) {
        self.batteryName = batteryName
        self.backTitle = backTitle
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
        .interactiveDismissDisabled(
            isLoadingPhoto ||
            viewModel?.isBusy == true ||
            (
                viewModel?.photo != nil &&
                viewModel?.savedInspection == nil
            )
        )
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Button {
                Task {
                    if let viewModel {
                        if await viewModel.discardDraft() {
                            dismiss()
                        }
                    } else {
                        dismiss()
                    }
                }
            } label: {
                Label(backTitle, systemImage: "chevron.left")
                    .font(.body)
                    .foregroundStyle(AppColor.accent)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isLoadingPhoto || viewModel?.isBusy == true)
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
        .photosPicker(
            isPresented: $showingPhotoLibrary,
            selection: $selectedPhoto,
            matching: .images
        )
        .fullScreenCover(
            isPresented: $showingCamera,
            onDismiss: {
                handleCameraDismissal(using: model)
            }
        ) {
            InspectionCameraPicker(
                onCapture: { data in
                    capturedPhotoData = data
                    showingCamera = false
                },
                onCancel: {
                    showingCamera = false
                },
                onFailure: { message in
                    cameraError = message
                    showingCamera = false
                }
            )
            .ignoresSafeArea()
            .interactiveDismissDisabled()
        }
        .task(id: selectedPhoto) {
            await importSelectedPhoto(into: model)
        }
        .alert(
            "Inspection",
            isPresented: Binding(
                get: { model.errorMessage != nil },
                set: {
                    if !$0 {
                        model.errorMessage = nil
                    }
                }
            )
        ) {
            if offeringCameraSettings {
                Button("Open Settings") {
                    offeringCameraSettings = false
                    model.errorMessage = nil

                    if let url = URL(
                        string: UIApplication.openSettingsURLString
                    ) {
                        openURL(url)
                    }
                }
            }

            Button("OK", role: .cancel) {
                offeringCameraSettings = false
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
        .disabled(
            isLoadingPhoto ||
            model.isBusy ||
            model.savedInspection != nil
        )
        .accessibilityLabel("\(checkCopy(for: kind).title): \(title)")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func photoSection(
        _ model: InspectionViewModel
    ) -> some View {
        let photoButtonTitle: String

        if case .some = model.photo {
            photoButtonTitle = "Change photo"
        } else {
            photoButtonTitle = "Add photo"
        }

        return VStack(alignment: .leading, spacing: Spacing.sm) {
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

            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(
                    VStackLayout(
                        alignment: .leading,
                        spacing: Spacing.sm
                    )
                )
                : AnyLayout(HStackLayout(spacing: Spacing.sm))

            layout {
                if let data = model.photoData,
                   let image = UIImage(data: data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 64, height: 64)
                        .clipShape(
                            RoundedRectangle(cornerRadius: 10)
                        )
                        .accessibilityLabel("Attached inspection photo")
                }

                Button {
                    showingPhotoChoices = true
                } label: {
                    Label(photoButtonTitle, systemImage: "camera")
                        .padding(.horizontal, Spacing.sm)
                        .padding(.vertical, Spacing.xs)
                }
                .buttonStyle(.appSecondary)
                .disabled(!model.canAddPhoto || isLoadingPhoto)
                .confirmationDialog(
                    "Add inspection photo",
                    isPresented: $showingPhotoChoices,
                    titleVisibility: .visible
                ) {
                    Button("Take photo") {
                        Task {
                            await requestCamera(using: model)
                        }
                    }

                    Button("Choose from library") {
                        offeringCameraSettings = false
                        showingPhotoLibrary = true
                    }

                    Button("Cancel", role: .cancel) {}
                }
                .buttonStyle(.appSecondary)
                .disabled(!model.canAddPhoto || isLoadingPhoto)
            }

            if isLoadingPhoto || model.isProcessingPhoto {
                ProgressView("Preparing photo…")
                    .font(.footnote)
            }

            if model.photo != nil {
                Button("Remove photo", role: .destructive) {
                    Task {
                        await model.removePhoto()
                    }
                }
                .font(.footnote)
                .foregroundStyle(AppColor.highText)
                .frame(minHeight: 44)
                .disabled(
                    isLoadingPhoto ||
                    model.isBusy ||
                    model.savedInspection != nil
                )
            }
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
            .disabled(!model.canSave || isLoadingPhoto)
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
    
    private func importSelectedPhoto(
        into model: InspectionViewModel
    ) async {
        guard let selectedPhoto else {
            return
        }

        isLoadingPhoto = true
        model.errorMessage = nil

        defer {
            isLoadingPhoto = false
            self.selectedPhoto = nil
        }

        do {
            guard let data = try await selectedPhoto.loadTransferable(
                type: Data.self
            ) else {
                model.errorMessage =
                    "This photo could not be loaded. Choose another photo."
                return
            }

            try Task.checkCancellation()

            await model.importPhoto(data: data)
        } catch is CancellationError {
            return
        } catch {
            model.errorMessage =
                "This photo could not be loaded. Please try again."
        }
    }
    
    private func requestCamera(
        using model: InspectionViewModel
    ) async {
        guard model.canAddPhoto, !isLoadingPhoto else {
            return
        }

        offeringCameraSettings = false
        model.errorMessage = nil

        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            model.errorMessage =
                "A camera is not available on this device. "
                + "Choose a photo from your library instead."
            return
        }

        isLoadingPhoto = true

        defer {
            isLoadingPhoto = false
        }

        do {
            let status = try await CameraPermissionService()
                .requestAccessIfNeeded()

            switch status {
            case .authorized:
                capturedPhotoData = nil
                cameraError = nil
                showingCamera = true

            case .denied:
                offeringCameraSettings = true
                model.errorMessage =
                    "Camera access is turned off. Enable it in Settings "
                    + "or choose a photo from your library."

            case .restricted:
                model.errorMessage =
                    "Camera access is restricted on this device. "
                    + "You can continue without a photo."

            case .notDetermined:
                model.errorMessage =
                    "Camera permission was not granted. "
                    + "You can choose a photo from your library instead."
            }
        } catch {
            model.errorMessage =
                (error as? any LocalizedError)?.errorDescription
                ?? "Camera access could not be requested."
        }
    }

    private func handleCameraDismissal(
        using model: InspectionViewModel
    ) {
        if let cameraError {
            model.errorMessage = cameraError
            self.cameraError = nil
            capturedPhotoData = nil
            return
        }

        guard let data = capturedPhotoData else {
            return
        }

        capturedPhotoData = nil
        isLoadingPhoto = true

        Task {
            defer {
                isLoadingPhoto = false
            }

            await model.importPhoto(data: data)
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
