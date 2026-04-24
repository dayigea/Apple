import SwiftData
import SwiftUI

/// "时光对比"：今天 vs 半年前 / 一年前 / 两年前的照片并排展示。
struct TimeCapsuleView: View {

    let baby: Baby

    @Query(sort: \PhotoEntry.creationDate, order: .forward)
    private var allPhotos: [PhotoEntry]

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            ScrollView {
                if capsules.isEmpty {
                    emptyState
                } else {
                    VStack(spacing: 24) {
                        ForEach(capsules) { capsule in
                            CapsuleCard(capsule: capsule, baby: baby)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("时光对比")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    struct Capsule: Identifiable {
        let id = UUID()
        let label: String
        let oldPhoto: PhotoEntry
        let newPhoto: PhotoEntry
        let monthsAgo: Int
    }

    private var capsules: [Capsule] {
        let now = Date.now
        var result: [Capsule] = []

        // "新照片"直接取时间线里最近的一张
        guard let newPhoto = allPhotos.last else { return [] }

        // 尝试若干个时间跨度：6个月、1年、1.5年、2年、3年
        let spans = [6, 12, 18, 24, 36]
        for months in spans {
            guard let targetDate = calendar.date(byAdding: .month, value: -months, to: now) else { continue }
            if targetDate < baby.birthday { continue }

            // 在目标日期 ±30 天内找最近的照片
            guard let oldPhoto = closestPhoto(to: targetDate, within: 30) else { continue }
            if oldPhoto.assetLocalId == newPhoto.assetLocalId { continue }

            let label: String
            switch months {
            case 6: label = "半年前的今天"
            case 12: label = "一年前的今天"
            case 18: label = "一年半前"
            case 24: label = "两年前的今天"
            case 36: label = "三年前的今天"
            default: label = "\(months) 个月前"
            }

            result.append(Capsule(
                label: label,
                oldPhoto: oldPhoto,
                newPhoto: newPhoto,
                monthsAgo: months
            ))
        }
        return result
    }

    private func closestPhoto(to target: Date, within days: Int) -> PhotoEntry? {
        let limit = TimeInterval(days * 86400)
        return allPhotos.min { a, b in
            let da = abs(a.creationDate.timeIntervalSince(target))
            let db = abs(b.creationDate.timeIntervalSince(target))
            return da < db
        }.flatMap { photo in
            abs(photo.creationDate.timeIntervalSince(target)) <= limit ? photo : nil
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock.arrow.trianglehead.counterclockwise.rotate.90")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("还没有足够的历史照片来做时光对比")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("等时间线跨度超过半年后，这里就会出现\n「半年前 vs 现在」的并排对比。")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - 对比卡片

private struct CapsuleCard: View {
    let capsule: TimeCapsuleView.Capsule
    let baby: Baby

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(capsule.label)
                .font(.headline)

            HStack(spacing: 8) {
                VStack(spacing: 4) {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncPHAssetImage(
                            localIdentifier: capsule.oldPhoto.assetLocalId,
                            size: .thumbnail(200)
                        )
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if capsule.oldPhoto.isVideo {
                            VideoDurationBadge(duration: capsule.oldPhoto.duration)
                                .padding(6)
                        }
                    }

                    Text(AgeCalculator.age(
                        birthday: baby.birthday,
                        at: capsule.oldPhoto.creationDate
                    ).localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(Self.df.string(from: capsule.oldPhoto.creationDate))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)

                VStack(spacing: 4) {
                    ZStack(alignment: .bottomTrailing) {
                        AsyncPHAssetImage(
                            localIdentifier: capsule.newPhoto.assetLocalId,
                            size: .thumbnail(200)
                        )
                        .frame(height: 200)
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        if capsule.newPhoto.isVideo {
                            VideoDurationBadge(duration: capsule.newPhoto.duration)
                                .padding(6)
                        }
                    }

                    Text(AgeCalculator.age(
                        birthday: baby.birthday,
                        at: capsule.newPhoto.creationDate
                    ).localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                    Text(Self.df.string(from: capsule.newPhoto.creationDate))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M 月 d 日"
        return f
    }()
}
