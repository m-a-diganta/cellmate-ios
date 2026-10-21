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
    
    @ObservationIgnored
    private let inspectionRepository: any InspectionRepository
    
    @ObservationIgnored
    private let photoStore: (any InspectionPhotoStoring)?

    private(set) var inspectionSummaries: [UUID: String] = [:]
    private(set) var inspectionStatuses: [
        UUID: EvaluateInspectionDue.Status
    ] = [:]

    var isBusy: Bool {
        isLoading || isSaving
    }

    init(
        repository: any GarageRepository,
        inspectionRepository: (any InspectionRepository)? = nil,
        photoStore: (any InspectionPhotoStoring)? = nil
    ) {
        self.repository = repository

        self.inspectionRepository = inspectionRepository
            ?? InMemoryInspectionRepository(
                garageRepository: repository
            )

        self.photoStore = photoStore

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
            
            let currentBatteryIDs = Set(loadedBatteries.map(\.id))

            inspectionSummaries = inspectionSummaries.filter {
                currentBatteryIDs.contains($0.key)
            }

            inspectionStatuses = inspectionStatuses.filter {
                currentBatteryIDs.contains($0.key)
            }

            await refreshInspectionStatuses()
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
            inspectionSummaries[battery.id] = "No inspections yet"
            inspectionStatuses[battery.id] = .neverInspected
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

            inspectionStatuses[retiredBattery.id] = .notRequired
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

    private func summaryText(for inspection: Inspection) -> String {
        let date = inspection.inspectedAt.formatted(
            date: .abbreviated,
            time: .omitted
        )
        let result: String

        switch inspection.result {
        case .pass:
            result = "Pass"
        case .caution:
            result = "Caution"
        case .fail:
            result = "Fail"
        }

        return "\(date) · \(result)"
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
    
    /// Creates a fresh checklist for each new inspection.
    func makeInspectionViewModel(
        for batteryID: UUID
    ) -> InspectionViewModel {
        InspectionViewModel(
            batteryID: batteryID,
            logInspection: LogInspection(
                garageRepository: repository,
                inspectionRepository: inspectionRepository
            ),
            photoStore: photoStore
        )
    }

    /// Loads the latest inspection description for Battery detail.
    func loadInspectionSummary(for batteryID: UUID) async {
        do {
            let inspections = try await inspectionRepository.fetchInspections(
                for: batteryID
            )

            try Task.checkCancellation()

            guard let battery = batteries.first(where: {
                $0.id == batteryID
            }) else {
                return
            }

            let latest = inspections.first

            let status = try EvaluateInspectionDue().execute(
                battery: battery,
                latestInspection: latest
            )

            if let latest {
                inspectionSummaries[batteryID] = summaryText(for: latest)
            } else {
                inspectionSummaries[batteryID] = "No inspections yet"
            }

            inspectionStatuses[batteryID] = status
        } catch is CancellationError {
            return
        } catch {
            // Do not display an outdated status after a failed refresh.
            inspectionStatuses.removeValue(forKey: batteryID)

            errorMessage = message(
                for: error,
                fallback: "Inspection information could not be loaded."
            )
        }
    }
    
    func refreshInspectionStatuses() async {
        let batteryIDs = batteries.map(\.id)

        for batteryID in batteryIDs {
            guard !Task.isCancelled else {
                return
            }

            await loadInspectionSummary(for: batteryID)
        }
    }

    /// Call with the saved result returned by InspectionViewModel.save().
    func inspectionDidSave(_ inspection: Inspection) {
        inspectionSummaries[inspection.batteryID] = summaryText(
            for: inspection
        )

        guard let battery = batteries.first(where: {
            $0.id == inspection.batteryID
        }) else {
            return
        }

        do {
            inspectionStatuses[battery.id] =
                try EvaluateInspectionDue().execute(
                    battery: battery,
                    latestInspection: inspection
                )
        } catch {
            inspectionStatuses.removeValue(forKey: battery.id)

            errorMessage = message(
                for: error,
                fallback: "The inspection was saved, but its due date could not be calculated."
            )
        }
    }
}
