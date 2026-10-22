import Foundation

extension GarageRepository {
    /// The battery, or nil when it does not exist.
    func findBattery(id: UUID) async -> Battery? {
        try? await battery(id: id)
    }

    /// The charger, or nil when it does not exist.
    func findCharger(id: UUID) async -> Charger? {
        try? await charger(id: id)
    }
}
