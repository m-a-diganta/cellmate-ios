import CoreData

/// Export and delete for Settings, backed by the Core Data store and the photo folder.
struct CoreDataRecordsManager: RecordsManaging {
    private let persistence: PersistenceController
    private let photoDirectory: URL?
    private let onDeleted: @MainActor (_ sessionIDs: [UUID]) async -> Void

    /// - Parameters:
    ///   - photoDirectory: Folder of inspection photos to remove on delete. Nil uses the default folder.
    ///   - onDeleted: Runs after a delete with the IDs of the removed charges, so the caller can cancel
    ///     their alerts and clear the widget.
    init(
        persistence: PersistenceController,
        photoDirectory: URL? = nil,
        onDeleted: @escaping @MainActor (_ sessionIDs: [UUID]) async -> Void = { _ in }
    ) {
        self.persistence = persistence
        self.photoDirectory = photoDirectory
        self.onDeleted = onDeleted
    }

    // MARK: Export

    func exportRecords() async throws -> URL {
        let csv = try makeCSV()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CellMate-records.csv")
        try csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// One row per record: type, date, battery, details.
    func makeCSV() throws -> String {
        let context = persistence.viewContext
        let batteries = try context.fetchObjects(entity: CDEntity.battery, sort: [Self.sort("createdAt", true)])
        let chargers = try context.fetchObjects(entity: CDEntity.charger, sort: [Self.sort("createdAt", true)])
        let sessions = try context.fetchObjects(entity: CDEntity.chargeSession, sort: [Self.sort("startedAt", true)])
        let inspections = try context.fetchObjects(entity: CDEntity.inspection, sort: [Self.sort("inspectedAt", true)])

        var names: [UUID: String] = [:]
        for battery in batteries {
            if let id = battery.value(forKey: "id") as? UUID {
                names[id] = battery.value(forKey: "name") as? String ?? ""
            }
        }

        let formatter = ISO8601DateFormatter()
        func date(_ value: Any?) -> String { (value as? Date).map { formatter.string(from: $0) } ?? "" }

        var rows: [[String]] = [["type", "date", "battery", "details"]]

        for battery in batteries {
            let brand = battery.value(forKey: "brand") as? String ?? ""
            let capacity = battery.value(forKey: "capacityWh") as? Double ?? 0
            var parts: [String] = [brand, "\(capacity) Wh"]
            if battery.value(forKey: "status") as? String == "retired" {
                let reason = battery.value(forKey: "retiredReason") as? String ?? ""
                parts.append("retired: \(reason)")
            }
            rows.append([
                "battery",
                date(battery.value(forKey: "purchaseDate")),
                battery.value(forKey: "name") as? String ?? "",
                parts.joined(separator: "; ")
            ])
        }

        for charger in chargers {
            let name = charger.value(forKey: "name") as? String ?? ""
            let brand = charger.value(forKey: "brand") as? String ?? ""
            rows.append([
                "charger",
                date(charger.value(forKey: "createdAt")),
                "",
                "\(name); \(brand)"
            ])
        }

        for session in sessions {
            let batteryID = session.value(forKey: "batteryID") as? UUID
            let batteryName = batteryID.flatMap { names[$0] } ?? ""
            let flagObjects = session.value(forKey: "riskFlags") as? Set<NSManagedObject> ?? []
            let flags = flagObjects
                .compactMap { $0.value(forKey: "message") as? String }
                .sorted()
                .joined(separator: " | ")
            let place = session.value(forKey: "place") as? String ?? ""
            let minutes = session.value(forKey: "plannedDurationMinutes") as? Int32 ?? 0
            let status = session.value(forKey: "status") as? String ?? ""
            let risk = session.value(forKey: "riskLevel") as? String ?? "none"
            var parts: [String] = ["place: \(place)", "planned: \(minutes) min", "status: \(status)", "risk: \(risk)"]
            if session.value(forKey: "overnight") as? Bool == true { parts.append("overnight") }
            if !flags.isEmpty { parts.append("flags: \(flags)") }
            rows.append([
                "charge",
                date(session.value(forKey: "startedAt")),
                batteryName,
                parts.joined(separator: "; ")
            ])
        }

        for inspection in inspections {
            let batteryID = inspection.value(forKey: "batteryID") as? UUID
            let batteryName = batteryID.flatMap { names[$0] } ?? ""
            let items = inspection.value(forKey: "items") as? Set<NSManagedObject> ?? []
            let problems = items
                .filter { $0.value(forKey: "isProblem") as? Bool == true }
                .compactMap { $0.value(forKey: "kind") as? String }
                .sorted()
            let photoCount = (inspection.value(forKey: "photos") as? Set<NSManagedObject>)?.count ?? 0
            let result = inspection.value(forKey: "result") as? String ?? ""
            let source = inspection.value(forKey: "source") as? String ?? ""
            var parts: [String] = ["result: \(result)", "source: \(source)", "photos: \(photoCount)"]
            if !problems.isEmpty { parts.append("problems: \(problems.joined(separator: ", "))") }
            rows.append([
                "inspection",
                date(inspection.value(forKey: "inspectedAt")),
                batteryName,
                parts.joined(separator: "; ")
            ])
        }

        return rows.map { $0.map(Self.csvField).joined(separator: ",") }.joined(separator: "\n") + "\n"
    }

    private static func sort(_ key: String, _ ascending: Bool) -> NSSortDescriptor {
        NSSortDescriptor(key: key, ascending: ascending)
    }

    /// Quotes a field when needed. A leading = + - or @ is neutralised so a spreadsheet never runs it as a formula.
    private static func csvField(_ raw: String) -> String {
        var value = raw
        if let first = value.first, "=+-@".contains(first) { value = "'" + value }
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: Delete

    func deleteAllRecords() async throws {
        let context = persistence.viewContext

        let sessionIDs = try context.fetchObjects(entity: CDEntity.chargeSession)
            .compactMap { $0.value(forKey: "id") as? UUID }

        do {
            for entity in CDEntity.all {
                for object in try context.fetchObjects(entity: entity) {
                    context.delete(object)
                }
            }
            try context.commit()
        } catch {
            context.rollback()
            throw error
        }

        let directory = try photoDirectory ?? LocalInspectionPhotoStore.defaultDirectory()
        if FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.removeItem(at: directory)
        }

        await onDeleted(sessionIDs)
    }
}
