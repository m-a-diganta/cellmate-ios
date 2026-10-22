import Foundation

/// Inject Person 1's battery repository projection and Person 4's LogInspection adapter here.
/// Until those land on main, fail explicitly instead of inventing records or successful saves.
@MainActor
struct AskDependencies {
    let assistant: any BatteryAssistant
    let batteries: any AskBatteryProviding
    let inspections: any AskInspectionLogging

    static func pendingIntegration() -> Self {
        Self(assistant: FoundationBatteryAssistant(), batteries: PendingAskRecords(), inspections: PendingAskRecords())
    }
}

@MainActor
private struct PendingAskRecords: AskBatteryProviding, AskInspectionLogging {
    func batteries() async throws -> [AskBattery] { [] }
    func log(_ assessment: BatteryAssessment, for batteryID: UUID) async throws {
        throw BatteryProblemError.integrationUnavailable
    }
}
