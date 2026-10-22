//
//  LogInspectionTests.swift
//  CellMateTests
//
//  Created by Yufan on 22/10/2026.
//

import Foundation
import XCTest
@testable import CellMate

@MainActor
final class LogInspectionTests: XCTestCase {
    private let fixedDate = Date(timeIntervalSince1970: 1_700_000_000)

    func testAllOKChecksSavePassingInspection() async throws {
        let fixture = makeFixture()

        let inspection = try await fixture.useCase.execute(
            LogInspection.Input(
                batteryID: fixture.battery.id,
                items: makeItems()
            )
        )

        XCTAssertEqual(inspection.batteryID, fixture.battery.id)
        XCTAssertEqual(inspection.inspectedAt, fixedDate)
        XCTAssertEqual(inspection.source, .manual)
        XCTAssertEqual(inspection.result, .pass)
        XCTAssertEqual(inspection.items.count, 5)
        XCTAssertFalse(inspection.hasReportedProblem)
        XCTAssertEqual(fixture.store.savedInspections, [inspection])
    }

    func testAnyProblemProducesFailResult() async throws {
        // Each of the five checks must independently trigger failure.
        for kind in Inspection.Item.Kind.allCases {
            let fixture = makeFixture()

            let inspection = try await fixture.useCase.execute(
                LogInspection.Input(
                    batteryID: fixture.battery.id,
                    items: makeItems(problem: kind)
                )
            )

            XCTAssertEqual(
                inspection.result,
                .fail,
                "A problem with \(kind) must not produce a pass."
            )
            XCTAssertTrue(inspection.hasReportedProblem)
            XCTAssertEqual(fixture.store.savedInspections, [inspection])
        }
    }

    func testIncompleteChecklistIsRejected() async {
        let fixture = makeFixture()
        let items = Array(makeItems().dropLast())

        do {
            _ = try await fixture.useCase.execute(
                LogInspection.Input(
                    batteryID: fixture.battery.id,
                    items: items
                )
            )
            XCTFail("Expected incompleteChecklist.")
        } catch {
            XCTAssertEqual(
                error as? LogInspection.ValidationError,
                .incompleteChecklist
            )
        }

        XCTAssertEqual(fixture.store.saveCalls, 0)
    }

    func testDuplicateCheckKindsAreRejected() async {
        let fixture = makeFixture()

        // Five answers, but swelling is repeated and charger is missing.
        var items = Array(makeItems().dropLast())
        items.append(
            Inspection.Item(
                kind: .swelling,
                finding: .ok
            )
        )

        do {
            _ = try await fixture.useCase.execute(
                LogInspection.Input(
                    batteryID: fixture.battery.id,
                    items: items
                )
            )
            XCTFail("Expected duplicateChecks.")
        } catch {
            XCTAssertEqual(
                error as? LogInspection.ValidationError,
                .duplicateChecks
            )
        }

        XCTAssertEqual(fixture.store.saveCalls, 0)
    }

    func testDuplicateItemIDsAreRejected() async {
        let fixture = makeFixture()
        let sharedID = UUID()

        let items = Inspection.Item.Kind.allCases.map { kind in
            Inspection.Item(
                id: sharedID,
                kind: kind,
                finding: .ok
            )
        }

        do {
            _ = try await fixture.useCase.execute(
                LogInspection.Input(
                    batteryID: fixture.battery.id,
                    items: items
                )
            )
            XCTFail("Expected duplicateItemIDs.")
        } catch {
            XCTAssertEqual(
                error as? LogInspection.ValidationError,
                .duplicateItemIDs
            )
        }

        XCTAssertEqual(fixture.store.saveCalls, 0)
    }

    func testMoreThanOnePhotoIsRejected() async {
        let fixture = makeFixture()

        let photos = [
            Inspection.PhotoEvidence(
                filename: "\(UUID().uuidString).jpg",
                capturedAt: fixedDate
            ),
            Inspection.PhotoEvidence(
                filename: "\(UUID().uuidString).jpg",
                capturedAt: fixedDate
            )
        ]

        do {
            _ = try await fixture.useCase.execute(
                LogInspection.Input(
                    batteryID: fixture.battery.id,
                    items: makeItems(),
                    photos: photos
                )
            )
            XCTFail("Expected tooManyPhotos.")
        } catch {
            XCTAssertEqual(
                error as? LogInspection.ValidationError,
                .tooManyPhotos
            )
        }

        XCTAssertEqual(fixture.store.saveCalls, 0)
    }

    func testMissingBatteryPreventsSaving() async {
        let fixture = makeFixture()

        do {
            _ = try await fixture.useCase.execute(
                LogInspection.Input(
                    batteryID: UUID(),
                    items: makeItems()
                )
            )
            XCTFail("Expected batteryNotFound.")
        } catch {
            XCTAssertEqual(
                error as? GarageRepositoryError,
                .batteryNotFound
            )
        }

        XCTAssertEqual(fixture.store.saveCalls, 0)
    }

    func testSaveFailureIsPassedToCaller() async {
        let fixture = makeFixture()
        fixture.store.saveError = .saveFailed

        do {
            _ = try await fixture.useCase.execute(
                LogInspection.Input(
                    batteryID: fixture.battery.id,
                    items: makeItems()
                )
            )
            XCTFail("Expected saveFailed.")
        } catch {
            XCTAssertEqual(
                error as? InspectionRepositoryError,
                .saveFailed
            )
        }

        XCTAssertEqual(fixture.store.saveCalls, 1)
        XCTAssertTrue(fixture.store.savedInspections.isEmpty)
    }

    private func makeItems(
        problem: Inspection.Item.Kind? = nil
    ) -> [Inspection.Item] {
        Inspection.Item.Kind.allCases.map { kind in
            Inspection.Item(
                kind: kind,
                finding: kind == problem ? .problem : .ok
            )
        }
    }

    private func makeFixture() -> (
        battery: Battery,
        store: InspectionRepositoryStub,
        useCase: LogInspection
    ) {
        let charger = Charger(name: "Bosch 4A", brand: "Bosch")

        let battery = Battery(
            name: "Battery A",
            brand: "Bosch",
            capacityWh: 720,
            purchaseDate: fixedDate,
            chargerID: charger.id
        )

        let garage = InMemoryGarageRepository(
            batteries: [battery],
            chargers: [charger]
        )

        let store = InspectionRepositoryStub()
        let date = fixedDate

        let useCase = LogInspection(
            garageRepository: garage,
            inspectionRepository: store,
            now: { date }
        )

        return (battery, store, useCase)
    }
}

@MainActor
private final class InspectionRepositoryStub: InspectionRepository {
    var saveError: InspectionRepositoryError?

    private(set) var savedInspections: [Inspection] = []
    private(set) var saveCalls = 0

    func fetchInspections(
        for batteryID: UUID
    ) async throws -> [Inspection] {
        savedInspections
            .filter { $0.batteryID == batteryID }
            .sorted { $0.inspectedAt > $1.inspectedAt }
    }

    func inspection(id: UUID) async throws -> Inspection {
        guard let inspection = savedInspections.first(where: {
            $0.id == id
        }) else {
            throw InspectionRepositoryError.inspectionNotFound
        }

        return inspection
    }

    func addInspection(_ inspection: Inspection) async throws {
        saveCalls += 1

        if let saveError {
            throw saveError
        }

        savedInspections.append(inspection)
    }
}
