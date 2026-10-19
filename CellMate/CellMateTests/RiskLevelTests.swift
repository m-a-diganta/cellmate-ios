import XCTest
@testable import CellMate

@MainActor
final class RiskLevelTests: XCTestCase {

    func testTitles() {
        XCTAssertEqual(RiskLevel.low.title, "Low risk")
        XCTAssertEqual(RiskLevel.medium.title, "Medium risk")
        XCTAssertEqual(RiskLevel.high.title, "High risk")
    }

    func testEveryLevelHasASymbol() {
        for level in RiskLevel.allCases {
            XCTAssertFalse(level.symbol.isEmpty, "\(level) has no symbol")
        }
    }

    func testRawValuesAreStable() {
        // These are saved with each charge. Changing them breaks old history.
        XCTAssertEqual(RiskLevel.allCases.map(\.rawValue), ["low", "medium", "high"])
    }
}
