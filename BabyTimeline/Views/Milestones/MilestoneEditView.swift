import SwiftData
import SwiftUI

/// 新建 / 编辑一个里程碑。
struct MilestoneEditView: View {

    let baby: Baby
    let milestone: Milestone?   // nil = 新建

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var linkedAssetLocalId: String?

    @State private var showingPhotoPicker = false

    private var isEditing: Bool { milestone != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("里程碑") {
                    TextField("标题（如：第一次走路）", text: $title)
                    DatePicker(
                        "发生日期",
                        selection: $date,
                        in: baby.birthday...Date.now,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "zh_CN"))
                    Text(AgeCalculator.age(birthday: baby.birthday, at: date).localized)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("备注") {
                    TextField("比如当时的心情或细节", text: $note, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("绑定照片（可选）") {
                    if let id = linkedAssetLocalId {
                        HStack(spacing: 12) {
                            AsyncPHAssetImage(localIdentifier: id, size: .thumbnail(60))
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            Text("已绑定一张照片").font(.footnote)
                            Spacer()
                            Button("取消绑定", role: .destructive) {
                                linkedAssetLocalId = nil
                            }
                            .font(.footnote)
                        }
                    } else {
                        Button {
                            showingPhotoPicker = true
                        } label: {
                            Label("从时间线里选一张", systemImage: "photo.on.rectangle")
                        }
                    }
                }
            }
            .navigationTitle(isEditing ? "编辑里程碑" : "新增里程碑")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear(perform: loadInitial)
            .sheet(isPresented: $showingPhotoPicker) {
                LinkedPhotoPickerView(linkedAssetLocalId: $linkedAssetLocalId)
            }
        }
    }

    // MARK: - 数据

    private func loadInitial() {
        guard let milestone else { return }
        title = milestone.title
        date = milestone.date
        note = milestone.note ?? ""
        linkedAssetLocalId = milestone.linkedAssetLocalId
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)
        let trimmedNote = note.trimmingCharacters(in: .whitespaces)

        if let milestone {
            milestone.title = trimmedTitle
            milestone.date = date
            milestone.note = trimmedNote.isEmpty ? nil : trimmedNote
            milestone.linkedAssetLocalId = linkedAssetLocalId
        } else {
            let m = Milestone(
                title: trimmedTitle,
                date: date,
                note: trimmedNote.isEmpty ? nil : trimmedNote,
                linkedAssetLocalId: linkedAssetLocalId
            )
            context.insert(m)
        }
        try? context.save()
        dismiss()
    }
}

// MARK: - 从时间线里选一张的 Picker

private struct LinkedPhotoPickerView: View {
    @Binding var linkedAssetLocalId: String?
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \PhotoEntry.creationDate, order: .reverse)
    private var entries: [PhotoEntry]

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 6)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(entries, id: \.assetLocalId) { entry in
                        Button {
                            linkedAssetLocalId = entry.assetLocalId
                            dismiss()
                        } label: {
                            AsyncPHAssetImage(
                                localIdentifier: entry.assetLocalId,
                                size: .thumbnail(120)
                            )
                            .frame(height: 100)
                            .clipped()
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                    }
                }
                .padding(.horizontal, 6)
            }
            .navigationTitle("选一张照片")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") { dismiss() }
                }
            }
        }
    }
}
