//
//  InspectionViewModelTests.swift
//  CellMateTests
//
//  Created by Yufan on 22/10/2026.
//

import Foundation
import XCTest
@testable import CellMate

@MainActor
final class InspectionViewModelTests: XCTestCase {
    func testUnansweredChecklistCannotSave() async {
        let fixture = makeFixture()

        XCTAssertEqual(fixture.model.answeredCount, 0)
        XCTAssertFalse(fixture.model.canSave)

        let result = await fixture.model.save()

        XCTAssertNil(result)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertEqual(fixture.inspections.saveCalls, 0)
    }

    func testReplacingPhotoDeletesPreviousFile() async throws {
        let fixture = makeFixture()

        await fixture.model.importPhoto(data: Data([1]))
        let first = try XCTUnwrap(fixture.model.photo)

        await fixture.model.importPhoto(data: Data([2]))
        let second = try XCTUnwrap(fixture.model.photo)

        XCTAssertNotEqual(first.filename, second.filename)
        XCTAssertNil(fixture.photos.files[first.filename])
        XCTAssertEqual(fixture.photos.files[second.filename], Data([2]))
        XCTAssertEqual(fixture.model.photoData, Data([2]))
        XCTAssertEqual(fixture.photos.files.count, 1)
    }

    func testRemovingPhotoDeletesFileAndClearsPreview() async throws {
        let fixture = makeFixture()

        await fixture.model.importPhoto(data: Data([1]))
        let photo = try XCTUnwrap(fixture.model.photo)

        await fixture.model.removePhoto()

        XCTAssertNil(fixture.model.photo)
        XCTAssertNil(fixture.model.photoData)
        XCTAssertNil(fixture.photos.files[photo.filename])
        XCTAssertNil(fixture.model.errorMessage)
    }

    func testDiscardingDraftDeletesItsPhoto() async {
        let fixture = makeFixture()

        await fixture.model.importPhoto(data: Data([1]))

        let discarded = await fixture.model.discardDraft()

        XCTAssertTrue(discarded)
        XCTAssertTrue(fixture.photos.files.isEmpty)
        XCTAssertNil(fixture.model.photo)
        XCTAssertNil(fixture.model.photoData)
    }

    func testSavedInspectionKeepsPhotoWhenLeaving() async throws {
        let fixture = makeFixture()
        completeChecklist(fixture.model)

        await fixture.model.importPhoto(data: Data([1]))
        let photo = try XCTUnwrap(fixture.model.photo)

        let result = await fixture.model.save()
        let inspection = try XCTUnwrap(result)

        let discarded = await fixture.model.discardDraft()

        // Removal must also be blocked after a successful save.
        await fixture.model.removePhoto()

        XCTAssertTrue(discarded)
        XCTAssertEqual(inspection.photos, [photo])
        XCTAssertEqual(fixture.model.photo, photo)
        XCTAssertEqual(fixture.photos.files[photo.filename], Data([1]))
    }

    func testRepeatedSaveDoesNotCreateDuplicateInspection() async throws {
        let fixture = makeFixture()
        completeChecklist(fixture.model)

        let firstResult = await fixture.model.save()
        let first = try XCTUnwrap(firstResult)

        let secondResult = await fixture.model.save()
        let second = try XCTUnwrap(secondResult)

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(fixture.inspections.saveCalls, 1)
        XCTAssertEqual(fixture.inspections.records.count, 1)
        XCTAssertFalse(fixture.model.canSave)
    }

    func testFailedPhotoImportPreservesExistingAttachment() async throws {
        let fixture = makeFixture()

        await fixture.model.importPhoto(data: Data([1]))
        let original = try XCTUnwrap(fixture.model.photo)

        fixture.photos.failSaving = true
        await fixture.model.importPhoto(data: Data([2]))

        XCTAssertEqual(fixture.model.photo, original)
        XCTAssertEqual(fixture.model.photoData, Data([1]))
        XCTAssertEqual(fixture.photos.files.count, 1)
        XCTAssertNotNil(fixture.model.errorMessage)
        XCTAssertFalse(fixture.model.isProcessingPhoto)
    }

