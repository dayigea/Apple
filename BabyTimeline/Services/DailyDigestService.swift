import Foundation
import SwiftData

/// 今日主页的数据聚合：把已经积累的食谱 / 发育 / 体检 / 照片 / 词典数据，
/// 按今天的日期和宝宝月龄拼出一份"今天可以做这些"的卡片清单。
///
/// 全部是纯函数式计算，无副作用。
struct DailyDigest {
    let date: Date
    let baby: Baby

    // 计算结果
    let mealSuggestion: MealSuggestion?
    let developmentTips: [DevelopmentItem]
    let pediatricDue: [PediatricEvent]
    let photoMemories: [PhotoMemory]
    let recentWords: [BabyWord]

    struct MealSuggestion {
        let dayLabel: String      // "周三"
        let stageTitle: String    // "16–18 月龄 · 自主进食萌芽"
        let breakfast: String
        let lunch: String
        let dinner: String
        let morningSnack: String?
        let afternoonSnack: String?
        let stageId: String
    }

    struct PhotoMemory: Identifiable {
        let id: String
        let label: String         // "一年前的今天"
        let assetLocalId: String
        let creationDate: Date
        let ageAtThen: String     // "6 个月"
    }
}

enum DailyDigestService {

    /// 算出今天该展示的内容。需要传入当前已有的体检记录、词典记录和照片。
    static func compute(
        for baby: Baby,
        date: Date = .now,
        pediatricRecords: [PediatricRecord],
        babyWords: [BabyWord],
        photos: [PhotoEntry]
    ) -> DailyDigest {
        return DailyDigest(
            date: date,
            baby: baby,
            mealSuggestion: mealSuggestion(birthday: baby.birthday, date: date),
            developmentTips: developmentTips(baby: baby, date: date),
            pediatricDue: pediatricDue(baby: baby, date: date, records: pediatricRecords),
            photoMemories: photoMemories(baby: baby, date: date, photos: photos),
            recentWords: Array(babyWords.sorted { $0.dateSaid > $1.dateSaid }.prefix(3))
        )
    }

    // MARK: - 三餐推荐

    private static func mealSuggestion(birthday: Date, date: Date) -> DailyDigest.MealSuggestion? {
        guard let stage = FoodGuideData.currentStage(birthday: birthday) else { return nil }
        let dayLabel = weekdayLabel(date)

        // 优先取今日对应的 weeklyPlan
        if let plan = stage.weeklyPlan {
            let idx = weekdayIndex(date)
            let day = plan.days[idx % plan.days.count]
            return DailyDigest.MealSuggestion(
                dayLabel: dayLabel,
                stageTitle: "\(stage.monthRange) · \(stage.title)",
                breakfast: day.breakfast,
                lunch: day.lunch,
                dinner: day.dinner,
                morningSnack: day.morningSnack,
                afternoonSnack: day.afternoonSnack,
                stageId: stage.id
            )
        }
        // 没有 weeklyPlan 的阶段（早月龄）：从 pairings 里随机取
        guard !stage.pairings.isEmpty else { return nil }
        let seed = stableSeed(date)
        let pick = stage.pairings[seed % stage.pairings.count]
        return DailyDigest.MealSuggestion(
            dayLabel: dayLabel,
            stageTitle: "\(stage.monthRange) · \(stage.title)",
            breakfast: pick.title,
            lunch: pick.title,
            dinner: pick.title,
            morningSnack: nil,
            afternoonSnack: nil,
            stageId: stage.id
        )
    }

    // MARK: - 这周学一学（发育清单）

    private static func developmentTips(baby: Baby, date: Date) -> [DevelopmentItem] {
        guard let stage = DevelopmentMilestoneData.currentStage(birthday: baby.birthday) else {
            return []
        }
        // 当前阶段里**还没勾**的项
        let notCompleted = stage.allItems.filter { !baby.isDevelopmentItemCompleted($0.id) }
        guard !notCompleted.isEmpty else {
            // 全部完成了 → 推下一阶段几项作为预览
            let stages = DevelopmentMilestoneData.stages
            if let idx = stages.firstIndex(where: { $0.id == stage.id }),
               idx + 1 < stages.count {
                let next = stages[idx + 1]
                return Array(next.allItems.prefix(3))
            }
            return []
        }
        // 用本周作为 seed 选 3 项，保持本周稳定（同一周打开都是相同 3 项）
        let weekSeed = weekOfYearSeed(date)
        let shuffled = deterministicShuffle(notCompleted, seed: weekSeed)
        return Array(shuffled.prefix(3))
    }

    // MARK: - 体检 / 疫苗待办

    private static func pediatricDue(
        baby: Baby,
        date: Date,
        records: [PediatricRecord]
    ) -> [PediatricEvent] {
        let ageMonths = Calendar.current.dateComponents([.month], from: baby.birthday, to: date).month ?? 0
        let doneIds = Set(records.map { $0.scheduleEventId })
        // 必打的 + 在当前月龄附近 3 个月以内 + 没做
        let due = PediatricSchedule.events.filter {
            $0.category != .optional &&
            !doneIds.contains($0.id) &&
            $0.ageMonths <= ageMonths + 1 && // 已到期或下月到期
            ageMonths - $0.ageMonths <= 12    // 落后 1 年内还显示
        }
        // 优先逾期的
        return due.sorted { $0.ageMonths < $1.ageMonths }.prefix(3).map { $0 }
    }

