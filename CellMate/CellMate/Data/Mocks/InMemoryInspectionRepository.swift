//
//  InMemoryInspectionRepository.swift
//  CellMate
//
//  Created by Yufan on 21/10/2026.
//

import Foundation

@MainActor
final class InMemoryInspectionRepository: InspectionRepository {
    private var inspections: [Inspection]
    private let garageRepository: any GarageRepository

    init(
        garageRepository: any GarageRepository,
        inspections: [Inspection] = []
    ) {
        self.garageRepository = garageRepository
        self.inspections = inspections
    }

    func fetchInspections(
        for batteryID: UUID
    ) async throws -> [Inspection] {
        try await verifyBatteryExists(id: batteryID)

        return inspections
            .filter { $0.batteryID == batteryID }
            .sorted { first, second in
                if first.inspectedAt == second.inspectedAt {
                    return first.id.uuidString < second.id.uuidString
                }

                return first.inspectedAt > second.inspectedAt
            }
    }

    func inspection(id: UUID) async throws -> Inspection {
        guard let inspection = inspections.first(where: {
            $0.id == id
        }) else {
            throw InspectionRepositoryError.inspectionNotFound
        }

        return inspection
    }

    func addInspection(_ inspection: Inspection) async throws {
        try await verifyBatteryExists(id: inspection.batteryID)

        // Check after awaiting so another save cannot insert
        // the same ID between this check and the append.
        guard !inspections.contains(where: {
            $0.id == inspection.id
        }) else {
            throw InspectionRepositoryError.duplicateInspectionID
        }

        inspections.append(inspection)
    }

    private func verifyBatteryExists(id: UUID) async throws {
        do {
            _ = try await garageRepository.battery(id: id)
        } catch is CancellationError {
            throw CancellationError()
        } catch GarageRepositoryError.batteryNotFound {
            throw InspectionRepositoryError.batteryNotFound
        } catch {
            throw InspectionRepositoryError.readFailed
        }
    }
}
