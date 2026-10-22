import CoreData

/// Saves batteries and chargers in Core Data. Same behaviour and errors as the in-memory version.
@MainActor
final class CoreDataGarageRepository: GarageRepository {
    private let context: NSManagedObjectContext

    init(persistence: PersistenceController) {
        self.context = persistence.viewContext
    }

    func fetchBatteries() async throws -> [Battery] {
        do {
            return try context.fetchObjects(entity: CDEntity.battery, sort: Self.creationOrder)
                .compactMap(Self.battery(from:))
        } catch {
            throw GarageRepositoryError.readFailed
        }
    }

    func fetchChargers() async throws -> [Charger] {
        do {
            return try context.fetchObjects(entity: CDEntity.charger, sort: Self.creationOrder)
                .compactMap(Self.charger(from:))
        } catch {
            throw GarageRepositoryError.readFailed
        }
    }

    func battery(id: UUID) async throws -> Battery {
        let object: NSManagedObject?
        do {
            object = try context.firstObject(entity: CDEntity.battery, id: id)
        } catch {
            throw GarageRepositoryError.readFailed
        }
        guard let object, let battery = Self.battery(from: object) else {
            throw GarageRepositoryError.batteryNotFound
        }
        return battery
    }

    func charger(id: UUID) async throws -> Charger {
        let object: NSManagedObject?
        do {
            object = try context.firstObject(entity: CDEntity.charger, id: id)
        } catch {
            throw GarageRepositoryError.readFailed
        }
        guard let object, let charger = Self.charger(from: object) else {
            throw GarageRepositoryError.chargerNotFound
        }
        return charger
    }

    func addBattery(_ battery: Battery) async throws {
        let chargerObject: NSManagedObject?
        do {
            guard try context.firstObject(entity: CDEntity.battery, id: battery.id) == nil else {
                throw GarageRepositoryError.duplicateBatteryID
            }
            chargerObject = try context.firstObject(entity: CDEntity.charger, id: battery.chargerID)
        } catch let error as GarageRepositoryError {
            throw error
        } catch {
            throw GarageRepositoryError.readFailed
        }
        guard let chargerObject else { throw GarageRepositoryError.chargerNotFound }

        let object = context.insertObject(entity: CDEntity.battery)
        object.setValue(Date(), forKey: "createdAt")
        Self.apply(battery, to: object, charger: chargerObject)
        try save()
    }

    func addCharger(_ charger: Charger) async throws {
        do {
            guard try context.firstObject(entity: CDEntity.charger, id: charger.id) == nil else {
                throw GarageRepositoryError.duplicateChargerID
            }
        } catch let error as GarageRepositoryError {
            throw error
        } catch {
            throw GarageRepositoryError.readFailed
        }

        let object = context.insertObject(entity: CDEntity.charger)
        object.setValue(charger.id, forKey: "id")
        object.setValue(charger.name, forKey: "name")
        object.setValue(charger.brand, forKey: "brand")
        object.setValue(Date(), forKey: "createdAt")
        try save()
    }

    func updateBattery(_ battery: Battery) async throws {
        let object: NSManagedObject?
        let chargerObject: NSManagedObject?
        do {
            object = try context.firstObject(entity: CDEntity.battery, id: battery.id)
            chargerObject = try context.firstObject(entity: CDEntity.charger, id: battery.chargerID)
        } catch {
            throw GarageRepositoryError.readFailed
        }
        guard let object else { throw GarageRepositoryError.batteryNotFound }
        guard let chargerObject else { throw GarageRepositoryError.chargerNotFound }

        Self.apply(battery, to: object, charger: chargerObject)
        try save()
    }

    // MARK: Helpers

    private func save() throws {
        do {
            try context.commit()
        } catch {
            throw GarageRepositoryError.saveFailed
        }
    }

    private static var creationOrder: [NSSortDescriptor] {
        [NSSortDescriptor(key: "createdAt", ascending: true)]
    }

    private static func apply(_ battery: Battery, to object: NSManagedObject, charger: NSManagedObject) {
        object.setValue(battery.id, forKey: "id")
        object.setValue(battery.name, forKey: "name")
        object.setValue(battery.brand, forKey: "brand")
        object.setValue(battery.capacityWh, forKey: "capacityWh")
        object.setValue(battery.purchaseDate, forKey: "purchaseDate")
        object.setValue(battery.chargerID, forKey: "chargerID")
        object.setValue(charger, forKey: "charger")
        switch battery.status {
        case .active:
            object.setValue("active", forKey: "status")
            object.setValue(nil, forKey: "retiredReason")
        case .retired(let reason):
            object.setValue("retired", forKey: "status")
            object.setValue(reason, forKey: "retiredReason")
        }
    }

    static func battery(from object: NSManagedObject) -> Battery? {
        guard let id = object.value(forKey: "id") as? UUID,
              let chargerID = object.value(forKey: "chargerID") as? UUID,
              let purchaseDate = object.value(forKey: "purchaseDate") as? Date else { return nil }

        let status: Battery.Status
        if object.value(forKey: "status") as? String == "retired" {
            status = .retired(reason: object.value(forKey: "retiredReason") as? String ?? "")
        } else {
            status = .active
        }

        return Battery(
            id: id,
            name: object.value(forKey: "name") as? String ?? "",
            brand: object.value(forKey: "brand") as? String ?? "",
            capacityWh: object.value(forKey: "capacityWh") as? Double ?? 0,
            purchaseDate: purchaseDate,
            chargerID: chargerID,
            status: status
        )
    }

    static func charger(from object: NSManagedObject) -> Charger? {
        guard let id = object.value(forKey: "id") as? UUID else { return nil }
        return Charger(
            id: id,
            name: object.value(forKey: "name") as? String ?? "",
            brand: object.value(forKey: "brand") as? String ?? ""
        )
    }
}
