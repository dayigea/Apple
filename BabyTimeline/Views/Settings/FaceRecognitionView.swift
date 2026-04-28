import PhotosUI
import SwiftData
import SwiftUI

/// 智能识别二级页：认人主参考、补充参考、排除人脸；
/// 高级设置（匹配阈值、扫描操作）折叠到下方 disclosure。
struct FaceRecognitionView: View {

    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context

    @State private var importer = PhotoImporter()
    @State private var refilter = PhotoReFilter()
    @State private var showAdvanced = false

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                introCard
                ReferenceFaceCard(baby: baby)
                ExtraPositiveFaceCard(baby: baby)
                NegativeFaceCard(baby: baby)
                advancedSection
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("智能识别")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Intro

    private var introCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "wand.and.stars")
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text("只把宝宝的照片纳入时间线")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("通过设置参考照片，扫描时自动过滤掉别人的脸。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Advanced

    private var advancedSection: some View {
        VStack(spacing: 12) {
            DisclosureGroup(isExpanded: $showAdvanced) {
                VStack(spacing: 14) {
                    if baby.referenceFacePrintData != nil {
                        thresholdRow
                        Divider()
                    }
                    rescanButton
                    refilterButton
                    if let message = refilterMessage {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, 12)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                    Text("高级设置")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                }
            }
            .tint(.primary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var thresholdRow: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("匹配严格程度")
                    .font(.subheadline)
                Spacer()
                Text(strictnessLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(value: $baby.faceMatchThreshold, in: 10...30, step: 0.5)
                .tint(.accentColor)
                .onChange(of: baby.faceMatchThreshold) {
                    try? context.save()
                }
            HStack {
                Text("严格").foregroundStyle(.secondary)
                Spacer()
                Text("宽松").foregroundStyle(.secondary)
            }
            .font(.caption2)
        }
    }

    private var rescanButton: some View {
        Button {
            Task { await importer.run(baby: baby, context: context) }
        } label: {
            HStack {
                Image(systemName: "arrow.clockwise")
                switch importer.phase {
                case .scanning(let p, let t):
                    Text("正在扫描 \(p)/\(t) …")
                default:
                    Text("重新扫描相册")
                }
                Spacer()
            }
            .font(.subheadline)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.accent)
        .disabled(isScanning || isRefiltering)
    }

    private var refilterButton: some View {
        Button {
            Task { await refilter.run(baby: baby, context: context) }
        } label: {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                switch refilter.phase {
                case .running(let p, let t):
                    Text("正在复核 \(p)/\(t) …")
                default:
                    Text("用当前规则复核已有照片")
                }
                Spacer()
            }
            .font(.subheadline)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .foregroundStyle(.accent)
        .disabled(isScanning || isRefiltering || baby.referenceFacePrintData == nil)
    }

    // MARK: - Helpers

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

    private var strictnessLabel: String {
        switch baby.faceMatchThreshold {
        case ..<14: return "很严"
        case 14..<20: return "适中"
        default: return "宽松"
        }
    }
}

// MARK: - 主参考卡片

private struct ReferenceFaceCard: View {
    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context
    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        FaceCardShell(
            icon: baby.referenceFacePrintData != nil
                ? "person.crop.circle.badge.checkmark"
                : "person.crop.circle.badge.questionmark",
            iconTint: baby.referenceFacePrintData != nil ? .green : .gray,
            title: "认人主参考",
            statusText: baby.referenceFacePrintData != nil ? "已开启" : "未设置",
            description: baby.referenceFacePrintData != nil
                ? "扫描时只纳入含宝宝本人的照片"
                : "选一张宝宝清晰的正脸照作为基准"
        ) {
            VStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    PrimaryActionLabel(
                        icon: "person.crop.rectangle",
                        text: baby.referenceFacePrintData == nil ? "选认人照片" : "更换认人照片"
                    )
                }
                .buttonStyle(.plain)
                if baby.referenceFacePrintData != nil {
                    Button(role: .destructive) {
                        baby.referenceFacePrintData = nil
                        baby.clearExtraPositiveFacePrints()
                        try? context.save()
                        successMessage = "已清除认人照片"
                    } label: {
                        SecondaryActionLabel(icon: "trash", text: "清除认人照片", tint: .red)
                    }
                    .buttonStyle(.plain)
                }
                StatusFooter(
                    isProcessing: isProcessing,
                    error: errorMessage,
                    success: successMessage
                )
            }
        }
        .onChange(of: pickerItem) {
            Task { await generateReference() }
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
            errorMessage = "没找到清晰的人脸，请换一张正脸照。"
            return
        }

        baby.referenceFacePrintData = printData
        try? context.save()
        successMessage = "已设置。建议接着「重新扫描相册」。"
    }
}

