import SwiftData
import SwiftUI

/// 成长里程碑列表：
/// - 上半：**已记录** —— 父母手动填过的，按日期升序
/// - 下半：**建议记录** —— 从 `MilestoneCatalog` 里按宝宝月龄自动挑出的发育阶段提醒，
///   每条都可以一键转成正式的 `Milestone`
struct MilestoneListView: View {

    let baby: Baby

    @Environment(\.modelContext) private var context
    @Query(sort: \Milestone.date, order: .forward)
    private var milestones: [Milestone]

    /// 时间线里的所有照片，供「建议 → 自动匹配一张最近的照片」用
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
        let suggestions = MilestoneSuggester.suggestions(for: baby, existing: milestones)

        if milestones.isEmpty && suggestions.isEmpty {
            EmptyMilestoneView { showingNew = true }
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
                    Section {
                        ForEach(suggestions) { suggestion in
                            Button {
                                // 照片匹配在 MilestoneEditView.loadInitial 里统一做，
                                // 避免这里预算 + EditView 再算一次产生两个不同结果
                                preFilledDraft = MilestoneDraft(
                                    title: suggestion.entry.title,
                                    date: suggestion.suggestedDate,
                                    note: suggestion.entry.detail
                                )
                            } label: {
                                SuggestionRow(baby: baby, suggestion: suggestion)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        Text("建议记录（按月龄推算）")
                    } footer: {
                        Text("根据发育阶段给的提醒，不是固定时间。点一下可以快速添加，App 会预填标题、日期、说明，并从时间线里自动配一张最接近那个日期的照片。")
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
}

// MARK: - 建议行

private struct SuggestionRow: View {
    let baby: Baby
    let suggestion: MilestoneSuggester.Suggestion

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: suggestion.entry.icon)
                    .foregroundStyle(.tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(suggestion.entry.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("约 \(suggestion.entry.expectedMonths) 月龄 · \(Self.dateFormatter.string(from: suggestion.suggestedDate))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(suggestion.entry.detail)
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
        df.dateFormat = "yyyy 年 M 月"
        return df
    }()
}

// MARK: - 单行

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
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.circle")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("还没有记录任何里程碑\n点击下面按钮添加第一个")
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
