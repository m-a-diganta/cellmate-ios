import CoreData
import XCTest
@testable import CellMate

/// Runs the real Core Data repositories against an in-memory store.
@MainActor
final class CoreDataRepositoryTests: XCTestCase {
    private var persistence: PersistenceController!
    private var garage: CoreDataGarageRepository!
    private var charges: CoreDataChargeRepository!
    private var inspections: CoreDataInspectionRepository!

    private let charger = Charger(name: "Stock charger", brand: "InMotion")
    private let date = Date(timeIntervalSince1970: 1_700_000_000)
    private lazy var battery = Battery(
        name: "Main pack",
        brand: "InMotion",
        capacityWh: 500,
        purchaseDate: date,
        chargerID: charger.id
    )

    override func setUp() async throws {
        persistence = PersistenceController(inMemory: true)
        garage = CoreDataGarageRepository(persistence: persistence)
        charges = CoreDataChargeRepository(persistence: persistence)
        inspections = CoreDataInspectionRepository(persistence: persistence)
    }

    private func seedGarage() async throws {
        try await garage.addCharger(charger)
        try await garage.addBattery(battery)
    }

    private func makeSession(
        start: Date,
        status: ChargeSessionStatus = .running,
        flags: [RiskFlag] = []
    ) -> ChargeSession {
        ChargeSession(
            batteryID: battery.id,
            chargerID: charger.id,
            startedAt: start,
            endedAt: nil,
            plannedUnplug: start.addingTimeInterval(3_600),
            plannedDurationMinutes: 60,
            place: .garage,
            checklistTicks: [true, false, true],
            checklistLabels: ["A", "B", "C"],
            overnight: true,
            status: status,
            riskLevel: .medium,
            riskFlags: flags,
            rulesVersion: "v1.0"
        )
    }

    // MARK: Garage

    func testGarageRoundTrip() async throws {
        try await seedGarage()

        let batteries = try await garage.fetchBatteries()
        let chargers = try await garage.fetchChargers()
        XCTAssertEqual(batteries, [battery])
        XCTAssertEqual(chargers, [charger])
        let found = try await garage.battery(id: battery.id)
        XCTAssertEqual(found, battery)
    }

    func testGarageKeepsInsertionOrder() async throws {
        try await garage.addCharger(charger)
        let first = Battery(name: "First", brand: "A", capacityWh: 1, purchaseDate: date.addingTimeInterval(500), chargerID: charger.id)
        let second = Battery(name: "Second", brand: "B", capacityWh: 2, purchaseDate: date, chargerID: charger.id)
        try await garage.addBattery(first)
        try await garage.addBattery(second)

        let names = try await garage.fetchBatteries().map(\.name)
        XCTAssertEqual(names, ["First", "Second"])
    }

    func testBatteryNeedsAnExistingCharger() async throws {
        do {
            try await garage.addBattery(battery)
            XCTFail("Expected chargerNotFound")
        } catch {
            XCTAssertEqual(error as? GarageRepositoryError, .chargerNotFound)
        }
    }

    func testDuplicateIDsAreRejected() async throws {
        try await seedGarage()

        do {
            try await garage.addBattery(battery)
            XCTFail("Expected duplicateBatteryID")
        } catch {
            XCTAssertEqual(error as? GarageRepositoryError, .duplicateBatteryID)
        }

        do {
            try await garage.addCharger(charger)
            XCTFail("Expected duplicateChargerID")
        } catch {
            XCTAssertEqual(error as? GarageRepositoryError, .duplicateChargerID)
        }
    }

    func testRetiringABatteryIsSaved() async throws {
        try await seedGarage()
        let retired = Battery(
            id: battery.id,
            name: battery.name,
            brand: battery.brand,
            capacityWh: battery.capacityWh,
            purchaseDate: battery.purchaseDate,
            chargerID: battery.chargerID,
            status: .retired(reason: "Swollen")
        )
        try await garage.updateBattery(retired)

        let saved = try await garage.battery(id: battery.id)
        XCTAssertEqual(saved.retirementReason, "Swollen")
        let all = try await garage.fetchBatteries()
        XCTAssertEqual(all.count, 1)
    }

