import SwiftData
import SwiftUI

/// 时间线主界面：按年龄阶段分组展示所有已入库的照片。
struct TimelineView: View {

    let baby: Baby

    @Environment(\.modelContext) private var context
    @Query(sort: \PhotoEntry.creationDate, order: .forward)
    private var entries: [PhotoEntry]

    @State private var importer = PhotoImporter()

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    EmptyTimelineView(phase: importer.phase) {
                        Task { await importer.run(baby: baby, context: context) }
                    }
                } else {
                    TimelineList(baby: baby, entries: entries)
                }
            }
            .navigationTitle("\(baby.name) 的成长时光")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    ImportStatusButton(phase: importer.phase) {
                        Task { await importer.run(baby: baby, context: context) }
                    }
                }
            }
        }
    }
}

// MARK: - 分段列表

private struct TimelineList: View {
    let baby: Baby
    let entries: [PhotoEntry]

    var body: some View {
        // 按阶段分组并排序
        let sections = Self.groupByStage(entries: entries, birthday: baby.birthday)

        List {
            ForEach(sections, id: \.stage) { section in
                Section {
                    // 照片流：单列大图，便于回忆
                    ForEach(section.entries, id: \.assetLocalId) { entry in
                        NavigationLink {
                            PhotoDetailView(baby: baby, entry: entry)
                        } label: {
                            TimelinePhotoCell(baby: baby, entry: entry)
                        }
                    }
                } header: {
                    TimelineSectionHeader(
                        stage: section.stage,
                        count: section.entries.count
                    )
                }
            }
        }
        .listStyle(.plain)
    }

    // MARK: - 分组

    private struct SectionBucket {
        let stage: AgeCalculator.Stage
        let entries: [PhotoEntry]
    }

    private static func groupByStage(
        entries: [PhotoEntry],
        birthday: Date
    ) -> [SectionBucket] {
        var groups: [AgeCalculator.Stage: [PhotoEntry]] = [:]
        for entry in entries {
            let stage = AgeCalculator.stage(birthday: birthday, at: entry.creationDate)
            groups[stage, default: []].append(entry)
        }
        return groups
            .map { SectionBucket(stage: $0.key, entries: $0.value) }
            .sorted { $0.stage < $1.stage }
    }
}

// MARK: - 空状态

private struct EmptyTimelineView: View {
    let phase: PhotoImporter.Phase
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 32)

            if case .scanning(let processed, let total) = phase {
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                    .frame(maxWidth: 240)
                Text("已处理 \(processed) / \(total)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if case .geocoding(let processed, let total) = phase {
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                    .frame(maxWidth: 240)
                Text("正在补全地点信息 \(processed) / \(total)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if showStartButton {
                Button(action: onStart) {
                    Text("开始扫描相册")
                        .fontWeight(.semibold)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var showStartButton: Bool {
        switch phase {
        case .idle, .finished, .failed:
            return true
        case .requestingAuth, .scanning, .geocoding:
            return false
        }
    }

    private var message: String {
        switch phase {
        case .idle:
            return "还没有照片\n点击下面的按钮开始扫描相册"
        case .requestingAuth:
            return "正在请求相册权限…"
        case .scanning:
            return "正在整理相册里的照片和视频…\n只纳入含有人脸的内容"
        case .geocoding:
            return "正在补全地点信息…"
        case .finished(let inserted, _):
            return inserted == 0
                ? "没有找到符合条件的照片或视频\n确认相册里有出生之后、含有人脸的内容"
                : "已整理 \(inserted) 条记录"
        case .failed(let reason):
            return reason
        }
    }
}

// MARK: - 右上角按钮

private struct ImportStatusButton: View {
    let phase: PhotoImporter.Phase
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            switch phase {
            case .scanning, .geocoding:
                ProgressView()
            default:
                Image(systemName: "arrow.clockwise")
            }
        }
        .disabled(isRunning)
    }

    private var isRunning: Bool {
        if case .scanning = phase { return true }
        if case .geocoding = phase { return true }
        if case .requestingAuth = phase { return true }
        return false
    }
}
