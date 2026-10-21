//
//  InspectionPhotoStoring.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

/// Stores inspection images separately from database records.
///
/// Callers use the returned filename as the photo reference.
/// Absolute file paths must not be stored in inspection records.
@MainActor
protocol InspectionPhotoStoring {
    /// Validates image data, saves a display-sized image,
    /// and returns its metadata.
    ///
    /// Returns only after the file has been saved successfully.
    func savePhoto(
        imageData: Data
    ) async throws -> Inspection.PhotoEvidence

    /// Loads a previously saved photo.
    func loadPhoto(
        filename: String
    ) async throws -> Data

    /// Removes an unused photo file.
    /// A file that is already missing is treated as deleted.
    func deletePhoto(
        filename: String
    ) async throws
}

enum InspectionPhotoStorageError: Error, Equatable, LocalizedError {
    case invalidImage
    case imageTooLarge
    case invalidFilename
    case photoNotFound
    case readFailed
    case saveFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "This image could not be opened. Choose another photo."

        case .imageTooLarge:
            return "This image is too large. Choose a smaller photo."

        case .invalidFilename:
            return "The photo reference is invalid."

        case .photoNotFound:
            return "This photo could not be found."

        case .readFailed:
            return "The photo could not be loaded. Please try again."

        case .saveFailed:
            return "The photo could not be saved. Please try again."

        case .deleteFailed:
            return "The unused photo could not be removed. Please try again."
        }
    }
}
