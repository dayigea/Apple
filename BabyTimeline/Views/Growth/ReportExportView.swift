import SwiftData
import SwiftUI

/// 导出成长报告页面：预览 PDF 或生成分享卡片，通过系统分享面板导出。
struct ReportExportView: View {

    let baby: Baby

    @Query(sort: \PhotoEntry.creationDate, order: .forward)
    private var photos: [PhotoEntry]
    @Query(sort: \Milestone.date, order: .forward)
    private var milestones: [Milestone]
    @Query(sort: \GrowthRecord.date, order: .forward)
    private var growthRecords: [GrowthRecord]

    @State private var isGenerating = false
    @State private var pdfData: Data?
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    var body: some View {
        List {
            // ---- PDF 完整报告 ----
            Section {
                Button {
                    generatePDF()
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.12))
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.richtext.fill")
                                .font(.title3)
                                .foregroundStyle(.red)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("生成 PDF 成长报告")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Text("包含成长数据、里程碑、收藏照片")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .disabled(isGenerating)
            } header: {
                Text("完整报告")
            } footer: {
                Text("生成 A4 格式的 PDF，可以打印或通过微信/邮件发送。")
            }

            // ---- 分享卡片 ----
            Section {
                if let latestGrowth = growthRecords.last {
                    Button {
                        generateGrowthCard(latest: latestGrowth)
                    } label: {
                        CardRow(
                            icon: "chart.bar.fill",
                            color: .teal,
                            title: "成长数据卡片",
                            subtitle: "最新身高体重数据，适合分享给家人"
                        )
                    }
                }

                if let firstMilestone = milestones.last {
                    Button {
                        generateMilestoneCard(milestone: firstMilestone)
                    } label: {
                        CardRow(
                            icon: "star.fill",
                            color: .orange,
                            title: "最新里程碑卡片",
                            subtitle: "「\(firstMilestone.title)」的分享图"
                        )
                    }
                }
            } header: {
                Text("分享卡片")
            } footer: {
                Text("生成一张精美的图片，保存到相册或直接分享。")
            }

            // ---- 数据概览 ----
            Section("当前数据") {
                LabeledContent("照片", value: "\(photos.filter { !$0.isVideo }.count) 张")
                LabeledContent("视频", value: "\(photos.filter { $0.isVideo }.count) 段")
                LabeledContent("里程碑", value: "\(milestones.count) 个")
                LabeledContent("测量记录", value: "\(growthRecords.count) 次")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("导出报告")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isGenerating {
                ZStack {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("正在生成…")
                            .font(.subheadline)
                            .foregroundStyle(.white)
                    }
                    .padding(30)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData {
                ShareSheet(items: [pdfData as Any], fileName: "\(baby.name)的成长报告.pdf")
            } else if let shareImage {
                ShareSheet(items: [shareImage])
            }
        }
    }

    // MARK: - 生成 PDF

    private func generatePDF() {
        isGenerating = true
        Task {
            let data = GrowthReportRenderer.ReportData(
                baby: baby,
                photos: photos,
                milestones: milestones,
                growthRecords: growthRecords
            )
            let pdf = await GrowthReportRenderer.render(data)
            pdfData = pdf
            shareImage = nil
            isGenerating = false
            showShareSheet = true
        }
    }

    // MARK: - 生成卡片

    private func generateGrowthCard(latest: GrowthRecord) {
        isGenerating = true
        Task {
            let previous = growthRecords.count >= 2
                ? growthRecords[growthRecords.count - 2]
                : nil
            let image = ShareCardRenderer.growthCard(
                baby: baby,
                latest: latest,
                previous: previous
            )
            shareImage = image
            pdfData = nil
            isGenerating = false
            showShareSheet = true
        }
    }

    private func generateMilestoneCard(milestone: Milestone) {
        isGenerating = true
        Task {
            var photo: UIImage?
            if let assetId = milestone.linkedAssetLocalId,
               let asset = PhotoLibraryService.asset(withLocalIdentifier: assetId) {
                photo = await PhotoLibraryService.requestFullImage(for: asset)
            }
            let image = ShareCardRenderer.milestoneCard(
                milestone: milestone,
                baby: baby,
                photo: photo
            )
            shareImage = image
            pdfData = nil
            isGenerating = false
            showShareSheet = true
        }
    }
}

// MARK: - 分享面板

private struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var fileName: String?

    func makeUIViewController(context: Context) -> UIActivityViewController {
        var activityItems: [Any] = []
        for item in items {
            if let data = item as? Data, let name = fileName {
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                try? data.write(to: url)
                activityItems.append(url)
            } else {
                activityItems.append(item)
            }
        }
        return UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - 卡片行

private struct CardRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(color.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(color)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }
}
