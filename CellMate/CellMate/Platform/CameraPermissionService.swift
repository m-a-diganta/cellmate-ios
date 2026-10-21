//
//  CameraPermissionService.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import AVFoundation
import Foundation

enum CameraPermissionStatus: Equatable, Sendable {
    case authorized
    case notDetermined
    case denied
    case restricted
}

enum CameraPermissionError: Error, LocalizedError {
    case missingUsageDescription

    var errorDescription: String? {
        switch self {
        case .missingUsageDescription:
            return "Camera access has not been configured for this app."
        }
    }
}

@MainActor
protocol CameraPermissionChecking {
    var status: CameraPermissionStatus { get }

    func requestAccessIfNeeded() async throws -> CameraPermissionStatus
}

@MainActor
struct CameraPermissionService: CameraPermissionChecking {
    var status: CameraPermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized

        case .notDetermined:
            return .notDetermined

        case .denied:
            return .denied

        case .restricted:
            return .restricted

        @unknown default:
            return .restricted
        }
    }

    func requestAccessIfNeeded() async throws -> CameraPermissionStatus {
        let currentStatus = status

        guard currentStatus == .notDetermined else {
            return currentStatus
        }

        let usageDescription = Bundle.main.object(
            forInfoDictionaryKey: "NSCameraUsageDescription"
        ) as? String

        guard let usageDescription,
              !usageDescription.trimmingCharacters(
                  in: .whitespacesAndNewlines
              ).isEmpty else {
            throw CameraPermissionError.missingUsageDescription
        }

        _ = await AVCaptureDevice.requestAccess(for: .video)

        return status
    }
}
