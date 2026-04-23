import Photos
import SwiftData
import SwiftUI
import UIKit
import WidgetKit

// MARK: - Timeline Entry

struct TimeCapsuleEntry: TimelineEntry {
    let date: Date
    let state: State

    enum State {
        case pair(old: CapsulePhoto, new: CapsulePhoto, label: String)
        case noData(message: String)
    }

    struct CapsulePhoto {
        let image: UIImage
        let ageText: String
        let dateText: String
    }
}

// MARK: - Timeline Provider

struct TimeCapsuleProvider: TimelineProvider {

    func placeholder(in context: Context) -> TimeCapsuleEntry {
        TimeCapsuleEntry(date: .now, state: .noData(message: "加载中…"))
    }

    func getSnapshot(in context: Context, completion: @escaping (TimeCapsuleEntry) -> Void) {
        Task {
            let entry = await buildEntry()
            completion(entry)
        }
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TimeCapsuleEntry>) -> Void) {
        Task {
            let entry = await buildEntry()
            // 每天凌晨刷新一次
            let tomorrow = Calendar.current.startOfDay(
                for: Calendar.current.date(byAdding: .day, value: 1, to: .now) ?? .now
            )
            completion(Timeline(entries: [entry], policy: .after(tomorrow)))
        }
    }

    // MARK: - 核心逻辑

    private func buildEntry() async -> TimeCapsuleEntry {
        guard let (baby, photos) = loadData() else {
            return TimeCapsuleEntry(date: .now, state: .noData(message: "还没有设置宝宝信息"))
        }

        let calendar = Calendar(identifier: .gregorian)
        let now = Date.now

        // 按优先级尝试：1年前 → 半年前 → 2年前
        let spans: [(months: Int, label: String)] = [
            (12, "一年前 vs 现在"),
            (6, "半年前 vs 现在"),
            (24, "两年前 vs 现在"),
            (18, "一年半前 vs 现在"),
        ]

        for span in spans {
            guard let targetDate = calendar.date(byAdding: .month, value: -span.months, to: now) else {
                continue
            }
            if targetDate < baby.birthday { continue }

            guard let oldPhoto = closest(to: targetDate, in: photos, within: 7),
                  let newPhoto = closest(to: now, in: photos, within: 7),
                  oldPhoto.assetLocalId != newPhoto.assetLocalId else {
                continue
            }

            // 加载缩略图
            async let oldImg = loadThumbnail(assetId: oldPhoto.assetLocalId)
            async let newImg = loadThumbnail(assetId: newPhoto.assetLocalId)

            guard let oi = await oldImg, let ni = await newImg else { continue }

            let oldAge = ageText(birthday: baby.birthday, at: oldPhoto.creationDate)
            let newAge = ageText(birthday: baby.birthday, at: newPhoto.creationDate)

            let df = DateFormatter()
            df.locale = Locale(identifier: "zh_CN")
            df.dateFormat = "M月d日"

            return TimeCapsuleEntry(
                date: .now,
                state: .pair(
                    old: .init(image: oi, ageText: oldAge, dateText: df.string(from: oldPhoto.creationDate)),
                    new: .init(image: ni, ageText: newAge, dateText: df.string(from: newPhoto.creationDate)),
                    label: span.label
                )
            )
        }

        return TimeCapsuleEntry(date: .now, state: .noData(message: "时间线还不够长\n等半年后再来看"))
    }

    // MARK: - SwiftData

    private func loadData() -> (Baby, [PhotoEntry])? {
        do {
            let schema = Schema([Baby.self, PhotoEntry.self, Milestone.self, GrowthRecord.self])
            let config = ModelConfiguration(
                schema: schema,
                url: AppGroup.sharedStoreURL,
                cloudKitDatabase: .none
            )
            let container = try ModelContainer(for: schema, configurations: config)
            let context = ModelContext(container)

            let babies = try context.fetch(FetchDescriptor<Baby>())
            guard let baby = babies.first else { return nil }

            let photos = try context.fetch(
                FetchDescriptor<PhotoEntry>(sortBy: [SortDescriptor(\.creationDate)])
            )
            guard !photos.isEmpty else { return nil }

            return (baby, photos)
        } catch {
            return nil
        }
    }

    // MARK: - Helpers

    private func closest(to target: Date, in photos: [PhotoEntry], within days: Int) -> PhotoEntry? {
        let limit = TimeInterval(days * 86400)
        return photos.min {
            abs($0.creationDate.timeIntervalSince(target)) < abs($1.creationDate.timeIntervalSince(target))
        }.flatMap {
            abs($0.creationDate.timeIntervalSince(target)) <= limit ? $0 : nil
        }
    }

    private func loadThumbnail(assetId: String) async -> UIImage? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetId], options: nil)
        guard let asset = result.firstObject else { return nil }

        return await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            options.resizeMode = .fast

            var didResume = false
            let lock = NSLock()

            PHImageManager.default().requestImage(
                for: asset,
                targetSize: CGSize(width: 400, height: 400),
                contentMode: .aspectFill,
                options: options
            ) { image, info in
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if isDegraded { return }
                lock.lock()
                defer { lock.unlock() }
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: image)
            }
        }
    }

    private func ageText(birthday: Date, at date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month], from: birthday, to: date)
        let y = max(comps.year ?? 0, 0)
        let m = max(comps.month ?? 0, 0)
        if y == 0 { return "\(m)个月" }
        if m == 0 { return "\(y)岁" }
        return "\(y)岁\(m)个月"
    }
}

// MARK: - Widget View

struct TimeCapsuleWidgetView: View {
    let entry: TimeCapsuleEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch entry.state {
        case .pair(let old, let new, let label):
            pairView(old: old, new: new, label: label)
        case .noData(let message):
            VStack(spacing: 4) {
                Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ViewBuilder
    private func pairView(old: TimeCapsuleEntry.CapsulePhoto, new: TimeCapsuleEntry.CapsulePhoto, label: String) -> some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            HStack(spacing: 6) {
                photoColumn(photo: old)
                photoColumn(photo: new)
            }
        }
        .padding(family == .systemSmall ? 8 : 12)
    }

    @ViewBuilder
    private func photoColumn(photo: TimeCapsuleEntry.CapsulePhoto) -> some View {
        VStack(spacing: 2) {
            Image(uiImage: photo.image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(photo.ageText)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.primary)
            if family != .systemSmall {
                Text(photo.dateText)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Widget Definition

struct TimeCapsuleWidget: Widget {
    let kind = "TimeCapsuleWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TimeCapsuleProvider()) { entry in
            TimeCapsuleWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("时光对比")
        .description("每天自动展示「一年前 vs 现在」的宝宝照片对比。")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
