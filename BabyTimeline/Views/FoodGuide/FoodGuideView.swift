import SwiftUI

struct FoodGuideView: View {
    let baby: Baby

    var body: some View {
        List {
            currentStageSection
            allStagesSection
        }
        .listStyle(.insetGrouped)
        .navigationTitle("辅食指南")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var currentStageSection: some View {
        if let stage = FoodGuideData.currentStage(birthday: baby.birthday) {
            Section {
                NavigationLink {
                    FoodStageDetailView(stage: stage)
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(.green.opacity(0.12))
                                .frame(width: 50, height: 50)
                            Image(systemName: stage.icon)
                                .font(.title2)
                                .foregroundStyle(.green)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("当前阶段")
                                .font(.caption)
                                .foregroundStyle(.green)
                                .fontWeight(.semibold)
                            Text(stage.title)
                                .font(.headline)
                            Text(stage.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            } header: {
                Text("宝宝现在适合吃什么")
            }
        }
    }

    private var allStagesSection: some View {
        Section {
            ForEach(FoodGuideData.stages) { stage in
                NavigationLink {
                    FoodStageDetailView(stage: stage)
                } label: {
                    stageRow(stage)
                }
            }
        } header: {
            Text("全部阶段")
        } footer: {
            Text("参考来源：WHO、AAP、《中国居民膳食指南2022》")
        }
    }

    private func stageRow(_ stage: FoodStage) -> some View {
        HStack(spacing: 12) {
            Image(systemName: stage.icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(stage.monthRange)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(stage.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}
