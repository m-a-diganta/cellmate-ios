import Foundation

/// Keeps charge sessions in memory until the Core Data version replaces it.
/// Sessions are lost when the app closes.
@MainActor
final class InMemoryChargeRepository: ChargeRepository {
    private var sessions: [UUID: ChargeSession]

    init(sessions: [ChargeSession] = []) {
        self.sessions = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
    }

    func save(_ session: ChargeSession) { sessions[session.id] = session }

    func update(_ session: ChargeSession) { sessions[session.id] = session }

    func runningSession(forBatteryID batteryID: UUID) -> ChargeSession? {
        sessions.values.first { $0.batteryID == batteryID && $0.status == .running }
    }

    func anyRunningSession() -> ChargeSession? {
        sessions.values.first { $0.status == .running }
    }

    func session(withID id: UUID) -> ChargeSession? { sessions[id] }

    func allSessions() -> [ChargeSession] {
        sessions.values.sorted { $0.startedAt > $1.startedAt }
    }

    func sessions(forBatteryID batteryID: UUID) -> [ChargeSession] {
        allSessions().filter { $0.batteryID == batteryID }
    }
}
