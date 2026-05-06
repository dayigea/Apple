import SwiftData
import SwiftUI

/// 发育里程碑清单：按月龄分阶段展示，每项可勾选完成。
/// 当前阶段默认展开；过去 / 未来阶段折叠（可手动展开回顾或预览）。
struct DevelopmentChecklistView: View {

    @Bindable var baby: Baby
    @Environment(\.modelContext) private var context

    @State private var expandedStages: Set<String> = []

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                progressCard
                ForEach(DevelopmentMilestoneData.stages) { stage in
                    stageSection(stage)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("发育清单")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 默认展开当前阶段
            if expandedStages.isEmpty,
               let current = DevelopmentMilestoneData.currentStage(birthday: baby.birthday) {
                expandedStages.insert(current.id)
            }
        }
    }

    // MARK: - Progress card

    private var progressCard: some View {
        let current = DevelopmentMilestoneData.currentStage(birthday: baby.birthday)
        let totalCurrent = current?.allItems.count ?? 0
        let doneCurrent = current.map { stage in
            stage.allItems.filter { baby.isDevelopmentItemCompleted($0.id) }.count
        } ?? 0
        let totalAll = DevelopmentMilestoneData.stages.flatMap { $0.allItems }.count
        let doneAll = baby.completedDevelopmentItems.count

        return VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "checklist")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(current?.title ?? "")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(current?.monthRange ?? "")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            if totalCurrent > 0 {
                ProgressView(value: Double(doneCurrent), total: Double(totalCurrent)) {
                    HStack {
                        Text("当前阶段").font(.caption2).foregroundStyle(.secondary)
                        Spacer()
                        Text("\(doneCurrent) / \(totalCurrent)")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .progressViewStyle(.linear)
                .tint(.accentColor)
            }

            HStack {
                Text("累计完成")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(doneAll) / \(totalAll)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Stage section

    private func stageSection(_ stage: DevelopmentStage) -> some View {
        let isExpanded = Binding(
            get: { expandedStages.contains(stage.id) },
            set: { newValue in
                if newValue { expandedStages.insert(stage.id) }
                else { expandedStages.remove(stage.id) }
            }
        )
        let isCurrent = DevelopmentMilestoneData.currentStage(birthday: baby.birthday)?.id == stage.id
        let totalItems = stage.allItems.count
        let doneItems = stage.allItems.filter { baby.isDevelopmentItemCompleted($0.id) }.count

        return VStack(spacing: 0) {
            DisclosureGroup(isExpanded: isExpanded) {
                VStack(spacing: 12) {
                    ForEach(stage.categories) { category in
                        categoryBlock(category)
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: stage.icon)
                        .font(.title3)
                        .foregroundStyle(isCurrent ? Color.accentColor : .secondary)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(stage.title)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            if isCurrent {
                                Text("当前")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 1)
                                    .background(Color.accentColor.opacity(0.15))
                                    .foregroundStyle(Color.accentColor)
                                    .clipShape(Capsule())
                            }
                        }
                        Text("\(stage.monthRange) · \(doneItems)/\(totalItems)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
            .tint(.primary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Category block

    private func categoryBlock(_ category: DevelopmentCategory) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: category.icon)
                    .font(.caption)
                    .foregroundStyle(tintColor(for: category.tint))
                Text(category.name)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            VStack(spacing: 4) {
                ForEach(category.items) { item in
                    itemRow(item, tint: tintColor(for: category.tint))
                }
            }
        }
    }

    private func itemRow(_ item: DevelopmentItem, tint: Color) -> some View {
        let isDone = baby.isDevelopmentItemCompleted(item.id)
        let completedDate = baby.completedDevelopmentItems[item.id]
        return Button {
            baby.toggleDevelopmentItem(item.id)
            try? context.save()
            // 触觉反馈
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isDone ? tint : .tertiary)
                    .padding(.top, 1)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .strikethrough(isDone, color: .secondary)
                    if let detail = item.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if let completedDate {
                        Text(formatDate(completedDate))
                            .font(.caption2)
                            .foregroundStyle(tint)
                    }
                }
                Spacer(minLength: 4)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isDone ? tint.opacity(0.06) : Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func tintColor(for kind: DevTint) -> Color {
        switch kind {
        case .motor: return .orange
        case .fine: return .blue
        case .language: return .purple
        case .cognitive: return .indigo
        case .social: return .pink
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日 完成"
        return f.string(from: date)
    }
}
