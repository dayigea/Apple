import CoreLocation
import Foundation
import Photos

/// 从 PHAsset 上读取元数据：拍摄时间、GPS 坐标。
enum MetadataExtractor {

    struct Metadata {
        let creationDate: Date
        let latitude: Double?
        let longitude: Double?
    }

    static func extract(from asset: PHAsset) -> Metadata {
        // creationDate 在极少数情况下可能为空（截图等），回退到 modificationDate 或当下
        let date = asset.creationDate ?? asset.modificationDate ?? .now
        let coordinate = asset.location?.coordinate
        return Metadata(
            creationDate: date,
            latitude: coordinate?.latitude,
            longitude: coordinate?.longitude
        )
    }
}
