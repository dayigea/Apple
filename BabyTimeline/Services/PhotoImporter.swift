import Foundation
import Observation
import Photos
import SwiftData
import Vision
import WidgetKit

/// 从系统相册把照片和视频导入到 SwiftData。
///
/// 筛选规则（按顺序）：
/// 1. PHAsset 是图片或视频、`creationDate >= birthday`
/// 2. 封面帧里至少有 1 张人脸（视频取第 1 秒帧做检测）
/// 3. 如果 Baby 设置了「认人参考照」：至少一张人脸与参考指纹距离 ≤ 阈值，
///    **并且**比任何一张「排除人脸」都更像女儿；
///    否则：只要有人脸就算通过
/// 4. 通过后：读取 GPS → 场景分类 → 落库
/// 5. **地理编码延后**：入库后批量异步反查地名，不阻塞扫描主流程
/// 6. 如果拍摄日期正好落在某个生日周年前后 3 天内 → 自动创建
///    「N 岁生日」里程碑
///
/// 性能优化：
/// - 流式 TaskGroup：始终保持 6 个并发分析任务，一个完成立刻补一个，不等批次
/// - 每张照片有 15 秒超时，iCloud 下载卡住不会阻塞整条流水线
/// - 地理编码从扫描循环中剥离，扫完后批量补全
/// - 每 20 条落盘一次
///
/// 重复导入：以 `PHAsset.localIdentifier` 去重。
@Observable
@MainActor
final class PhotoImporter {

    enum Phase: Equatable {
        case idle
        case requestingAuth
        case scanning(processed: Int, total: Int)
        case geocoding(processed: Int, total: Int)
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
        let allAssets = PhotoLibraryService.fetchAssets(after: baby.birthday)
        if allAssets.isEmpty {
            phase = .finished(inserted: 0, skipped: 0)
            return
        }

        // 3. 预取已入库 id，批量过滤
        let existing = (try? Self.existingLocalIds(in: context)) ?? []
        let assets = allAssets.filter { !existing.contains($0.localIdentifier) }
        let skippedExisting = allAssets.count - assets.count

        if assets.isEmpty {
            phase = .finished(inserted: 0, skipped: skippedExisting)
            return
        }

        // 4. 解归档参考指纹
        let references: [VNFeaturePrintObservation] = baby.positiveFacePrints
            .compactMap { FaceRecognitionService.unarchive($0) }
        let negativeReferences: [VNFeaturePrintObservation] = baby.negativeFacePrints
            .compactMap { FaceRecognitionService.unarchive($0) }
        let threshold = Float(baby.faceMatchThreshold)

        phase = .scanning(processed: 0, total: assets.count)

        // 5. 流式并发分析 + 入库
        // 始终保持 maxConcurrency 个分析任务在飞，一个完成立刻补一个，
        // 不会因为某张 iCloud 照片下载慢而让其它工位空转。
        let maxConcurrency = 6
        var inserted = 0
        var processed = 0
        var nextIndex = 0

        let capturedRefs = references
        let capturedNeg = negativeReferences
        let capturedThreshold = threshold

        await withTaskGroup(of: AnalysisResult?.self) { group in
            // 播种：先塞满工位
            while nextIndex < assets.count, nextIndex < maxConcurrency {
                let asset = assets[nextIndex]
                nextIndex += 1
                group.addTask { [self] in
                    await self.analyzeOneWithTimeout(
                        asset,
                        references: capturedRefs,
                        negativeReferences: capturedNeg,
                        threshold: capturedThreshold
                    )
                }
            }

            // 流式消费：每完成一个，立刻补一个新任务
            for await result in group {
                processed += 1
                phase = .scanning(processed: processed, total: assets.count)

                if let result {
                    let entry = PhotoEntry(
                        assetLocalId: result.assetLocalId,
                        creationDate: result.creationDate,
                        latitude: result.latitude,
                        longitude: result.longitude,
                        faceCount: result.faceCount,
                        autoTags: result.tags,
                        mediaType: result.mediaType,
                        duration: result.duration
                    )
                    context.insert(entry)
                    inserted += 1

                    Self.maybeCreateBirthdayMilestone(
                        photoAssetLocalId: result.assetLocalId,
                        photoDate: result.creationDate,
                        baby: baby,
                        context: context
                    )

                    if inserted % 20 == 0 {
                        try? context.save()
                    }
                }

                // 补一个新任务进去
                if nextIndex < assets.count {
                    let asset = assets[nextIndex]
                    nextIndex += 1
                    group.addTask { [self] in
                        await self.analyzeOneWithTimeout(
                            asset,
                            references: capturedRefs,
                            negativeReferences: capturedNeg,
                            threshold: capturedThreshold
                        )
                    }
                }
            }
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        // 6. 批量补全地理编码（不阻塞主流程，后台异步）
        await geocodePending(context: context)

        phase = .finished(inserted: inserted, skipped: skippedExisting + (assets.count - inserted))
    }

