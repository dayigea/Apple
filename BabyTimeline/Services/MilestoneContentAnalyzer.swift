import Foundation

/// 把"理解照片内容"的逻辑收在一个地方：
///
/// - **从里程碑标题反推该匹配哪些 Vision 标签**（用户手写的标题也能自动推导，不需要写死映射）
/// - **用照片的 `autoTags` + 年龄 + 地点生成一段自然中文备注**
///
/// 全部纯本地规则，不联网不调模型，改了即生效。
enum MilestoneContentAnalyzer {

    // MARK: - 关键词推导

    /// 同义词兜底：里程碑标题里有些词不一定能在 Vision 标签体系里直接对到，
    /// 这里补一小张映射把标题词根 → 期望命中的中文 tag。
    ///
    /// 例如 `"跑"` 没有对应 tag，但拍照时身体动作最接近的是 `"走路"`；
    /// `"骑三轮车"` 对应 `"自行车"`；`"咯咯笑"` 对应 `"微笑"`。
    ///
    /// 只放**一定需要扩展的**条目；能直接在 TagTranslator 命中的（如 "生日"、"微笑"、"吃饭"）
    /// 由下方 `inferredKeywords` 的第一阶段子串匹配自动处理。
    private static let synonyms: [String: [String]] = [
        "跑":        ["走路"],
        "独立走":    ["走路"],
        "咯咯笑":    ["微笑"],
        "吃辅食":    ["吃饭", "食物", "餐椅", "餐食"],
        "自己吃饭":  ["吃饭", "食物", "餐椅", "餐食"],
        "生日":      ["生日", "生日蛋糕", "蛋糕", "派对"],
        "骑三轮车":  ["自行车"],
    ]

    /// 给定一个里程碑标题，推导它应该在照片 `autoTags` 里命中的关键词集合。
    ///
    /// 两阶段：
    /// 1. **标题直接子串匹配**：扫一遍 `TagTranslator.allChineseTags()`，
    ///    标题包含的 tag 全部算命中（例：标题「第一个生日」→ 命中 "生日"）
    /// 2. **同义词扩展**：标题命中 `synonyms` 的 key，就把对应 value 也加进来
    ///    （例：标题里有 "生日" → 再加 "生日蛋糕、蛋糕、派对"）
    ///
    /// 这样 catalog 不用再显式列 `photoKeywords`，标题本身就是语义来源。
    /// 手写标题（不在 catalog 里）也一样能自动推导关键词。
    static func inferredKeywords(forTitle rawTitle: String) -> [String] {
        let title = rawTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return [] }

        var hits = Set<String>()

        // 阶段 1：直接子串匹配 Vision 标签
        for tag in TagTranslator.allChineseTags() where title.contains(tag) {
            hits.insert(tag)
        }

        // 阶段 2：同义词扩展
        for (pattern, tags) in synonyms where title.contains(pattern) {
            hits.formUnion(tags)
        }

        return hits.sorted()
    }

    // MARK: - 自动生成备注

    /// 生成备注时忽略的"太过宽泛、读起来像废话"的标签。
    private static let uninterestingTags: Set<String> = [
        "宝宝", "小朋友", "人物", "人像",
        "室内", "户外",
    ]

    /// 挑出适合写进备注的有信息量的标签（去重后按 autoTags 原顺序保留，
    /// 这样置信度高的会排在前面，取前若干个即可）。
    private static func meaningfulTags(from autoTags: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for tag in autoTags where !uninterestingTags.contains(tag) {
            if seen.insert(tag).inserted {
                result.append(tag)
            }
        }
        return result
    }

    /// 根据一张照片 + 宝宝信息，拼一段自然中文的备注。
    ///
    /// 输出模板（按可用信息拼接）：
    /// - `{年龄描述}{在 地点}拍的。{照片里能看到 …}{。}`
    ///
    /// 例：
    /// - 1 岁生日：`"1 岁时，在 北京市朝阳区 拍的。照片里能看到 生日蛋糕、蛋糕、微笑。"`
    /// - 吃辅食：`"6 个月时拍的。照片里能看到 餐椅、食物。"`
    /// - 信息匮乏：`"1 岁 2 个月时拍的。"`
    static func generatedNote(for photo: PhotoEntry, baby: Baby) -> String {
        let age = AgeCalculator.age(birthday: baby.birthday, at: photo.creationDate).localized

        var opener = "\(age)时"
        if let place = photo.placeName?.trimmingCharacters(in: .whitespaces), !place.isEmpty {
            opener += "，在 \(place) "
        }
        opener += "拍的。"

        let meaningful = meaningfulTags(from: photo.autoTags)
        if meaningful.isEmpty {
            return opener
        }
        let tagList = meaningful.prefix(4).joined(separator: "、")
        return opener + "照片里能看到 \(tagList)。"
    }
}
