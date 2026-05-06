import SwiftData
import SwiftUI

/// 单个儿保 / 疫苗事件的详情：可标记为完成、记录测量值与备注。
struct PediatricEventDetailView: View {

    let event: PediatricEvent
    let existing: PediatricRecord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var completedAt: Date = .now
    @State private var heightStr: String = ""
    @State private var weightStr: String = ""
    @State private var headStr: String = ""
    @State private var notes: String = ""
    @State private var location: String = ""
    @State private var hasInitialized = false

    var body: some View {
        Form {
            Section {
                LabeledContent("事件", value: event.title)
                LabeledContent("推荐月龄", value: event.ageLabel)
                if let detail = event.detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("完成信息") {
                DatePicker(
                    "完成日期",
                    selection: $completedAt,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .environment(\.locale, Locale(identifier: "zh_CN"))

                TextField("接种 / 体检地点", text: $location)
            }

            if event.kind == .checkup {
                Section("体格数据（可选）") {
                    measurementRow(label: "身高", unit: "cm", text: $heightStr)
                    measurementRow(label: "体重", unit: "kg", text: $weightStr)
                    measurementRow(label: "头围", unit: "cm", text: $headStr)
                }
            }

            Section("备注") {
                TextField("医生建议、反应等", text: $notes, axis: .vertical)
                    .lineLimit(2...6)
            }

            if existing != nil {
                Section {
                    Button(role: .destructive) {
                        deleteRecord()
                    } label: {
                        Label("撤销完成", systemImage: "arrow.uturn.backward")
                    }
                }
            }
        }
        .navigationTitle(event.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(existing == nil ? "标记完成" : "保存") {
                    save()
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear { initializeIfNeeded() }
    }

    // MARK: - Helpers

    private func measurementRow(label: String, unit: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func initializeIfNeeded() {
        guard !hasInitialized else { return }
        hasInitialized = true
        guard let r = existing else { return }
        completedAt = r.completedAt
        heightStr = r.heightCm.map { String($0) } ?? ""
        weightStr = r.weightKg.map { String($0) } ?? ""
        headStr = r.headCircumferenceCm.map { String($0) } ?? ""
        notes = r.notes ?? ""
        location = r.location ?? ""
    }

    private func save() {
        let h = Double(heightStr.trimmingCharacters(in: .whitespaces))
        let w = Double(weightStr.trimmingCharacters(in: .whitespaces))
        let hc = Double(headStr.trimmingCharacters(in: .whitespaces))
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedLoc = location.trimmingCharacters(in: .whitespacesAndNewlines)

        if let r = existing {
            r.completedAt = completedAt
            r.heightCm = h
            r.weightKg = w
            r.headCircumferenceCm = hc
            r.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            r.location = trimmedLoc.isEmpty ? nil : trimmedLoc
        } else {
            let r = PediatricRecord(
                scheduleEventId: event.id,
                completedAt: completedAt,
                heightCm: h,
                weightKg: w,
                headCircumferenceCm: hc,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                location: trimmedLoc.isEmpty ? nil : trimmedLoc
            )
            context.insert(r)
        }
        try? context.save()
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        dismiss()
    }

    private func deleteRecord() {
        guard let r = existing else { return }
        context.delete(r)
        try? context.save()
        dismiss()
    }
}
