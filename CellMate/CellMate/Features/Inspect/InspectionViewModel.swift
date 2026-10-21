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
    private(set) var isSaving = false
    private(set) var savedInspection: Inspection?

    var errorMessage: String?

    @ObservationIgnored
    private let logInspection: LogInspection

    init(
        batteryID: UUID,
        logInspection: LogInspection
    ) {
        self.batteryID = batteryID
        self.logInspection = logInspection
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

    var canSave: Bool {
        isComplete && !isSaving && savedInspection == nil
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
        guard !isSaving, savedInspection == nil else {
            return
        }

        findings[kind] = finding
        errorMessage = nil
    }

    /// Call only after the photo service has saved the image file.
    func attachPhoto(_ evidence: Inspection.PhotoEvidence) {
        guard !isSaving, savedInspection == nil else {
            return
        }

        photo = evidence
        errorMessage = nil
    }

    /// Removes the reference from this draft.
    /// The photo service handles deleting the unused file.
    func removePhoto() {
        guard !isSaving, savedInspection == nil else {
            return
        }

        photo = nil
    }

    /// Returns the saved inspection, or nil when saving fails.
    func save() async -> Inspection? {
        guard !isSaving else {
            return nil
        }

        // A completed draft must not create another record.
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

        let photos = photo.map { [$0] } ?? []

        do {
            let inspection = try await logInspection.execute(
                LogInspection.Input(
                    batteryID: batteryID,
                    items: items,
                    photos: photos
                )
            )

            savedInspection = inspection
            return inspection
        } catch is CancellationError {
            return nil
        } catch {
            errorMessage =
                (error as? any LocalizedError)?.errorDescription
                ?? "The inspection could not be saved. Please try again."

            return nil
        }
    }
}
