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
    /// 「认人」参考照片的 Vision 特征指纹。nil 表示未启用认人，退化成「任意人脸」策略。
    /// 数据是一个 `VNFeaturePrintObservation` 经 NSKeyedArchiver 归档后的 blob。
    var referenceFacePrintData: Data?
    /// 认人匹配阈值。`VNFeaturePrintObservation.computeDistance` 返回值越小越像，
    /// 阈值越小越严格。典型范围 10 – 30，默认 18 适中。
    var faceMatchThreshold: Double
    var createdAt: Date

    init(
        name: String,
        birthday: Date,
        gender: String? = nil,
        avatarData: Data? = nil,
        referenceFacePrintData: Data? = nil,
        faceMatchThreshold: Double = 18.0,
        createdAt: Date = .now
    ) {
        self.name = name
        self.birthday = birthday
        self.gender = gender
        self.avatarData = avatarData
        self.referenceFacePrintData = referenceFacePrintData
        self.faceMatchThreshold = faceMatchThreshold
        self.createdAt = createdAt
    }
}
