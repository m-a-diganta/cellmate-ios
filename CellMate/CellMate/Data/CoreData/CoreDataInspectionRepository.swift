import CoreData

/// Saves inspections, their checklist items and photo references in Core Data.
/// Photo files stay on disk (see LocalInspectionPhotoStore); only the filename is stored here.
@MainActor
final class CoreDataInspectionRepository: InspectionRepository {
    private let context: NSManagedObjectContext

    init(persistence: PersistenceController) {
        self.context = persistence.viewContext
    }

    func fetchInspections(for batteryID: UUID) async throws -> [Inspection] {
        try verifyBatteryExists(id: batteryID)

        let objects: [NSManagedObject]
        do {
            objects = try context.fetchObjects(
                entity: CDEntity.inspection,
                predicate: NSPredicate(format: "batteryID == %@", batteryID as CVarArg)
            )
        } catch {
            throw InspectionRepositoryError.readFailed
        }

        return objects
            .compactMap(Self.inspection(from:))
            .sorted { first, second in
                if first.inspectedAt == second.inspectedAt {
                    return first.id.uuidString < second.id.uuidString
                }
                return first.inspectedAt > second.inspectedAt
            }
    }

    func inspection(id: UUID) async throws -> Inspection {
        let object: NSManagedObject?
        do {
            object = try context.firstObject(entity: CDEntity.inspection, id: id)
        } catch {
            throw InspectionRepositoryError.readFailed
        }
        guard let object, let inspection = Self.inspection(from: object) else {
            throw InspectionRepositoryError.inspectionNotFound
        }
        return inspection
    }

    func addInspection(_ inspection: Inspection) async throws {
        let batteryObject = try verifyBatteryExists(id: inspection.batteryID)

        do {
            guard try context.firstObject(entity: CDEntity.inspection, id: inspection.id) == nil else {
                throw InspectionRepositoryError.duplicateInspectionID
            }
        } catch let error as InspectionRepositoryError {
            throw error
        } catch {
            throw InspectionRepositoryError.readFailed
        }

        // The inspection, its items and its photos are saved together or not at all.
        let object = context.insertObject(entity: CDEntity.inspection)
        object.setValue(inspection.id, forKey: "id")
        object.setValue(inspection.batteryID, forKey: "batteryID")
        object.setValue(inspection.inspectedAt, forKey: "inspectedAt")
        object.setValue(inspection.source.rawValue, forKey: "source")
        object.setValue(inspection.result.rawValue, forKey: "result")
        object.setValue(batteryObject, forKey: "battery")

        for (index, item) in inspection.items.enumerated() {
            let itemObject = context.insertObject(entity: CDEntity.inspectionItem)
            itemObject.setValue(item.id, forKey: "id")
            itemObject.setValue(item.kind.rawValue, forKey: "kind")
            itemObject.setValue(item.finding == .problem, forKey: "isProblem")
            itemObject.setValue(item.note, forKey: "note")
            itemObject.setValue(Int32(index), forKey: "sortIndex")
            itemObject.setValue(object, forKey: "inspection")
        }

        for (index, photo) in inspection.photos.enumerated() {
            let photoObject = context.insertObject(entity: CDEntity.photoEvidence)
            photoObject.setValue(photo.id, forKey: "id")
            photoObject.setValue(photo.filename, forKey: "filename")
            photoObject.setValue(photo.capturedAt, forKey: "capturedAt")
            photoObject.setValue(Int32(index), forKey: "sortIndex")
            photoObject.setValue(object, forKey: "inspection")
        }

        do {
            try context.commit()
        } catch {
            throw InspectionRepositoryError.saveFailed
        }
    }

    @discardableResult
    private func verifyBatteryExists(id: UUID) throws -> NSManagedObject {
        let object: NSManagedObject?
        do {
            object = try context.firstObject(entity: CDEntity.battery, id: id)
        } catch {
            throw InspectionRepositoryError.readFailed
        }
        guard let object else { throw InspectionRepositoryError.batteryNotFound }
        return object
    }

    static func inspection(from object: NSManagedObject) -> Inspection? {
        guard let id = object.value(forKey: "id") as? UUID,
              let batteryID = object.value(forKey: "batteryID") as? UUID,
              let inspectedAt = object.value(forKey: "inspectedAt") as? Date,
              let source = (object.value(forKey: "source") as? String).flatMap(Inspection.Source.init(rawValue:)),
              let result = (object.value(forKey: "result") as? String).flatMap(Inspection.Result.init(rawValue:))
        else { return nil }

        func order(_ a: NSManagedObject, _ b: NSManagedObject) -> Bool {
            (a.value(forKey: "sortIndex") as? Int32 ?? 0) < (b.value(forKey: "sortIndex") as? Int32 ?? 0)
        }

        let items: [Inspection.Item] = (object.value(forKey: "items") as? Set<NSManagedObject> ?? [])
            .sorted(by: order)
            .compactMap { item in
                guard let itemID = item.value(forKey: "id") as? UUID,
                      let kind = (item.value(forKey: "kind") as? String).flatMap(Inspection.Item.Kind.init(rawValue:))
                else { return nil }
                return Inspection.Item(
                    id: itemID,
                    kind: kind,
                    finding: (item.value(forKey: "isProblem") as? Bool ?? false) ? .problem : .ok,
                    note: item.value(forKey: "note") as? String
                )
            }

        let photos: [Inspection.PhotoEvidence] = (object.value(forKey: "photos") as? Set<NSManagedObject> ?? [])
            .sorted(by: order)
            .compactMap { photo in
                guard let photoID = photo.value(forKey: "id") as? UUID,
                      let filename = photo.value(forKey: "filename") as? String,
                      let capturedAt = photo.value(forKey: "capturedAt") as? Date
                else { return nil }
                return Inspection.PhotoEvidence(id: photoID, filename: filename, capturedAt: capturedAt)
            }

        return Inspection(
            id: id,
            batteryID: batteryID,
            inspectedAt: inspectedAt,
            source: source,
            result: result,
            items: items,
            photos: photos
        )
    }
}