    func testFailedCleanupCanBeRetried() async throws {
        let fixture = makeFixture()

        await fixture.model.importPhoto(data: Data([1]))
        let photo = try XCTUnwrap(fixture.model.photo)

        fixture.photos.failDeleting = true
        let firstAttempt = await fixture.model.discardDraft()

        XCTAssertFalse(firstAttempt)
        XCTAssertEqual(fixture.model.photo, photo)
        XCTAssertNotNil(fixture.photos.files[photo.filename])
        XCTAssertNotNil(fixture.model.errorMessage)

        fixture.photos.failDeleting = false
        let secondAttempt = await fixture.model.discardDraft()

        XCTAssertTrue(secondAttempt)
        XCTAssertTrue(fixture.photos.files.isEmpty)
        XCTAssertNil(fixture.model.photo)
        XCTAssertNil(fixture.model.errorMessage)
    }

    func testFailedInspectionSaveKeepsPhotoForRetry() async throws {
        let fixture = makeFixture()
        completeChecklist(fixture.model)

        await fixture.model.importPhoto(data: Data([1]))
        let photo = try XCTUnwrap(fixture.model.photo)

        fixture.inspections.failSaving = true
        let failedResult = await fixture.model.save()

        XCTAssertNil(failedResult)
        XCTAssertNil(fixture.model.savedInspection)
        XCTAssertEqual(fixture.model.photo, photo)
        XCTAssertNotNil(fixture.photos.files[photo.filename])
        XCTAssertTrue(fixture.model.canSave)
        XCTAssertNotNil(fixture.model.errorMessage)

        fixture.inspections.failSaving = false
        let successfulResult = await fixture.model.save()
        let inspection = try XCTUnwrap(successfulResult)

        XCTAssertEqual(inspection.photos, [photo])
        XCTAssertEqual(fixture.inspections.records.count, 1)
        XCTAssertNotNil(fixture.photos.files[photo.filename])
        XCTAssertNil(fixture.model.errorMessage)
    }

    private func completeChecklist(_ model: InspectionViewModel) {
        for kind in Inspection.Item.Kind.allCases {
            model.setFinding(.ok, for: kind)
        }
    }

    private func makeFixture() -> (
        model: InspectionViewModel,
        photos: PhotoStoreStub,
        inspections: ViewModelInspectionRepositoryStub
    ) {
        let charger = Charger(name: "Bosch 4A", brand: "Bosch")

        let battery = Battery(
            name: "Battery A",
            brand: "Bosch",
            capacityWh: 720,
            purchaseDate: Date(timeIntervalSince1970: 1_700_000_000),
            chargerID: charger.id
        )

        let garage = InMemoryGarageRepository(
            batteries: [battery],
            chargers: [charger]
        )

        let photos = PhotoStoreStub()
        let inspections = ViewModelInspectionRepositoryStub()

        let model = InspectionViewModel(
            batteryID: battery.id,
            logInspection: LogInspection(
                garageRepository: garage,
                inspectionRepository: inspections
            ),
            photoStore: photos
        )

        return (model, photos, inspections)
    }
}

@MainActor
private final class PhotoStoreStub: InspectionPhotoStoring {
    private(set) var files: [String: Data] = [:]

    var failSaving = false
    var failDeleting = false

    func savePhoto(
        imageData: Data
    ) async throws -> Inspection.PhotoEvidence {
        if failSaving {
            throw InspectionPhotoStorageError.saveFailed
        }

        let id = UUID()
        let filename = "\(id.uuidString).jpg"

        files[filename] = imageData

        return Inspection.PhotoEvidence(
            id: id,
            filename: filename,
            capturedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }

    func loadPhoto(filename: String) async throws -> Data {
        guard let data = files[filename] else {
            throw InspectionPhotoStorageError.photoNotFound
        }

        return data
    }

    func deletePhoto(filename: String) async throws {
        if failDeleting {
            throw InspectionPhotoStorageError.deleteFailed
        }

        files.removeValue(forKey: filename)
    }
}

@MainActor
private final class ViewModelInspectionRepositoryStub:
    InspectionRepository
{
    private(set) var records: [Inspection] = []
    private(set) var saveCalls = 0

    var failSaving = false

    func fetchInspections(
        for batteryID: UUID
    ) async throws -> [Inspection] {
        records
            .filter { $0.batteryID == batteryID }
            .sorted { $0.inspectedAt > $1.inspectedAt }
    }

    func inspection(id: UUID) async throws -> Inspection {
        guard let inspection = records.first(where: {
            $0.id == id
        }) else {
            throw InspectionRepositoryError.inspectionNotFound
        }

        return inspection
    }

    func addInspection(_ inspection: Inspection) async throws {
        saveCalls += 1

        if failSaving {
            throw InspectionRepositoryError.saveFailed
        }

        records.append(inspection)
    }
}
