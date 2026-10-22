//
//  RetireBatteryTests.swift
//  CellMateTests
//
//  Created by Yufan on 22/10/2026.
//

import Foundation
import XCTest
@testable import CellMate

@MainActor
final class RetireBatteryTests: XCTestCase {
    func testRetirementPreservesBatteryDetails() async throws {
        let original = makeBattery()
        let repository = RetirementRepositoryStub(battery: original)
        let useCase = RetireBattery(repository: repository)

        let retired = try await useCase.execute(
            RetireBattery.Input(
                batteryID: original.id,
                reason: "  No longer in use \n"
            )
        )

        XCTAssertTrue(retired.isRetired)
        XCTAssertEqual(retired.retirementReason, "No longer in use")

        XCTAssertEqual(retired.id, original.id)
        XCTAssertEqual(retired.name, original.name)
        XCTAssertEqual(retired.brand, original.brand)
        XCTAssertEqual(retired.capacityWh, original.capacityWh)
        XCTAssertEqual(retired.purchaseDate, original.purchaseDate)
        XCTAssertEqual(retired.chargerID, original.chargerID)

        XCTAssertEqual(repository.storedBattery, retired)
        XCTAssertEqual(repository.updateCalls, 1)
    }

    func testWhitespaceOnlyReasonIsRejected() async {
        let original = makeBattery()
        let repository = RetirementRepositoryStub(battery: original)
        let useCase = RetireBattery(repository: repository)

        do {
            _ = try await useCase.execute(
                RetireBattery.Input(
                    batteryID: original.id,
                    reason: " \n\t "
                )
            )
            XCTFail("Expected missingReason.")
        } catch {
            XCTAssertEqual(
                error as? RetireBattery.ValidationError,
                .missingReason
            )
        }

        XCTAssertEqual(repository.updateCalls, 0)
        XCTAssertEqual(repository.storedBattery, original)
    }

    func testAlreadyRetiredBatteryKeepsOriginalReason() async {
        let original = makeBattery(
            status: .retired(reason: "Original retirement reason")
        )

        let repository = RetirementRepositoryStub(battery: original)
        let useCase = RetireBattery(repository: repository)

        do {
            _ = try await useCase.execute(
                RetireBattery.Input(
                    batteryID: original.id,
                    reason: "Replacement reason"
                )
            )
            XCTFail("Expected alreadyRetired.")
        } catch {
            XCTAssertEqual(
                error as? RetireBattery.ValidationError,
                .alreadyRetired
            )
        }

        XCTAssertEqual(repository.updateCalls, 0)
        XCTAssertEqual(repository.storedBattery, original)
    }

    func testMissingBatteryIsRejected() async {
        let original = makeBattery()
        let repository = RetirementRepositoryStub(battery: original)
        let useCase = RetireBattery(repository: repository)

        do {
            _ = try await useCase.execute(
                RetireBattery.Input(
                    batteryID: UUID(),
                    reason: "No longer in use"
                )
            )
            XCTFail("Expected batteryNotFound.")
        } catch {
            XCTAssertEqual(
                error as? GarageRepositoryError,
                .batteryNotFound
            )
        }

        XCTAssertEqual(repository.updateCalls, 0)
        XCTAssertEqual(repository.storedBattery, original)
    }

    func testSaveFailureLeavesBatteryActive() async {
        let original = makeBattery()
        let repository = RetirementRepositoryStub(battery: original)
        repository.updateError = .saveFailed

        let useCase = RetireBattery(repository: repository)

        do {
            _ = try await useCase.execute(
                RetireBattery.Input(
                    batteryID: original.id,
                    reason: "No longer in use"
                )
            )
            XCTFail("Expected saveFailed.")
        } catch {
            XCTAssertEqual(
                error as? GarageRepositoryError,
                .saveFailed
            )
        }

        XCTAssertEqual(repository.updateCalls, 1)
        XCTAssertEqual(repository.storedBattery, original)
        XCTAssertFalse(repository.storedBattery.isRetired)
    }

    private func makeBattery(
        status: Battery.Status = .active
    ) -> Battery {
        Battery(
            name: "Battery A",
            brand: "Bosch",
            capacityWh: 720,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            chargerID: UUID(),
            status: status
        )
    }
}

@MainActor
private final class RetirementRepositoryStub: GarageRepository {
    private(set) var storedBattery: Battery
    private(set) var updateCalls = 0

    var updateError: GarageRepositoryError?

    init(battery: Battery) {
        storedBattery = battery
    }

    func fetchBatteries() async throws -> [Battery] {
        [storedBattery]
    }

    func fetchChargers() async throws -> [Charger] {
        []
    }

    func battery(id: UUID) async throws -> Battery {
        guard storedBattery.id == id else {
            throw GarageRepositoryError.batteryNotFound
        }

        return storedBattery
    }

    func charger(id: UUID) async throws -> Charger {
        XCTFail("Retirement should not look up a charger.")
        throw GarageRepositoryError.chargerNotFound
    }

    func addBattery(_ battery: Battery) async throws {
        XCTFail("Retirement should update the existing battery.")
        throw GarageRepositoryError.saveFailed
    }

    func addCharger(_ charger: Charger) async throws {
        XCTFail("Retirement should not create a charger.")
        throw GarageRepositoryError.saveFailed
    }

    func updateBattery(_ battery: Battery) async throws {
        updateCalls += 1

        guard battery.id == storedBattery.id else {
            throw GarageRepositoryError.batteryNotFound
        }

        if let updateError {
            throw updateError
        }

        storedBattery = battery
    }
}
