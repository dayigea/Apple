import Foundation
import SwiftData

/// 一次体检/测量记录：身高、体重、头围。
@Model
final class GrowthRecord {
    var date: Date
    /// 身高（厘米）
    var heightCM: Double?
    /// 体重（千克）
    var weightKG: Double?
    /// 头围（厘米）
    var headCircumCM: Double?
    var note: String?
    var createdAt: Date

    init(
        date: Date,
        heightCM: Double? = nil,
        weightKG: Double? = nil,
        headCircumCM: Double? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.date = date
        self.heightCM = heightCM
        self.weightKG = weightKG
        self.headCircumCM = headCircumCM
        self.note = note
        self.createdAt = createdAt
    }
}
