//
//  InspectionViewModel.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class InspectionViewModel {
    let batteryID: UUID

    private(set) var findings: [
        Inspection.Item.Kind: Inspection.Item.Finding
    ] = [:]

    private(set) var photo: Inspection.PhotoEvidence?
    private(set) var photoData: Data?

    private(set) var isSaving = false
    private(set) var isProcessingPhoto = false
    private(set) var savedInspection: Inspection?

    var errorMessage: String?

    @ObservationIgnored
    private let logInspection: LogInspection

    @ObservationIgnored
    private let photoStore: (any InspectionPhotoStoring)?

    @ObservationIgnored
    private var pendingPhotoDeletion: Set<String> = []

    init(
        batteryID: UUID,
        logInspection: LogInspection,
        photoStore: (any InspectionPhotoStoring)? = nil
    ) {
        self.batteryID = batteryID
        self.logInspection = logInspection
        self.photoStore = photoStore
    }

    var answeredCount: Int {
        findings.count
    }

    var isComplete: Bool {
        Inspection.Item.Kind.allCases.allSatisfy {
            findings[$0] != nil
        }
    }

    var hasReportedProblem: Bool {
        findings.values.contains(.problem)
    }

    var isBusy: Bool {
        isSaving || isProcessingPhoto
    }

    var canSave: Bool {
        isComplete && !isBusy && savedInspection == nil
    }

    var canAddPhoto: Bool {
        photoStore != nil && !isBusy && savedInspection == nil
    }

    func finding(
        for kind: Inspection.Item.Kind
    ) -> Inspection.Item.Finding? {
        findings[kind]
    }

    func setFinding(
        _ finding: Inspection.Item.Finding,
        for kind: Inspection.Item.Kind
    ) {
        guard !isBusy, savedInspection == nil else {
            return
        }

        findings[kind] = finding
        errorMessage = nil
    }

    /// Saves an imported image and loads its resized preview.
    /// Keeps the previous attachment if importing fails.
    func importPhoto(data: Data) async {
        guard canAddPhoto, let photoStore else {
            return
        }

        isProcessingPhoto = true
        errorMessage = nil

        defer {
            isProcessingPhoto = false
        }

        do {
            try await deletePendingPhotos()

            let evidence = try await photoStore.savePhoto(
                imageData: data
            )

            // Track the file until it becomes the attached photo.
            pendingPhotoDeletion.insert(evidence.filename)

            let preview = try await photoStore.loadPhoto(
                filename: evidence.filename
            )

            if let previous = photo {
                pendingPhotoDeletion.insert(previous.filename)
            }

            photo = evidence
            photoData = preview
            pendingPhotoDeletion.remove(evidence.filename)

            try await deletePendingPhotos()
        } catch {
            // Keep failed cleanup entries so they can be retried.
            errorMessage = message(
                for: error,
                fallback: "The photo could not be prepared. Please try again."
            )
        }
    }

    func removePhoto() async {
        guard !isBusy,
              savedInspection == nil,
              let photoStore else {
            return
        }

        isProcessingPhoto = true
        errorMessage = nil

        defer {
            isProcessingPhoto = false
        }

        do {
            try await deletePendingPhotos()

            if let photo {
                try await photoStore.deletePhoto(
                    filename: photo.filename
                )
            }

            photo = nil
            photoData = nil
        } catch {
            errorMessage = message(
                for: error,
                fallback: "The photo could not be removed. Please try again."
            )
        }
    }

    /// Call before leaving an unsaved inspection.
    /// Saved inspection photos are never deleted here.
    func discardDraft() async -> Bool {
        guard !isBusy else {
            return false
        }

        guard savedInspection == nil else {
            return true
        }

        isProcessingPhoto = true
        errorMessage = nil

        defer {
            isProcessingPhoto = false
        }

        do {
            try await deletePendingPhotos()

            if let photo, let photoStore {
                try await photoStore.deletePhoto(
                    filename: photo.filename
                )
            }

            photo = nil
            photoData = nil
            return true
        } catch {
            errorMessage = message(
                for: error,
                fallback: "The draft photo could not be removed. Please try again."
            )
            return false
        }
    }

    /// Returns the saved inspection, or nil when saving fails.
    func save() async -> Inspection? {
        guard !isBusy else {
            return nil
        }

        if let savedInspection {
            return savedInspection
        }

        guard isComplete else {
            errorMessage = "Complete all five checks before saving."
            return nil
        }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        let items = Inspection.Item.Kind.allCases.compactMap { kind in
            guard let finding = findings[kind] else {
                return nil as Inspection.Item?
            }

            return Inspection.Item(
                kind: kind,
                finding: finding
            )
        }

        do {
            // Remove replaced or failed-import files before committing
            // the inspection's current photo reference.
            try await deletePendingPhotos()

            let inspection = try await logInspection.execute(
                LogInspection.Input(
                    batteryID: batteryID,
                    items: items,
                    photos: photo.map { [$0] } ?? []
                )
            )

            savedInspection = inspection
            return inspection
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage = message(
                for: error,
                fallback: "The inspection could not be saved. Please try again."
            )
            return nil
        }
    }

    private func deletePendingPhotos() async throws {
        guard let photoStore else {
            return
        }

        // Work from a snapshot because successful deletions
        // remove entries from the original set.
        for filename in Array(pendingPhotoDeletion) {
            try await photoStore.deletePhoto(filename: filename)
            pendingPhotoDeletion.remove(filename)
        }
    }

    private func message(
        for error: any Error,
        fallback: String
    ) -> String {
        (error as? any LocalizedError)?.errorDescription ?? fallback
    }
}
