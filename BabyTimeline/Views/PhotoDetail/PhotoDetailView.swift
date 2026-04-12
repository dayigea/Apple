import SwiftData
import SwiftUI

/// 单张照片的详情页：大图 + 年龄 / 日期 / 地点 / 标签 / 备注 / 收藏。
struct PhotoDetailView: View {

    let baby: Baby
    @Bindable var entry: PhotoEntry

    @Environment(\.modelContext) private var context

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 大图
                AsyncPHAssetImage(
                    localIdentifier: entry.assetLocalId,
                    size: .fullSize
                )
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // 核心信息
                VStack(alignment: .leading, spacing: 8) {
                    Text(Self.dateFormatter.string(from: entry.creationDate))
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text(AgeCalculator.age(birthday: baby.birthday, at: entry.creationDate).localized)
                        .font(.headline)
                        .foregroundStyle(.secondary)

                    if let place = entry.placeName, !place.isEmpty {
                        Label(place, systemImage: "mappin.and.ellipse")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                // 自动标签
                if !entry.autoTags.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("画面里有")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        TagCloud(tags: entry.autoTags)
                    }
                }

                Divider()

                // 备注
                VStack(alignment: .leading, spacing: 6) {
                    Text("备注")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("写一点当时的故事…", text: noteBinding, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        .navigationTitle("照片详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    entry.isFavorite.toggle()
                    try? context.save()
                } label: {
                    Image(systemName: entry.isFavorite ? "star.fill" : "star")
                        .foregroundStyle(entry.isFavorite ? .yellow : .primary)
                }
            }
        }
        .onDisappear { try? context.save() }
    }

    // MARK: - Helpers

    private var noteBinding: Binding<String> {
        Binding(
            get: { entry.note ?? "" },
            set: { entry.note = $0.isEmpty ? nil : $0 }
        )
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy 年 M 月 d 日 EEEE"
        return df
    }()
}

// MARK: - 简易标签云

private struct TagCloud: View {
    let tags: [String]

    var body: some View {
        // FlowLayout 需要 iOS 16+，这里用简单换行 HStack 代替
        WrappingHStack(items: tags) { tag in
            Text(tag)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.15), in: Capsule())
                .foregroundStyle(Color.accentColor)
        }
    }
}

/// 一个非常简易的自动换行容器，用 SwiftUI Layout 协议实现。
private struct WrappingHStack<Item: Hashable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content

    init(items: [Item], @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.content = content
    }

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(items, id: \.self) { item in
                content(item)
            }
        }
    }
}

/// 一个最小可用的 FlowLayout（按行从左到右摆，宽度不够就换行）。
private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = computeRows(maxWidth: maxWidth, subviews: subviews)
        let height = rows
            .map { $0.maxY }
            .max() ?? 0
        return CGSize(width: maxWidth.isFinite ? maxWidth : rows.first?.maxX ?? 0,
                      height: height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = computeRows(maxWidth: bounds.width, subviews: subviews)
        for row in rows {
            for item in row.items {
                let origin = CGPoint(x: bounds.minX + item.x, y: bounds.minY + item.y)
                subviews[item.index].place(
                    at: origin,
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct RowItem {
        let index: Int
        let size: CGSize
        let x: CGFloat
        let y: CGFloat
    }

    private struct Row {
        var items: [RowItem] = []
        var maxX: CGFloat = 0
        var maxY: CGFloat = 0
    }

    private func computeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for (index, sub) in subviews.enumerated() {
            let size = sub.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                // 换行
                y += rowHeight + spacing
                x = 0
                rowHeight = 0
                rows.append(Row())
            }
            rows[rows.count - 1].items.append(
                RowItem(index: index, size: size, x: x, y: y)
            )
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            rows[rows.count - 1].maxX = max(rows[rows.count - 1].maxX, x)
            rows[rows.count - 1].maxY = y + rowHeight
        }
        return rows
    }
}
