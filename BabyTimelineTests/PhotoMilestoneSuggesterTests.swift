import XCTest
@testable import BabyTimeline

final class PhotoMilestoneSuggesterTests: XCTestCase {

    private func date(_ str: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return df.date(from: str)!
    }

    private func makeBaby() -> Baby {
        Baby(name: "测试", birthday: date("2024-01-01"))
    }

    private func makeEntry(id: String, date: Date, tags: [String]) -> PhotoEntry {
        PhotoEntry(assetLocalId: id, creationDate: date, autoTags: tags)
    }

    // MARK: - suggestions

    func testSnowTriggersMilestone() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "snow1", date: date("2024-12-20"), tags: ["雪", "户外"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let titles = suggestions.map(\.title)
        XCTAssertTrue(titles.contains("第一次见到雪"))
    }

    func testDogTriggersMilestone() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "dog1", date: date("2024-06-01"), tags: ["狗", "公园"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let titles = suggestions.map(\.title)
        XCTAssertTrue(titles.contains("第一次见到小狗"))
    }

    func testBeachTriggersSeaMilestone() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "sea1", date: date("2024-08-01"), tags: ["海滩"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let titles = suggestions.map(\.title)
        XCTAssertTrue(titles.contains("第一次去海边"))
    }

    func testAlreadyRecordedSkipped() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "snow1", date: date("2024-12-20"), tags: ["雪"]),
        ]
        let existing = [Milestone(title: "第一次见到雪", date: date("2024-12-20"))]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: existing)
        let titles = suggestions.map(\.title)
        XCTAssertFalse(titles.contains("第一次见到雪"))
    }

    func testFirstOccurrenceUsed() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "snow_late", date: date("2024-12-25"), tags: ["雪"]),
            makeEntry(id: "snow_early", date: date("2024-12-01"), tags: ["雪"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let snow = suggestions.first(where: { $0.title == "第一次见到雪" })
        XCTAssertEqual(snow?.assetLocalId, "snow_early")
    }

    func testEmptyPhotosNoSuggestions() {
        let baby = makeBaby()
        let suggestions = PhotoMilestoneSuggester.suggestions(from: [], baby: baby, existing: [])
        XCTAssertTrue(suggestions.isEmpty)
    }

    func testMultipleRulesFire() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "multi", date: date("2024-06-01"), tags: ["狗", "海滩", "蛋糕"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let titles = Set(suggestions.map(\.title))
        XCTAssertTrue(titles.contains("第一次见到小狗"))
        XCTAssertTrue(titles.contains("第一次去海边"))
        XCTAssertTrue(titles.contains("第一次吃蛋糕"))
    }

    // MARK: - grouped

    func testGroupedByCategory() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "a", date: date("2024-03-01"), tags: ["走路"]),
            makeEntry(id: "b", date: date("2024-06-01"), tags: ["海滩"]),
            makeEntry(id: "c", date: date("2024-09-01"), tags: ["狗"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let grouped = PhotoMilestoneSuggester.grouped(suggestions)
        let categories = grouped.map(\.category)
        XCTAssertTrue(categories.contains(.activity))
        XCTAssertTrue(categories.contains(.place))
        XCTAssertTrue(categories.contains(.nature))
    }

    // MARK: - new rules coverage

    func testNewActivityRules() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "d1", date: date("2024-03-01"), tags: ["跳舞"]),
            makeEntry(id: "d2", date: date("2024-04-01"), tags: ["画画"]),
            makeEntry(id: "d3", date: date("2024-05-01"), tags: ["钢琴"]),
            makeEntry(id: "d4", date: date("2024-06-01"), tags: ["露营"]),
            makeEntry(id: "d5", date: date("2024-07-01"), tags: ["风筝"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let titles = Set(suggestions.map(\.title))
        XCTAssertTrue(titles.contains("第一次跳舞"))
        XCTAssertTrue(titles.contains("第一次画画"))
        XCTAssertTrue(titles.contains("第一次��钢琴"))
        XCTAssertTrue(titles.contains("第一次露营"))
        XCTAssertTrue(titles.contains("第一次放风筝"))
    }

    func testNewAnimalRules() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "a1", date: date("2024-06-01"), tags: ["大象"]),
            makeEntry(id: "a2", date: date("2024-07-01"), tags: ["熊猫"]),
            makeEntry(id: "a3", date: date("2024-08-01"), tags: ["蝴蝶"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let titles = Set(suggestions.map(\.title))
        XCTAssertTrue(titles.contains("第一次见到大象"))
        XCTAssertTrue(titles.contains("第一次见到熊猫"))
        XCTAssertTrue(titles.contains("第一次见到蝴蝶"))
    }

    func testNewFoodRules() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "f1", date: date("2024-06-01"), tags: ["西瓜"]),
            makeEntry(id: "f2", date: date("2024-07-01"), tags: ["披萨"]),
            makeEntry(id: "f3", date: date("2024-08-01"), tags: ["饺子"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let titles = Set(suggestions.map(\.title))
        XCTAssertTrue(titles.contains("第一次吃西瓜"))
        XCTAssertTrue(titles.contains("第一次吃披萨"))
        XCTAssertTrue(titles.contains("第一次吃饺子"))
    }

    func testNewEventRules() {
        let baby = makeBaby()
        let photos = [
            makeEntry(id: "e1", date: date("2024-02-10"), tags: ["烟花"]),
            makeEntry(id: "e2", date: date("2024-09-15"), tags: ["灯笼"]),
        ]
        let suggestions = PhotoMilestoneSuggester.suggestions(from: photos, baby: baby, existing: [])
        let titles = Set(suggestions.map(\.title))
        XCTAssertTrue(titles.contains("第一次看烟花"))
        XCTAssertTrue(titles.contains("第一次提灯笼"))
    }
}
