import PhotosUI
import SwiftData
import SwiftUI

/// 首次启动引导：让用户填写宝宝的基础信息。
struct SetupView: View {

    @Environment(\.modelContext) private var context

    @State private var name: String = ""
    @State private var birthday: Date = Calendar.current.date(
        byAdding: .year, value: -1, to: .now
    ) ?? .now
    @State private var gender: String? = "girl"
    @State private var avatarItem: PhotosPickerItem?
    @State private var avatarData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $avatarItem, matching: .images) {
                            AvatarView(data: avatarData)
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("点击圆形头像选一张宝宝的照片（可选）")
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                Section("基本信息") {
                    TextField("宝宝姓名", text: $name)
                        .textInputAutocapitalization(.never)

                    DatePicker(
                        "出生日期",
                        selection: $birthday,
                        in: ...Date.now,
                        displayedComponents: .date
                    )
                    .environment(\.locale, Locale(identifier: "zh_CN"))

                    Picker("性别", selection: $gender) {
                        Text("女宝宝").tag(String?.some("girl"))
                        Text("男宝宝").tag(String?.some("boy"))
                        Text("不填").tag(String?.none)
                    }
                }

                Section {
                    Button(action: save) {
                        Text("开始记录成长时光")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.semibold)
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                } footer: {
                    Text("接下来 App 会请求相册权限，自动把出生之后所有含人脸的照片整理成时间线。")
                }
            }
            .navigationTitle("欢迎")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: avatarItem) {
                Task { await loadAvatar() }
            }
        }
    }

    // MARK: - 动作

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let baby = Baby(
            name: trimmed,
            birthday: birthday,
            gender: gender,
            avatarData: avatarData
        )
        context.insert(baby)
        try? context.save()
    }

    private func loadAvatar() async {
        guard let avatarItem else { return }
        if let data = try? await avatarItem.loadTransferable(type: Data.self) {
            avatarData = data
        }
    }
}

// MARK: - 头像占位

private struct AvatarView: View {
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
                        .padding(24)
                        .foregroundStyle(Color.pink.opacity(0.6))
                }
            }
        }
        .frame(width: 120, height: 120)
        .clipShape(Circle())
        .overlay(Circle().stroke(Color.white, lineWidth: 3))
        .shadow(radius: 4)
    }
}
