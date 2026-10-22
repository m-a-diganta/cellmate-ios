//
//  InspectionCameraPicker.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import SwiftUI
import UIKit
import AVFoundation

struct InspectionCameraPicker: UIViewControllerRepresentable {
    let onCapture: (Data) -> Void
    let onCancel: () -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(
        context: Context
    ) -> UIViewController {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            return failureController(
                message: "A camera is not available on this device."
            )
        }

        guard AVCaptureDevice.authorizationStatus(for: .video)
                == .authorized else {
            return failureController(
                message:
                    "Camera access is unavailable. "
                    + "You can choose a photo from your library instead."
            )
        }

        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.allowsEditing = false
        picker.delegate = context.coordinator

        return picker
    }

    func updateUIViewController(
        _ uiViewController: UIViewController,
        context: Context
    ) {
        context.coordinator.parent = self
    }

    private func failureController(
        message: String
    ) -> UIViewController {
        let controller = UIViewController()

        // Report after SwiftUI finishes creating the controller.
        Task { @MainActor in
            onFailure(message)
        }

        return controller
    }

    @MainActor
    final class Coordinator:
        NSObject,
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        var parent: InspectionCameraPicker
        private var hasCompleted = false

        init(parent: InspectionCameraPicker) {
            self.parent = parent
        }

        func imagePickerControllerDidCancel(
            _ picker: UIImagePickerController
        ) {
            guard !hasCompleted else {
                return
            }

            hasCompleted = true
            parent.onCancel()
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [
                UIImagePickerController.InfoKey: Any
            ]
        ) {
            guard !hasCompleted else {
                return
            }

            hasCompleted = true

            guard let image = info[.originalImage] as? UIImage,
                  let data = image.jpegData(compressionQuality: 0.85) else {
                parent.onFailure(
                    "The photo could not be prepared. Please try again."
                )
                return
            }

            parent.onCapture(data)
        }
    }
}
