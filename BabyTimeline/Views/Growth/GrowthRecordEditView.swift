import SwiftData
import SwiftUI

struct GrowthRecordEditView: View {

    let baby: Baby
    let record: GrowthRecord?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var date: Date = .now
    @State private var heightText = ""
    @State private var weightText = ""
    @State private var headText = ""
    @State private var note = ""

    private var isEditing: Bool { record != nil }

    private var canSave: Bool {
        !heightText.isEmpty || !weightText.isEmpty || !headText.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("测量日期") {
                    DatePicker(
                        "日期",
                        selection: $date,
                        in: baby.birthday...Date.now,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    Text(AgeCalculator.age(birthday: baby.birthday, at: date).localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section {
                    HStack {
                        Text("身高")
                        Spacer()
                        TextField("cm", text: $heightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("体重")
                        Spacer()
                        TextField("kg", text: $weightText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("头围")
                        Spacer()
                        TextField("cm", text: $headText)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("测量数据")
                } footer: {
                    Text("填你有的就行，不需要三项全填。")
                }

                Section("备注") {
                    TextField("比如在哪个医院测的", text: $note, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(isEditing ? "编辑记录" : "添加测量")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: loadInitial)
        }
    }

    private func loadInitial() {
        guard let record else { return }
        date = record.date
        if let h = record.heightCM { heightText = formatNumber(h) }
        if let w = record.weightKG { weightText = formatNumber(w) }
        if let hc = record.headCircumCM { headText = formatNumber(hc) }
        note = record.note ?? ""
    }

    private func save() {
        let h = Double(heightText)
        let w = Double(weightText)
        let hc = Double(headText)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)

        if let record {
            record.date = date
            record.heightCM = h
            record.weightKG = w
            record.headCircumCM = hc
            record.note = trimmedNote.isEmpty ? nil : trimmedNote
        } else {
            let r = GrowthRecord(
                date: date,
                heightCM: h,
                weightKG: w,
                headCircumCM: hc,
                note: trimmedNote.isEmpty ? nil : trimmedNote
            )
            context.insert(r)
        }
        try? context.save()
        dismiss()
    }

    private func formatNumber(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }
}
