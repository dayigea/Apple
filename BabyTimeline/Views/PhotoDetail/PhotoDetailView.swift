import AVKit
import Photos
import SwiftData
import SwiftUI

/// 照片 / 视频的详情页：大图或视频播放器 + 年龄 / 日期 / 地点 / 标签 / 备注 / 收藏。
///
/// 工具栏里右上角是「收藏」，左侧的「…」菜单里提供「从时间线里移除」——
/// 把这条记录的 `PhotoEntry` 从本地库里删掉，并顺带把所有指向它的
/// 里程碑 `linkedAssetLocalId` 清空。系统相册里的原文件不会动。
struct PhotoDetailView: View {

    let baby: Baby
    @Bindable var entry: PhotoEntry

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var showingRemoveConfirm = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 大图 or 视频播放器
                if entry.isVideo {
                    VideoPlayerView(localIdentifier: entry.assetLocalId)
                        .aspectRatio(16/9, contentMode: .fit)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    AsyncPHAssetImage(
                        localIdentifier: entry.assetLocalId,
                        size: .fullSize
                    )
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }

                // 核心信息
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Text(Self.dateFormatter.string(from: entry.creationDate))
                            .font(.title3)
                            .fontWeight(.semibold)
                        if entry.isVideo {
                            Label(Self.formatDuration(entry.duration), systemImage: "video.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(.blue.opacity(0.7), in: Capsule())
                        }
                    }

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
        .navigationTitle(entry.isVideo ? "视频详情" : "照片详情")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        entry.isFavorite.toggle()
                        try? context.save()
                    } label: {
                        Label(
                            entry.isFavorite ? "取消收藏" : "收藏",
                            systemImage: entry.isFavorite ? "star.slash" : "star"
                        )
                    }
                    Divider()
                    Button(role: .destructive) {
                        showingRemoveConfirm = true
                    } label: {
                        Label("从时间线里移除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .confirmationDialog(
            entry.isVideo ? "把这段视频从时间线里移除？" : "把这张照片从时间线里移除？",
            isPresented: $showingRemoveConfirm,
            titleVisibility: .visible
        ) {
            Button("移除", role: .destructive) { removeFromTimeline() }
            Button("取消", role: .cancel) {}
        } message: {
            Text("只会从 App 里删掉这条记录，系统相册的原始文件不会动。绑定的里程碑会变成「未绑定」，但里程碑本身不会被删除。")
        }
        .onDisappear { try? context.save() }
    }

    // MARK: - 移除

    private func removeFromTimeline() {
        let assetId = entry.assetLocalId
        // 先解绑所有指向这张照片的里程碑，避免留下死链接
        let descriptor = FetchDescriptor<Milestone>(
            predicate: #Predicate { $0.linkedAssetLocalId == assetId }
        )
        if let linkedMilestones = try? context.fetch(descriptor) {
            for milestone in linkedMilestones {
                milestone.linkedAssetLocalId = nil
            }
        }
        context.delete(entry)
        try? context.save()
        dismiss()
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

    private static func formatDuration(_ seconds: Double) -> String {
        let total = Int(seconds)
        let m = total / 60
        let s = total % 60
        return m > 0 ? String(format: "%d:%02d", m, s) : String(format: "0:%02d", s)
    }
}

// MARK: - 视频播放器

/// 通过 PHAsset localIdentifier 加载并播放视频。
private struct VideoPlayerView: View {
    let localIdentifier: String

    @State private var player: AVPlayer?
    @State private var isLoading = true

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
            } else if isLoading {
                Color(.secondarySystemBackground)
                    .overlay(ProgressView())
            } else {
                Color(.secondarySystemBackground)
                    .overlay(
                        Image(systemName: "video.slash")
                            .font(.title)
                            .foregroundStyle(.secondary)
                    )
            }
        }
        .task(id: localIdentifier) {
            await load()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }

        guard let asset = PhotoLibraryService.asset(withLocalIdentifier: localIdentifier) else {
            return
        }
        guard let playerItem = await PhotoLibraryService.requestPlayerItem(for: asset) else {
            return
        }
        player = AVPlayer(playerItem: playerItem)
    }
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
