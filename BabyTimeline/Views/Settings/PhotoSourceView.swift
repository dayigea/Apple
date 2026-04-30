import SwiftData
import SwiftUI

/// 「宝宝照片」二级页：
/// - 主路径：PHPicker 让用户在「人物与宠物」里选宝宝那一组，全选导入
/// - 高级（折叠）：旧的自动扫描 + 自家人脸识别那一套，保留作为备选
struct PhotoSourceView: View {

    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context
    @Query private var photos: [PhotoEntry]

    @State private var pickerImporter = PhotoPickerImporter()
    @State private var isPickerPresented = false
    @State private var showAdvanced = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                introCard
                primaryActionCard
                statsCard
                advancedDisclosure
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("宝宝照片")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isPickerPresented) {
            PhotoPickerSheet(isPresented: $isPickerPresented) { identifiers in
                Task { await runPickerImport(identifiers) }
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Intro

    private var introCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "person.crop.rectangle.stack.fill")
                .font(.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text("用 Apple 的人像识别")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("在系统相册的「人物与宠物」里点宝宝那一组，全选回到这里，比 App 自己识别更准。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Primary action

    private var primaryActionCard: some View {
        VStack(spacing: 12) {
            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "photo.badge.plus")
                        .font(.headline)
                    Text(isImporting ? "正在导入…" : "从相册导入照片")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isImporting)

            stepGuide
            statusFooter
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var stepGuide: some View {
        VStack(alignment: .leading, spacing: 6) {
            stepRow(num: 1, text: "点上方按钮 → 打开系统相册选择器")
            stepRow(num: 2, text: "下方切到「相簿」→ 找到「人物与宠物」")
            stepRow(num: 3, text: "点宝宝头像 → 右上角全选 → 完成")
        }
        .padding(.top, 4)
    }

    private func stepRow(num: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle().fill(Color.accentColor.opacity(0.18))
                    .frame(width: 18, height: 18)
                Text("\(num)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.accentColor)
            }
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
    }

    @ViewBuilder
    private var statusFooter: some View {
        switch pickerImporter.phase {
        case .idle:
            EmptyView()
        case .importing(let p, let t):
            ProgressView(value: Double(p), total: Double(max(t, 1))) {
                Text("正在导入 \(p)/\(t)").font(.caption2)
            }
            .progressViewStyle(.linear)
            .padding(.top, 4)
        case .geocoding(let p, let t):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("反查地名 \(p)/\(t)…").font(.caption)
            }
            .padding(.top, 4)
        case .finished(let inserted, let skipped, let beforeBirthday):
            VStack(alignment: .leading, spacing: 2) {
                Text("导入完成：新增 \(inserted) 张")
                    .font(.caption)
                    .foregroundStyle(.green)
                if let skipText = skippedSummary(skipped: skipped, beforeBirthday: beforeBirthday) {
                    Text(skipText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 4)
        case .failed(let msg):
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
                .padding(.top, 4)
        }
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("当前时间线")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(photos.count) 张照片")
                    .font(.title3)
                    .fontWeight(.semibold)
            }
            Spacer()
            Image(systemName: "photo.stack")
                .font(.title2)
                .foregroundStyle(Color.accentColor)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Advanced

    private var advancedDisclosure: some View {
        VStack(spacing: 0) {
            DisclosureGroup(isExpanded: $showAdvanced) {
                NavigationLink {
                    FaceRecognitionView(baby: baby)
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.blue)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("自家人脸识别 + 自动扫描")
                                .font(.subheadline)
                            Text("不用 Apple 人像分组时的备选方案")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "slider.horizontal.3")
                        .foregroundStyle(.secondary)
                    Text("高级")
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

    // MARK: - Helpers

    private var isImporting: Bool {
        switch pickerImporter.phase {
        case .importing, .geocoding: return true
        default: return false
        }
    }

    private func runPickerImport(_ identifiers: [String]) async {
        guard !identifiers.isEmpty else { return }
        await pickerImporter.import(
            assetIdentifiers: identifiers,
            baby: baby,
            context: context
        )
    }

    private func skippedSummary(skipped: Int, beforeBirthday: Int) -> String? {
        var parts: [String] = []
        if skipped > 0 { parts.append("已存在 \(skipped) 张") }
        if beforeBirthday > 0 { parts.append("早于生日 \(beforeBirthday) 张") }
        guard !parts.isEmpty else { return nil }
        return "跳过：\(parts.joined(separator: "，"))"
    }
}
