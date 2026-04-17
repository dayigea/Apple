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
    @State private var refilter = PhotoReFilter()
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

                // 认人
                ReferenceFaceSection(baby: baby)

                // 排除人脸（爸爸/妈妈/其他家人）
                NegativeFaceSection(baby: baby)

                // 相册同步
                Section {
                    Button {
                        Task { await importer.run(baby: baby, context: context) }
                    } label: {
                        switch importer.phase {
                        case .scanning(let p, let t):
                            Label("正在扫描 \(p)/\(t) …", systemImage: "arrow.clockwise")
                        default:
                            Label("重新扫描相册", systemImage: "arrow.clockwise")
                        }
                    }
                    .disabled(isScanning || isRefiltering)

                    Button {
                        Task { await refilter.run(baby: baby, context: context) }
                    } label: {
                        switch refilter.phase {
                        case .running(let p, let t):
                            Label("正在复核 \(p)/\(t) …", systemImage: "line.3.horizontal.decrease.circle")
                        default:
                            Label("重新应用过滤规则", systemImage: "line.3.horizontal.decrease.circle")
                        }
                    }
                    .disabled(isScanning || isRefiltering || baby.referenceFacePrintData == nil)

                    if let message = refilterMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                } footer: {
                    Text("「重新扫描相册」只会把**新拍的**照片补进时间线，已经入库的不会再复核。\n如果你刚刚加了「排除人脸」或者调严了阈值，想把时间线里已有的误判（比如你自己的照片）清掉，就点「重新应用过滤规则」——它会用当前设置重新检查每一张已有记录。系统相册的原图都不会动。")
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

    private var isRefiltering: Bool {
        if case .running = refilter.phase { return true }
        return false
    }

    private var refilterMessage: String? {
        switch refilter.phase {
        case .finished(let kept, let removed, let missing):
            var parts = ["保留 \(kept) 张"]
            if removed > 0 { parts.append("移除 \(removed) 张") }
            if missing > 0 { parts.append("相册已删 \(missing) 张") }
            return "复核完成：\(parts.joined(separator: "，"))。"
        case .failed(let msg):
            return msg
        default:
            return nil
        }
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

// MARK: - 认人参考照

/// 让用户选一张「女儿本人、清晰正脸」的照片作为认人基准，
/// 并在这里提供匹配阈值滑块。
private struct ReferenceFaceSection: View {
    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context

    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        Section {
            // 当前状态
            HStack(spacing: 12) {
                Image(systemName: baby.referenceFacePrintData != nil
                      ? "person.crop.circle.badge.checkmark"
                      : "person.crop.circle.badge.questionmark")
                    .font(.title2)
                    .foregroundStyle(baby.referenceFacePrintData != nil ? .green : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(baby.referenceFacePrintData != nil ? "已开启认人" : "认人未设置")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(baby.referenceFacePrintData != nil
                         ? "扫描时只纳入含女儿本人的照片"
                         : "扫描时任何含人脸的照片都会纳入")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            // 选照片
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label(
                    baby.referenceFacePrintData == nil ? "选一张女儿的认人照片" : "更换认人照片",
                    systemImage: "person.crop.rectangle"
                )
            }

            // 清除
            if baby.referenceFacePrintData != nil {
                Button(role: .destructive) {
                    baby.referenceFacePrintData = nil
                    try? context.save()
                    successMessage = "已清除认人照片"
                } label: {
                    Label("清除认人照片", systemImage: "trash")
                }
            }

            // 阈值
            if baby.referenceFacePrintData != nil {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("匹配严格程度")
                            .font(.subheadline)
                        Spacer()
                        Text(strictnessLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(
                        value: $baby.faceMatchThreshold,
                        in: 10...30,
                        step: 0.5
                    )
                    .onChange(of: baby.faceMatchThreshold) {
                        try? context.save()
                    }
                    HStack {
                        Text("严格")
                        Spacer()
                        Text("宽松")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            // 状态提示
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在分析人脸…").font(.footnote)
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let successMessage {
                Text(successMessage)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("认人")
        } footer: {
            Text("选一张只包含女儿本人的清晰正脸照，App 会生成人脸指纹。之后扫描时只保留含有她本人的照片。改了认人照或阈值后，记得「重新扫描相册」。")
        }
        .onChange(of: pickerItem) {
            Task { await generateReference() }
        }
    }

    private var strictnessLabel: String {
        switch baby.faceMatchThreshold {
        case ..<14: return "很严 (\(String(format: "%.1f", baby.faceMatchThreshold)))"
        case 14..<20: return "适中 (\(String(format: "%.1f", baby.faceMatchThreshold)))"
        default: return "宽松 (\(String(format: "%.1f", baby.faceMatchThreshold)))"
        }
    }

    private func generateReference() async {
        guard let pickerItem else { return }
        errorMessage = nil
        successMessage = nil
        isProcessing = true
        defer { isProcessing = false }

        guard
            let data = try? await pickerItem.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: data),
            let cgImage = uiImage.cgImage
        else {
            errorMessage = "读取照片失败，换一张试试。"
            return
        }

        guard let printData = await FaceRecognitionService.generateReferencePrint(from: cgImage) else {
            errorMessage = "没在这张照片里找到清晰的人脸。请换一张正脸照。"
            return
        }

        baby.referenceFacePrintData = printData
        try? context.save()
        successMessage = "认人照片已设置。记得去「重新扫描相册」。"
    }
}

// MARK: - 排除人脸

/// 让用户添加多张「不是女儿」的参考脸（爸爸、妈妈、其他家人等）。
/// 扫描时任何更像这些脸而不是女儿的照片都会被过滤掉。
private struct NegativeFaceSection: View {
    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context

    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: baby.negativeFacePrints.isEmpty
                      ? "person.2.slash"
                      : "person.2.slash.fill")
                    .font(.title2)
                    .foregroundStyle(baby.negativeFacePrints.isEmpty ? Color.secondary : Color.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text(baby.negativeFacePrints.isEmpty
                         ? "还没有排除人脸"
                         : "已排除 \(baby.negativeFacePrints.count) 张脸")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("扫描时会过滤掉更像这些脸的照片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)

            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("加一张不是女儿的脸（爸爸/妈妈/…）", systemImage: "person.crop.rectangle.badge.xmark")
            }
            .disabled(baby.referenceFacePrintData == nil)

            if !baby.negativeFacePrints.isEmpty {
                Button(role: .destructive) {
                    baby.clearNegativeFacePrints()
                    try? context.save()
                    successMessage = "已清空排除人脸"
                } label: {
                    Label("清空所有排除人脸", systemImage: "trash")
                }
            }

            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("正在分析人脸…").font(.footnote)
                }
            }
            if let errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
            if let successMessage {
                Text(successMessage)
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        } header: {
            Text("排除人脸")
        } footer: {
            if baby.referenceFacePrintData == nil {
                Text("需要先设置上面的「认人」照片，才能添加排除人脸。")
            } else {
                Text("如果你发现扫描结果里把你自己或其他家人错当成女儿了，在这里加一张你本人/那个家人的正脸照，再「重新扫描相册」就能把这类误判过滤掉。可以加多张（爸爸、外公、外婆……）。")
            }
        }
        .onChange(of: pickerItem) {
            Task { await addNegative() }
        }
    }

    private func addNegative() async {
        guard let pickerItem else { return }
        errorMessage = nil
        successMessage = nil
        isProcessing = true
        defer {
            isProcessing = false
            self.pickerItem = nil
        }

        guard
            let data = try? await pickerItem.loadTransferable(type: Data.self),
            let uiImage = UIImage(data: data),
            let cgImage = uiImage.cgImage
        else {
            errorMessage = "读取照片失败，换一张试试。"
            return
        }

        guard let printData = await FaceRecognitionService.generateNegativePrint(from: cgImage) else {
            errorMessage = "没在这张照片里找到清晰的人脸。请换一张正脸照。"
            return
        }

        baby.addNegativeFacePrint(printData)
        try? context.save()
        successMessage = "已添加。现在共 \(baby.negativeFacePrints.count) 张排除人脸。记得去「重新扫描相册」。"
    }
}
