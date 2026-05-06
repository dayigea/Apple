import SwiftUI

/// 「成长」Tab 的主页：成长数据 + 时光对比 + 成长月报入口。
struct GrowthHubView: View {

    let baby: Baby

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        GrowthChartView(baby: baby)
                    } label: {
                        FeatureRow(
                            icon: "chart.xyaxis.line",
                            color: .indigo,
                            title: "成长数据",
                            subtitle: "记录身高、体重、头围，对照 WHO 生长曲线"
                        )
                    }

                    NavigationLink {
                        TimeCapsuleView(baby: baby)
                    } label: {
                        FeatureRow(
                            icon: "clock.arrow.trianglehead.counterclockwise.rotate.90",
                            color: .blue,
                            title: "时光对比",
                            subtitle: "一年前的今天 vs 现在，看看长了多少"
                        )
                    }

                    NavigationLink {
                        MonthlyReportView(baby: baby)
                    } label: {
                        FeatureRow(
                            icon: "doc.richtext",
                            color: .orange,
                            title: "成长月报",
                            subtitle: "每月自动总结：照片、地点、里程碑、发育数据"
                        )
                    }

                    NavigationLink {
                        DevelopmentChecklistView(baby: baby)
                    } label: {
                        FeatureRow(
                            icon: "checklist",
                            color: .purple,
                            title: "发育清单",
                            subtitle: "按月龄勾选已掌握的大动作 / 语言 / 社交…"
                        )
                    }

                    NavigationLink {
                        FoodGuideView(baby: baby)
                    } label: {
                        FeatureRow(
                            icon: "fork.knife.circle",
                            color: .green,
                            title: "辅食指南",
                            subtitle: "按月龄查看适合的肉类、面食、蔬菜和搭配建议"
                        )
                    }

                    NavigationLink {
                        ReportExportView(baby: baby)
                    } label: {
                        FeatureRow(
                            icon: "square.and.arrow.up",
                            color: .red,
                            title: "导出报告",
                            subtitle: "生成 PDF 成长报告或分享卡片"
                        )
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("成长")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct FeatureRow: View {
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
