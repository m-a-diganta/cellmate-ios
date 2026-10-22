import Foundation

/// Storage for charge sessions. The in-memory version is used until Core Data replaces it.
@MainActor
protocol ChargeRepository: AnyObject {
    /// Saves a new session (Start charge).
    func save(_ session: ChargeSession)
    /// Updates an existing session (end, extend, risk re-evaluation).
    func update(_ session: ChargeSession)
    /// The session currently running for a battery, if any.
    func runningSession(forBatteryID batteryID: UUID) -> ChargeSession?
    /// Any session currently running. Only one charge runs at a time.
    func anyRunningSession() -> ChargeSession?
    func session(withID id: UUID) -> ChargeSession?
    /// All sessions, newest first.
    func allSessions() -> [ChargeSession]
    /// Sessions for one battery, newest first.
    func sessions(forBatteryID batteryID: UUID) -> [ChargeSession]
}
