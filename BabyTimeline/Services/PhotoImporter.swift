import Foundation
import Observation
import Photos
import SwiftData

/// 从系统相册把照片导入到 SwiftData。
/// - 只处理「生日之后」的图片
/// - 对每张照片跑 Vision 分析
///   - 没有人脸 → 跳过
///   - 有人脸 → 记录人脸数 + 场景标签 + GPS 反查地名
/// - 已存在（localId 已入库）的照片会被跳过
@Observable
@MainActor
final class PhotoImporter {

    enum Phase: Equatable {
        case idle
        case requestingAuth
        case scanning(processed: Int, total: Int)
        case finished(inserted: Int, skipped: Int)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private var isRunning = false

    /// 执行一次完整的增量扫描。
    /// - Parameter birthday: 下限日期，早于此日期的照片不会被考虑
    /// - Parameter context: 当前 SwiftData 上下文
    func run(birthday: Date, context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        // 1. 授权
        phase = .requestingAuth
        let status = await PhotoLibraryService.requestAuthorization()
        guard status == .authorized || status == .limited else {
            phase = .failed("没有相册访问权限，无法生成时间线。")
            return
        }

        // 2. 拉全量 PHAsset（生日之后的图片）
        let assets = PhotoLibraryService.fetchAssets(after: birthday)
        if assets.isEmpty {
            phase = .finished(inserted: 0, skipped: 0)
            return
        }

        // 3. 预取已入库 id 集合
        let existing = (try? Self.existingLocalIds(in: context)) ?? []

        var inserted = 0
        var skipped = 0
        phase = .scanning(processed: 0, total: assets.count)

        for (index, asset) in assets.enumerated() {
            defer {
                phase = .scanning(processed: index + 1, total: assets.count)
            }

            if existing.contains(asset.localIdentifier) {
                skipped += 1
                continue
            }

            // 4. 拿一张 512 分析图
            guard let cgImage = await PhotoLibraryService.requestAnalysisImage(for: asset) else {
                skipped += 1
                continue
            }

            // 5. Vision 分析
            let analysis = await ImageAnalysisService.analyze(cgImage)
            guard analysis.faceCount > 0 else {
                skipped += 1
                continue
            }

            // 6. 元数据
            let meta = MetadataExtractor.extract(from: asset)
            var placeName: String? = nil
            if let lat = meta.latitude, let lng = meta.longitude {
                placeName = await GeocodingService.shared.placeName(
                    latitude: lat,
                    longitude: lng
                )
            }

            // 7. 落库
            let entry = PhotoEntry(
                assetLocalId: asset.localIdentifier,
                creationDate: meta.creationDate,
                latitude: meta.latitude,
                longitude: meta.longitude,
                placeName: placeName,
                faceCount: analysis.faceCount,
                autoTags: analysis.tags
            )
            context.insert(entry)
            inserted += 1

            // 每 20 张落一次盘，避免一次性太大压力
            if inserted % 20 == 0 {
                try? context.save()
            }
        }

        // 8. 最后一批
        try? context.save()
        phase = .finished(inserted: inserted, skipped: skipped)
    }

    // MARK: - Helpers

    private static func existingLocalIds(in context: ModelContext) throws -> Set<String> {
        let descriptor = FetchDescriptor<PhotoEntry>()
        let all = try context.fetch(descriptor)
        return Set(all.map { $0.assetLocalId })
    }
}
