import Foundation
import Observation
import Photos
import SwiftData
import Vision

/// 从系统相册把照片导入到 SwiftData。
///
/// 筛选规则（按顺序）：
/// 1. PHAsset 是一张图片、`creationDate >= birthday`
/// 2. 照片里至少有 1 张人脸
/// 3. 如果 Baby 设置了「认人参考照」：至少一张人脸与参考指纹距离 ≤ 阈值
///    否则：只要有人脸就算通过
/// 4. 通过后：读取 GPS → 反查中文地名 → 场景分类 → 落库
///
/// 重复导入：以 `PHAsset.localIdentifier` 去重。
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
    func run(baby: Baby, context: ModelContext) async {
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

        // 2. 拉 PHAsset
        let assets = PhotoLibraryService.fetchAssets(after: baby.birthday)
        if assets.isEmpty {
            phase = .finished(inserted: 0, skipped: 0)
            return
        }

        // 3. 预取已入库 id
        let existing = (try? Self.existingLocalIds(in: context)) ?? []

        // 4. 解归档参考指纹（如果设置了）
        let reference: VNFeaturePrintObservation? = baby.referenceFacePrintData
            .flatMap { FaceRecognitionService.unarchive($0) }
        let threshold = Float(baby.faceMatchThreshold)

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

            // 5. 拿 512 分析图
            guard let cgImage = await PhotoLibraryService.requestAnalysisImage(for: asset) else {
                skipped += 1
                continue
            }

            // 6. 人脸检查（认人优先，否则退化到「任意人脸」）
            let faceCount: Int
            if let reference {
                let result = await FaceRecognitionService.matchResult(
                    in: cgImage,
                    reference: reference,
                    threshold: threshold
                )
                guard result.matched else {
                    skipped += 1
                    continue
                }
                faceCount = result.faceCount
            } else {
                let faces = await FaceRecognitionService.detectFaces(in: cgImage)
                guard !faces.isEmpty else {
                    skipped += 1
                    continue
                }
                faceCount = faces.count
            }

            // 7. 场景分类
            let tags = await ImageAnalysisService.classifyScene(cgImage)

            // 8. 元数据 + GPS 反查
            let meta = MetadataExtractor.extract(from: asset)
            var placeName: String? = nil
            if let lat = meta.latitude, let lng = meta.longitude {
                placeName = await GeocodingService.shared.placeName(
                    latitude: lat,
                    longitude: lng
                )
            }

            // 9. 落库
            let entry = PhotoEntry(
                assetLocalId: asset.localIdentifier,
                creationDate: meta.creationDate,
                latitude: meta.latitude,
                longitude: meta.longitude,
                placeName: placeName,
                faceCount: faceCount,
                autoTags: tags
            )
            context.insert(entry)
            inserted += 1

            // 每 20 张落一次盘
            if inserted % 20 == 0 {
                try? context.save()
            }
        }

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