    // MARK: - 并发分析

    private struct AnalysisResult {
        let assetLocalId: String
        let creationDate: Date
        let latitude: Double?
        let longitude: Double?
        let faceCount: Int
        let tags: [String]
        let mediaType: Int
        let duration: Double
    }

    /// 带超时的单张分析：超过 15 秒自动放弃，防止 iCloud 下载卡死流水线。
    private nonisolated func analyzeOneWithTimeout(
        _ asset: PHAsset,
        references: [VNFeaturePrintObservation],
        negativeReferences: [VNFeaturePrintObservation],
        threshold: Float
    ) async -> AnalysisResult? {
        await withTaskGroup(of: AnalysisResult?.self) { group in
            group.addTask {
                await self.analyzeOne(
                    asset,
                    references: references,
                    negativeReferences: negativeReferences,
                    threshold: threshold
                )
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private nonisolated func analyzeOne(
        _ asset: PHAsset,
        references: [VNFeaturePrintObservation],
        negativeReferences: [VNFeaturePrintObservation],
        threshold: Float
    ) async -> AnalysisResult? {
        let isVideo = asset.mediaType == .video

        // 取分析图
        let cgImage: CGImage?
        if isVideo {
            cgImage = await PhotoLibraryService.requestVideoAnalysisImage(for: asset)
        } else {
            cgImage = await PhotoLibraryService.requestAnalysisImage(for: asset)
        }
        guard let cgImage else { return nil }

        // 人脸检查
        let faceCount: Int
        if !references.isEmpty {
            let result = await FaceRecognitionService.matchResult(
                in: cgImage,
                references: references,
                negativeReferences: negativeReferences,
                threshold: threshold
            )
            guard result.matched else { return nil }
            faceCount = result.faceCount
        } else {
            let faces = await FaceRecognitionService.detectFaces(in: cgImage)
            guard !faces.isEmpty else { return nil }
            faceCount = faces.count
        }

        // 场景分类
        let tags = await ImageAnalysisService.classifyScene(cgImage)

        // 元数据
        let meta = MetadataExtractor.extract(from: asset)

        return AnalysisResult(
            assetLocalId: asset.localIdentifier,
            creationDate: meta.creationDate,
            latitude: meta.latitude,
            longitude: meta.longitude,
            faceCount: faceCount,
            tags: tags,
            mediaType: isVideo ? 1 : 0,
            duration: isVideo ? asset.duration : 0
        )
    }

    // MARK: - 延迟地理编码

    private func geocodePending(context: ModelContext) async {
        let descriptor = FetchDescriptor<PhotoEntry>(
            predicate: #Predicate { $0.placeName == nil && $0.latitude != nil }
        )
        guard let entries = try? context.fetch(descriptor), !entries.isEmpty else { return }

        let toGeocode = entries.prefix(200)
        phase = .geocoding(processed: 0, total: toGeocode.count)

        for (i, entry) in toGeocode.enumerated() {
            guard let lat = entry.latitude, let lng = entry.longitude else { continue }
            let name = await GeocodingService.shared.placeName(latitude: lat, longitude: lng)
            if let name {
                entry.placeName = name
            }
            if (i + 1) % 10 == 0 {
                try? context.save()
                phase = .geocoding(processed: i + 1, total: toGeocode.count)
            }
        }
        try? context.save()
    }

    // MARK: - Helpers

    private static func existingLocalIds(in context: ModelContext) throws -> Set<String> {
        let descriptor = FetchDescriptor<PhotoEntry>()
        let all = try context.fetch(descriptor)
        return Set(all.map { $0.assetLocalId })
    }

    private static func maybeCreateBirthdayMilestone(
        photoAssetLocalId: String,
        photoDate: Date,
        baby: Baby,
        context: ModelContext
    ) {
        let calendar = Calendar(identifier: .gregorian)
        let years = calendar.dateComponents([.year], from: baby.birthday, to: photoDate).year ?? -1
        guard years >= 1 else { return }

        guard let anniversary = calendar.date(
            byAdding: .year,
            value: years,
            to: baby.birthday
        ) else { return }

        let dayDiff = abs(calendar.dateComponents([.day], from: anniversary, to: photoDate).day ?? Int.max)
        guard dayDiff <= 3 else { return }

        let title = birthdayTitle(years: years)

        let descriptor = FetchDescriptor<Milestone>(
            predicate: #Predicate { $0.title == title }
        )
        if let existing = try? context.fetch(descriptor), !existing.isEmpty {
            return
        }

        let milestone = Milestone(
            title: title,
            date: anniversary,
            note: "从相册里自动识别到的生日照。",
            linkedAssetLocalId: photoAssetLocalId
        )
        context.insert(milestone)
    }

    private static func birthdayTitle(years: Int) -> String {
        switch years {
        case 1: return "第一个生日"
        case 2: return "第二个生日"
        case 3: return "第三个生日"
        default: return "\(years) 岁生日"
        }
    }
}
