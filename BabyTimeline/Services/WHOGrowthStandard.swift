import Foundation

/// WHO 女婴 0–36 个月生长标准百分位数据（简化版）。
/// 数据来源：WHO Child Growth Standards (2006)，只取 P3 / P15 / P50 / P85 / P97。
/// 用于在图表上画参考曲线，让家长直观看到宝宝在同龄女婴中的位置。
enum WHOGrowthStandard {

    struct Percentiles {
        let monthAge: Int
        let p3: Double
        let p15: Double
        let p50: Double
        let p85: Double
        let p97: Double
    }

    // MARK: - 女婴身高（cm），0–36 月龄

    static let girlHeightCM: [Percentiles] = [
        Percentiles(monthAge: 0,  p3: 45.4, p15: 47.0, p50: 49.1, p85: 51.0, p97: 52.9),
        Percentiles(monthAge: 1,  p3: 49.8, p15: 51.3, p50: 53.7, p85: 55.6, p97: 57.6),
        Percentiles(monthAge: 2,  p3: 53.0, p15: 54.6, p50: 57.1, p85: 59.1, p97: 61.1),
        Percentiles(monthAge: 3,  p3: 55.6, p15: 57.2, p50: 59.8, p85: 61.9, p97: 64.0),
        Percentiles(monthAge: 4,  p3: 57.8, p15: 59.5, p50: 62.1, p85: 64.3, p97: 66.4),
        Percentiles(monthAge: 5,  p3: 59.6, p15: 61.3, p50: 64.0, p85: 66.2, p97: 68.5),
        Percentiles(monthAge: 6,  p3: 61.2, p15: 62.9, p50: 65.7, p85: 68.0, p97: 70.3),
        Percentiles(monthAge: 7,  p3: 62.7, p15: 64.4, p50: 67.3, p85: 69.6, p97: 71.9),
        Percentiles(monthAge: 8,  p3: 64.0, p15: 65.7, p50: 68.7, p85: 71.1, p97: 73.5),
        Percentiles(monthAge: 9,  p3: 65.3, p15: 67.0, p50: 70.1, p85: 72.6, p97: 75.0),
        Percentiles(monthAge: 10, p3: 66.5, p15: 68.3, p50: 71.5, p85: 73.9, p97: 76.4),
        Percentiles(monthAge: 11, p3: 67.7, p15: 69.5, p50: 72.8, p85: 75.3, p97: 77.8),
        Percentiles(monthAge: 12, p3: 68.9, p15: 70.7, p50: 74.0, p85: 76.6, p97: 79.2),
        Percentiles(monthAge: 15, p3: 72.0, p15: 73.8, p50: 77.5, p85: 80.2, p97: 83.0),
        Percentiles(monthAge: 18, p3: 74.9, p15: 76.8, p50: 80.7, p85: 83.6, p97: 86.5),
        Percentiles(monthAge: 21, p3: 77.5, p15: 79.5, p50: 83.7, p85: 86.7, p97: 89.8),
        Percentiles(monthAge: 24, p3: 80.0, p15: 82.1, p50: 86.4, p85: 89.6, p97: 92.9),
        Percentiles(monthAge: 27, p3: 82.2, p15: 84.4, p50: 88.9, p85: 92.2, p97: 95.6),
        Percentiles(monthAge: 30, p3: 84.4, p15: 86.6, p50: 91.2, p85: 94.7, p97: 98.1),
        Percentiles(monthAge: 33, p3: 86.4, p15: 88.7, p50: 93.4, p85: 96.9, p97: 100.5),
        Percentiles(monthAge: 36, p3: 88.4, p15: 90.7, p50: 95.5, p85: 99.1, p97: 102.7),
    ]

    // MARK: - 女婴体重（kg），0–36 月龄

