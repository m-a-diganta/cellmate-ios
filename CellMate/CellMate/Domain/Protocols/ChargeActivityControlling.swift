import Foundation

enum ChargeActivityError: Error, Equatable {
    /// Live Activities are turned off in Settings. Notifications still cover every alert.
    case turnedOff
    case couldNotStart
}

/// Starts, moves and ends the Lock Screen / Dynamic Island countdown for a charge.
protocol ChargeActivityControlling {
    func start(batteryName: String, startedAt: Date, unplugAt: Date) throws
    func update(unplugAt: Date) async
    func end() async
}