    func testMissingRecordsThrowNotFound() async throws {
        do {
            _ = try await garage.battery(id: UUID())
            XCTFail("Expected batteryNotFound")
        } catch {
            XCTAssertEqual(error as? GarageRepositoryError, .batteryNotFound)
        }

        do {
            try await garage.updateBattery(battery)
            XCTFail("Expected batteryNotFound")
        } catch {
            XCTAssertEqual(error as? GarageRepositoryError, .batteryNotFound)
        }
    }

    // MARK: Charges

    func testChargeRoundTripKeepsEveryField() async throws {
        try await seedGarage()
        let flag = RiskFlag(type: .nearBedtime, severity: .high, message: "Close to bedtime")
        let session = makeSession(start: date, flags: [flag])
        charges.save(session)

        XCTAssertEqual(charges.session(withID: session.id), session)
    }

    func testChargeUpdateEndsTheSessionAndReplacesFlags() async throws {
        try await seedGarage()
        var session = makeSession(start: date, flags: [RiskFlag(type: .tooLong, severity: .medium, message: "Long")])
        charges.save(session)
        XCTAssertNotNil(charges.runningSession(forBatteryID: battery.id))
        XCTAssertNotNil(charges.anyRunningSession())

        session.status = .completed
        session.endedAt = date.addingTimeInterval(1_800)
        session.riskFlags = []
        charges.update(session)

        XCTAssertNil(charges.anyRunningSession())
        XCTAssertEqual(charges.allSessions().count, 1)
        XCTAssertEqual(charges.session(withID: session.id)?.riskFlags, [])
        XCTAssertEqual(charges.session(withID: session.id)?.status, .completed)
    }

    func testChargesAreNewestFirstAndFilterByBattery() async throws {
        try await seedGarage()
        let older = makeSession(start: date, status: .completed)
        let newer = makeSession(start: date.addingTimeInterval(86_400), status: .completed)
        charges.save(older)
        charges.save(newer)

        XCTAssertEqual(charges.allSessions().map(\.id), [newer.id, older.id])
        XCTAssertEqual(charges.sessions(forBatteryID: battery.id).count, 2)
        XCTAssertTrue(charges.sessions(forBatteryID: UUID()).isEmpty)
    }

    // MARK: Inspections

    func testInspectionRoundTripKeepsItemsAndPhotos() async throws {
        try await seedGarage()
        let inspection = Inspection(
            batteryID: battery.id,
            inspectedAt: date,
            source: .manual,
            result: .caution,
            items: [
                Inspection.Item(kind: .swelling, finding: .ok),
                Inspection.Item(kind: .heat, finding: .problem, note: "Warm to touch"),
                Inspection.Item(kind: .smell, finding: .ok)
            ],
            photos: [Inspection.PhotoEvidence(filename: "\(UUID().uuidString).jpg", capturedAt: date)]
        )
        try await inspections.addInspection(inspection)

        let loaded = try await inspections.inspection(id: inspection.id)
        XCTAssertEqual(loaded, inspection)
        let list = try await inspections.fetchInspections(for: battery.id)
        XCTAssertEqual(list, [inspection])
    }

    func testInspectionsAreNewestFirst() async throws {
        try await seedGarage()
        let older = Inspection(batteryID: battery.id, inspectedAt: date, source: .manual, result: .pass, items: [])
        let newer = Inspection(batteryID: battery.id, inspectedAt: date.addingTimeInterval(60), source: .assistant, result: .fail, items: [])
        try await inspections.addInspection(older)
        try await inspections.addInspection(newer)

        let ids = try await inspections.fetchInspections(for: battery.id).map(\.id)
        XCTAssertEqual(ids, [newer.id, older.id])
    }

