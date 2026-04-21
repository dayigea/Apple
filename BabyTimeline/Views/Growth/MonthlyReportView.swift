import SwiftData
import SwiftUI

/// 成长月报：按月自动生成一页总结。
struct MonthlyReportView: View {

    let baby: Baby

    @Query(sort: \PhotoEntry.creationDate, order: .forward)
    private var photos: [PhotoEntry]

    @Query(sort: \Milestone.date, order: .forward)
    private var milestones: [Milestone]

    @Query(sort: \GrowthRecord.date, order: .forward)
    private var growthRecords: [GrowthRecord]

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            ScrollView {
                if reports.isEmpty {
                    emptyState
                } else {
                    LazyVStack(spacing: 16) {
                        ForEach(reports) { report in
                            ReportCard(report: report, baby: baby)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("成长月报")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - 数据

    struct Report: Identifiable {
        let id: String
        let year: Int
        let month: Int
        let age: AgeCalculator.Age
        let photoCount: Int
        let places: [String]
        let milestones: [Milestone]
        let topTags: [String]
        let growth: GrowthRecord?
        let prevGrowth: GrowthRecord?
        let coverPhotoId: String?
    }

    private var reports: [Report] {
        let now = Date.now
        let start = calendar.dateComponents([.year, .month], from: baby.birthday)
        let end = calendar.dateComponents([.year, .month], from: now)

        guard let startYear = start.year, let startMonth = start.month,
              let endYear = end.year, let endMonth = end.month else { return [] }

        var result: [Report] = []

        var y = endYear
        var m = endMonth

        while (y > startYear) || (y == startYear && m >= startMonth) {
            let report = buildReport(year: y, month: m)
            if report.photoCount > 0 || !report.milestones.isEmpty || report.growth != nil {
                result.append(report)
            }

            m -= 1
            if m < 1 { m = 12; y -= 1 }
        }

        return result
    }

    private func buildReport(year: Int, month: Int) -> Report {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let monthStart = calendar.date(from: comps),
              let monthEnd = calendar.date(byAdding: .month, value: 1, to: monthStart) else {
            return Report(id: "\(year)-\(month)", year: year, month: month,
                          age: AgeCalculator.age(birthday: baby.birthday, at: Date.now),
                          photoCount: 0, places: [], milestones: [],
                          topTags: [], growth: nil, prevGrowth: nil, coverPhotoId: nil)
        }

        let monthPhotos = photos.filter { $0.creationDate >= monthStart && $0.creationDate < monthEnd }
        let monthMilestones = milestones.filter { $0.date >= monthStart && $0.date < monthEnd }
        let monthGrowth = growthRecords.filter { $0.date >= monthStart && $0.date < monthEnd }.last

        // 上个月的成长数据，用来算增长量
        let prevGrowth: GrowthRecord?
        if let prevMonthEnd = calendar.date(byAdding: .month, value: -1, to: monthEnd) {
            prevGrowth = growthRecords
                .filter { $0.date < monthStart && $0.date >= prevMonthEnd }
                .last
                ?? growthRecords.last(where: { $0.date < monthStart })
        } else {
            prevGrowth = nil
        }

        let places = Array(Set(monthPhotos.compactMap { $0.placeName }).prefix(5))

        var tagCounts: [String: Int] = [:]
        let boring: Set<String> = [
            "宝宝", "小朋友", "人物", "人像", "婴儿", "室内", "户外", "家", "衣服", "自拍",
        ]
        for photo in monthPhotos {
            for tag in photo.autoTags where !boring.contains(tag) {
                tagCounts[tag, default: 0] += 1
            }
        }
        let topTags = tagCounts.sorted { $0.value > $1.value }.prefix(5).map(\.key)

        let age = AgeCalculator.age(birthday: baby.birthday, at: monthStart)

        let cover = monthPhotos.first(where: { $0.isFavorite })
            ?? monthPhotos.max(by: { $0.autoTags.count < $1.autoTags.count })

        return Report(
            id: "\(year)-\(month)",
            year: year,
            month: month,
            age: age,
            photoCount: monthPhotos.count,
            places: places,
            milestones: monthMilestones,
            topTags: topTags,
            growth: monthGrowth,
            prevGrowth: prevGrowth,
            coverPhotoId: cover?.assetLocalId
        )
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("还没有数据来生成月报")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("扫描相册后，这里会按月自动生成成长总结。")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}

// MARK: - 月报卡片

private struct ReportCard: View {
    let report: MonthlyReportView.Report
    let baby: Baby

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(String(report.year)) 年 \(report.month) 月")
                        .font(.headline)
                    Text(report.age.localized)
                        .font(.caption)
                        .foregroundStyle(.tint)
                }
                Spacer()
                if let coverId = report.coverPhotoId {
                    AsyncPHAssetImage(localIdentifier: coverId, size: .thumbnail(60))
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            Divider()

            // 统计摘要
            HStack(spacing: 16) {
                StatItem(icon: "photo", value: "\(report.photoCount)", label: "张照片")
                if !report.places.isEmpty {
                    StatItem(icon: "mappin", value: "\(report.places.count)", label: "个地方")
                }
                if !report.milestones.isEmpty {
                    StatItem(icon: "star.fill", value: "\(report.milestones.count)", label: "个里程碑")
                }
            }

            // 成长数据 + 增长量
            if let g = report.growth {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 12) {
                        if let h = g.heightCM {
                            GrowthBadge(label: "身高", value: "\(fmtVal(h)) cm",
                                        delta: delta(\.heightCM, cur: g, prev: report.prevGrowth, unit: "cm"),
                                        color: .pink)
                        }
                        if let w = g.weightKG {
                            GrowthBadge(label: "体重", value: "\(fmtVal(w)) kg",
                                        delta: delta(\.weightKG, cur: g, prev: report.prevGrowth, unit: "kg"),
                                        color: .orange)
                        }
                        if let hc = g.headCircumCM {
                            GrowthBadge(label: "头围", value: "\(fmtVal(hc)) cm",
                                        delta: delta(\.headCircumCM, cur: g, prev: report.prevGrowth, unit: "cm"),
                                        color: .purple)
                        }
                    }
                }
            }

            // 去过的地方
            if !report.places.isEmpty {
                FlowText(icon: "mappin.circle.fill", color: .green,
                         text: "去过：" + report.places.joined(separator: "、"))
            }

            // 里程碑
            if !report.milestones.isEmpty {
                FlowText(icon: "star.circle.fill", color: .yellow,
                         text: "里程碑：" + report.milestones.map(\.title).joined(separator: "、"))
            }

            // 热门标签
            if !report.topTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        ForEach(report.topTags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func fmtVal(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }

    private func delta(
        _ keyPath: KeyPath<GrowthRecord, Double?>,
        cur: GrowthRecord,
        prev: GrowthRecord?,
        unit: String
    ) -> String? {
        guard let c = cur[keyPath: keyPath],
              let p = prev?[keyPath: keyPath] else { return nil }
        let d = c - p
        if abs(d) < 0.05 { return nil }
        let sign = d > 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", d)) \(unit)"
    }
}

// MARK: - 小组件

private struct StatItem: View {
    let icon: String
    let value: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct GrowthBadge: View {
    let label: String
    let value: String
    let delta: String?
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text("\(label) \(value)")
                    .font(.caption)
            }
            if let d = delta {
                Text(d)
                    .font(.caption2)
                    .foregroundStyle(d.hasPrefix("+") ? .green : .red)
                    .padding(.leading, 10)
            }
        }
    }
}

private struct FlowText: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
