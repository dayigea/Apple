import PhotosUI
import SwiftData
import SwiftUI

/// 设置页：
/// - 查看/修改宝宝资料
/// - 重新扫描相册
/// - 清空本地记录（不动系统相册）
struct SettingsView: View {

    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context
    @Query private var photos: [PhotoEntry]
    @Query private var milestones: [Milestone]

    @State private var avatarItem: PhotosPickerItem?
    @State private var importer = PhotoImporter()
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                // 宝宝资料
                Section("宝宝资料") {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            AvatarCircle(data: baby.avatarData)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)

                    TextField("姓名", text: $baby.name)

                    DatePicker(
                        "生日",
                        selection: $baby.birthday,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "zh_CN"))

                    Picker("性别", selection: Binding(
                        get: { baby.gender ?? "none" },
                        set: { baby.gender = $0 == "none" ? nil : $0 }
                    )) {
                        Text("女宝宝").tag("girl")
                        Text("男宝宝").tag("boy")
                        Text("不填").tag("none")
                    }
                }

                // 数据概览
                Section("数据") {
                    LabeledContent("时间线照片", value: "\(photos.count) 张")
                    LabeledContent("里程碑", value: "\(milestones.count) 条")
                }

                // 相册同步
                Section {
                    Button {
                        Task { await importer.run(birthday: baby.birthday, context: context) }
                    } label: {
                        switch importer.phase {
                        case .scanning(let p, let t):
                            Label("正在扫描 \(p)/\(t) …", systemImage: "arrow.clockwise")
                        default:
                            Label("重新扫描相册", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isScanning)
                } footer: {
                    Text("会把新拍的、生日之后含人脸的照片补进时间线。不会修改系统相册。")
                }

                // 危险区
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Label("清空时间线记录", systemImage: "trash")
                    }
                } footer: {
                    Text("只会删除 App 里保存的元数据（拍摄时间、标签、备注等）。系统相册里的原图不会动。")
                }
            }
            .navigationTitle("设置")
            .onChange(of: avatarItem) {
                Task { await loadAvatar() }
            }
            .onChange(of: baby.name) { try? context.save() }
            .onChange(of: baby.birthday) { try? context.save() }
            .onChange(of: baby.gender) { try? context.save() }
            .confirmationDialog(
                "确定清空所有时间线记录吗？",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("清空", role: .destructive) { clearAll() }
                Button("取消", role: .cancel) {}
            } message: {
                Text("系统相册不受影响。这一步不可撤销。")
            }
        }
    }

    // MARK: - 动作

    private var isScanning: Bool {
        if case .scanning = importer.phase { return true }
        if case .requestingAuth = importer.phase { return true }
        return false
    }

    private func loadAvatar() async {
        guard let avatarItem else { return }
        if let data = try? await avatarItem.loadTransferable(type: Data.self) {
            baby.avatarData = data
            try? context.save()
        }
    }

    private func clearAll() {
        for photo in photos { context.delete(photo) }
        try? context.save()
    }
}

// MARK: - 头像

private struct AvatarCircle: View {
    let data: Data?

    var body: some View {
        Group {
            if let data, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle().fill(Color.pink.opacity(0.15))
                    Image(systemName: "figure.child.circle")
                        .resizable()
                        .scaledToFit()
                        .padding(20)
                        .foregroundStyle(Color.pink.opacity(0.6))
                }
            }
        }
        .frame(width: 96, height: 96)
        .clipShape(Circle())
    }
}
