//
//  InspectionRepository.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

/// Storage operations required by inspection use cases.
///
/// Implementations map storage failures to
/// InspectionRepositoryError before returning them.

@MainActor
protocol InspectionRepository {
    /// Returns this battery's inspections, newest first.
    /// Returns an empty array when there are no records.
    func fetchInspections(
        for batteryID: UUID
    ) async throws -> [Inspection]

    func inspection(id: UUID) async throws -> Inspection

    /// Saves a new inspection and its items and photo metadata
    /// as one operation.
    ///
    /// Photo files must already exist before this is called.
    func addInspection(_ inspection: Inspection) async throws
}

enum InspectionRepositoryError: Error, Equatable, LocalizedError {
    case inspectionNotFound
    case batteryNotFound
    case duplicateInspectionID
    case readFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .inspectionNotFound:
            return "This inspection could not be found."

        case .batteryNotFound:
            return "The battery for this inspection could not be found."

        case .duplicateInspectionID:
            return "This inspection record already exists."

        case .readFailed:
            return "Your inspections could not be loaded. Please try again."

        case .saveFailed:
            return "The inspection could not be saved. Please try again."
        }
    }
}
