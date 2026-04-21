import XCTest
@testable import BabyTimeline

final class MilestonePhotoMatcherTests: XCTestCase {

    private func date(_ str: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return df.date(from: str)!
    }

    private func makeEntry(id: String, date: Date, tags: [String] = []) -> PhotoEntry {
        PhotoEntry(assetLocalId: id, creationDate: date, autoTags: tags)
    }

    // MARK: - bestMatch

    func testClosestByDateWhenNoKeywords() {
        let photos = [
            makeEntry(id: "a", date: date("2024-03-01")),
            makeEntry(id: "b", date: date("2024-03-10")),
            makeEntry(id: "c", date: date("2024-03-20")),
        ]
        let match = MilestonePhotoMatcher.bestMatch(for: date("2024-03-11"), in: photos)
        XCTAssertEqual(match?.assetLocalId, "b")
    }

    func testKeywordMatchTakesPriority() {
        let photos = [
            makeEntry(id: "close_no_tag", date: date("2024-03-10")),
            makeEntry(id: "far_with_tag", date: date("2024-06-01"), tags: ["蛋糕"]),
        ]
        let match = MilestonePhotoMatcher.bestMatch(
            for: date("2024-03-11"),
            in: photos,
            preferringKeywords: ["蛋糕"]
        )
        XCTAssertEqual(match?.assetLocalId, "far_with_tag")
    }

    func testKeywordMatchFallsBackToDateWhenNoHit() {
        let photos = [
            makeEntry(id: "a", date: date("2024-03-01"), tags: ["狗"]),
            makeEntry(id: "b", date: date("2024-03-15"), tags: ["猫"]),
        ]
        let match = MilestonePhotoMatcher.bestMatch(
            for: date("2024-03-10"),
            in: photos,
            preferringKeywords: ["蛋糕"]
        )
        // No photo has "蛋糕" → fall back to date → "a" is closer to 3/10
        XCTAssertEqual(match?.assetLocalId, "a")
    }

    func testEmptyPhotos() {
        let match = MilestonePhotoMatcher.bestMatch(for: date("2024-03-10"), in: [])
        XCTAssertNil(match)
    }

    // MARK: - hasKeywordMatch

    func testHasKeywordMatchTrue() {
        let entry = makeEntry(id: "x", date: date("2024-01-01"), tags: ["狗", "公园"])
        XCTAssertTrue(MilestonePhotoMatcher.hasKeywordMatch(entry, keywords: ["公园"]))
    }

    func testHasKeywordMatchFalse() {
        let entry = makeEntry(id: "x", date: date("2024-01-01"), tags: ["狗", "公园"])
        XCTAssertFalse(MilestonePhotoMatcher.hasKeywordMatch(entry, keywords: ["蛋糕"]))
    }

    func testHasKeywordMatchEmptyKeywords() {
        let entry = makeEntry(id: "x", date: date("2024-01-01"), tags: ["狗"])
        XCTAssertFalse(MilestonePhotoMatcher.hasKeywordMatch(entry, keywords: []))
    }

    // MARK: - dayDiff

    func testDayDiffSameDay() {
        let entry = makeEntry(id: "x", date: date("2024-03-10"))
        XCTAssertEqual(MilestonePhotoMatcher.dayDiff(matchedPhoto: entry, targetDate: date("2024-03-10")), 0)
    }

    func testDayDiffFiveDays() {
        let entry = makeEntry(id: "x", date: date("2024-03-15"))
        XCTAssertEqual(MilestonePhotoMatcher.dayDiff(matchedPhoto: entry, targetDate: date("2024-03-10")), 5)
    }
}
