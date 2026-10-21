import XCTest
@testable import CellMate

@MainActor
final class AssessBatteryProblemTests: XCTestCase {
    func testEmptyDescriptionIsRejected() async {
        do {
            _ = try await AssessBatteryProblem(assistant: AssistantStub())(text: " \n", selected: [])
            XCTFail("Empty input must not produce advice")
        } catch { XCTAssertTrue(error is BatteryProblemError) }
    }

    func testOverlongDescriptionIsRejectedBeforeCallingAI() async {
        let assistant = AssistantStub()
        do {
            _ = try await AssessBatteryProblem(assistant: assistant)(text: String(repeating: "a", count: 1_001), selected: [])
            XCTFail("Input limit must be enforced")
        } catch { XCTAssertEqual(assistant.calls, 0) }
    }

    func testSmokeGivesEmergencyImmediatelyWithoutAI() async throws {
        let assistant = AssistantStub()
        let result = try await AssessBatteryProblem(assistant: assistant)(text: "My battery is smoking", selected: [])
        XCTAssertEqual(result.level, .emergency)
        XCTAssertEqual(assistant.calls, 0)
        XCTAssertFalse(result.needsQuickCheck)
    }

    func testChineseWarningAlsoHasAnImmediateSafetyFloor() async throws {
        let result = try await AssessBatteryProblem(assistant: AssistantStub())(text: "电池正在冒烟", selected: [])
        XCTAssertEqual(result.level, .emergency)
    }

    func testPhotoDoesNotMatchHotAndFumesAreUrgent() {
        XCTAssertFalse(BatteryProblemRules.mentionedSymptoms(in: "Can I add a photo?").contains(.excessiveHeat))
        XCTAssertTrue(BatteryProblemRules.mentionedSymptoms(in: "It is producing fumes").contains(.smokeOrFlames))
    }

    func testAIOnlyAddsToSelectedConcerns() async throws {
        let assistant = AssistantStub(output: [.excessiveHeat])
        let result = try await AssessBatteryProblem(assistant: assistant)(text: "It feels different", selected: [.unsafeCharging])
        XCTAssertEqual(result.level, .stopUsing)
        XCTAssertEqual(result.symptoms, [.unsafeCharging, .excessiveHeat])
    }

    func testAIEmptyResponseCannotClearConcern() async throws {
        let result = try await AssessBatteryProblem(assistant: AssistantStub(output: []))(text: "I charge overnight", selected: [])
        XCTAssertEqual(result.level, .caution)
        XCTAssertTrue(result.symptoms.contains(.unsafeCharging))
        XCTAssertTrue(result.needsQuickCheck)
    }

    func testUnavailableAndFailedModelBothRequireQuickCheck() async throws {
        for assistant in [AssistantStub(availability: .unavailable("Unavailable")), AssistantStub(shouldFail: true)] {
            let result = try await AssessBatteryProblem(assistant: assistant)(text: "It seems different", selected: [])
            XCTAssertTrue(result.needsQuickCheck)
            XCTAssertEqual(result.level, .caution)
            XCTAssertTrue(result.symptoms.contains(.unknown))
        }
    }

    func testCancellationDoesNotTurnIntoGuidance() async {
        do {
            _ = try await AssessBatteryProblem(assistant: AssistantStub(cancel: true))(text: "Question", selected: [])
            XCTFail("Cancelled work must not publish a result")
        } catch { XCTAssertTrue(error is CancellationError) }
    }

    func testRetiredBatteryCannotReceiveInfoAdvice() async throws {
        let battery = AskBattery(id: UUID(), name: "Old battery", brand: "Brand", isRetired: true)
        let assistant = AssistantStub()
        let result = try await AssessBatteryProblem(assistant: assistant)(text: "Can I charge?", selected: [], battery: battery)
        XCTAssertEqual(result.level, .stopUsing)
        XCTAssertEqual(result.batteryID, battery.id)
        XCTAssertEqual(assistant.calls, 0)
    }

    func testEachWarningHasTheExpectedMinimumLevel() {
        for symptom in BatterySymptom.allCases {
            let expected: BatteryAdviceLevel
            switch symptom {
            case .smokeOrFlames, .hissingOrPopping: expected = .emergency
            case .unsafeCharging, .unknown: expected = .caution
            default: expected = .stopUsing
            }
            XCTAssertEqual(BatteryProblemRules.level(for: [symptom]), expected, symptom.rawValue)
        }
    }

    func testQuickCheckRequiresAnExplicitAnswer() {
        XCTAssertThrowsError(try AssessBatteryProblem(assistant: AssistantStub()).quickCheck(selected: [], noneNoticed: false))
    }

    func testNoSignsNeverClaimsBatteryIsSafe() throws {
        let result = try AssessBatteryProblem(assistant: AssistantStub()).quickCheck(selected: [], noneNoticed: true)
        XCTAssertEqual(result.level, .info)
        XCTAssertTrue(BatteryProblemRules.steps(for: result.level)[0].contains("does not confirm"))
    }

    func testQuickCheckCannotLowerAnEarlierWarning() async throws {
        let useCase = AssessBatteryProblem(assistant: AssistantStub())
        let prior = try await useCase(text: "", selected: [.swelling])
        let result = try useCase.quickCheck(selected: [], noneNoticed: true, prior: prior)
        XCTAssertEqual(result.level, .stopUsing)
        XCTAssertTrue(result.symptoms.contains(.swelling))
    }

