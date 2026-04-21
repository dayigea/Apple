import XCTest
@testable import BabyTimeline

final class ContinuationGateTests: XCTestCase {

    func testFirstOpenReturnsTrue() {
        let gate = ContinuationGate()
        XCTAssertTrue(gate.open())
    }

    func testSecondOpenReturnsFalse() {
        let gate = ContinuationGate()
        _ = gate.open()
        XCTAssertFalse(gate.open())
    }

    func testThirdOpenReturnsFalse() {
        let gate = ContinuationGate()
        _ = gate.open()
        _ = gate.open()
        XCTAssertFalse(gate.open())
    }

    func testConcurrentAccess() async {
        let gate = ContinuationGate()
        let iterations = 1000

        let trueCount = await withTaskGroup(of: Bool.self, returning: Int.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    gate.open()
                }
            }
            var count = 0
            for await result in group {
                if result { count += 1 }
            }
            return count
        }

        XCTAssertEqual(trueCount, 1, "Exactly one concurrent caller should get true")
    }
}
