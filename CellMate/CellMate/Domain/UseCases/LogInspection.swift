//
//  LogInspection.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

@MainActor
struct LogInspection {
    struct Input {
        let batteryID: UUID
        let items: [Inspection.Item]
        let photos: [Inspection.PhotoEvidence]

        init(
            batteryID: UUID,
            items: [Inspection.Item],
            photos: [Inspection.PhotoEvidence] = []
        ) {
            self.batteryID = batteryID
            self.items = items
            self.photos = photos
        }
    }

    enum ValidationError: Error, Equatable, LocalizedError {
        case incompleteChecklist
        case duplicateChecks
        case duplicateItemIDs
        case tooManyPhotos
        case invalidPhotoFilename

        var errorDescription: String? {
            switch self {
            case .incompleteChecklist:
                return "Complete all five checks before saving."

            case .duplicateChecks:
                return "Each inspection check must appear only once."

            case .duplicateItemIDs:
                return "The checklist contains duplicate records."

            case .tooManyPhotos:
                return "Attach no more than one photo."

            case .invalidPhotoFilename:
                return "The photo reference is invalid. Attach the photo again."
            }
        }
    }

    private let garageRepository: any GarageRepository
    private let inspectionRepository: any InspectionRepository
    private let now: () -> Date

    init(
        garageRepository: any GarageRepository,
        inspectionRepository: any InspectionRepository,
        now: @escaping () -> Date = { Date() }
    ) {
        self.garageRepository = garageRepository
        self.inspectionRepository = inspectionRepository
        self.now = now
    }

    func execute(_ input: Input) async throws -> Inspection {
        let submittedKinds = input.items.map(\.kind)
        let uniqueKinds = Set(submittedKinds)
        let requiredKinds = Set(Inspection.Item.Kind.allCases)

        guard uniqueKinds.count == submittedKinds.count else {
            throw ValidationError.duplicateChecks
        }

        guard uniqueKinds == requiredKinds else {
            throw ValidationError.incompleteChecklist
        }

        guard Set(input.items.map(\.id)).count == input.items.count else {
            throw ValidationError.duplicateItemIDs
        }

        guard input.photos.count <= 1 else {
            throw ValidationError.tooManyPhotos
        }

        for photo in input.photos {
            let filename = photo.filename

            guard !filename.trimmingCharacters(
                in: .whitespacesAndNewlines
            ).isEmpty,
                  filename != ".",
                  filename != "..",
                  !filename.contains("/"),
                  !filename.contains("\\") else {
                throw ValidationError.invalidPhotoFilename
            }
        }

        // Verify that the battery still exists before saving.
        _ = try await garageRepository.battery(id: input.batteryID)

        let items = input.items.map { item in
            let trimmedNote = item.note?.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

            return Inspection.Item(
                id: item.id,
                kind: item.kind,
                finding: item.finding,
                note: trimmedNote.flatMap {
                    $0.isEmpty ? nil : $0
                }
            )
        }

        let hasProblem = items.contains {
            $0.finding == .problem
        }

        let inspection = Inspection(
            batteryID: input.batteryID,
            inspectedAt: now(),
            source: .manual,
            result: hasProblem ? .fail : .pass,
            items: items,
            photos: input.photos
        )

        try await inspectionRepository.addInspection(inspection)

        return inspection
    }
}
