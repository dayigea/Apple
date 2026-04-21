import Charts
import SwiftData
import SwiftUI

struct GrowthChartView: View {

    let baby: Baby

    @Environment(\.modelContext) private var context
    @Query(sort: \GrowthRecord.date, order: .forward)
    private var records: [GrowthRecord]

    @State private var metric: Metric = .height
    @State private var showingAdd = false
    @State private var editing: GrowthRecord?

    enum Metric: String, CaseIterable, Identifiable {
        case height = "身高"
        case weight = "体重"
        case head = "头围"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Picker("指标", selection: $metric) {
                        ForEach(Metric.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    chartSection
                        .frame(height: 280)
                        .padding(.horizontal)

                    latestSummary
                        .padding(.horizontal)

                    recordsList
                }
                .padding(.vertical)
            }
            .navigationTitle("成长数据")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAdd) {
                GrowthRecordEditView(baby: baby, record: nil)
            }
            .sheet(item: $editing) { record in
                GrowthRecordEditView(baby: baby, record: record)
            }
        }
    }

    // MARK: - 图表

    @ViewBuilder
    private var chartSection: some View {
        let dataPoints = chartData
        let whoData = whoPercentiles

        if dataPoints.isEmpty {
            VStack(spacing: 8) {
                Image(systemName: "chart.xyaxis.line")
                    .font(.system(size: 40))
                    .foregroundStyle(.secondary)
                Text("还没有\(metric.rawValue)数据\n点右上角 + 添加第一次测量")
                    .multilineTextAlignment(.center)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            Chart {
                // WHO 百分位区间带
                ForEach(whoData, id: \.monthAge) { p in
                    AreaMark(
                        x: .value("月龄", p.monthAge),
                        yStart: .value("P3", p.p3),
                        yEnd: .value("P97", p.p97)
                    )
                    .foregroundStyle(.blue.opacity(0.06))

                    AreaMark(
                        x: .value("月龄", p.monthAge),
                        yStart: .value("P15", p.p15),
                        yEnd: .value("P85", p.p85)
                    )
                    .foregroundStyle(.blue.opacity(0.08))

                    LineMark(
                        x: .value("月龄", p.monthAge),
                        y: .value("P50", p.p50)
                    )
                    .foregroundStyle(.blue.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }

                // 宝宝的实际数据
                ForEach(dataPoints, id: \.monthAge) { dp in
                    LineMark(
                        x: .value("月龄", dp.monthAge),
                        y: .value(metric.rawValue, dp.value)
                    )
                    .foregroundStyle(.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2))

                    PointMark(
                        x: .value("月龄", dp.monthAge),
                        y: .value(metric.rawValue, dp.value)
                    )
                    .foregroundStyle(.pink)
                    .symbolSize(30)
                }
            }
            .chartXAxisLabel("月龄")
            .chartYAxisLabel(unit)
        }
    }

    private var unit: String {
        switch metric {
        case .height: "cm"
        case .weight: "kg"
        case .head: "cm"
        }
    }

    struct DataPoint {
        let monthAge: Double
        let value: Double
    }

    private var chartData: [DataPoint] {
        records.compactMap { r in
            let value: Double?
            switch metric {
            case .height: value = r.heightCM
            case .weight: value = r.weightKG
            case .head: value = r.headCircumCM
            }
            guard let v = value else { return nil }
            let months = Calendar.current.dateComponents([.month, .day], from: baby.birthday, to: r.date)
            let m = Double(months.month ?? 0) + Double(months.day ?? 0) / 30.0
            return DataPoint(monthAge: m, value: v)
        }
    }

    private var whoPercentiles: [WHOGrowthStandard.Percentiles] {
        switch metric {
        case .height: WHOGrowthStandard.girlHeightCM
        case .weight: WHOGrowthStandard.girlWeightKG
        case .head: WHOGrowthStandard.girlHeadCM
        }
    }

    // MARK: - 最近一次概况

    @ViewBuilder
    private var latestSummary: some View {
        if let latest = records.last {
            let age = AgeCalculator.age(birthday: baby.birthday, at: latest.date)
            VStack(alignment: .leading, spacing: 8) {
                Text("最近一次测量 · \(age.localized)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                HStack(spacing: 16) {
                    if let h = latest.heightCM {
                        StatBadge(label: "身高", value: "\(formatVal(h)) cm", color: .pink)
                    }
                    if let w = latest.weightKG {
                        StatBadge(label: "体重", value: "\(formatVal(w)) kg", color: .orange)
                    }
                    if let hc = latest.headCircumCM {
                        StatBadge(label: "头围", value: "\(formatVal(hc)) cm", color: .purple)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    // MARK: - 记录列表

    @ViewBuilder
    private var recordsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("历史记录")
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal)

            if records.isEmpty {
                Text("暂无记录")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal)
            } else {
                ForEach(records.reversed()) { record in
                    Button {
                        editing = record
                    } label: {
                        RecordRow(record: record, baby: baby)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func formatVal(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }
}

// MARK: - 小组件

private struct StatBadge: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 70)
    }
}

private struct RecordRow: View {
    let record: GrowthRecord
    let baby: Baby

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(Self.df.string(from: record.date))
                    .font(.subheadline)
                Text(AgeCalculator.age(birthday: baby.birthday, at: record.date).localized)
                    .font(.caption)
                    .foregroundStyle(.tint)
            }
            Spacer()
            HStack(spacing: 12) {
                if let h = record.heightCM {
                    Text("\(fmt(h)) cm")
                        .font(.footnote)
                        .foregroundStyle(.pink)
                }
                if let w = record.weightKG {
                    Text("\(fmt(w)) kg")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
                if let hc = record.headCircumCM {
                    Text("\(fmt(hc)) cm")
                        .font(.footnote)
                        .foregroundStyle(.purple)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
    }

    private func fmt(_ v: Double) -> String {
        v.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", v)
            : String(format: "%.1f", v)
    }

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "yyyy 年 M 月 d 日"
        return f
    }()
}
