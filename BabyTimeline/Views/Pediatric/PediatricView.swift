import SwiftData
import SwiftUI

/// 儿保 / 疫苗主页：按时间表展示每个事件的完成状态。
/// - 顶部：当前推荐做的（接近月龄）
/// - 下方：按月龄分组列出所有事件
struct PediatricView: View {

    let baby: Baby

    @Environment(\.modelContext) private var context
    @Query private var records: [PediatricRecord]

    @State private var filter: Filter = .all

    enum Filter: String, CaseIterable, Identifiable {
        case all = "全部"
        case checkup = "儿保"
        case vaccine = "疫苗"
        var id: String { rawValue }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                upcomingCard
                filterPicker
                eventsList
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("体检 / 疫苗")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Computed

    private var babyAgeMonths: Int {
        Calendar.current.dateComponents([.month], from: baby.birthday, to: .now).month ?? 0
    }

    private var recordById: [String: PediatricRecord] {
        Dictionary(uniqueKeysWithValues: records.map { ($0.scheduleEventId, $0) })
    }

    /// 待办：未来 3 月内或已经"过期未做"的，不区分类型
    private var upcomingEvents: [PediatricEvent] {
        let allUndone = PediatricSchedule.events.filter {
            recordById[$0.id] == nil && $0.category != .optional
        }
        // 推荐显示：当前月龄 -3 到 +3 月内，并且没做的
        let recent = allUndone.filter { abs($0.ageMonths - babyAgeMonths) <= 3 }
        if !recent.isEmpty { return recent.sorted { $0.ageMonths < $1.ageMonths } }
        // 没有近期项时显示下一个未做的
        return allUndone.filter { $0.ageMonths >= babyAgeMonths }.prefix(2).map { $0 }
    }

    private var filteredEvents: [PediatricEvent] {
        switch filter {
        case .all: return PediatricSchedule.events
        case .checkup: return PediatricSchedule.events.filter { $0.kind == .checkup }
        case .vaccine: return PediatricSchedule.events.filter { $0.kind == .vaccine }
        }
    }

    // MARK: - Upcoming card

    @ViewBuilder
    private var upcomingCard: some View {
        if upcomingEvents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                    Text("近期没有待办")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                Text("所有近期儿保和疫苗都已记录完成。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(.orange)
                    Text("近期待办")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                }
                ForEach(upcomingEvents.prefix(3)) { event in
                    NavigationLink {
                        PediatricEventDetailView(
                            event: event,
                            existing: recordById[event.id]
                        )
                    } label: {
                        upcomingRow(event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func upcomingRow(_ event: PediatricEvent) -> some View {
        let dueLabel = dueLabel(for: event)
        return HStack(spacing: 10) {
            Image(systemName: kindIcon(event.kind))
                .font(.callout)
                .foregroundStyle(kindColor(event.kind))
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Text("\(event.ageLabel) · \(dueLabel)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Filter

    private var filterPicker: some View {
        Picker("", selection: $filter) {
            ForEach(Filter.allCases) { f in
                Text(f.rawValue).tag(f)
            }
        }
        .pickerStyle(.segmented)
    }

    // MARK: - Events list

    private var eventsList: some View {
        let grouped = Dictionary(grouping: filteredEvents) { $0.ageMonths }
        let sortedKeys = grouped.keys.sorted()
        return VStack(spacing: 12) {
            ForEach(sortedKeys, id: \.self) { months in
                let events = grouped[months] ?? []
                eventGroup(ageMonths: months, events: events)
            }
        }
    }

    private func eventGroup(ageMonths months: Int, events: [PediatricEvent]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(monthsLabel(months))
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                if babyAgeMonths >= months {
                    Text("已过")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.15))
                        .foregroundStyle(.secondary)
                        .clipShape(Capsule())
                } else if babyAgeMonths >= months - 3 {
                    Text("即将")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .clipShape(Capsule())
                }
                Spacer()
            }
            VStack(spacing: 4) {
                ForEach(events) { event in
                    NavigationLink {
                        PediatricEventDetailView(
                            event: event,
                            existing: recordById[event.id]
                        )
                    } label: {
                        eventRow(event)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func eventRow(_ event: PediatricEvent) -> some View {
        let record = recordById[event.id]
        let isDone = record != nil
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: isDone ? "checkmark.circle.fill" : kindIcon(event.kind))
                .font(.callout)
                .foregroundStyle(isDone ? .green : kindColor(event.kind))
                .frame(width: 22)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(event.title)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                    if event.category == .optional {
                        Text("自费")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(Color.purple.opacity(0.12))
                            .foregroundStyle(.purple)
                            .clipShape(Capsule())
                    }
                }
                if isDone, let date = record?.completedAt {
                    Text("已完成 · \(formatDate(date))")
                        .font(.caption2)
                        .foregroundStyle(.green)
                } else if let detail = event.detail {
                    Text(detail)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(isDone ? Color.green.opacity(0.04) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Helpers

    private func kindIcon(_ kind: PediatricEvent.Kind) -> String {
        switch kind {
        case .checkup: return "stethoscope"
        case .vaccine: return "syringe"
        }
    }

    private func kindColor(_ kind: PediatricEvent.Kind) -> Color {
        switch kind {
        case .checkup: return .blue
        case .vaccine: return .pink
        }
    }

    private func monthsLabel(_ months: Int) -> String {
        if months == 0 { return "出生时" }
        if months < 12 { return "\(months) 月" }
        let y = months / 12
        let m = months % 12
        return m == 0 ? "\(y) 岁" : "\(y) 岁 \(m) 月"
    }

    private func dueLabel(for event: PediatricEvent) -> String {
        let diff = event.ageMonths - babyAgeMonths
        if diff > 0 { return "还有 \(diff) 个月到时" }
        if diff == 0 { return "本月该做" }
        return "已过 \(-diff) 个月" + "，建议尽快"
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy年M月d日"
        return f.string(from: date)
    }
}