    func testInspectionErrors() async throws {
        let orphan = Inspection(batteryID: UUID(), inspectedAt: date, source: .manual, result: .pass, items: [])
        do {
            try await inspections.addInspection(orphan)
            XCTFail("Expected batteryNotFound")
        } catch {
            XCTAssertEqual(error as? InspectionRepositoryError, .batteryNotFound)
        }

        try await seedGarage()
        let saved = Inspection(batteryID: battery.id, inspectedAt: date, source: .manual, result: .pass, items: [])
        try await inspections.addInspection(saved)
        do {
            try await inspections.addInspection(saved)
            XCTFail("Expected duplicateInspectionID")
        } catch {
            XCTAssertEqual(error as? InspectionRepositoryError, .duplicateInspectionID)
        }

        do {
            _ = try await inspections.inspection(id: UUID())
            XCTFail("Expected inspectionNotFound")
        } catch {
            XCTAssertEqual(error as? InspectionRepositoryError, .inspectionNotFound)
        }
    }

    // MARK: Records manager

    func testExportListsEveryRecordAndEscapesText() async throws {
        let tricky = Battery(name: "=Pack, \"A\"", brand: "Bosch", capacityWh: 720, purchaseDate: date, chargerID: charger.id)
        try await garage.addCharger(charger)
        try await garage.addBattery(tricky)
        charges.save(ChargeSession(
            batteryID: tricky.id, chargerID: charger.id, startedAt: date, endedAt: nil,
            plannedUnplug: date.addingTimeInterval(3_600), plannedDurationMinutes: 60, place: .outside,
            checklistTicks: [], checklistLabels: [], overnight: false, riskLevel: .low, rulesVersion: "v1.0"
        ))
        try await inspections.addInspection(
            Inspection(batteryID: tricky.id, inspectedAt: date, source: .manual, result: .pass, items: [])
        )

        let manager = CoreDataRecordsManager(persistence: persistence)
        let csv = try manager.makeCSV()
        let lines = csv.split(separator: "\n").map(String.init)

        XCTAssertEqual(lines.first, "type,date,battery,details")
        XCTAssertEqual(lines.count, 5) // header + battery + charger + charge + inspection
        XCTAssertTrue(csv.contains("\"'=Pack, \"\"A\"\"\""), "Formula-like and quoted text must be neutralised and escaped")
    }

    func testDeleteAllRemovesEverythingAndReportsTheCharges() async throws {
        try await seedGarage()
        let session = makeSession(start: date)
        charges.save(session)
        try await inspections.addInspection(
            Inspection(batteryID: battery.id, inspectedAt: date, source: .manual, result: .pass,
                       items: [Inspection.Item(kind: .heat, finding: .ok)])
        )

        let photoDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("CellMateTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: photoDirectory, withIntermediateDirectories: true)
        try Data([1]).write(to: photoDirectory.appendingPathComponent("a.jpg"))

        var reported: [UUID] = []
        let manager = CoreDataRecordsManager(persistence: persistence, photoDirectory: photoDirectory) { reported = $0 }
        try await manager.deleteAllRecords()

        let batteries = try await garage.fetchBatteries()
        let chargers = try await garage.fetchChargers()
        XCTAssertTrue(batteries.isEmpty)
        XCTAssertTrue(chargers.isEmpty)
        XCTAssertTrue(charges.allSessions().isEmpty)
        for entity in CDEntity.all {
            XCTAssertEqual(try persistence.viewContext.fetchObjects(entity: entity).count, 0, entity)
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: photoDirectory.path))
        XCTAssertEqual(reported, [session.id])
    }

    func testDeletingABatteryRemovesItsChargesAndInspections() async throws {
        try await seedGarage()
        charges.save(makeSession(start: date))
        try await inspections.addInspection(
            Inspection(batteryID: battery.id, inspectedAt: date, source: .manual, result: .pass, items: [])
        )

        let context = persistence.viewContext
        let object = try XCTUnwrap(context.firstObject(entity: CDEntity.battery, id: battery.id))
        context.delete(object)
        try context.commit()

        XCTAssertTrue(charges.allSessions().isEmpty)
        XCTAssertEqual(try context.fetchObjects(entity: CDEntity.inspection).count, 0)
    }
}
