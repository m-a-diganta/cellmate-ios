import Foundation

/// What Settings needs from the data layer.
protocol RecordsManaging {
    /// Writes every record to a file and returns where the file is.
    func exportRecords() async throws -> URL
    /// Deletes every battery, charge, inspection and photo.
    func deleteAllRecords() async throws
}
