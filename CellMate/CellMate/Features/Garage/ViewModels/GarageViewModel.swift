//
//  GarageViewModel.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation
import Observation

@MainActor
@Observable
final class GarageViewModel {
    private(set) var batteries: [Battery] = []
    private(set) var chargers: [Charger] = []

    private(set) var isLoading = false
    private(set) var isSaving = false

    var errorMessage: String?

    @ObservationIgnored
    private let repository: any GarageRepository

    @ObservationIgnored
    private let registerBattery: RegisterBattery

    @ObservationIgnored
    private let registerCharger: RegisterCharger
    
    @ObservationIgnored
    private let retireBattery: RetireBattery

    var isBusy: Bool {
        isLoading || isSaving
    }

    init(repository: any GarageRepository) {
        self.repository = repository
        
        self.registerBattery = RegisterBattery(
            repository: repository
        )
        self.registerCharger = RegisterCharger(
            repository: repository
        )
        self.retireBattery = RetireBattery(
            repository: repository
        )
    }

    func load() async {
        guard !isBusy else { return }

        isLoading = true
        errorMessage = nil

        defer {
            isLoading = false
        }

        do {
            let loadedBatteries = try await repository.fetchBatteries()
            let loadedChargers = try await repository.fetchChargers()

            try Task.checkCancellation()

            // Update both lists only after both reads succeed.
            batteries = loadedBatteries
            chargers = loadedChargers
        } catch is CancellationError {
            // Leaving the screen can cancel loading.
        } catch {
            errorMessage = message(
                for: error,
                fallback: "Your Garage could not be loaded. Please try again."
            )
        }
    }

    /// Returns true only when the battery was saved successfully.
    func addBattery(_ input: RegisterBattery.Input) async -> Bool {
        guard !isBusy else { return false }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            let battery = try await registerBattery.execute(input)

            batteries.append(battery)
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = message(
                for: error,
                fallback: "The battery could not be saved. Please try again."
            )
            return false
        }
    }

    /// Returns true only when the charger was saved successfully.
    func addCharger(_ input: RegisterCharger.Input) async -> Bool {
        guard !isBusy else { return false }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            let charger = try await registerCharger.execute(input)

            chargers.append(charger)
            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = message(
                for: error,
                fallback: "The charger could not be saved. Please try again."
            )
            return false
        }
    }
    
    /// Returns true only when retirement was saved successfully.
    func retireBattery(
        id: UUID,
        reason: String
    ) async -> Bool {
        guard !isBusy else { return false }

        isSaving = true
        errorMessage = nil

        defer {
            isSaving = false
        }

        do {
            let retiredBattery = try await retireBattery.execute(
                RetireBattery.Input(
                    batteryID: id,
                    reason: reason
                )
            )

            if let index = batteries.firstIndex(where: {
                $0.id == retiredBattery.id
            }) {
                batteries[index] = retiredBattery
            } else {
                batteries.append(retiredBattery)
            }

            return true
        } catch is CancellationError {
            return false
        } catch {
            errorMessage = message(
                for: error,
                fallback: "The battery could not be retired. Please try again."
            )
            return false
        }
    }

    func chargerName(for battery: Battery) -> String {
        chargers.first(where: {
            $0.id == battery.chargerID
        })?.name ?? "Charger unavailable"
    }

    private func message(
        for error: any Error,
        fallback: String
    ) -> String {
        guard let localizedError = error as? any LocalizedError,
              let description = localizedError.errorDescription else {
            return fallback
        }

        return description
    }
}
