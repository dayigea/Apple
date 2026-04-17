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

    /// 请求一张用于 UI 显示的缩略图（320 pt 一般够 List 里铺满）
    static func requestThumbnail(for asset: PHAsset, pointSize: CGFloat = 320) async -> UIImage? {
        // 所有现代 iPhone 都是 @3x；iPad 偶尔 @2x 但拿大了也无妨
        let pixel = pointSize * 3
        return await requestImage(for: asset, targetSize: CGSize(width: pixel, height: pixel))
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
            let gate = ContinuationGate()
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            // 导入 / 分析路径要求只拿一次最终图：opportunistic 会先回调低清图
            // 再回调高清图，这种多次回调 + 我们之前用 `var didResume = false`
            // 跨线程更新的写法存在竞态，可能双重 resume → EXC_BAD_ACCESS。
            // highQualityFormat 保证只触发一次非降级回调，再配合 ContinuationGate
            // 把所有路径收敛到「最多 resume 一次」。
            options.deliveryMode = deliveryMode == .opportunistic
                ? .highQualityFormat
                : deliveryMode
            options.resizeMode = .fast
            options.isSynchronous = false

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, info in
                // iCloud 下载失败 / 取消 / 降级图都不 resume，等最终非降级图。
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let isCancelled = (info?[PHImageCancelledKey] as? Bool) ?? false
                let hasError = info?[PHImageErrorKey] != nil
                if isDegraded { return }
                // 最终图到了（可能是 nil，比如 iCloud 下载失败）
                if gate.open() {
                    if isCancelled || hasError {
                        continuation.resume(returning: nil)
                    } else {
                        continuation.resume(returning: image)
                    }
                }
            }
        }
    }
}
