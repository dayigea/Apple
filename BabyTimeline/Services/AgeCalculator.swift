import Foundation

/// 根据生日 + 拍摄日期计算宝宝年龄，以及把年龄映射到阶段桶。
enum AgeCalculator {

    /// 年龄（年、月、日）
    struct Age: Hashable {
        let years: Int
        let months: Int
        let days: Int

        /// 总月数（用于阶段分桶）
        var totalMonths: Int {
            years * 12 + months
        }

        /// 中文可读描述
        var localized: String {
            if years == 0 && months == 0 {
                return "出生 \(days) 天"
            }
            if years == 0 {
                if days == 0 {
                    return "\(months) 个月"
                }
                return "\(months) 个月 \(days) 天"
            }
            if months == 0 {
                return "\(years) 岁"
            }
            return "\(years) 岁 \(months) 个月"
        }
    }

    /// 宝宝在拍摄那一刻的年龄
    static func age(birthday: Date, at date: Date) -> Age {
        let components = Calendar.current.dateComponents(
            [.year, .month, .day],
            from: birthday,
            to: date
        )
        return Age(
            years: max(components.year ?? 0, 0),
            months: max(components.month ?? 0, 0),
            days: max(components.day ?? 0, 0)
        )
    }

    // MARK: - 阶段桶

    /// 成长阶段。每个阶段有 **稳定的排序** 与 **中文标题**。
    struct Stage: Hashable, Comparable {
        /// 用 "从出生起的月数下界" 作为排序 key
        let sortKey: Int
        let title: String

        static func < (lhs: Stage, rhs: Stage) -> Bool {
            lhs.sortKey < rhs.sortKey
        }
    }

    /// 把一个年龄映射到它所属的阶段桶
    static func stage(for age: Age) -> Stage {
        let m = age.totalMonths

        if m < 1 {
            return Stage(sortKey: 0, title: "新生儿（0–1 个月）")
        }
        if m < 3 {
            return Stage(sortKey: 1, title: "1–3 个月")
        }
        if m < 6 {
            return Stage(sortKey: 3, title: "3–6 个月")
        }
        if m < 12 {
            return Stage(sortKey: 6, title: "6–12 个月")
        }
        if m < 18 {
            return Stage(sortKey: 12, title: "1 岁 – 1 岁半")
        }
        if m < 24 {
            return Stage(sortKey: 18, title: "1 岁半 – 2 岁")
        }
        // 2 岁及以上按「整岁」分桶
        let years = m / 12
        return Stage(
            sortKey: years * 12,
            title: "\(years) 岁 – \(years + 1) 岁"
        )
    }

    /// 直接基于生日 + 拍摄日期取阶段，便于调用点一行搞定
    static func stage(birthday: Date, at date: Date) -> Stage {
        stage(for: age(birthday: birthday, at: date))
    }
}