// MARK: - 补充参考卡片

private struct ExtraPositiveFaceCard: View {
    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context
    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        FaceCardShell(
            icon: baby.extraPositiveFacePrints.isEmpty ? "person.2.circle" : "person.2.circle.fill",
            iconTint: baby.extraPositiveFacePrints.isEmpty ? .gray : .green,
            title: "补充参考照",
            statusText: baby.extraPositiveFacePrints.isEmpty
                ? "0 张"
                : "\(baby.extraPositiveFacePrints.count) 张",
            description: "不同角度 / 月龄越多，识别越稳，建议 3–5 张"
        ) {
            VStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    PrimaryActionLabel(icon: "person.badge.plus", text: "追加补充参考")
                }
                .buttonStyle(.plain)
                .disabled(baby.referenceFacePrintData == nil)

                if !baby.extraPositiveFacePrints.isEmpty {
                    Button(role: .destructive) {
                        baby.clearExtraPositiveFacePrints()
                        try? context.save()
                        successMessage = "已清空"
                    } label: {
                        SecondaryActionLabel(icon: "trash", text: "清空补充参考", tint: .red)
                    }
                    .buttonStyle(.plain)
                }
                if baby.referenceFacePrintData == nil {
                    Text("请先设置认人主参考")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                StatusFooter(
                    isProcessing: isProcessing,
                    error: errorMessage,
                    success: successMessage
                )
            }
        }
        .onChange(of: pickerItem) {
            Task { await addExtra() }
        }
    }

    private func addExtra() async {
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

        guard let printData = await FaceRecognitionService.generateReferencePrint(from: cgImage) else {
            errorMessage = "没找到清晰的人脸，请换一张正脸照。"
            return
        }

        baby.addExtraPositiveFacePrint(printData)
        try? context.save()
        successMessage = "已添加，共 \(baby.extraPositiveFacePrints.count) 张。"
    }
}

// MARK: - 排除人脸卡片

private struct NegativeFaceCard: View {
    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context
    @State private var pickerItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var successMessage: String?

    var body: some View {
        FaceCardShell(
            icon: baby.negativeFacePrints.isEmpty ? "person.2.slash" : "person.2.slash.fill",
            iconTint: baby.negativeFacePrints.isEmpty ? .gray : .orange,
            title: "排除人脸",
            statusText: baby.negativeFacePrints.isEmpty
                ? "未排除"
                : "\(baby.negativeFacePrints.count) 张",
            description: "把家人的脸加进来，避免他们的照片混进时间线"
        ) {
            VStack(spacing: 8) {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    PrimaryActionLabel(icon: "person.badge.minus", text: "添加要排除的脸")
                }
                .buttonStyle(.plain)
                .disabled(baby.referenceFacePrintData == nil)

                if !baby.negativeFacePrints.isEmpty {
                    Button(role: .destructive) {
                        baby.clearNegativeFacePrints()
                        try? context.save()
                        successMessage = "已清空"
                    } label: {
                        SecondaryActionLabel(icon: "trash", text: "清空排除人脸", tint: .red)
                    }
                    .buttonStyle(.plain)
                }
                if baby.referenceFacePrintData == nil {
                    Text("请先设置认人主参考")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                StatusFooter(
                    isProcessing: isProcessing,
                    error: errorMessage,
                    success: successMessage
                )
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
            errorMessage = "没找到清晰的人脸，请换一张正脸照。"
            return
        }

        baby.addNegativeFacePrint(printData)
        try? context.save()
        successMessage = "已添加，共 \(baby.negativeFacePrints.count) 张。"
    }
}

// MARK: - 共享外壳

private struct FaceCardShell<Content: View>: View {
    let icon: String
    let iconTint: Color
    let title: String
    let statusText: String
    let description: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(iconTint.opacity(0.14))
                        .frame(width: 40, height: 40)
                    Image(systemName: icon)
                        .font(.subheadline)
                        .foregroundStyle(iconTint)
                }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(statusText)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(iconTint.opacity(0.14))
                            .foregroundStyle(iconTint)
                            .clipShape(Capsule())
                    }
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            content()
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct PrimaryActionLabel: View {
    let icon: String
    let text: String

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(text)
                .fontWeight(.medium)
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.accentColor.opacity(0.12))
        .foregroundStyle(.accent)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct SecondaryActionLabel: View {
    let icon: String
    let text: String
    let tint: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
            Text(text)
            Spacer()
        }
        .font(.subheadline)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(tint.opacity(0.10))
        .foregroundStyle(tint)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct StatusFooter: View {
    let isProcessing: Bool
    let error: String?
    let success: String?

    var body: some View {
        Group {
            if isProcessing {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("正在分析人脸…").font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let error {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let success {
                Text(success)
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
