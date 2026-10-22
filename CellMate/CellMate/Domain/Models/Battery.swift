//
//  Battery.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

/// A battery recorded in the user's Garage.
///
/// Its status describes whether it remains in use,
/// not whether it is safe.
struct Battery: Identifiable, Equatable, Sendable {
    enum Status: Equatable, Sendable {
        case active
        case retired(reason: String)
    }

    let id: UUID
    let name: String
    let brand: String
    let capacityWh: Double
    let purchaseDate: Date
    let chargerID: UUID
    let status: Status

    init(
        id: UUID = UUID(),
        name: String,
        brand: String,
        capacityWh: Double,
        purchaseDate: Date,
        chargerID: UUID,
        status: Status = .active
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.capacityWh = capacityWh
        self.purchaseDate = purchaseDate
        self.chargerID = chargerID
        self.status = status
    }

    var isRetired: Bool {
        switch status {
        case .active:
            return false
        case .retired:
            return true
        }
    }

    var retirementReason: String? {
        switch status {
        case .active:
            return nil
        case .retired(let reason):
            return reason
        }
    }
}
