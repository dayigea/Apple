import SwiftData
import SwiftUI

/// 新建 / 编辑一个里程碑。
///
/// 三种打开方式：
/// - `milestone != nil` → 编辑已有里程碑
/// - `milestone == nil, draft == nil` → 全空白新建
/// - `milestone == nil, draft != nil` → 从"建议"点进来，预填标题/日期/说明
///
/// 照片自动绑定：新建里程碑时（空白或草稿），会用 `MilestonePhotoMatcher`
/// 从时间线里自动挑一张离当前日期最近的照片贴上去。用户改日期时，只要
/// 还没主动选过照片，自动匹配会跟着重跑。只要用户手动点了「更换」或
/// 「取消绑定」，`photoWasUserEdited = true`，自动逻辑就不再干预。
struct MilestoneEditView: View {

    let baby: Baby
    let milestone: Milestone?   // nil = 新建
    let draft: MilestoneDraft?  // nil = 不预填

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    /// 时间线里所有照片，用来做自动匹配
    @Query(sort: \PhotoEntry.creationDate, order: .forward)
    private var photos: [PhotoEntry]

    @State private var title: String = ""
    @State private var date: Date = .now
    @State private var note: String = ""
    @State private var linkedAssetLocalId: String?

    /// 用户是否主动碰过「绑定照片」区？
    /// - `false`：仍在自动匹配模式，日期一变自动重配
    /// - `true`：用户点过「更换」/「取消绑定」/ 编辑已有记录，自动逻辑交棒给用户
    @State private var photoWasUserEdited = false

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

                Section {
                    if let id = linkedAssetLocalId {
                        HStack(spacing: 12) {
                            AsyncPHAssetImage(localIdentifier: id, size: .thumbnail(60))
                                .frame(width: 60, height: 60)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(photoWasUserEdited
                                     ? "已绑定一张照片"
                                     : "已自动匹配附近的一张照片")
                                    .font(.footnote)
                                Text(photoWasUserEdited
                                     ? "手动选择"
                                     : "可以点下面更换或取消")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        HStack {
                            Button {
                                photoWasUserEdited = true
                                showingPhotoPicker = true
                            } label: {
                                Label("更换照片", systemImage: "photo.stack")
                            }
                            .font(.footnote)
                            Spacer()
                            Button(role: .destructive) {
                                linkedAssetLocalId = nil
                                photoWasUserEdited = true
                            } label: {
                                Label("取消绑定", systemImage: "xmark.circle")
                            }
                            .font(.footnote)
                        }
                    } else {
                        Button {
                            photoWasUserEdited = true
                            showingPhotoPicker = true
                        } label: {
                            Label("从时间线里选一张", systemImage: "photo.on.rectangle")
                        }
                        if !photos.isEmpty {
                            Button {
                                photoWasUserEdited = false
                                autoLinkPhotoFromTimeline()
                            } label: {
                                Label("自动匹配最接近日期的一张", systemImage: "wand.and.stars")
                            }
                        }
                    }
                } header: {
                    Text("绑定照片（可选）")
                } footer: {
                    if !isEditing && !photoWasUserEdited {
                        Text("默认会从时间线里挑一张拍摄日期最接近里程碑日期的照片。改日期时会自动跟着换，除非你自己手动改过。")
                    } else {
                        Text("绑定的照片会显示在时间线和里程碑列表里。")
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
            .onChange(of: date) {
                // 日期改了，只要用户没主动动过照片，就自动重新匹配
                if !isEditing && !photoWasUserEdited {
                    autoLinkPhotoFromTimeline()
                }
            }
            .sheet(isPresented: $showingPhotoPicker) {
                LinkedPhotoPickerView(linkedAssetLocalId: $linkedAssetLocalId)
            }
        }
    }

    // MARK: - 数据

    private func loadInitial() {
        if let milestone {
            // 编辑已有：原样载入，把自动匹配开关交给用户
            title = milestone.title
            date = milestone.date
            note = milestone.note ?? ""
            linkedAssetLocalId = milestone.linkedAssetLocalId
            photoWasUserEdited = true
            return
        }
        if let draft {
            title = draft.title
            // 如果建议日期是未来（万一系统时钟不对），压到今天
            date = min(draft.date, .now)
            // 如果建议日期早于生日（不应该发生），压到生日
            date = max(date, baby.birthday)
            note = draft.note
            // 建议里可能已经预先配好了一张
            linkedAssetLocalId = draft.linkedAssetLocalId
        }
        // 空白新建或 draft 没配到 → 根据当前日期立即自动配一张
        if linkedAssetLocalId == nil {
            autoLinkPhotoFromTimeline()
        }
    }

    private func autoLinkPhotoFromTimeline() {
        linkedAssetLocalId = MilestonePhotoMatcher.bestMatchAssetId(for: date, in: photos)
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
