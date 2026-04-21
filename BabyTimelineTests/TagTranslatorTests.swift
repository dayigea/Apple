import XCTest
@testable import BabyTimeline

final class TagTranslatorTests: XCTestCase {

    func testKnownTranslations() {
        XCTAssertEqual(TagTranslator.translate("dog"), "狗")
        XCTAssertEqual(TagTranslator.translate("cake"), "蛋糕")
        XCTAssertEqual(TagTranslator.translate("beach"), "海滩")
        XCTAssertEqual(TagTranslator.translate("walking"), "走路")
        XCTAssertEqual(TagTranslator.translate("piano"), "钢琴")
        XCTAssertEqual(TagTranslator.translate("rainbow"), "彩虹")
        XCTAssertEqual(TagTranslator.translate("panda"), "熊猫")
        XCTAssertEqual(TagTranslator.translate("strawberry"), "草莓")
    }

    func testUnknownReturnsNil() {
        XCTAssertNil(TagTranslator.translate("xyzzy_not_a_real_tag"))
        XCTAssertNil(TagTranslator.translate(""))
    }

    func testAllChineseTagsNotEmpty() {
        let all = TagTranslator.allChineseTags()
        XCTAssertTrue(all.count > 100, "Should have 100+ unique Chinese tags, got \(all.count)")
    }

    func testNoDuplicateValues() {
        // Multiple English keys can map to the same Chinese value (e.g. "ocean" → "海"),
        // but allChineseTags() should still include all unique values.
        let all = TagTranslator.allChineseTags()
        XCTAssertTrue(all.contains("海"))
        XCTAssertTrue(all.contains("海滩"))
        XCTAssertTrue(all.contains("海边"))
    }

    func testNewlyAddedCategories() {
        // Verify a sampling of newly added tags from each category
        XCTAssertEqual(TagTranslator.translate("elephant"), "大象")
        XCTAssertEqual(TagTranslator.translate("butterfly"), "蝴蝶")
        XCTAssertEqual(TagTranslator.translate("waterfall"), "瀑布")
        XCTAssertEqual(TagTranslator.translate("dancing"), "跳舞")
        XCTAssertEqual(TagTranslator.translate("guitar"), "吉他")
        XCTAssertEqual(TagTranslator.translate("fireworks"), "烟花")
        XCTAssertEqual(TagTranslator.translate("sushi"), "寿司")
        XCTAssertEqual(TagTranslator.translate("umbrella"), "伞")
    }
}
