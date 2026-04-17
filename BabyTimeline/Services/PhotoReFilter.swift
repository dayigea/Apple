import Foundation
import Observation
import Photos
import SwiftData
import Vision

/// 用当前的「认人 + 排除人脸 + 阈值」设置，重新检查时间线里每一条 `PhotoEntry`，
/// 把不再通过过滤规则的删掉。
///
/// 为什么需要这个：
/// `PhotoImporter` 是增量的——以 `PHAsset.localIdentifier` 去重，已经入库的
/// 照片在「重新扫描相册」时直接跳过。所以你**后加**的排除人脸 / 收紧的阈值
/// 只会影响之后新拍的照片，对已经在时间线里的照片没有任何作用。
/// 这个服务专门处理这一块：不新增照片，只是用当前规则复核已有条目。
///
/// 流程（按顺序）：
/// 1. 要求设置了「认人」参考照，否则没什么可过滤的，直接结束。
/// 2. 拉出所有 `PhotoEntry` 的 `assetLocalId`（纯字符串），然后逐个重新 fetch
///    对应的模型对象。这样做是因为 SwiftData 的模型对象在 `context.delete` +
///    `context.save` 之后可能失效（EXC_BAD_ACCESS），直接持有整个数组不安全。
/// 3. 用 `FaceRecognitionService.matchResult` 复核：
///    - 匹配失败 → 删除 entry，同时把所有指向它的里程碑 `linkedAssetLocalId` 清空
///    - 匹配成功 → 保留
/// 4. 阶段性落盘，UI 可以看到进度。
@Observable
@MainActor
final class PhotoReFilter {

    enum Phase: Equatable {
        case idle
        case running(processed: Int, total: Int)
        case finished(kept: Int, removed: Int, missing: Int)
        case failed(String)
    }

    private(set) var phase: Phase = .idle
    private var isRunning = false

    /// 执行一次复核。如果没设置认人参考照，会走 `failed` 分支给出提示。
    func run(baby: Baby, context: ModelContext) async {
        guard !isRunning else { return }
        isRunning = true
        defer { isRunning = false }

        let references: [VNFeaturePrintObservation] = baby.positiveFacePrints
            .compactMap { FaceRecognitionService.unarchive($0) }
        guard !references.isEmpty else {
            phase = .failed("还没设置认人参考照，没法复核。先在上面「认人」里选一张。")
            return
        }

        let negativeReferences: [VNFeaturePrintObservation] = baby.negativeFacePrints
            .compactMap { FaceRecognitionService.unarchive($0) }
        let threshold = Float(baby.faceMatchThreshold)

        // 先只取所有 assetLocalId（纯 String），不持有 PhotoEntry 对象。
        // 这样后续 delete + save 不会让数组里的其他元素变成野指针。
        let descriptor = FetchDescriptor<PhotoEntry>(
            sortBy: [SortDescriptor(\.creationDate, order: .forward)]
        )
        guard let entries = try? context.fetch(descriptor) else {
            phase = .failed("读取时间线记录失败。")
            return
        }
        let allIds = entries.map { $0.assetLocalId }
        if allIds.isEmpty {
            phase = .finished(kept: 0, removed: 0, missing: 0)
            return
        }

        var kept = 0
        var removed = 0
        var missing = 0
        phase = .running(processed: 0, total: allIds.count)

        for (index, assetId) in allIds.enumerated() {
            defer {
                phase = .running(processed: index + 1, total: allIds.count)
            }

            // 每次循环重新 fetch 这一条，保证拿到的是活的模型对象
            let entryDescriptor = FetchDescriptor<PhotoEntry>(
                predicate: #Predicate { $0.assetLocalId == assetId }
            )
            guard let entry = (try? context.fetch(entryDescriptor))?.first else {
                // 已经在前面的循环里被删掉了（理论上不会发生），跳过
                missing += 1
                continue
            }

            guard let asset = PhotoLibraryService.asset(withLocalIdentifier: assetId) else {
                Self.removeEntry(entry, in: context)
                missing += 1
                continue
            }
            guard let cgImage = await PhotoLibraryService.requestAnalysisImage(for: asset) else {
                kept += 1
                continue
            }

            let result = await FaceRecognitionService.matchResult(
                in: cgImage,
                references: references,
                negativeReferences: negativeReferences,
                threshold: threshold
            )
            if result.matched {
                kept += 1
            } else {
                Self.removeEntry(entry, in: context)
                removed += 1
            }

            if (removed + missing) > 0, (index + 1) % 20 == 0 {
                try? context.save()
            }
        }

        try? context.save()
        phase = .finished(kept: kept, removed: removed, missing: missing)
    }

    // MARK: - Helpers

    private static func removeEntry(_ entry: PhotoEntry, in context: ModelContext) {
        let assetId = entry.assetLocalId
        let descriptor = FetchDescriptor<Milestone>(
            predicate: #Predicate { $0.linkedAssetLocalId == assetId }
        )
        if let linked = try? context.fetch(descriptor) {
            for m in linked {
                m.linkedAssetLocalId = nil
            }
        }
        context.delete(entry)
    }
}
