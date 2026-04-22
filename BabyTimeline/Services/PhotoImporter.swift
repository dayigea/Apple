import Foundation
import Observation
import Photos
import SwiftData
import Vision

/// 从系统相册把照片和视频导入到 SwiftData。
///
/// 筛选规则（按顺序）：
/// 1. PHAsset 是图片或视频、`creationDate >= birthday`
/// 2. 封面帧里至少有 1 张人脸（视频取第 1 秒帧做检测）
/// 3. 如果 Baby 设置了「认人参考照」：至少一张人脸与参考指纹距离 ≤ 阈值，
///    **并且**比任何一张「排除人脸」都更像女儿；
///    否则：只要有人脸就算通过
/// 4. 通过后：读取 GPS → 反查中文地名 → 场景分类 → 落库
/// 5. 如果拍摄日期正好落在某个生日周年前后 3 天内 → 自动创建
///    「N 岁生日」里程碑（如果还没有的话），并绑定过去
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
        //    主参考 + 补充参考一起构成 positive 列表，匹配时用最小距离。
        let references: [VNFeaturePrintObservation] = baby.positiveFacePrints
            .compactMap { FaceRecognitionService.unarchive($0) }
        let negativeReferences: [VNFeaturePrintObservation] = baby.negativeFacePrints
            .compactMap { FaceRecognitionService.unarchive($0) }
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

            let isVideo = asset.mediaType == .video

            // 5. 拿分析用的封面帧（照片用 requestAnalysisImage，视频用 requestVideoAnalysisImage）
            let cgImage: CGImage?
            if isVideo {
                cgImage = await PhotoLibraryService.requestVideoAnalysisImage(for: asset)
            } else {
                cgImage = await PhotoLibraryService.requestAnalysisImage(for: asset)
            }
            guard let cgImage else {
                skipped += 1
                continue
            }

            // 6. 人脸检查（认人优先，否则退化到「任意人脸」）
            let faceCount: Int
            if !references.isEmpty {
                let result = await FaceRecognitionService.matchResult(
                    in: cgImage,
                    references: references,
                    negativeReferences: negativeReferences,
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
                autoTags: tags,
                mediaType: isVideo ? 1 : 0,
                duration: isVideo ? asset.duration : 0
            )
            context.insert(entry)
            inserted += 1

            // 10. 生日照自动建里程碑
            Self.maybeCreateBirthdayMilestone(
                photoAssetLocalId: asset.localIdentifier,
                photoDate: meta.creationDate,
                baby: baby,
                context: context
            )

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

    /// 如果 `photoDate` 落在「生日周年 ± 3 天」内，并且还没有同标题的里程碑，
    /// 就自动创建一条「N 岁生日」并把这张照片绑定过去。
    ///
    /// 只取每个生日周年里**最早**遇到的一张照片作为绑定；之后再来的同一天照片不会覆盖。
    private static func maybeCreateBirthdayMilestone(
        photoAssetLocalId: String,
        photoDate: Date,
        baby: Baby,
        context: ModelContext
    ) {
        let calendar = Calendar(identifier: .gregorian)
        let years = calendar.dateComponents([.year], from: baby.birthday, to: photoDate).year ?? -1
        guard years >= 1 else { return }   // 小于一岁不算周年生日

        // 这一年生日的具体日期
        guard let anniversary = calendar.date(
            byAdding: .year,
            value: years,
            to: baby.birthday
        ) else { return }

        // 照片日期与周年日的差（天数）
        let dayDiff = abs(calendar.dateComponents([.day], from: anniversary, to: photoDate).day ?? Int.max)
        guard dayDiff <= 3 else { return }

        let title = birthdayTitle(years: years)

        // 已有同标题里程碑就不重复建
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
