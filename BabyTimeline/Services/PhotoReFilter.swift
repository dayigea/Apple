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
/// 2. 拉出所有 `PhotoEntry`，依次通过 `PHAsset.localIdentifier` 回到系统相册。
///    - 如果 asset 在相册里已经被删掉了，我们也把 SwiftData 里的 entry 删掉。
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

        guard
            let refData = baby.referenceFacePrintData,
            let reference = FaceRecognitionService.unarchive(refData)
        else {
            phase = .failed("还没设置认人参考照，没法复核。先在上面「认人」里选一张。")
            return
        }

        let negativeReferences: [VNFeaturePrintObservation] = baby.negativeFacePrints
            .compactMap { FaceRecognitionService.unarchive($0) }
        let threshold = Float(baby.faceMatchThreshold)

        let descriptor = FetchDescriptor<PhotoEntry>(
            sortBy: [SortDescriptor(\.creationDate, order: .forward)]
        )
        guard let entries = try? context.fetch(descriptor) else {
            phase = .failed("读取时间线记录失败。")
            return
        }
        if entries.isEmpty {
            phase = .finished(kept: 0, removed: 0, missing: 0)
            return
        }

        var kept = 0
        var removed = 0
        var missing = 0
        phase = .running(processed: 0, total: entries.count)

        for (index, entry) in entries.enumerated() {
            defer {
                phase = .running(processed: index + 1, total: entries.count)
            }

            guard let asset = PhotoLibraryService.asset(withLocalIdentifier: entry.assetLocalId) else {
                // 系统相册里已经没有这张了，顺手清掉
                Self.removeEntry(entry, in: context)
                missing += 1
                continue
            }
            guard let cgImage = await PhotoLibraryService.requestAnalysisImage(for: asset) else {
                // 取图失败不贸然删，保留
                kept += 1
                continue
            }

            let result = await FaceRecognitionService.matchResult(
                in: cgImage,
                reference: reference,
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

    /// 删掉一条 `PhotoEntry`，并把所有绑在它上面的里程碑 `linkedAssetLocalId`
    /// 清空，避免留下指向已删除照片的死链接。里程碑条目本身保留。
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
