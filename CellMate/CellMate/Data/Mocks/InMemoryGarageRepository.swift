//
//  InMemoryGarageRepository.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

@MainActor
final class InMemoryGarageRepository: GarageRepository {
    private var batteries: [Battery]
    private var chargers: [Charger]

    init(
        batteries: [Battery] = [],
        chargers: [Charger] = []
    ) {
        self.batteries = batteries
        self.chargers = chargers
    }

    func fetchBatteries() async throws -> [Battery] {
        batteries
    }

    func fetchChargers() async throws -> [Charger] {
        chargers
    }

    func battery(id: UUID) async throws -> Battery {
        guard let battery = batteries.first(where: {
            $0.id == id
        }) else {
            throw GarageRepositoryError.batteryNotFound
        }

        return battery
    }

    func charger(id: UUID) async throws -> Charger {
        guard let charger = chargers.first(where: {
            $0.id == id
        }) else {
            throw GarageRepositoryError.chargerNotFound
        }

        return charger
    }

    func addBattery(_ battery: Battery) async throws {
        guard !batteries.contains(where: {
            $0.id == battery.id
        }) else {
            throw GarageRepositoryError.duplicateBatteryID
        }

        guard chargers.contains(where: {
            $0.id == battery.chargerID
        }) else {
            throw GarageRepositoryError.chargerNotFound
        }

        batteries.append(battery)
    }

    func addCharger(_ charger: Charger) async throws {
        guard !chargers.contains(where: {
            $0.id == charger.id
        }) else {
            throw GarageRepositoryError.duplicateChargerID
        }

        chargers.append(charger)
    }

    func updateBattery(_ battery: Battery) async throws {
        guard let index = batteries.firstIndex(where: {
            $0.id == battery.id
        }) else {
            throw GarageRepositoryError.batteryNotFound
        }

        guard chargers.contains(where: {
            $0.id == battery.chargerID
        }) else {
            throw GarageRepositoryError.chargerNotFound
        }

        batteries[index] = battery
    }
}
