import SwiftUI

/// 时间线里每一张照片的单 Cell：左图 + 右文（日期 / 年龄 / 地点 / 自动标签）。
struct TimelinePhotoCell: View {
    let baby: Baby
    let entry: PhotoEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncPHAssetImage(
                localIdentifier: entry.assetLocalId,
                size: .thumbnail(88)
            )
            .frame(width: 88, height: 88)
            .clipShape(RoundedRectangle(cornerRadius: 10))

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
