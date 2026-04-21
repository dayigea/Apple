import XCTest
@testable import BabyTimeline

final class AgeCalculatorTests: XCTestCase {

    private func date(_ str: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.timeZone = TimeZone(identifier: "Asia/Shanghai")
        return df.date(from: str)!
    }

    // MARK: - age()

    func testNewborn() {
        let age = AgeCalculator.age(birthday: date("2024-01-01"), at: date("2024-01-05"))
        XCTAssertEqual(age.years, 0)
        XCTAssertEqual(age.months, 0)
        XCTAssertEqual(age.days, 4)
        XCTAssertEqual(age.localized, "出生 4 天")
    }

    func testThreeMonths() {
        let age = AgeCalculator.age(birthday: date("2024-01-15"), at: date("2024-04-15"))
        XCTAssertEqual(age.years, 0)
        XCTAssertEqual(age.months, 3)
        XCTAssertEqual(age.totalMonths, 3)
        XCTAssertEqual(age.localized, "3 个月")
    }

    func testOneYearTwoMonths() {
        let age = AgeCalculator.age(birthday: date("2023-01-01"), at: date("2024-03-01"))
        XCTAssertEqual(age.years, 1)
        XCTAssertEqual(age.months, 2)
        XCTAssertEqual(age.totalMonths, 14)
        XCTAssertEqual(age.localized, "1 岁 2 个月")
    }

    func testExactlyOneYear() {
        let age = AgeCalculator.age(birthday: date("2023-06-15"), at: date("2024-06-15"))
        XCTAssertEqual(age.years, 1)
        XCTAssertEqual(age.months, 0)
        XCTAssertEqual(age.localized, "1 岁")
    }

    func testSameDay() {
        let age = AgeCalculator.age(birthday: date("2024-01-01"), at: date("2024-01-01"))
        XCTAssertEqual(age.years, 0)
        XCTAssertEqual(age.months, 0)
        XCTAssertEqual(age.days, 0)
        XCTAssertEqual(age.localized, "出生 0 天")
    }

    // MARK: - stage()

    func testStageNewborn() {
        let stage = AgeCalculator.stage(birthday: date("2024-01-01"), at: date("2024-01-20"))
        XCTAssertEqual(stage.title, "新生儿（0–1 个月）")
        XCTAssertEqual(stage.sortKey, 0)
    }

    func testStageOneToThreeMonths() {
        let stage = AgeCalculator.stage(birthday: date("2024-01-01"), at: date("2024-03-01"))
        XCTAssertEqual(stage.title, "1–3 个月")
    }

    func testStageSixToTwelveMonths() {
        let stage = AgeCalculator.stage(birthday: date("2024-01-01"), at: date("2024-09-01"))
        XCTAssertEqual(stage.title, "6–12 个月")
    }

    func testStageOneToOneAndHalf() {
        let stage = AgeCalculator.stage(birthday: date("2023-01-01"), at: date("2024-04-01"))
        XCTAssertEqual(stage.title, "1 岁 – 1 岁半")
    }

    func testStageTwoYears() {
        let stage = AgeCalculator.stage(birthday: date("2022-01-01"), at: date("2024-06-01"))
        XCTAssertEqual(stage.title, "2 岁 – 3 岁")
    }
}
