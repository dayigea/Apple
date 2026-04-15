import Foundation

/// 根据宝宝年龄和已有里程碑，从 `MilestoneCatalog` 里挑出可以提醒父母记录的条目。
enum MilestoneSuggester {

    /// 结果：一条"建议"，可以被父母一键转化为正式 `Milestone`。
    struct Suggestion: Identifiable {
        let entry: MilestoneCatalog.Entry
        /// 这个里程碑的建议发生日期（生日 + expectedMonths 个月）
        let suggestedDate: Date
        var id: String { entry.id }
    }

    /// 返回所有"宝宝实际月龄 >= 预计月龄"、**且还没被手动记录**的条目。
    ///
    /// 去重逻辑：已存在的 `Milestone.title` 与 catalog entry 的 title 完全一致视为"已记录"，
    /// 这条就不会再出现在建议列表里。
    static func suggestions(
        for baby: Baby,
        existing milestones: [Milestone],
        now: Date = .now
    ) -> [Suggestion] {
        let calendar = Calendar(identifier: .gregorian)
        let months = calendar.dateComponents([.month], from: baby.birthday, to: now).month ?? 0

        let recordedTitles = Set(milestones.map { $0.title })

        return MilestoneCatalog.all.compactMap { entry in
            guard months >= entry.expectedMonths else { return nil }
            if recordedTitles.contains(entry.title) { return nil }

            let suggestedDate = calendar.date(
                byAdding: .month,
                value: entry.expectedMonths,
                to: baby.birthday
            ) ?? baby.birthday
            return Suggestion(entry: entry, suggestedDate: suggestedDate)
        }
    }
}