    // MARK: - 那时候的照片

    private static func photoMemories(
        baby: Baby,
        date: Date,
        photos: [PhotoEntry]
    ) -> [DailyDigest.PhotoMemory] {
        guard !photos.isEmpty else { return [] }
        let calendar = Calendar.current
        // 候选 span：1年前、半年前、2年前、3年前、出生头一周
        let spans: [(months: Int?, label: String)] = [
            (12, "一年前的今天"),
            (6, "半年前的今天"),
            (24, "两年前的今天"),
            (3, "3 个月前的今天"),
        ]
        var memories: [DailyDigest.PhotoMemory] = []
        for span in spans {
            guard let months = span.months,
                  let target = calendar.date(byAdding: .month, value: -months, to: date) else { continue }
            if target < baby.birthday { continue }
            // 找最近 ±7 天的照片
            let window: TimeInterval = 7 * 86400
            let nearby = photos.filter { abs($0.creationDate.timeIntervalSince(target)) <= window }
            guard let pick = nearby.min(by: {
                abs($0.creationDate.timeIntervalSince(target)) < abs($1.creationDate.timeIntervalSince(target))
            }) else { continue }
            memories.append(.init(
                id: span.label,
                label: span.label,
                assetLocalId: pick.assetLocalId,
                creationDate: pick.creationDate,
                ageAtThen: ageText(birthday: baby.birthday, at: pick.creationDate)
            ))
            if memories.count >= 2 { break }
        }
        return memories
    }

    // MARK: - 辅助

    static func ageText(birthday: Date, at date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: birthday, to: date)
        let y = max(comps.year ?? 0, 0)
        let m = max(comps.month ?? 0, 0)
        let d = max(comps.day ?? 0, 0)
        if y == 0 && m == 0 { return "\(d) 天" }
        if y == 0 { return "\(m) 个月" }
        if m == 0 { return "\(y) 岁" }
        return "\(y) 岁 \(m) 月"
    }

    private static func weekdayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    private static func weekdayIndex(_ date: Date) -> Int {
        // 周一 = 0, 周二 = 1, ..., 周日 = 6（与 WeeklyMealPlan.days 的顺序对齐）
        let weekday = Calendar.current.component(.weekday, from: date)
        // Calendar weekday: 周日=1, 周一=2, ..., 周六=7
        return (weekday + 5) % 7
    }

    private static func stableSeed(_ date: Date) -> Int {
        let day = Calendar.current.dateComponents([.year, .dayOfYear], from: date)
        return (day.year ?? 0) * 366 + (day.dayOfYear ?? 0)
    }

    private static func weekOfYearSeed(_ date: Date) -> Int {
        let comps = Calendar.current.dateComponents([.year, .weekOfYear], from: date)
        return (comps.year ?? 0) * 53 + (comps.weekOfYear ?? 0)
    }

    /// 用同一个 seed 出同一份顺序，但不同 seed 之间打乱。
    private static func deterministicShuffle<T>(_ array: [T], seed: Int) -> [T] {
        var arr = array
        var rng = SeededRandomGenerator(seed: UInt64(bitPattern: Int64(seed)))
        for i in (1..<arr.count).reversed() {
            let j = Int(rng.next() % UInt64(i + 1))
            arr.swapAt(i, j)
        }
        return arr
    }
}

/// 简单的可复现 RNG（线性同余）。
private struct SeededRandomGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed &+ 0x9E3779B97F4A7C15 }
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

// MARK: - 连续打开天数

/// 用户连续打开 App 的天数追踪，纯 UserDefaults，不影响主数据。
enum OpenStreak {
    private static let lastDateKey = "openStreak.lastDate"
    private static let countKey = "openStreak.count"
    private static let promptDismissedKey = "openStreak.notifPromptDismissed"

    static var count: Int {
        UserDefaults.standard.integer(forKey: countKey)
    }

    static var notifPromptDismissed: Bool {
        get { UserDefaults.standard.bool(forKey: promptDismissedKey) }
        set { UserDefaults.standard.set(newValue, forKey: promptDismissedKey) }
    }

    /// 在 TodayView 出现时调用。返回更新后的天数。
    @discardableResult
    static func recordOpen(now: Date = .now) -> Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: now)
        guard let last = UserDefaults.standard.object(forKey: lastDateKey) as? Date else {
            UserDefaults.standard.set(today, forKey: lastDateKey)
            UserDefaults.standard.set(1, forKey: countKey)
            return 1
        }
        let lastDay = cal.startOfDay(for: last)
        if lastDay == today { return count }
        let dayDiff = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
        let newCount: Int
        if dayDiff == 1 {
            newCount = count + 1
        } else {
            newCount = 1
        }
        UserDefaults.standard.set(today, forKey: lastDateKey)
        UserDefaults.standard.set(newCount, forKey: countKey)
        return newCount
    }
}
