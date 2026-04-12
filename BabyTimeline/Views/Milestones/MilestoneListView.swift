import SwiftData
import SwiftUI

/// 成长里程碑列表：按日期升序显示所有手动记录的关键事件。
struct MilestoneListView: View {

    let baby: Baby

    @Environment(\.modelContext) private var context
    @Query(sort: \Milestone.date, order: .forward)
    private var milestones: [Milestone]

    @State private var editing: Milestone?
    @State private var showingNew = false

    var body: some View {
        NavigationStack {
            Group {
                if milestones.isEmpty {
                    EmptyMilestoneView { showingNew = true }
                } else {
                    List {
                        ForEach(milestones) { milestone in
                            Button {
                                editing = milestone
                            } label: {
                                MilestoneRow(baby: baby, milestone: milestone)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: delete)
                    }
                    .listStyle(.plain)
                }
            }
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
                MilestoneEditView(baby: baby, milestone: nil)
            }
            .sheet(item: $editing) { milestone in
                MilestoneEditView(baby: baby, milestone: milestone)
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            context.delete(milestones[index])
        }
        try? context.save()
    }
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
