//
//  RegisterBattery.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

@MainActor
struct RegisterBattery {
    struct Input {
        let name: String
        let brand: String
        let capacityWh: Double
        let purchaseDate: Date
        let chargerID: UUID
    }

    enum ValidationError: Error, Equatable, LocalizedError {
        case missingName
        case missingBrand
        case invalidCapacity
        case futurePurchaseDate

        var errorDescription: String? {
            switch self {
            case .missingName:
                return "Enter a name for your battery."

            case .missingBrand:
                return "Enter the battery brand."

            case .invalidCapacity:
                return "Enter a capacity greater than zero in watt-hours."

            case .futurePurchaseDate:
                return "The purchase date cannot be in the future."
            }
        }
    }

    private let repository: any GarageRepository
    private let calendar: Calendar
    private let now: () -> Date

    init(
        repository: any GarageRepository,
        calendar: Calendar = .current,
        now: @escaping () -> Date = { Date() }
    ) {
        self.repository = repository
        self.calendar = calendar
        self.now = now
    }

    func execute(_ input: Input) async throws -> Battery {
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

        guard input.capacityWh.isFinite,
              input.capacityWh > 0 else {
            throw ValidationError.invalidCapacity
        }

        let purchaseDay = calendar.startOfDay(
            for: input.purchaseDate
        )
        let today = calendar.startOfDay(for: now())

        guard purchaseDay <= today else {
            throw ValidationError.futurePurchaseDate
        }

        // Confirms that the charger record exists.
        // This does not verify physical compatibility.
        _ = try await repository.charger(id: input.chargerID)

        let battery = Battery(
            name: name,
            brand: brand,
            capacityWh: input.capacityWh,
            purchaseDate: purchaseDay,
            chargerID: input.chargerID
        )

        try await repository.addBattery(battery)

        return battery
    }
}
