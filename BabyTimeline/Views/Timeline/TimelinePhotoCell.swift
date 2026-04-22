import SwiftUI

/// 时间线里每条记录的单 Cell：左图 + 右文（日期 / 年龄 / 地点 / 自动标签）。
/// 视频会在缩略图右下角显示时长标签。
struct TimelinePhotoCell: View {
    let baby: Baby
    let entry: PhotoEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack(alignment: .bottomTrailing) {
                AsyncPHAssetImage(
                    localIdentifier: entry.assetLocalId,
                    size: .thumbnail(88)
                )
                .frame(width: 88, height: 88)
                .clipShape(RoundedRectangle(cornerRadius: 10))

                if entry.isVideo {
                    VideoDurationBadge(duration: entry.duration)
                        .padding(4)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(Self.dateFormatter.string(from: entry.creationDate))
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(AgeCalculator.age(birthday: baby.birthday, at: entry.creationDate).localized)
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                if let place = entry.placeName, !place.isEmpty {
                    Label(place, systemImage: "mappin.and.ellipse")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                if !entry.autoTags.isEmpty {
                    Text(entry.autoTags.prefix(3).joined(separator: " · "))
                        .font(.caption)
                        .foregroundStyle(.tint)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)

            if entry.isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
        .padding(.vertical, 4)
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy 年 M 月 d 日"
        return df
    }()
}

/// 视频缩略图右下角的时长标签，仿系统相册样式。
struct VideoDurationBadge: View {
    let duration: Double

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "play.fill")
                .font(.system(size: 8))
            Text(formatted)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(.black.opacity(0.6), in: Capsule())
    }

    private var formatted: String {
        let total = Int(duration)
        let m = total / 60
        let s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }
}
