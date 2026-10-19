import Foundation
import Observation

@Observable
final class SettingsViewModel {
    struct ExportFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    var exportFile: ExportFile?
    var errorMessage: String?
    private(set) var isWorking = false

    private let records: any RecordsManaging

    init(records: any RecordsManaging) {
        self.records = records
    }

    func export() async {
        isWorking = true
        defer { isWorking = false }
        do {
            exportFile = ExportFile(url: try await records.exportRecords())
        } catch {
            errorMessage = "Couldn't export your records. Try again."
        }
    }

    /// Returns true when everything was deleted.
    func deleteAll() async -> Bool {
        isWorking = true
        defer { isWorking = false }
        do {
            try await records.deleteAllRecords()
            return true
        } catch {
            errorMessage = "Couldn't delete your records. Try again."
            return false
        }
    }
}
