import Foundation

/// 给定一个里程碑日期，从时间线里自动挑一张最贴近那个日期的照片。
///
/// 用于：
/// - 点「建议记录」里某一条时，自动把同月龄附近的一张照片预填进去
/// - 用户手动新建里程碑、还没主动选照片时，根据当前选的日期自动配一张
/// - 用户改了日期并且没主动挑过照片 → 跟着重新配
///
/// 策略非常简单：按 `|photo.creationDate - milestoneDate|` 升序，
/// 取第一张且差值 ≤ `maxDays` 天。时间线里所有照片都已经在导入时
/// 过了人脸 / 认人这道坎，这里不需要再过滤一次。
enum MilestonePhotoMatcher {

    /// 在 `photos` 里找到与 `date` 日期最接近的一张。
    /// - Parameter maxDays: 容忍的最大天数差（双向）。默认 30 天 —— 太远的
    ///   照片硬配意义不大，宁可留空让用户手动选。
    static func bestMatch(
        for date: Date,
        in photos: [PhotoEntry],
        maxDays: Int = 30
    ) -> PhotoEntry? {
        let maxInterval = Double(maxDays) * 24 * 3600
        return photos
            .filter { abs($0.creationDate.timeIntervalSince(date)) <= maxInterval }
            .min { a, b in
                abs(a.creationDate.timeIntervalSince(date))
                    < abs(b.creationDate.timeIntervalSince(date))
            }
    }

    /// 简便写法：直接返回匹配到的 `assetLocalId`，找不到时返回 nil。
    static func bestMatchAssetId(
        for date: Date,
        in photos: [PhotoEntry],
        maxDays: Int = 30
    ) -> String? {
        bestMatch(for: date, in: photos, maxDays: maxDays)?.assetLocalId
    }
}
