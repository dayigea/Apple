import Foundation
import SwiftData

/// 每条被纳入时间线的媒体（照片或视频），对应系统相册里的一个 PHAsset。
/// 本地只保存元数据，原始文件始终留在系统相册里，通过 `assetLocalId` 按需读取。
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
    /// 反查到的中文地名,例如「北京市朝阳区」
    var placeName: String?
    /// 用户手写的备注
    var note: String?
    /// 是否星标
    var isFavorite: Bool
    /// Vision 检测到的人脸数量（导入时必定 > 0，因为没人脸的照片会被过滤掉）
    var faceCount: Int
    /// 自动标签的 JSON 编码存储。
    ///
    /// 不直接声明 `[String]`：iOS 18 的 SwiftData 对 `Array<String>` 走的是
    /// CoreData 的 transformable 路径，会去找一个名为 "Array" 的 Obj-C 类，
    /// 找不到就 schema 直接挂掉。所以这里手动序列化成 JSON Data 绕过去。
    var autoTagsData: Data
    /// 记录入库时间
    var importedAt: Date

    /// 媒体类型：0 = 照片，1 = 视频。默认 0 兼容已有数据。
    var mediaType: Int

    /// 视频时长（秒），照片为 0。
    var duration: Double

    /// Vision 场景分类自动标签（中文），例如 ["宝宝", "食物", "室内"]
    /// 透明转发到底层的 `autoTagsData`，不被 SwiftData 直接持久化。
    var autoTags: [String] {
        get {
            (try? JSONDecoder().decode([String].self, from: autoTagsData)) ?? []
        }
        set {
            autoTagsData = (try? JSONEncoder().encode(newValue)) ?? Data("[]".utf8)
        }
    }

    var isVideo: Bool { mediaType == 1 }

    init(
        assetLocalId: String,
        creationDate: Date,
        latitude: Double? = nil,
        longitude: Double? = nil,
        placeName: String? = nil,
        note: String? = nil,
        isFavorite: Bool = false,
        faceCount: Int = 0,
        autoTags: [String] = [],
        importedAt: Date = .now,
        mediaType: Int = 0,
        duration: Double = 0
    ) {
        self.assetLocalId = assetLocalId
        self.creationDate = creationDate
        self.latitude = latitude
        self.longitude = longitude
        self.placeName = placeName
        self.note = note
        self.isFavorite = isFavorite
        self.faceCount = faceCount
        self.autoTagsData = (try? JSONEncoder().encode(autoTags)) ?? Data("[]".utf8)
        self.importedAt = importedAt
        self.mediaType = mediaType
        self.duration = duration
    }
}
