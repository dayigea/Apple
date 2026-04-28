import PhotosUI
import SwiftData
import SwiftUI
import WidgetKit

/// 宝宝资料编辑页：姓名 / 生日 / 性别 / 头像。
struct BabyProfileView: View {

    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context
    @State private var avatarItem: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                avatarCard
                fieldsCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("宝宝资料")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: avatarItem) {
            Task { await loadAvatar() }
        }
        .onChange(of: baby.name) { saveAndReloadWidget() }
        .onChange(of: baby.birthday) { saveAndReloadWidget() }
        .onChange(of: baby.gender) { saveAndReloadWidget() }
    }

    // MARK: - Avatar

    private var avatarCard: some View {
        VStack(spacing: 14) {
            PhotosPicker(selection: $avatarItem, matching: .images) {
                ZStack(alignment: .bottomTrailing) {
                    SettingsAvatar(data: baby.avatarData, size: 110)
                    ZStack {
                        Circle().fill(Color.accentColor)
                            .frame(width: 30, height: 30)
                        Image(systemName: "camera.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                    .overlay(Circle().stroke(.white, lineWidth: 2))
                    .shadow(color: .black.opacity(0.1), radius: 3, y: 1)
                }
            }
            Text("点头像更换")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Fields

    private var fieldsCard: some View {
        VStack(spacing: 0) {
            fieldRow(icon: "person.fill", iconTint: .accentColor, label: "姓名") {
                TextField("宝宝的名字", text: $baby.name)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.primary)
            }
            Divider().padding(.leading, 56)
            fieldRow(icon: "birthday.cake.fill", iconTint: .pink, label: "生日") {
                DatePicker(
                    "",
                    selection: $baby.birthday,
                    in: ...Date.now,
                    displayedComponents: .date
                )
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "zh_CN"))
            }
            Divider().padding(.leading, 56)
            fieldRow(icon: "figure.child", iconTint: .indigo, label: "性别") {
                Picker("", selection: Binding(
                    get: { baby.gender ?? "none" },
                    set: { baby.gender = $0 == "none" ? nil : $0 }
                )) {
                    Text("女宝宝").tag("girl")
                    Text("男宝宝").tag("boy")
                    Text("不填").tag("none")
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }
        }
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func fieldRow<Trailing: View>(
        icon: String,
        iconTint: Color,
        label: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(iconTint.opacity(0.14))
                    .frame(width: 32, height: 32)
                Image(systemName: icon)
                    .font(.footnote)
                    .foregroundStyle(iconTint)
            }
            Text(label)
                .font(.subheadline)
            Spacer(minLength: 4)
            trailing()
                .font(.subheadline)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Actions

    private func loadAvatar() async {
        guard let avatarItem else { return }
        if let data = try? await avatarItem.loadTransferable(type: Data.self) {
            baby.avatarData = data
            saveAndReloadWidget()
        }
    }

    private func saveAndReloadWidget() {
        try? context.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
