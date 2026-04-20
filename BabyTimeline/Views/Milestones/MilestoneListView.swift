import SwiftData
import SwiftUI

/// 成长里程碑列表：
/// - 上半：**已记录** —— 父母手动填过的，按日期升序
/// - 下半：**建议记录** —— 由 `PhotoMilestoneSuggester` 直接从时间线照片的内容
///   推导出来：当某张照片的自动标签里出现 "雪 / 海滩 / 蛋糕 / 狗 …" 等触发词时，
///   就推荐对应的「第一次见到雪 / 第一次去海边 / 第一次吃蛋糕 / 第一次见到小狗」。
///   每条建议都已经带上了**那张真实照片**作为日期与封面来源，点一下就能保存。
struct MilestoneListView: View {

    let baby: Baby

    @Environment(\.modelContext) private var context
    @Query(sort: \Milestone.date, order: .forward)
    private var milestones: [Milestone]

    /// 时间线里的所有照片，建议生成器会从这里抽取「第一次出现 X」的真实证据。
    @Query(sort: \PhotoEntry.creationDate, order: .forward)
    private var photos: [PhotoEntry]

    @State private var editing: Milestone?
    @State private var showingNew = false
    /// 点击某条"建议"后跳进的预填表单
    @State private var preFilledDraft: MilestoneDraft?

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("成长里程碑")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingNew = true
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                }
                .sheet(isPresented: $showingNew) {
                    MilestoneEditView(baby: baby, milestone: nil, draft: nil)
                }
                .sheet(item: $editing) { milestone in
                    MilestoneEditView(baby: baby, milestone: milestone, draft: nil)
                }
                .sheet(item: $preFilledDraft) { draft in
                    MilestoneEditView(baby: baby, milestone: nil, draft: draft)
                }
        }
    }

    @ViewBuilder
    private var content: some View {
        let suggestions = PhotoMilestoneSuggester.suggestions(
            from: photos,
            baby: baby,
            existing: milestones
        )
        let grouped = PhotoMilestoneSuggester.grouped(suggestions)

        if milestones.isEmpty && suggestions.isEmpty {
            EmptyMilestoneView(hasPhotos: !photos.isEmpty) { showingNew = true }
        } else {
            List {
                if !milestones.isEmpty {
                    Section {
                        ForEach(milestones) { milestone in
                            Button {
                                editing = milestone
                            } label: {
                                MilestoneRow(baby: baby, milestone: milestone)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    } header: {
                        Text("已记录（\(milestones.count)）")
                    }
                }

                if !suggestions.isEmpty {
                    ForEach(grouped, id: \.category.id) { group in
                        Section {
                            ForEach(group.items) { suggestion in
                                Button {
                                    preFilledDraft = MilestoneDraft(
                                        title: suggestion.title,
                                        date: suggestion.date,
                                        note: suggestion.note,
                                        linkedAssetLocalId: suggestion.assetLocalId
                                    )
                                } label: {
                                    SuggestionRow(baby: baby, suggestion: suggestion)
                                }
                                .buttonStyle(.plain)
                            }
                        } header: {
                            Text("建议·\(group.category.label)（\(group.items.count)）")
                        }
                    }
                } else if !photos.isEmpty {
                    Section {
                        Text("时间线里没有触发任何建议——等更多照片入库后再回来看看。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } header: {
                        Text("建议")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(milestones[index])
        }
        try? context.save()
    }
}

// MARK: - 建议一条的预填草稿

struct MilestoneDraft: Identifiable {
    let id = UUID()
    let title: String
    let date: Date
    let note: String
    /// 来自建议的预绑定照片。从 `PhotoMilestoneSuggester` 来的建议必带；
    /// 用户从空白新建走过来时为 nil，由 `MilestoneEditView` 自动匹配。
    let linkedAssetLocalId: String?
}

// MARK: - 建议行：左边放真实照片缩略图，证明这条建议是有出处的

private struct SuggestionRow: View {
    let baby: Baby
    let suggestion: PhotoMilestoneSuggester.Suggestion

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AsyncPHAssetImage(localIdentifier: suggestion.assetLocalId, size: .thumbnail(70))
                .frame(width: 70, height: 70)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: suggestion.icon)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(4)
                        .background(Color.accentColor, in: Circle())
                        .padding(4)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(AgeCalculator.age(birthday: baby.birthday, at: suggestion.date).localized) · \(Self.dateFormatter.string(from: suggestion.date))")
                    .font(.caption)
                    .foregroundStyle(.tint)
                Text(suggestion.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
            Image(systemName: "plus.circle.fill")
                .foregroundStyle(.tint)
                .font(.title3)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy 年 M 月 d 日"
        return df
    }()
}

// MARK: - 已记录行

private struct MilestoneRow: View {
    let baby: Baby
    let milestone: Milestone

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if let id = milestone.linkedAssetLocalId {
                AsyncPHAssetImage(localIdentifier: id, size: .thumbnail(70))
                    .frame(width: 70, height: 70)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "star.fill")
                            .foregroundStyle(.tint)
                    )
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.headline)
                Text(Self.dateFormatter.string(from: milestone.date))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(AgeCalculator.age(birthday: baby.birthday, at: milestone.date).localized)
                    .font(.caption)
                    .foregroundStyle(.tint)
                if let note = milestone.note, !note.isEmpty {
                    Text(note)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "zh_CN")
        df.dateFormat = "yyyy 年 M 月 d 日"
        return df
    }()
}

// MARK: - 空状态

private struct EmptyMilestoneView: View {
    let hasPhotos: Bool
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text(hasPhotos
                 ? "还没有记录任何里程碑\n时间线里也还没有触发自动建议"
                 : "还没有记录任何里程碑\n等时间线里有照片后会自动给出建议")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Button(action: onAdd) {
                Label("添加里程碑", systemImage: "plus")
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
