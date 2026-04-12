import Foundation
import Photos
import UIKit

/// 封装系统相册的授权与基础 PHAsset 获取。
enum PhotoLibraryService {

    // MARK: - 授权

    static var currentAuthorizationStatus: PHAuthorizationStatus {
        PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    static func requestAuthorization() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: status)
            }
        }
    }

    // MARK: - 获取照片

    /// 拉取指定日期之后的所有图片 PHAsset（升序：老的在前）
    static func fetchAssets(after startDate: Date) -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND creationDate >= %@",
            PHAssetMediaType.image.rawValue,
            startDate as NSDate
        )
        options.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]
        let result = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    /// 按 localIdentifier 精确找回一张 PHAsset（可能相册被删过，返回 nil）
    static func asset(withLocalIdentifier id: String) -> PHAsset? {
        PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil).firstObject
    }

    // MARK: - 取图（用于 Vision 分析或 UI 显示）

    /// 请求一张用于分析的中等尺寸 CGImage。
    /// 选 512 px 做 Vision 分析足够，再大只是浪费内存与 CPU。
    static func requestAnalysisImage(for asset: PHAsset) async -> CGImage? {
        await requestImage(for: asset, targetSize: CGSize(width: 512, height: 512))
            .flatMap { $0.cgImage }
    }

    /// 请求一张用于 UI 显示的缩略图（320 px 一般够 List 里铺满）
    static func requestThumbnail(for asset: PHAsset, pointSize: CGFloat = 320) async -> UIImage? {
        let scale = await UIScreen.main.scale
        let pixelSize = CGSize(width: pointSize * scale, height: pointSize * scale)
        return await requestImage(for: asset, targetSize: pixelSize)
    }

    /// 请求一张全屏原图（用于 PhotoDetailView）
    static func requestFullImage(for asset: PHAsset) async -> UIImage? {
        await requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            deliveryMode: .highQualityFormat
        )
    }

    // MARK: - 内部实现

    private static func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic
    ) async -> UIImage? {
        await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = deliveryMode
            options.resizeMode = .fast
            // 一次性回调，避免拿到低清图后又被高清图覆盖重复触发
            options.isSynchronous = false

            var didResume = false
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                // 只在非降级图或最终图时 resume
                if !didResume && !isDegraded {
                    didResume = true
                    continuation.resume(returning: image)
                }
            }
        }
    }
}
