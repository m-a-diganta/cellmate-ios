//
//  Charger.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

/// A charger recorded in the user's Garage.
///
/// Recording a charger does not verify its compatibility
/// with a battery.
struct Charger: Identifiable, Equatable, Sendable {
    let id: UUID
    let name: String
    let brand: String

    init(
        id: UUID = UUID(),
        name: String,
        brand: String
    ) {
        self.id = id
        self.name = name
        self.brand = brand
    }
}
