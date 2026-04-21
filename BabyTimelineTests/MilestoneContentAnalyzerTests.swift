import XCTest
@testable import BabyTimeline

final class MilestoneContentAnalyzerTests: XCTestCase {

    // MARK: - inferredKeywords

    func testDirectSubstringMatch() {
        let kw = MilestoneContentAnalyzer.inferredKeywords(forTitle: "第一次去海边")
        XCTAssertTrue(kw.contains("海边"), "Should match '海边' from TagTranslator")
    }

    func testSynonymExpansion() {
        let kw = MilestoneContentAnalyzer.inferredKeywords(forTitle: "第一个生日")
        XCTAssertTrue(kw.contains("生日"))
        XCTAssertTrue(kw.contains("生日蛋糕"))
        XCTAssertTrue(kw.contains("蛋糕"))
        XCTAssertTrue(kw.contains("派对"))
    }

    func testRunSynonym() {
        let kw = MilestoneContentAnalyzer.inferredKeywords(forTitle: "第一次跑步")
        // "跑" synonym should expand to ["走路", "跑步"]
        XCTAssertTrue(kw.contains("走路") || kw.contains("跑步"))
    }

    func testRideSynonym() {
        let kw = MilestoneContentAnalyzer.inferredKeywords(forTitle: "第一次骑车")
        XCTAssertTrue(kw.contains("自行车"))
    }

    func testEmptyTitle() {
        XCTAssertTrue(MilestoneContentAnalyzer.inferredKeywords(forTitle: "").isEmpty)
        XCTAssertTrue(MilestoneContentAnalyzer.inferredKeywords(forTitle: "   ").isEmpty)
    }

    func testCustomTitle() {
        let kw = MilestoneContentAnalyzer.inferredKeywords(forTitle: "第一次看见狗")
        XCTAssertTrue(kw.contains("狗"))
    }

    func testFruitSynonym() {
        let kw = MilestoneContentAnalyzer.inferredKeywords(forTitle: "第一次吃水果")
        XCTAssertTrue(kw.contains("水果"))
        XCTAssertTrue(kw.contains("苹果"))
        XCTAssertTrue(kw.contains("草莓"))
    }
}