    func testBatteryToolCannotReadAnotherBattery() async throws {
        let battery = AskBattery(id: UUID(), name: "My battery", brand: "Brand", isRetired: false)
        let tool = BatteryLookupTool(battery: battery)
        let missing = try await tool.call(arguments: .init(batteryID: UUID().uuidString))
        XCTAssertEqual(missing, "No matching selected battery record.")
        let found = try await tool.call(arguments: .init(batteryID: battery.id.uuidString))
        XCTAssertTrue(found.contains("My battery"))
    }
}

@MainActor
final class AskViewModelTests: XCTestCase {
    func testMultipleBatteriesRequireSelectionBeforeSave() async {
        let records = AskRecordsStub(count: 2)
        let model = makeModel(records)
        await model.refresh()
        model.openQuickCheck()
        model.checkSymptoms = [.swelling]
        model.finishQuickCheck()
        await model.requestSave()
        XCTAssertTrue(model.showBatteryPicker)
        XCTAssertTrue(records.loggedIDs.isEmpty)
        await model.save(for: records.items[1].id)
        XCTAssertTrue(model.saved)
        XCTAssertEqual(records.loggedIDs, [records.items[1].id])
        await model.requestSave()
        XCTAssertEqual(records.loggedIDs.count, 1, "Repeated taps must not duplicate a saved inspection")
    }

    func testSaveFailureNeverShowsSavedState() async {
        let records = AskRecordsStub(count: 1, failSaving: true)
        let model = makeModel(records)
        await model.refresh()
        model.openQuickCheck()
        model.checkSymptoms = [.unusualSmell]
        model.finishQuickCheck()
        await model.requestSave()
        XCTAssertFalse(model.saved)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertFalse(model.isSaving)
    }

    func testResultKeepsTheOriginallySelectedBattery() async {
        let records = AskRecordsStub(count: 2)
        let model = makeModel(records)
        await model.refresh()
        model.selectedBatteryID = records.items[0].id
        model.openQuickCheck()
        model.checkSymptoms = [.swelling]
        model.finishQuickCheck()
        model.selectedBatteryID = records.items[1].id
        await model.requestSave()
        XCTAssertEqual(records.loggedIDs, [records.items[0].id])
    }

    func testNoBatteryDoesNotInventASavedInspection() async {
        let records = AskRecordsStub(count: 0)
        let model = makeModel(records)
        await model.refresh()
        model.openQuickCheck()
        model.noneNoticed = true
        model.finishQuickCheck()
        await model.requestSave()
        XCTAssertFalse(model.saved)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertTrue(records.loggedIDs.isEmpty)
    }

    func testChoosingRetiredBatteryAtSaveRaisesAdvice() async {
        let records = AskRecordsStub(count: 2, retired: true)
        let model = makeModel(records)
        await model.refresh()
        model.openQuickCheck()
        model.noneNoticed = true
        model.finishQuickCheck()
        XCTAssertEqual(model.assessment?.level, .info)
        await model.save(for: records.items[0].id)
        XCTAssertEqual(model.assessment?.level, .stopUsing)
        XCTAssertEqual(records.loggedAssessments.first?.level, .stopUsing)
        XCTAssertEqual(records.loggedAssessments.first?.batteryID, records.items[0].id)
    }

    private func makeModel(_ records: AskRecordsStub) -> AskViewModel {
        AskViewModel(dependencies: AskDependencies(assistant: AssistantStub(), batteries: records, inspections: records))
    }
}

@MainActor
private final class AssistantStub: BatteryAssistant {
    let availability: BatteryAssistantAvailability
    let output: Set<BatterySymptom>
    let shouldFail: Bool
    let cancel: Bool
    var calls = 0

    init(availability: BatteryAssistantAvailability = .available, output: Set<BatterySymptom> = [.unknown],
         shouldFail: Bool = false, cancel: Bool = false) {
        self.availability = availability
        self.output = output
        self.shouldFail = shouldFail
        self.cancel = cancel
    }

    func classify(_ text: String, battery: AskBattery?) async throws -> Set<BatterySymptom> {
        calls += 1
        if cancel { throw CancellationError() }
        if shouldFail { throw BatteryProblemError.integrationUnavailable }
        return output
    }
}

@MainActor
private final class AskRecordsStub: AskBatteryProviding, AskInspectionLogging {
    let items: [AskBattery]
    let failSaving: Bool
    var loggedIDs: [UUID] = []
    var loggedAssessments: [BatteryAssessment] = []

    init(count: Int, failSaving: Bool = false, retired: Bool = false) {
        items = (0..<count).map { AskBattery(id: UUID(), name: "Battery \($0)", brand: "Test", isRetired: retired) }
        self.failSaving = failSaving
    }
    func batteries() async throws -> [AskBattery] { items }
    func log(_ assessment: BatteryAssessment, for batteryID: UUID) async throws {
        if failSaving { throw BatteryProblemError.integrationUnavailable }
        loggedIDs.append(batteryID)
        loggedAssessments.append(assessment)
    }
}
