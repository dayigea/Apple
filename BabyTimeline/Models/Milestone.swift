import Foundation
import SwiftData

/// 成长里程碑：第一次翻身、第一次走路、第一次喊妈妈……
@Model
final class Milestone {
    var title: String
    var date: Date
    var note: String?
    /// 可选：绑定一张照片（PHAsset.localIdentifier）
    var linkedAssetLocalId: String?
    var createdAt: Date

    init(
        title: String,
        date: Date,
        note: String? = nil,
        linkedAssetLocalId: String? = nil,
        createdAt: Date = .now
    ) {
        self.title = title
        self.date = date
        self.note = note
        self.linkedAssetLocalId = linkedAssetLocalId
        self.createdAt = createdAt
    }
}
