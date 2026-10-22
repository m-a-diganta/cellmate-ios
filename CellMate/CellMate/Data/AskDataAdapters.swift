import Foundation

/// Lets Ask list the batteries from the Garage.
@MainActor
struct GarageAskBatteryProvider: AskBatteryProviding {
    let garage: any GarageRepository

    func batteries() async throws -> [AskBattery] {
        try await garage.fetchBatteries().map { battery in
            AskBattery(
                id: battery.id,
                name: battery.name,
                brand: battery.brand,
                isRetired: battery.isRetired
            )
        }
    }
}

/// Saves an Ask result as an inspection with the source "assistant".
/// It records the concern only. It never marks a physical check as OK, and an
/// Ask result is never saved as a pass, so it can't reset the monthly check.
@MainActor
struct InspectionAskLogger: AskInspectionLogging {
    let inspections: any InspectionRepository

    func log(_ assessment: BatteryAssessment, for batteryID: UUID) async throws {
        let inspection = Inspection(
            id: assessment.id,
            batteryID: batteryID,
            inspectedAt: assessment.date,
            source: .assistant,
            result: Self.result(for: assessment.level),
            items: Self.items(for: assessment.symptoms)
        )
        do {
            try await inspections.addInspection(inspection)
        } catch InspectionRepositoryError.duplicateInspectionID {
            // The same assessment was already saved. Saving it twice changes nothing.
        }
    }

    /// Stop using and Emergency are a fail. Everything else is a caution, never a pass.
    static func result(for level: BatteryAdviceLevel) -> Inspection.Result {
        switch level {
        case .emergency, .stopUsing: .fail
        case .caution, .info: .caution
        }
    }

    /// One problem item for each of the five checks the symptoms point to.
    static func items(for symptoms: Set<BatterySymptom>) -> [Inspection.Item] {
        var noticed: [Inspection.Item.Kind: BatterySymptom] = [:]
        for symptom in symptoms.sorted(by: { $0.rawValue < $1.rawValue }) {
            guard let kind = kind(for: symptom), noticed[kind] == nil else { continue }
            noticed[kind] = symptom
        }
        return Inspection.Item.Kind.allCases.compactMap { kind in
            noticed[kind].map { Inspection.Item(kind: kind, finding: .problem, note: $0.title) }
        }
    }

    private static func kind(for symptom: BatterySymptom) -> Inspection.Item.Kind? {
        switch symptom {
        case .swelling: .swelling
        case .excessiveHeat, .smokeOrFlames: .heat
        case .unusualSmell: .smell
        case .physicalDamage, .leaking, .hissingOrPopping: .damage
        case .chargerConcern: .charger
        case .unsafeCharging, .unknown: nil
        }
    }
}
