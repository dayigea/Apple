import SwiftUI

struct WeeklyMealPlanView: View {
    let stageTitle: String
    let plan: WeeklyMealPlan

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                summaryCard
                ForEach(plan.days) { day in
                    dayCard(day)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("一周食谱")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var summaryCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .font(.title3)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text(stageTitle)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(plan.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func dayCard(_ day: DailyMealPlan) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(day.day)
                .font(.headline)
                .foregroundStyle(.orange)
            mealRow(icon: "sun.max.fill", label: "早餐", text: day.breakfast, color: .orange)
            mealRow(icon: "leaf.fill", label: "上午加餐", text: day.morningSnack, color: .green)
            mealRow(icon: "fork.knife", label: "午餐", text: day.lunch, color: .red)
            mealRow(icon: "cup.and.saucer.fill", label: "下午加餐", text: day.afternoonSnack, color: .purple)
            mealRow(icon: "moon.stars.fill", label: "晚餐", text: day.dinner, color: .blue)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func mealRow(icon: String, label: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
                .frame(width: 18, height: 18)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
