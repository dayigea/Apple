import Foundation

/// 给定一个里程碑日期，从时间线里自动挑一张最贴近那个日期的照片。
///
/// 策略：按 `|photo.creationDate - milestoneDate|` 最小值，不设硬截止。
/// 理由：建议日期是 `生日 + N 月`，实际照片可能分散在前后数月；
/// 若用 30 天硬截止很容易返回 nil，导致兜底逻辑拿到 Date.now 的最新照片
/// 反而更错。返回最近的一张配上日期标注，让用户自己判断对不对。
enum MilestonePhotoMatcher {

    /// 在 `photos` 里找到与 `date` 日期最接近的一张照片（无距离上限）。
    /// 时间线里所有照片都已经过了人脸 / 认人过滤，这里不需要再过滤。
    static func bestMatch(for date: Date, in photos: [PhotoEntry]) -> PhotoEntry? {
        photos.min { a, b in
            abs(a.creationDate.timeIntervalSince(date))
                < abs(b.creationDate.timeIntervalSince(date))
        }
    }

    /// 简便写法：直接返回匹配到的 `assetLocalId`，找不到时返回 nil。
    static func bestMatchAssetId(for date: Date, in photos: [PhotoEntry]) -> String? {
        bestMatch(for: date, in: photos)?.assetLocalId
    }

    /// 匹配到的照片与目标日期相差多少天（取整，双向）。
    static func dayDiff(matchedPhoto: PhotoEntry, targetDate: Date) -> Int {
        Int(abs(matchedPhoto.creationDate.timeIntervalSince(targetDate)) / 86400)
    }
}
