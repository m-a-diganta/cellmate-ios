import XCTest
@testable import CellMate

@MainActor
final class PermissionsViewModelTests: XCTestCase {

    func testLoadReadsCurrentStatuses() async {
        let model = PermissionsViewModel(permissions: MockPermissionService(notifications: .granted, camera: .denied))
        await model.load()
        XCTAssertEqual(model.notifications, .granted)
        XCTAssertEqual(model.camera, .denied)
    }

    func testContinueAsksForNotificationsTheFirstTime() async {
        let mock = MockPermissionService()
        let model = PermissionsViewModel(permissions: mock)
        await model.load()
        await model.continueTapped()
        XCTAssertEqual(mock.notificationRequests, 1)
        XCTAssertEqual(model.notifications, .granted)
    }

    func testContinueDoesNotAskAgainOnceAnswered() async {
        let mock = MockPermissionService(notifications: .denied)
        let model = PermissionsViewModel(permissions: mock)
        await model.load()
        await model.continueTapped()
        XCTAssertEqual(mock.notificationRequests, 0)
        XCTAssertEqual(model.notifications, .denied)
    }

    func testContinueNeverAsksForTheOptionalCamera() async {
        let mock = MockPermissionService()
        let model = PermissionsViewModel(permissions: mock)
        await model.load()
        await model.continueTapped()
        XCTAssertEqual(mock.cameraRequests, 0)
        XCTAssertEqual(model.camera, .notDetermined)
    }

    func testDontAllowLeavesCameraDenied() async {
        let model = PermissionsViewModel(permissions: MockPermissionService(answer: .denied))
        await model.load()
        await model.allowCamera()
        XCTAssertEqual(model.camera, .denied)
    }
}
