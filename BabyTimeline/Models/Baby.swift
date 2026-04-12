import Foundation
import SwiftData

/// 宝宝的基本信息。整个 App 只保存一条记录（私人使用）。
@Model
final class Baby {
    var name: String
    var birthday: Date
    /// "girl" / "boy" / nil
    var gender: String?
    /// 头像（JPEG 压缩后的数据），允许为空
    var avatarData: Data?
    var createdAt: Date

    init(
        name: String,
        birthday: Date,
        gender: String? = nil,
        avatarData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.name = name
        self.birthday = birthday
        self.gender = gender
        self.avatarData = avatarData
        self.createdAt = createdAt
    }
}
