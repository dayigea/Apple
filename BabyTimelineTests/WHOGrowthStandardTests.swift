import XCTest
@testable import BabyTimeline

final class WHOGrowthStandardTests: XCTestCase {

    // MARK: - 数据完整性

    func testHeightDataCoversZeroToThirtySix() {
        let data = WHOGrowthStandard.girlHeightCM
        XCTAssertEqual(data.first?.monthAge, 0)
        XCTAssertEqual(data.last?.monthAge, 36)
        XCTAssertTrue(data.count >= 15, "Should have enough data points")
    }

    func testWeightDataCoversZeroToThirtySix() {
        let data = WHOGrowthStandard.girlWeightKG
        XCTAssertEqual(data.first?.monthAge, 0)
        XCTAssertEqual(data.last?.monthAge, 36)
    }

    func testHeadCircDataCoversZeroToThirtySix() {
        let data = WHOGrowthStandard.girlHeadCM
        XCTAssertEqual(data.first?.monthAge, 0)
        XCTAssertEqual(data.last?.monthAge, 36)
    }

    // MARK: - 百分位顺序

    func testPercentilesAreOrdered() {
        for dataset in [
            WHOGrowthStandard.girlHeightCM,
            WHOGrowthStandard.girlWeightKG,
            WHOGrowthStandard.girlHeadCM,
        ] {
            for p in dataset {
                XCTAssertLessThan(p.p3, p.p15, "P3 < P15 at month \(p.monthAge)")
                XCTAssertLessThan(p.p15, p.p50, "P15 < P50 at month \(p.monthAge)")
                XCTAssertLessThan(p.p50, p.p85, "P50 < P85 at month \(p.monthAge)")
                XCTAssertLessThan(p.p85, p.p97, "P85 < P97 at month \(p.monthAge)")
            }
        }
    }

    // MARK: - 百分位值单调递增（随月龄增长应该增大）

    func testHeightMonotonicallyIncreasing() {
        let data = WHOGrowthStandard.girlHeightCM
        for i in 1..<data.count {
            XCTAssertGreaterThanOrEqual(data[i].p50, data[i - 1].p50,
                "Height P50 should not decrease: month \(data[i].monthAge)")
        }
    }

    func testWeightMonotonicallyIncreasing() {
        let data = WHOGrowthStandard.girlWeightKG
        for i in 1..<data.count {
            XCTAssertGreaterThanOrEqual(data[i].p50, data[i - 1].p50,
                "Weight P50 should not decrease: month \(data[i].monthAge)")
        }
    }

    func testHeadCircMonotonicallyIncreasing() {
        let data = WHOGrowthStandard.girlHeadCM
        for i in 1..<data.count {
            XCTAssertGreaterThanOrEqual(data[i].p50, data[i - 1].p50,
                "Head circumference P50 should not decrease: month \(data[i].monthAge)")
        }
    }

    // MARK: - 合理范围检查

    func testNewbornHeightRange() {
        let birth = WHOGrowthStandard.girlHeightCM.first!
        XCTAssertTrue(birth.p50 > 45 && birth.p50 < 55, "Newborn P50 height should be ~49 cm")
    }

    func testNewbornWeightRange() {
        let birth = WHOGrowthStandard.girlWeightKG.first!
        XCTAssertTrue(birth.p50 > 2.5 && birth.p50 < 4.0, "Newborn P50 weight should be ~3.2 kg")
    }

    func testNewbornHeadRange() {
        let birth = WHOGrowthStandard.girlHeadCM.first!
        XCTAssertTrue(birth.p50 > 32 && birth.p50 < 36, "Newborn P50 head should be ~34 cm")
    }

    func testOneYearHeightRange() {
        let oneYear = WHOGrowthStandard.girlHeightCM.first(where: { $0.monthAge == 12 })!
        XCTAssertTrue(oneYear.p50 > 70 && oneYear.p50 < 80, "1-year P50 height should be ~74 cm")
    }

    func testOneYearWeightRange() {
        let oneYear = WHOGrowthStandard.girlWeightKG.first(where: { $0.monthAge == 12 })!
        XCTAssertTrue(oneYear.p50 > 7 && oneYear.p50 < 11, "1-year P50 weight should be ~9 kg")
    }
}
