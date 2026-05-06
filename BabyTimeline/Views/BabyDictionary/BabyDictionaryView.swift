import SwiftData
import SwiftUI

/// 宝宝词典：按日期倒序展示宝宝说过的萌句，可附录音。
struct BabyDictionaryView: View {

    @Environment(\.modelContext) private var context
    @Query(sort: \BabyWord.dateSaid, order: .reverse) private var words: [BabyWord]

    @State private var showingNew = false
    @State private var editingWord: BabyWord?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsCard
                if words.isEmpty {
                    emptyState
                } else {
                    wordsList
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("宝宝词典")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingNew = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NavigationStack {
                BabyDictionaryEditView(word: nil)
            }
        }
        .sheet(item: $editingWord) { word in
            NavigationStack {
                BabyDictionaryEditView(word: word)
            }
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("已记录")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(words.count) 个萌句")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Spacer()
            Image(systemName: "text.bubble.fill")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Empty

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "text.bubble")
                .font(.system(size: 44))
                .foregroundStyle(Color.accentColor.opacity(0.5))
            Text("还没有记录")
                .font(.subheadline)
                .fontWeight(.semibold)
            Text("宝宝说过有趣的话？\n点右上角 + 记下来，可以附 30 秒录音。")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
        .padding(.horizontal, 14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - List

    private var wordsList: some View {
        let grouped = Dictionary(grouping: words) { word in
            monthKey(word.dateSaid)
        }
        let keys = grouped.keys.sorted(by: >)
        return VStack(spacing: 12) {
            ForEach(keys, id: \.self) { key in
                let group = (grouped[key] ?? []).sorted { $0.dateSaid > $1.dateSaid }
                VStack(alignment: .leading, spacing: 8) {
                    Text(key)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                    VStack(spacing: 8) {
                        ForEach(group) { word in
                            wordRow(word)
                        }
                    }
                }
            }
        }
    }

    private func wordRow(_ word: BabyWord) -> some View {
        Button {
            editingWord = word
        } label: {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(word.text)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                    HStack(spacing: 8) {
                        Text(formatDate(word.dateSaid))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        if word.audioData != nil {
                            HStack(spacing: 3) {
                                Image(systemName: "waveform")
                                    .font(.caption2)
                                if let dur = word.audioDuration {
                                    Text(String(format: "%.0fs", dur))
                                        .font(.caption2)
                                }
                            }
                            .foregroundStyle(Color.accentColor)
                        }
                    }
                    if let note = word.note, !note.isEmpty {
                        Text(note)
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
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                context.delete(word)
                try? context.save()
            } label: {
                Label("删除", systemImage: "trash")
            }
        }
    }

    // MARK: - Helpers

    private func monthKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月"
        return f.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }
}
