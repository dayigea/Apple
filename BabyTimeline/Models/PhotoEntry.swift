import Foundation
import SwiftData

/// 每张被纳入时间线的照片，对应系统相册里的一个 PHAsset。
/// 本地只保存元数据，照片本体始终留在系统相册里，通过 `assetLocalId` 按需读取。
@Model
final class PhotoEntry {
    /// PHAsset.localIdentifier，是 App 里照片的唯一标识
    @Attribute(.unique) var assetLocalId: String
    /// 拍摄时间（优先使用 EXIF 原始时间，fallback 到 PHAsset.creationDate）
    var creationDate: Date
    /// GPS 纬度，可能为空
    var latitude: Double?
    /// GPS 经度，可能为空
    var longitude: Double?
    /// 反查到的中文地名，例如「北京市朝阳区」
    var placeName: String?
    /// 用户手写的备注
    var note: String?
    /// 是否星标
    var isFavorite: Bool
    /// Vision 检测到的人脸数量（为未来「只看含人脸的照片」开关预留，0 表示未检测）
    var faceCount: Int
    /// 记录入库时间
    var importedAt: Date

    init(
        assetLocalId: String,
        creationDate: Date,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        note: String? = nil,
        isFavorite: Bool = false,
        faceCount: Int = 0,
        importedAt: Date = .now
    ) {
        self.assetLocalId = assetLocalId
        self.creationDate = creationDate
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.note = note
        self.isFavorite = isFavorite
        self.faceCount = faceCount
        self.importedAt = importedAt
    }
}
