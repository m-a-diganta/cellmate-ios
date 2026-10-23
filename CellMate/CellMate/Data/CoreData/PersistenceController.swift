import CoreData
import os

/// Owns the Core Data stack: the model, the SQLite store and the main-thread context.
///
/// The model lives in `CellMate.xcdatamodeld`. If the on-disk store cannot be opened
/// (for example a corrupt file), the app falls back to an in-memory store so it still
/// launches, and `loadError` explains why. Records are then not kept after quitting.
final class PersistenceController {
    static let modelName = "CellMate"
    static let shared = PersistenceController()

    let container: NSPersistentContainer
    /// Set when the on-disk store failed to open and a temporary store is in use.
    private(set) var loadError: Error?

    var viewContext: NSManagedObjectContext { container.viewContext }

    private static let logger = Logger(subsystem: "CellMate", category: "CoreData")

    /// - Parameter inMemory: true for tests and previews. Nothing is written to disk.
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: Self.modelName)
        let coordinator = container.persistentStoreCoordinator

        if inMemory {
            Self.addInMemoryStore(to: coordinator)
        } else {
            do {
                try Self.addSQLiteStore(to: coordinator)
            } catch {
                Self.logger.error("Could not open the store: \(error.localizedDescription)")
                loadError = error
                Self.addInMemoryStore(to: coordinator)
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy.mergeByPropertyObjectTrump
    }

    private static func addSQLiteStore(to coordinator: NSPersistentStoreCoordinator) throws {
        let directory = NSPersistentContainer.defaultDirectoryURL()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(modelName).sqlite")
        let options: [AnyHashable: Any] = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
            NSPersistentStoreFileProtectionKey: FileProtectionType.completeUnlessOpen
        ]
        _ = try coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: url,
            options: options
        )
    }

    private static func addInMemoryStore(to coordinator: NSPersistentStoreCoordinator) {
        do {
            _ = try coordinator.addPersistentStore(
                ofType: NSInMemoryStoreType,
                configurationName: nil,
                at: nil,
                options: nil
            )
        } catch {
            fatalError("Core Data could not create an in-memory store: \(error)")
        }
    }
}

/// Entity names in `CellMate.xcdatamodeld`.
enum CDEntity {
    static let battery = "BatteryEntity"
    static let charger = "ChargerEntity"
    static let chargeSession = "ChargeSessionEntity"
    static let riskFlag = "RiskFlagEntity"
    static let inspection = "InspectionEntity"
    static let inspectionItem = "InspectionItemEntity"
    static let photoEvidence = "PhotoEvidenceEntity"

    static let all = [battery, charger, chargeSession, riskFlag, inspection, inspectionItem, photoEvidence]
}

extension NSManagedObjectContext {
    func fetchObjects(
        entity: String,
        predicate: NSPredicate? = nil,
        sort: [NSSortDescriptor] = [],
        limit: Int = 0
    ) throws -> [NSManagedObject] {
        let request = NSFetchRequest<NSManagedObject>(entityName: entity)
        request.predicate = predicate
        request.sortDescriptors = sort
        request.fetchLimit = limit
        return try fetch(request)
    }

    func firstObject(entity: String, id: UUID) throws -> NSManagedObject? {
        try fetchObjects(
            entity: entity,
            predicate: NSPredicate(format: "id == %@", id as CVarArg),
            limit: 1
        ).first
    }

    func insertObject(entity: String) -> NSManagedObject {
        NSEntityDescription.insertNewObject(forEntityName: entity, into: self)
    }

    /// Saves pending changes. On failure the changes are discarded so a bad save never lingers.
    func commit() throws {
        guard hasChanges else { return }
        do {
            try save()
        } catch {
            rollback()
            throw error
        }
    }
}
