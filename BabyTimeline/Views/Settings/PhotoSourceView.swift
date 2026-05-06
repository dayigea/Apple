import SwiftData
import SwiftUI

/// 「宝宝照片」页：
/// - 主操作：扫描相册（自动识别 + 自家人脸过滤），不联网避免 iCloud 卡死
/// - 副操作：从相册手动选（PHPicker，适合补几张）
/// - 入口：进识别设置（管理认人参考照、补充参考、排除人脸）
struct PhotoSourceView: View {

    @Bindable var baby: Baby

    @Environment(\.modelContext) private var context
    @Query private var photos: [PhotoEntry]

    @State private var importer = PhotoImporter()
    @State private var pickerImporter = PhotoPickerImporter()
    @State private var isPickerPresented = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsCard
                referenceStatusCard
                scanCard
                pickerCard
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

    // MARK: - Reference status

    private var referenceStatusCard: some View {
        let hasRef = baby.referenceFacePrintData != nil
        return NavigationLink {
            FaceRecognitionView(baby: baby)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: hasRef ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(hasRef ? .green : .orange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(hasRef ? "认人参考照已设置" : "建议先设置认人参考照")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(hasRef
                         ? "扫描时只纳入宝宝的照片"
                         : "不设置的话，扫描会纳入所有含人脸的照片")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 4)
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scan

    private var scanCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "arrow.clockwise.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("扫描相册")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("只处理已下载到本地的照片，不会卡在 iCloud")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                Task { await importer.run(baby: baby, context: context) }
            } label: {
                HStack(spacing: 8) {
                    if isScanning {
                        ProgressView().controlSize(.small).tint(.white)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(scanButtonText)
                        .fontWeight(.semibold)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isScanning)

            scanFooter
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var scanFooter: some View {
        switch importer.phase {
        case .idle:
            EmptyView()
        case .requestingAuth:
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("正在请求相册权限…").font(.caption)
            }
        case .scanning(let p, let t):
            ProgressView(value: Double(p), total: Double(max(t, 1))) {
                Text("正在扫描 \(p)/\(t)").font(.caption2)
            }
            .progressViewStyle(.linear)
        case .geocoding(let p, let t):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("反查地名 \(p)/\(t)…").font(.caption)
            }
        case .finished(let inserted, _, let notDownloaded):
            VStack(alignment: .leading, spacing: 4) {
                Text("扫描完成：新增 \(inserted) 张")
                    .font(.caption)
                    .foregroundStyle(.green)
                if notDownloaded > 0 {
                    Text("\(notDownloaded) 张未下载到本地，跳过。下次连 iCloud 时这些照片会自动下到设备，再扫一次就能补上。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case .failed(let msg):
            Text(msg)
                .font(.caption)
                .foregroundStyle(.red)
        }
    }

    private var scanButtonText: String {
        switch importer.phase {
        case .scanning: return "扫描中…"
        case .requestingAuth: return "请求权限中…"
        case .geocoding: return "处理中…"
        default: return photos.isEmpty ? "开始扫描" : "重新扫描"
        }
    }

    private var isScanning: Bool {
        switch importer.phase {
        case .scanning, .requestingAuth, .geocoding: return true
        default: return false
        }
    }

    // MARK: - Picker (secondary)

    private var pickerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "hand.point.up.left")
                    .font(.title3)
                    .foregroundStyle(.blue)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("从相册手动选")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("适合补几张特定照片，比如刚刚拍的")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Button {
                isPickerPresented = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "photo.badge.plus")
                    Text("打开相册选择器")
                    Spacer()
                    Image(systemName: "chevron.right").font(.caption2)
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color.blue.opacity(0.10))
                .foregroundStyle(.blue)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isPickerImporting)

            pickerStatusFooter
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private var pickerStatusFooter: some View {
        switch pickerImporter.phase {
        case .idle, .failed:
            EmptyView()
        case .importing(let p, let t):
            ProgressView(value: Double(p), total: Double(max(t, 1))) {
                Text("导入 \(p)/\(t)").font(.caption2)
            }
            .progressViewStyle(.linear)
        case .geocoding(let p, let t):
            HStack(spacing: 6) {
                ProgressView().controlSize(.small)
                Text("反查地名 \(p)/\(t)…").font(.caption)
            }
        case .finished(let inserted, let skipped, let beforeBirthday):
            VStack(alignment: .leading, spacing: 2) {
                Text("已添加 \(inserted) 张")
                    .font(.caption)
                    .foregroundStyle(.green)
                if let skipText = skippedSummary(skipped: skipped, beforeBirthday: beforeBirthday) {
                    Text(skipText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var isPickerImporting: Bool {
        switch pickerImporter.phase {
        case .importing, .geocoding: return true
        default: return false
        }
    }

    // MARK: - Helpers

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
