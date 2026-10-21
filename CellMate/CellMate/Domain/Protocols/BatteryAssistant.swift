import Foundation

@MainActor
protocol BatteryAssistant {
    var availability: BatteryAssistantAvailability { get }
    func classify(_ text: String, battery: AskBattery?) async throws -> Set<BatterySymptom>
}

@MainActor
protocol AskBatteryProviding {
    func batteries() async throws -> [AskBattery]
}

/// Person 4 adapts this to LogInspection. Keep the assessment ID as an idempotency key.
/// This is a concern record, not an automatic pass of the five physical inspection checks.
@MainActor
protocol AskInspectionLogging {
    func log(_ assessment: BatteryAssessment, for batteryID: UUID) async throws
}
