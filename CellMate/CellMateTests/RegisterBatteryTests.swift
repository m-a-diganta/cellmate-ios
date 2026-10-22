//
//  RegisterBatteryTests.swift
//  CellMateTests
//
//  Created by Yufan on 22/10/2026.
//

import Foundation
import XCTest
@testable import CellMate

@MainActor
final class RegisterBatteryTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testValidBatteryIsTrimmedAndSaved() async throws {
        let repository = RegistrationRepositoryStub()
        let useCase = makeUseCase(repository: repository)

        let battery = try await useCase.execute(
            makeInput(
                chargerID: repository.chargerRecord.id,
                name: "  Battery A \n",
                brand: " Bosch "
            )
        )

        XCTAssertEqual(battery.name, "Battery A")
        XCTAssertEqual(battery.brand, "Bosch")
        XCTAssertEqual(battery.capacityWh, 720)
        XCTAssertEqual(battery.chargerID, repository.chargerRecord.id)
        XCTAssertEqual(
            battery.purchaseDate,
            calendar.startOfDay(for: fixedDate)
        )
        XCTAssertFalse(battery.isRetired)
        XCTAssertEqual(repository.savedBatteries, [battery])
    }

    func testWhitespaceOnlyNameIsRejected() async {
        let repository = RegistrationRepositoryStub()
        let useCase = makeUseCase(repository: repository)

        do {
            _ = try await useCase.execute(
                makeInput(
                    chargerID: repository.chargerRecord.id,
                    name: " \n "
                )
            )
            XCTFail("Expected missingName.")
        } catch {
            XCTAssertEqual(
                error as? RegisterBattery.ValidationError,
                .missingName
            )
        }

        XCTAssertEqual(repository.addBatteryCalls, 0)
    }

    func testWhitespaceOnlyBrandIsRejected() async {
        let repository = RegistrationRepositoryStub()
        let useCase = makeUseCase(repository: repository)

        do {
            _ = try await useCase.execute(
                makeInput(
                    chargerID: repository.chargerRecord.id,
                    brand: " \t "
                )
            )
            XCTFail("Expected missingBrand.")
        } catch {
            XCTAssertEqual(
                error as? RegisterBattery.ValidationError,
                .missingBrand
            )
        }

        XCTAssertEqual(repository.addBatteryCalls, 0)
    }

    func testInvalidCapacitiesAreRejected() async {
        let repository = RegistrationRepositoryStub()
        let useCase = makeUseCase(repository: repository)

        let invalidCapacities: [Double] = [
            0,
            -1,
            .infinity,
            -.infinity,
            .nan
        ]

        for capacity in invalidCapacities {
            do {
                _ = try await useCase.execute(
                    makeInput(
                        chargerID: repository.chargerRecord.id,
                        capacityWh: capacity
                    )
                )
                XCTFail("Expected invalidCapacity for \(capacity).")
            } catch {
                XCTAssertEqual(
                    error as? RegisterBattery.ValidationError,
                    .invalidCapacity
                )
            }
        }

        XCTAssertEqual(repository.addBatteryCalls, 0)
    }

    func testFuturePurchaseDayIsRejected() async throws {
        let repository = RegistrationRepositoryStub()
        let useCase = makeUseCase(repository: repository)

        let tomorrow = try XCTUnwrap(
            calendar.date(
                byAdding: .day,
                value: 1,
                to: fixedDate
            )
        )

        do {
            _ = try await useCase.execute(
                makeInput(
                    chargerID: repository.chargerRecord.id,
                    purchaseDate: tomorrow
                )
            )
            XCTFail("Expected futurePurchaseDate.")
        } catch {
            XCTAssertEqual(
                error as? RegisterBattery.ValidationError,
                .futurePurchaseDate
            )
        }

        XCTAssertEqual(repository.addBatteryCalls, 0)
    }

    func testMissingChargerPreventsSaving() async {
        let repository = RegistrationRepositoryStub()
        let useCase = makeUseCase(repository: repository)

        do {
            _ = try await useCase.execute(
                makeInput(chargerID: UUID())
            )
            XCTFail("Expected chargerNotFound.")
        } catch {
            XCTAssertEqual(
                error as? GarageRepositoryError,
                .chargerNotFound
            )
        }

        XCTAssertEqual(repository.addBatteryCalls, 0)
        XCTAssertTrue(repository.savedBatteries.isEmpty)
    }

    func testSaveFailureIsPassedToCaller() async {
        let repository = RegistrationRepositoryStub()
        repository.saveError = .saveFailed

        let useCase = makeUseCase(repository: repository)

        do {
            _ = try await useCase.execute(
                makeInput(chargerID: repository.chargerRecord.id)
            )
            XCTFail("Expected saveFailed.")
        } catch {
            XCTAssertEqual(
                error as? GarageRepositoryError,
                .saveFailed
            )
        }

        XCTAssertEqual(repository.addBatteryCalls, 1)
        XCTAssertTrue(repository.savedBatteries.isEmpty)
    }

    private func makeUseCase(
        repository: any GarageRepository
    ) -> RegisterBattery {
        let date = fixedDate

        return RegisterBattery(
            repository: repository,
            calendar: calendar,
            now: { date }
        )
    }

    private func makeInput(
        chargerID: UUID,
        name: String = "Battery A",
        brand: String = "Bosch",
        capacityWh: Double = 720,
        purchaseDate: Date? = nil
    ) -> RegisterBattery.Input {
        RegisterBattery.Input(
            name: name,
            brand: brand,
            capacityWh: capacityWh,
            purchaseDate: purchaseDate ?? fixedDate,
            chargerID: chargerID
        )
    }
}

@MainActor
private final class RegistrationRepositoryStub: GarageRepository {
    let chargerRecord = Charger(
        name: "Bosch 4A",
        brand: "Bosch"
    )

    var saveError: GarageRepositoryError?

    private(set) var savedBatteries: [Battery] = []
    private(set) var addBatteryCalls = 0

    func fetchBatteries() async throws -> [Battery] {
        savedBatteries
    }

    func fetchChargers() async throws -> [Charger] {
        [chargerRecord]
    }

    func battery(id: UUID) async throws -> Battery {
        guard let battery = savedBatteries.first(where: {
            $0.id == id
        }) else {
            throw GarageRepositoryError.batteryNotFound
        }

        return battery
    }

    func charger(id: UUID) async throws -> Charger {
        guard id == chargerRecord.id else {
            throw GarageRepositoryError.chargerNotFound
        }

        return chargerRecord
    }

    func addBattery(_ battery: Battery) async throws {
        addBatteryCalls += 1

        if let saveError {
            throw saveError
        }

        savedBatteries.append(battery)
    }

    func addCharger(_ charger: Charger) async throws {
        XCTFail("Battery registration should not create a charger.")
        throw GarageRepositoryError.saveFailed
    }

    func updateBattery(_ battery: Battery) async throws {
        XCTFail("Battery registration should not update an existing battery.")
        throw GarageRepositoryError.saveFailed
    }
}
