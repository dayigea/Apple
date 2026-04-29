import AVFoundation
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

    // MARK: - 获取资源

    /// 拉取指定日期之后的所有图片和视频 PHAsset（升序：老的在前）
    static func fetchAssets(after startDate: Date) -> [PHAsset] {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "(mediaType == %d OR mediaType == %d) AND creationDate >= %@",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue,
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
        guard let uiImage = await requestImage(for: asset, targetSize: CGSize(width: 512, height: 512)) else {
            return nil
        }
        guard let sourceCG = uiImage.cgImage else { return nil }
        // `sourceCG.copy()` 只是个浅拷贝，底层 data provider 仍指向 UIImage 持有的
        // 那块 IOSurface/CVPixelBuffer。UIImage 一旦在 Swift 堆上被释放，Core Image
        // 异步的 `CI::RenderCompletionQueue` 如果还在跑 Vision 请求，就会读到已被
        // 释放的后备内存，触发 libRPAC.dylib 里 QoS 哈希表的 EXC_BAD_ACCESS。
        // 这里把图像整体画到一块**我们自己拥有的**位图里，得到的 CGImage 就完全
        // 和原 UIImage 解耦，后续 Vision/CoreImage 异步处理就安全了。
        return detachCGImage(sourceCG)
    }

    /// 把一个 CGImage 画到新的位图上下文里，得到一份拥有独立数据的 CGImage。
    /// 代价是一次 RGBA 解码（512x512 ≈ 1MB），但换来 Vision 处理期间的内存安全。
    private static func detachCGImage(_ source: CGImage) -> CGImage? {
        let width = source.width
        let height = source.height
        guard width > 0, height > 0 else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo: UInt32 = CGBitmapInfo.byteOrder32Little.rawValue
            | CGImageAlphaInfo.premultipliedFirst.rawValue
        guard let ctx = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        ctx.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
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

    // MARK: - 视频

    /// 从视频 PHAsset 提取一帧封面图用于 Vision 分析（512px）。
    static func requestVideoAnalysisImage(for asset: PHAsset) async -> CGImage? {
        guard let avAsset = await requestAVAsset(for: asset) else { return nil }
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 512, height: 512)

        let dur = (try? await avAsset.load(.duration).seconds) ?? 2
        let time = CMTime(seconds: min(1, dur / 2), preferredTimescale: 600)
        guard let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) else { return nil }
        return detachCGImage(cgImage)
    }

    /// 请求视频的 AVAsset（用于播放或帧提取）。
    static func requestAVAsset(for asset: PHAsset) async -> AVAsset? {
        let holder = RequestIDHolder()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let gate = ContinuationGate()
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .automatic

                let id = PHImageManager.default().requestAVAsset(
                    forVideo: asset,
                    options: options
                ) { avAsset, _, _ in
                    if gate.open() {
                        continuation.resume(returning: avAsset)
                    }
                }
                holder.set(id)
                if Task.isCancelled {
                    PHImageManager.default().cancelImageRequest(id)
                }
            }
        } onCancel: {
            let id = holder.consume()
            if id != PHInvalidImageRequestID {
                PHImageManager.default().cancelImageRequest(id)
            }
        }
    }

    /// 请求视频的 AVPlayerItem（用于 AVPlayer 播放）。
    static func requestPlayerItem(for asset: PHAsset) async -> AVPlayerItem? {
        let holder = RequestIDHolder()
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                let gate = ContinuationGate()
                let options = PHVideoRequestOptions()
                options.isNetworkAccessAllowed = true
                options.deliveryMode = .automatic

                let id = PHImageManager.default().requestPlayerItem(
                    forVideo: asset,
                    options: options
                ) { playerItem, _ in
                    if gate.open() {
                        continuation.resume(returning: playerItem)
                    }
                }
                holder.set(id)
                if Task.isCancelled {
                    PHImageManager.default().cancelImageRequest(id)
                }
            }
        } onCancel: {
            let id = holder.consume()
            if id != PHInvalidImageRequestID {
                PHImageManager.default().cancelImageRequest(id)
            }
        }
    }

    // MARK: - 内部实现

    private static func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        deliveryMode: PHImageRequestOptionsDeliveryMode = .opportunistic
    ) async -> UIImage? {
        let holder = RequestIDHolder()
        return await withTaskCancellationHandler {
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

                let id = PHImageManager.default().requestImage(
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
                holder.set(id)

                // 处理在 set(id) 之前任务就被取消的极端情况：
                // 此时 onCancel 已经跑过、看到的是 invalid id，没法取消请求。
                // 这里读一下 Task 状态，落后补一刀。
                if Task.isCancelled {
                    PHImageManager.default().cancelImageRequest(id)
                }
            }
        } onCancel: {
            // Task 被外层 TaskGroup.cancelAll 取消时，PHImageManager 的回调闭包不会
            // 自己结束。必须显式取消请求，回调才会以 PHImageCancelledKey=true 触发，
            // 进而 resume continuation，让 analyze 槽位释放出来。
            let id = holder.consume()
            if id != PHInvalidImageRequestID {
                PHImageManager.default().cancelImageRequest(id)
            }
        }
    }
}

/// 在 `withTaskCancellationHandler` 的 body 与 onCancel 之间安全地共享
/// PHImageRequestID。两端都通过 lock 访问。
private final class RequestIDHolder: @unchecked Sendable {
    private let lock = NSLock()
    private var id: PHImageRequestID = PHInvalidImageRequestID

    func set(_ value: PHImageRequestID) {
        lock.lock()
        defer { lock.unlock() }
        id = value
    }

    /// 读取并清零，避免重复取消。
    func consume() -> PHImageRequestID {
        lock.lock()
        defer { lock.unlock() }
        let v = id
        id = PHInvalidImageRequestID
        return v
    }
}
