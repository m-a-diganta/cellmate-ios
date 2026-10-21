//
//  RegisterCharger.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation
import Foundation

@MainActor
struct RegisterCharger {
    struct Input {
        let name: String
        let brand: String
    }

    enum ValidationError: Error, Equatable, LocalizedError {
        case missingName
        case missingBrand

        var errorDescription: String? {
            switch self {
            case .missingName:
                return "Enter a name for your charger."

            case .missingBrand:
                return "Enter the charger brand."
            }
        }
    }

    private let repository: any GarageRepository

    init(repository: any GarageRepository) {
        self.repository = repository
    }

    func execute(_ input: Input) async throws -> Charger {
        let name = input.name.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let brand = input.brand.trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        guard !name.isEmpty else {
            throw ValidationError.missingName
        }

        guard !brand.isEmpty else {
            throw ValidationError.missingBrand
        }

        let charger = Charger(
            name: name,
            brand: brand
        )

        try await repository.addCharger(charger)

        return charger
    }
}
