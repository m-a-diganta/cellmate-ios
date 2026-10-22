//
//  RetireBattery.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

@MainActor
struct RetireBattery {
    struct Input {
        let batteryID: UUID
        let reason: String
    }

    enum ValidationError: Error, Equatable, LocalizedError {
        case missingReason
        case alreadyRetired

        var errorDescription: String? {
            switch self {
            case .missingReason:
                return "Enter a reason for retiring this battery."

            case .alreadyRetired:
                return "This battery has already been retired."
            }
        }
    }

    private let repository: any GarageRepository

    init(repository: any GarageRepository) {
        self.repository = repository
    }

    func execute(_ input: Input) async throws -> Battery {
        let reason = input.reason.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !reason.isEmpty else {
            throw ValidationError.missingReason
        }

        let battery = try await repository.battery(
            id: input.batteryID
        )

        guard !battery.isRetired else {
            throw ValidationError.alreadyRetired
        }

        let retiredBattery = Battery(
            id: battery.id,
            name: battery.name,
            brand: battery.brand,
            capacityWh: battery.capacityWh,
            purchaseDate: battery.purchaseDate,
            chargerID: battery.chargerID,
            status: .retired(reason: reason)
        )

        try await repository.updateBattery(retiredBattery)

        return retiredBattery
    }
}
