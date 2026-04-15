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
    /// 「排除人脸」：爸爸妈妈/其他家人等不该被当成宝宝的脸。
    /// 存的是一份 JSON 编码的 base64 字符串数组，每一项对应一个
    /// 归档后的 `VNFeaturePrintObservation` 的 Data → base64。
    /// 不直接用 `[Data]` 因为 iOS 18 SwiftData 对 Array<…> 支持有坑。
    ///
    /// **必须是 Optional**。这个字段是在已经有老 Baby 记录的情况下后加的，
    /// SwiftData 在迁移老的 store 时会尝试做 Core Data lightweight migration：
    /// 非可选（mandatory）的新字段没法给老记录补默认值，迁移会直接挂掉
    /// （NSCocoaErrorDomain 134110 / "Validation error missing attribute values
    /// on mandatory destination attribute"）。做成 Optional 后老记录就可以
    /// 留成 `nil`，getter 里把 `nil` 视作「还没有任何排除人脸」即可。
    var negativeFacePrintsRawJSON: Data?
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
        negativeFacePrints: [Data] = [],
        faceMatchThreshold: Double = 18.0,
        createdAt: Date = .now
    ) {
        self.name = name
        self.birthday = birthday
        self.gender = gender
        self.avatarData = avatarData
        self.referenceFacePrintData = referenceFacePrintData
        self.negativeFacePrintsRawJSON = negativeFacePrints.isEmpty
            ? nil
            : Self.encodeNegativePrints(negativeFacePrints)
        self.faceMatchThreshold = faceMatchThreshold
        self.createdAt = createdAt
    }

    // MARK: - 排除人脸的读写

    /// 当前所有「排除人脸」的归档 Data 列表。只读；修改用 `addNegativeFacePrint` 等。
    /// `nil` 存储会被当作空列表处理。
    var negativeFacePrints: [Data] {
        guard let raw = negativeFacePrintsRawJSON else { return [] }
        return Self.decodeNegativePrints(raw)
    }

    /// 追加一个「排除人脸」。幂等：相同 Data 不会重复添加。
    func addNegativeFacePrint(_ data: Data) {
        var current = negativeFacePrints
        let base64 = data.base64EncodedString()
        // 去重
        if current.contains(where: { $0.base64EncodedString() == base64 }) { return }
        current.append(data)
        negativeFacePrintsRawJSON = Self.encodeNegativePrints(current)
    }

    /// 按索引删除一个排除人脸。
    func removeNegativeFacePrint(at index: Int) {
        var current = negativeFacePrints
        guard current.indices.contains(index) else { return }
        current.remove(at: index)
        negativeFacePrintsRawJSON = current.isEmpty
            ? nil
            : Self.encodeNegativePrints(current)
    }

    /// 清空所有排除人脸。
    func clearNegativeFacePrints() {
        negativeFacePrintsRawJSON = nil
    }

    private static func encodeNegativePrints(_ prints: [Data]) -> Data {
        let base64 = prints.map { $0.base64EncodedString() }
        return (try? JSONEncoder().encode(base64)) ?? Data("[]".utf8)
    }

    private static func decodeNegativePrints(_ raw: Data) -> [Data] {
        guard let base64 = try? JSONDecoder().decode([String].self, from: raw) else {
            return []
        }
        return base64.compactMap { Data(base64Encoded: $0) }
    }
}
