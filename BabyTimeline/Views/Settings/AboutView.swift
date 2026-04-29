import SwiftData
import SwiftUI

/// 「关于」二级页：数据概览、版本信息、清空记录。
struct AboutView: View {

    let photoCount: Int
    let milestoneCount: Int

    @Environment(\.modelContext) private var context
    @Query private var photos: [PhotoEntry]
    @State private var showingDeleteConfirm = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                statsCard
                appGroupCard
                infoCard
                dangerCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("关于")
        .navigationBarTitleDisplayMode(.inline)
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

    // MARK: - App Group 诊断

    private var appGroupCard: some View {
        let shared = AppGroup.isUsingSharedContainer
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: shared ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    .font(.title3)
                    .foregroundStyle(shared ? .green : .orange)
                VStack(alignment: .leading, spacing: 2) {
                    Text(shared ? "App Group 已生效" : "App Group 未生效")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(shared
                         ? "本 App 写入的数据可以被 Widget 读到"
                         : "Widget 看不到 App 的数据")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
            if !shared {
                Text("请到 Xcode → BabyTimeline target → Signing & Capabilities → +Capability → App Groups，勾上 group.com.personal.babytimeline。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("如果 Widget 仍显示「还没设置宝宝信息」，说明 BabyTimelineWidget target 还没勾 App Group——这两个 target 必须各自勾一次。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Stats

    private var statsCard: some View {
        HStack(spacing: 0) {
            statTile(value: "\(photoCount)", label: "时间线照片", icon: "photo.stack", tint: .accentColor)
            Divider().frame(height: 56)
            statTile(value: "\(milestoneCount)", label: "里程碑", icon: "star.circle", tint: .orange)
        }
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statTile(value: String, label: String, icon: String, tint: Color) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    // MARK: - Info

    private var infoCard: some View {
        VStack(spacing: 0) {
            infoRow(label: "版本", value: appVersion)
            Divider().padding(.leading, 16)
            infoRow(label: "构建号", value: buildNumber)
        }
        .padding(.vertical, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }

    // MARK: - Danger

    private var dangerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(role: .destructive) {
                showingDeleteConfirm = true
            } label: {
                HStack {
                    Image(systemName: "trash")
                    Text("清空时间线记录")
                        .fontWeight(.medium)
                    Spacer()
                }
                .font(.subheadline)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.red.opacity(0.10))
                .foregroundStyle(.red)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            Text("只删 App 内保存的元数据（拍摄时间、标签、备注）。系统相册原图不会动。")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Actions

    private func clearAll() {
        for photo in photos { context.delete(photo) }
        try? context.save()
    }
}
