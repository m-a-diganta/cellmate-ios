import CoreData
import os

/// Saves charge sessions, with their risk flags, in Core Data.
/// The protocol is synchronous and cannot throw, so a failed save is logged and rolled back.
@MainActor
final class CoreDataChargeRepository: ChargeRepository {
    private let context: NSManagedObjectContext
    private static let logger = Logger(subsystem: "CellMate", category: "CoreData")

    init(persistence: PersistenceController) {
        self.context = persistence.viewContext
    }

    func save(_ session: ChargeSession) { upsert(session) }

    func update(_ session: ChargeSession) { upsert(session) }

    func runningSession(forBatteryID batteryID: UUID) -> ChargeSession? {
        fetchSessions(
            predicate: NSPredicate(format: "status == %@ AND batteryID == %@", "running", batteryID as CVarArg),
            limit: 1
        ).first
    }

    func anyRunningSession() -> ChargeSession? {
        fetchSessions(predicate: NSPredicate(format: "status == %@", "running"), limit: 1).first
    }

    func session(withID id: UUID) -> ChargeSession? {
        fetchSessions(predicate: NSPredicate(format: "id == %@", id as CVarArg), limit: 1).first
    }

    func allSessions() -> [ChargeSession] {
        fetchSessions(predicate: nil)
    }

    func sessions(forBatteryID batteryID: UUID) -> [ChargeSession] {
        fetchSessions(predicate: NSPredicate(format: "batteryID == %@", batteryID as CVarArg))
    }

    // MARK: Reading

    private func fetchSessions(predicate: NSPredicate?, limit: Int = 0) -> [ChargeSession] {
        do {
            return try context.fetchObjects(
                entity: CDEntity.chargeSession,
                predicate: predicate,
                sort: [NSSortDescriptor(key: "startedAt", ascending: false)],
                limit: limit
            ).compactMap(Self.session(from:))
        } catch {
            Self.logger.error("Could not read charges: \(error.localizedDescription)")
            return []
        }
    }

    // MARK: Writing

    private func upsert(_ session: ChargeSession) {
        do {
            let object = try context.firstObject(entity: CDEntity.chargeSession, id: session.id)
                ?? context.insertObject(entity: CDEntity.chargeSession)
            try apply(session, to: object)
            try context.commit()
        } catch {
            context.rollback()
            Self.logger.error("Could not save the charge: \(error.localizedDescription)")
        }
    }

    private func apply(_ session: ChargeSession, to object: NSManagedObject) throws {
        object.setValue(session.id, forKey: "id")
        object.setValue(session.batteryID, forKey: "batteryID")
        object.setValue(session.chargerID, forKey: "chargerID")
        object.setValue(session.startedAt, forKey: "startedAt")
        object.setValue(session.endedAt, forKey: "endedAt")
        object.setValue(session.plannedUnplug, forKey: "plannedUnplugAt")
        object.setValue(Int32(clamping: session.plannedDurationMinutes), forKey: "plannedDurationMinutes")
        object.setValue(session.place.rawValue, forKey: "place")
        object.setValue(try JSONEncoder().encode(session.checklistTicks), forKey: "checklistTicks")
        object.setValue(try JSONEncoder().encode(session.checklistLabels), forKey: "checklistLabels")
        object.setValue(session.overnight, forKey: "overnight")
        object.setValue(session.status.rawValue, forKey: "status")
        object.setValue(session.riskLevel?.rawValue, forKey: "riskLevel")
        object.setValue(session.rulesVersion, forKey: "rulesVersion")

        // Link to the battery and charger when they exist, so deleting a battery removes its charges.
        object.setValue(try context.firstObject(entity: CDEntity.battery, id: session.batteryID), forKey: "battery")
        object.setValue(try context.firstObject(entity: CDEntity.charger, id: session.chargerID), forKey: "charger")

        // Flags are rewritten as a set each time the risk is re-evaluated.
        let oldFlags = object.value(forKey: "riskFlags") as? Set<NSManagedObject> ?? []
        for flag in oldFlags { context.delete(flag) }
        for (index, flag) in session.riskFlags.enumerated() {
            let flagObject = context.insertObject(entity: CDEntity.riskFlag)
            flagObject.setValue(flag.id, forKey: "id")
            flagObject.setValue(flag.type.rawValue, forKey: "type")
            flagObject.setValue(flag.severity.rawValue, forKey: "severity")
            flagObject.setValue(flag.message, forKey: "message")
            flagObject.setValue(Int32(index), forKey: "sortIndex")
            flagObject.setValue(object, forKey: "chargeSession")
        }
    }

    static func session(from object: NSManagedObject) -> ChargeSession? {
        guard let id = object.value(forKey: "id") as? UUID,
              let batteryID = object.value(forKey: "batteryID") as? UUID,
              let chargerID = object.value(forKey: "chargerID") as? UUID,
              let startedAt = object.value(forKey: "startedAt") as? Date,
              let plannedUnplug = object.value(forKey: "plannedUnplugAt") as? Date else { return nil }

        let ticks = (object.value(forKey: "checklistTicks") as? Data)
            .flatMap { try? JSONDecoder().decode([Bool].self, from: $0) } ?? []
        let labels = (object.value(forKey: "checklistLabels") as? Data)
            .flatMap { try? JSONDecoder().decode([String].self, from: $0) } ?? []

        let flagObjects = (object.value(forKey: "riskFlags") as? Set<NSManagedObject> ?? [])
            .sorted { ($0.value(forKey: "sortIndex") as? Int32 ?? 0) < ($1.value(forKey: "sortIndex") as? Int32 ?? 0) }
        let flags: [RiskFlag] = flagObjects.compactMap { flag in
            guard let flagID = flag.value(forKey: "id") as? UUID,
                  let type = (flag.value(forKey: "type") as? String).flatMap(RiskFlagType.init(rawValue:)),
                  let severity = (flag.value(forKey: "severity") as? String).flatMap(RiskLevel.init(rawValue:))
            else { return nil }
            return RiskFlag(
                id: flagID,
                type: type,
                severity: severity,
                message: flag.value(forKey: "message") as? String ?? ""
            )
        }

        return ChargeSession(
            id: id,
            batteryID: batteryID,
            chargerID: chargerID,
            startedAt: startedAt,
            endedAt: object.value(forKey: "endedAt") as? Date,
            plannedUnplug: plannedUnplug,
            plannedDurationMinutes: Int(object.value(forKey: "plannedDurationMinutes") as? Int32 ?? 0),
            place: (object.value(forKey: "place") as? String).flatMap(ChargePlace.init(rawValue:)) ?? .other,
            checklistTicks: ticks,
            checklistLabels: labels,
            overnight: object.value(forKey: "overnight") as? Bool ?? false,
            status: (object.value(forKey: "status") as? String).flatMap(ChargeSessionStatus.init(rawValue:)) ?? .completed,
            riskLevel: (object.value(forKey: "riskLevel") as? String).flatMap(RiskLevel.init(rawValue:)),
            riskFlags: flags,
            rulesVersion: object.value(forKey: "rulesVersion") as? String ?? ""
        )
    }
}
