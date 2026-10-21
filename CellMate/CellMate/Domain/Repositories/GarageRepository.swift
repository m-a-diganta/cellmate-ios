//
//  GarageRepository.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

/// Storage operations required by Garage use cases.
///
/// Implementations map storage failures to
/// GarageRepositoryError before returning them.
@MainActor
protocol GarageRepository {
    func fetchBatteries() async throws -> [Battery]

    func fetchChargers() async throws -> [Charger]

    func battery(id: UUID) async throws -> Battery

    func charger(id: UUID) async throws -> Charger

    func addBattery(_ battery: Battery) async throws

    func addCharger(_ charger: Charger) async throws

    /// Replaces an existing battery while preserving its ID.
    func updateBattery(_ battery: Battery) async throws
}

enum GarageRepositoryError: Error, Equatable, LocalizedError {
    case batteryNotFound
    case chargerNotFound
    case duplicateBatteryID
    case duplicateChargerID
    case readFailed
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .batteryNotFound:
            return "This battery could not be found."

        case .chargerNotFound:
            return "This charger could not be found."

        case .duplicateBatteryID:
            return "This battery record already exists."

        case .duplicateChargerID:
            return "This charger record already exists."

        case .readFailed:
            return "Your Garage could not be loaded. Please try again."

        case .saveFailed:
            return "Your changes could not be saved. Please try again."
        }
    }
}
