import Foundation
import Observation
import Photos
import SwiftData
import WidgetKit

/// 基于 PHPicker 用户选定列表的导入器：信任 Apple 的人像聚类，跳过自家人脸识别。
///
/// 流程：
/// 1. 拿到 `assetIdentifier` 列表（来自 PHPicker 选择）
/// 2. 按 `PhotoEntry.assetLocalId` 去重
/// 3. 用 `PHAsset.fetchAssets(withLocalIdentifiers:)` 取回 PHAsset
/// 4. 过滤掉非图片/视频、早于宝宝生日的
/// 5. 直接落库（无需下载图像，metadata 都在 PHAsset 同步属性上）
/// 6. 生日附近的照片自动加里程碑
/// 7. 后台异步反查地名
///
/// 比 `PhotoImporter` 快一个数量级，且永远不会因 iCloud 下载卡死——
/// 因为根本不下载图片。代价：没有自动场景标签 (`autoTags` 为空)。
@Observable
@MainActor
final class PhotoPickerImporter {

    enum Phase: Equatable {
        case idle
        case importing(processed: Int, total: Int)
        case geocoding(processed: Int, total: Int)
        case finished(inserted: Int, skipped: Int, skippedBeforeBirthday: Int)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private var isRunning = false

    func `import`(
        assetIdentifiers: [String],
        baby: Baby,
        context: ModelContext
    ) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        guard !assetIdentifiers.isEmpty else {
            phase = .finished(inserted: 0, skipped: 0, skippedBeforeBirthday: 0)
            return
        }

        phase = .importing(processed: 0, total: assetIdentifiers.count)

        // 1. 去重
        let existing = (try? Self.existingLocalIds(in: context)) ?? []
        let newIds = assetIdentifiers.filter { !existing.contains($0) }
        let alreadyImported = assetIdentifiers.count - newIds.count

        guard !newIds.isEmpty else {
            phase = .finished(
                inserted: 0,
                skipped: alreadyImported,
                skippedBeforeBirthday: 0
            )
            return
        }

        // 2. 取回 PHAsset
        let result = PHAsset.fetchAssets(withLocalIdentifiers: newIds, options: nil)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }

        // 3. 落库
        var inserted = 0
        var skippedBeforeBirthday = 0
        var processed = 0

        for asset in assets {
            processed += 1
            phase = .importing(processed: processed, total: assets.count)

            guard asset.mediaType == .image || asset.mediaType == .video else {
                continue
            }

            let meta = MetadataExtractor.extract(from: asset)
            guard meta.creationDate >= baby.birthday else {
                skippedBeforeBirthday += 1
                continue
            }

            let isVideo = asset.mediaType == .video
            let entry = PhotoEntry(
                assetLocalId: asset.localIdentifier,
                creationDate: meta.creationDate,
                latitude: meta.latitude,
                longitude: meta.longitude,
                // Apple 的人像聚类已经确认是宝宝，记 1
                faceCount: 1,
                autoTags: [],
                mediaType: isVideo ? 1 : 0,
                duration: isVideo ? asset.duration : 0
            )
            context.insert(entry)
            inserted += 1

            Self.maybeCreateBirthdayMilestone(
                photoAssetLocalId: asset.localIdentifier,
                photoDate: meta.creationDate,
                baby: baby,
                context: context
            )

            if inserted % 50 == 0 {
                try? context.save()
            }
        }

        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()

        // 4. 后台批量反查地名
        await geocodePending(context: context)

        phase = .finished(
            inserted: inserted,
            skipped: alreadyImported,
            skippedBeforeBirthday: skippedBeforeBirthday
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
