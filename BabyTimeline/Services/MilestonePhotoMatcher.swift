import Foundation

/// 给定一个里程碑事件，从时间线里自动挑一张最贴近的照片。
///
/// 两阶段匹配策略：
/// 1. **内容优先**：如果传入了 `preferringKeywords`（来自 `MilestoneCatalog.Entry.photoKeywords`），
///    先在 `PhotoEntry.autoTags` 命中任一关键词的照片里按日期距离挑最近的一张。
///    例如「第一个生日」会优先找自动标签里含"生日 / 生日蛋糕 / 蛋糕 / 派对"的照片。
/// 2. **日期兜底**：如果没有任何照片匹配关键词，或者关键词为空，退化到全库按
///    `|photo.creationDate − milestoneDate|` 最小值匹配。
///
/// 不设硬截止距离：建议日期是「生日 + N 月」的理论值，实际照片可能分散在前后数月，
/// 30 天硬截止会让大量条目返回 nil，反而不如返回最近的让用户自己判断。
enum MilestonePhotoMatcher {

    /// 在 `photos` 里找到与 `date` 日期最接近的一张照片。
    ///
    /// - Parameters:
    ///   - date: 里程碑日期。
    ///   - photos: 时间线里的全部照片（已过人脸 / 认人过滤）。
    ///   - preferringKeywords: 优先匹配的内容关键词；空数组或 nil 表示只按日期匹配。
    static func bestMatch(
        for date: Date,
        in photos: [PhotoEntry],
        preferringKeywords keywords: [String] = []
    ) -> PhotoEntry? {
        // 第一阶段：按内容关键词过滤再挑日期最近
        if !keywords.isEmpty {
            let keywordSet = Set(keywords)
            let keywordHits = photos.filter { entry in
                !keywordSet.isDisjoint(with: entry.autoTags)
            }
            if let match = closestByDate(to: date, in: keywordHits) {
                return match
            }
        }
        // 第二阶段：全库按日期最近
        return closestByDate(to: date, in: photos)
    }

    /// 简便写法：直接返回匹配到的 `assetLocalId`，找不到时返回 nil。
    static func bestMatchAssetId(
        for date: Date,
        in photos: [PhotoEntry],
        preferringKeywords keywords: [String] = []
    ) -> String? {
        bestMatch(for: date, in: photos, preferringKeywords: keywords)?.assetLocalId
    }

    /// 匹配到的照片与目标日期相差多少天（取整，双向）。
    static func dayDiff(matchedPhoto: PhotoEntry, targetDate: Date) -> Int {
        Int(abs(matchedPhoto.creationDate.timeIntervalSince(targetDate)) / 86400)
    }

    /// 判断一张照片是否命中了给定关键词里的任意一个（供 UI 展示"内容匹配"标注）。
    static func hasKeywordMatch(_ photo: PhotoEntry, keywords: [String]) -> Bool {
        guard !keywords.isEmpty else { return false }
        return !Set(keywords).isDisjoint(with: photo.autoTags)
    }

    // MARK: - 私有

    private static func closestByDate(to date: Date, in photos: [PhotoEntry]) -> PhotoEntry? {
        photos.min { a, b in
            abs(a.creationDate.timeIntervalSince(date))
                < abs(b.creationDate.timeIntervalSince(date))
        }
    }
}
