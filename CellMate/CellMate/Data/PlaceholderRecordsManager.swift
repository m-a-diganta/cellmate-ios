import Foundation

/// Stand-in until the Core Data version exists.
/// Export writes a CSV with only a header. Delete does nothing yet.
struct PlaceholderRecordsManager: RecordsManaging {
    func exportRecords() async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("CellMate-records.csv")
        try "type,date,battery,details\n".write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    func deleteAllRecords() async throws {}
}
