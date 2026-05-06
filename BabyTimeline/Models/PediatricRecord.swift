import Foundation
import SwiftData

/// 用户已完成的儿保 / 疫苗事件记录。
/// 静态时间表见 `PediatricSchedule`，本模型只存"做过的"——未做的不进库。
@Model
final class PediatricRecord {
    /// 对应 `PediatricEvent.id`，例 "checkup.18m" / "vaccine.dtp.4"
    @Attribute(.unique) var scheduleEventId: String
    var completedAt: Date

    // 儿保时可选的体格数据
    var heightCm: Double?
    var weightKg: Double?
    var headCircumferenceCm: Double?

    var notes: String?
    var location: String?

    init(
        scheduleEventId: String,
        completedAt: Date = .now,
        heightCm: Double? = nil,
        weightKg: Double? = nil,
        headCircumferenceCm: Double? = nil,
        notes: String? = nil,
        location: String? = nil
    ) {
        self.scheduleEventId = scheduleEventId
        self.completedAt = completedAt
        self.heightCm = heightCm
        self.weightKg = weightKg
        self.headCircumferenceCm = headCircumferenceCm
        self.notes = notes
        self.location = location
    }
}