    static let girlWeightKG: [Percentiles] = [
        Percentiles(monthAge: 0,  p3: 2.4, p15: 2.8, p50: 3.2, p85: 3.7, p97: 4.2),
        Percentiles(monthAge: 1,  p3: 3.2, p15: 3.6, p50: 4.2, p85: 4.8, p97: 5.5),
        Percentiles(monthAge: 2,  p3: 3.9, p15: 4.5, p50: 5.1, p85: 5.8, p97: 6.6),
        Percentiles(monthAge: 3,  p3: 4.5, p15: 5.1, p50: 5.8, p85: 6.6, p97: 7.5),
        Percentiles(monthAge: 4,  p3: 5.0, p15: 5.6, p50: 6.4, p85: 7.3, p97: 8.2),
        Percentiles(monthAge: 5,  p3: 5.4, p15: 6.1, p50: 6.9, p85: 7.8, p97: 8.8),
        Percentiles(monthAge: 6,  p3: 5.7, p15: 6.4, p50: 7.3, p85: 8.2, p97: 9.3),
        Percentiles(monthAge: 7,  p3: 6.0, p15: 6.7, p50: 7.6, p85: 8.6, p97: 9.8),
        Percentiles(monthAge: 8,  p3: 6.3, p15: 7.0, p50: 7.9, p85: 9.0, p97: 10.2),
        Percentiles(monthAge: 9,  p3: 6.5, p15: 7.2, p50: 8.2, p85: 9.3, p97: 10.5),
        Percentiles(monthAge: 10, p3: 6.7, p15: 7.5, p50: 8.5, p85: 9.6, p97: 10.9),
        Percentiles(monthAge: 11, p3: 6.9, p15: 7.7, p50: 8.7, p85: 9.9, p97: 11.2),
        Percentiles(monthAge: 12, p3: 7.0, p15: 7.9, p50: 8.9, p85: 10.1, p97: 11.5),
        Percentiles(monthAge: 15, p3: 7.6, p15: 8.5, p50: 9.6, p85: 10.9, p97: 12.4),
        Percentiles(monthAge: 18, p3: 8.1, p15: 9.0, p50: 10.2, p85: 11.6, p97: 13.2),
        Percentiles(monthAge: 21, p3: 8.6, p15: 9.5, p50: 10.9, p85: 12.3, p97: 14.0),
        Percentiles(monthAge: 24, p3: 9.0, p15: 10.0, p50: 11.5, p85: 13.0, p97: 14.8),
        Percentiles(monthAge: 27, p3: 9.4, p15: 10.5, p50: 12.0, p85: 13.6, p97: 15.5),
        Percentiles(monthAge: 30, p3: 9.9, p15: 10.9, p50: 12.5, p85: 14.2, p97: 16.2),
        Percentiles(monthAge: 33, p3: 10.3, p15: 11.4, p50: 13.0, p85: 14.8, p97: 16.9),
        Percentiles(monthAge: 36, p3: 10.6, p15: 11.8, p50: 13.5, p85: 15.3, p97: 17.5),
    ]

    // MARK: - 女婴头围（cm），0–36 月龄

    static let girlHeadCM: [Percentiles] = [
        Percentiles(monthAge: 0,  p3: 31.5, p15: 32.4, p50: 33.9, p85: 35.1, p97: 36.2),
        Percentiles(monthAge: 1,  p3: 34.2, p15: 35.1, p50: 36.5, p85: 37.7, p97: 38.9),
        Percentiles(monthAge: 2,  p3: 35.8, p15: 36.7, p50: 38.3, p85: 39.5, p97: 40.7),
        Percentiles(monthAge: 3,  p3: 37.1, p15: 38.0, p50: 39.5, p85: 40.8, p97: 42.0),
        Percentiles(monthAge: 4,  p3: 38.1, p15: 39.0, p50: 40.6, p85: 41.8, p97: 43.0),
        Percentiles(monthAge: 5,  p3: 38.9, p15: 39.8, p50: 41.5, p85: 42.7, p97: 43.8),
        Percentiles(monthAge: 6,  p3: 39.6, p15: 40.5, p50: 42.2, p85: 43.4, p97: 44.6),
        Percentiles(monthAge: 7,  p3: 40.2, p15: 41.0, p50: 42.8, p85: 44.0, p97: 45.2),
        Percentiles(monthAge: 8,  p3: 40.7, p15: 41.5, p50: 43.4, p85: 44.5, p97: 45.8),
        Percentiles(monthAge: 9,  p3: 41.2, p15: 42.0, p50: 43.8, p85: 45.0, p97: 46.3),
        Percentiles(monthAge: 10, p3: 41.5, p15: 42.4, p50: 44.2, p85: 45.4, p97: 46.7),
        Percentiles(monthAge: 11, p3: 41.9, p15: 42.7, p50: 44.6, p85: 45.8, p97: 47.0),
        Percentiles(monthAge: 12, p3: 42.2, p15: 43.0, p50: 44.9, p85: 46.1, p97: 47.4),
        Percentiles(monthAge: 15, p3: 42.9, p15: 43.8, p50: 45.7, p85: 46.9, p97: 48.1),
        Percentiles(monthAge: 18, p3: 43.5, p15: 44.3, p50: 46.2, p85: 47.5, p97: 48.8),
        Percentiles(monthAge: 21, p3: 43.9, p15: 44.8, p50: 46.7, p85: 48.0, p97: 49.2),
        Percentiles(monthAge: 24, p3: 44.3, p15: 45.2, p50: 47.2, p85: 48.5, p97: 49.7),
        Percentiles(monthAge: 27, p3: 44.7, p15: 45.5, p50: 47.5, p85: 48.8, p97: 50.1),
        Percentiles(monthAge: 30, p3: 45.0, p15: 45.8, p50: 47.8, p85: 49.1, p97: 50.4),
        Percentiles(monthAge: 33, p3: 45.2, p15: 46.0, p50: 48.1, p85: 49.4, p97: 50.7),
        Percentiles(monthAge: 36, p3: 45.4, p15: 46.3, p50: 48.3, p85: 49.6, p97: 50.9),
    ]
}
