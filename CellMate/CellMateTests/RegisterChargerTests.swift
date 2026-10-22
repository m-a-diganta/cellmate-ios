//
//  RegisterChargerTests.swift
//  CellMateTests
//
//  Created by Yufan on 22/10/2026.
//

import Foundation
import XCTest
@testable import CellMate

@MainActor
final class RegisterChargerTests: XCTestCase {
    func testValidChargerIsTrimmedAndSaved() async throws {
        let repository = ChargerRegistrationRepositoryStub()
        let useCase = RegisterCharger(repository: repository)

        let charger = try await useCase.execute(
            RegisterCharger.Input(
                name: "  Bosch 4A \n",
                brand: " Bosch "
            )
        )

        XCTAssertEqual(charger.name, "Bosch 4A")
        XCTAssertEqual(charger.brand, "Bosch")
        XCTAssertEqual(repository.savedChargers, [charger])
        XCTAssertEqual(repository.saveCalls, 1)
    }

    func testBlankNamesAreRejected() async {
        let repository = ChargerRegistrationRepositoryStub()
        let useCase = RegisterCharger(repository: repository)

        for name in ["", " ", "\n\t"] {
            do {
                _ = try await useCase.execute(
                    RegisterCharger.Input(
                        name: name,
                        brand: "Bosch"
                    )
                )
                XCTFail("Expected missingName.")
            } catch {
                XCTAssertEqual(
                    error as? RegisterCharger.ValidationError,
                    .missingName
                )
            }
        }

        XCTAssertEqual(repository.saveCalls, 0)
        XCTAssertTrue(repository.savedChargers.isEmpty)
    }

    func testBlankBrandsAreRejected() async {
        let repository = ChargerRegistrationRepositoryStub()
        let useCase = RegisterCharger(repository: repository)

        for brand in ["", " ", "\n\t"] {
            do {
                _ = try await useCase.execute(
                    RegisterCharger.Input(
                        name: "Bosch 4A",
                        brand: brand
                    )
                )
                XCTFail("Expected missingBrand.")
            } catch {
                XCTAssertEqual(
                    error as? RegisterCharger.ValidationError,
                    .missingBrand
                )
            }
        }

        XCTAssertEqual(repository.saveCalls, 0)
        XCTAssertTrue(repository.savedChargers.isEmpty)
    }

    func testSameNamesCanRepresentDifferentChargers() async throws {
        let repository = ChargerRegistrationRepositoryStub()
        let useCase = RegisterCharger(repository: repository)

        let input = RegisterCharger.Input(
            name: "Bosch 4A",
            brand: "Bosch"
        )

        let first = try await useCase.execute(input)
        let second = try await useCase.execute(input)

        XCTAssertEqual(first.name, second.name)
        XCTAssertNotEqual(first.id, second.id)
        XCTAssertEqual(repository.savedChargers.count, 2)
    }

    func testSaveFailureIsPassedToCaller() async {
        let repository = ChargerRegistrationRepositoryStub()
        repository.saveError = .saveFailed

        let useCase = RegisterCharger(repository: repository)

        do {
            _ = try await useCase.execute(
                RegisterCharger.Input(
                    name: "Bosch 4A",
                    brand: "Bosch"
                )
            )
            XCTFail("Expected saveFailed.")
        } catch {
            XCTAssertEqual(
                error as? GarageRepositoryError,
                .saveFailed
            )
        }

        XCTAssertEqual(repository.saveCalls, 1)
        XCTAssertTrue(repository.savedChargers.isEmpty)
    }
}

@MainActor
private final class ChargerRegistrationRepositoryStub:
    GarageRepository
{
    private(set) var savedChargers: [Charger] = []
    private(set) var saveCalls = 0

    var saveError: GarageRepositoryError?

    func fetchBatteries() async throws -> [Battery] {
        []
    }

    func fetchChargers() async throws -> [Charger] {
        savedChargers
    }

    func battery(id: UUID) async throws -> Battery {
        XCTFail("Charger registration should not look up a battery.")
        throw GarageRepositoryError.batteryNotFound
    }

    func charger(id: UUID) async throws -> Charger {
        guard let charger = savedChargers.first(where: {
            $0.id == id
        }) else {
            throw GarageRepositoryError.chargerNotFound
        }

        return charger
    }

    func addBattery(_ battery: Battery) async throws {
        XCTFail("Charger registration should not create a battery.")
        throw GarageRepositoryError.saveFailed
    }

    func addCharger(_ charger: Charger) async throws {
        saveCalls += 1

        if let saveError {
            throw saveError
        }

        savedChargers.append(charger)
    }

    func updateBattery(_ battery: Battery) async throws {
        XCTFail("Charger registration should not update a battery.")
        throw GarageRepositoryError.saveFailed
    }
}
