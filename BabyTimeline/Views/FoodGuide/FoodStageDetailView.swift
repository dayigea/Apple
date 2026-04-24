import SwiftUI

struct FoodStageDetailView: View {
    let stage: FoodStage
    @State private var selectedCategory = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                headerCard
                infoBanner
                categoryPicker
                categoryContent
                pairingsSection
                avoidSection
                tipsSection
            }
            .padding(.bottom, 32)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(stage.monthRange)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header

    private var headerCard: some View {
        VStack(spacing: 8) {
            Image(systemName: stage.icon)
                .font(.system(size: 40))
                .foregroundStyle(.orange)
            Text(stage.title)
                .font(.title2)
                .fontWeight(.bold)
            Text(stage.subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(.ultraThinMaterial)
    }

    // MARK: - Info Banner

    private var infoBanner: some View {
        HStack(spacing: 0) {
            infoPill(icon: "mouth", text: stage.texture.components(separatedBy: "，").first ?? stage.texture)
            Divider().frame(height: 30)
            infoPill(icon: "clock", text: stage.feedingFrequency)
            Divider().frame(height: 30)
            infoPill(icon: "drop", text: stage.dailyMilk)
        }
        .padding(.vertical, 10)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func infoPill(icon: String, text: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.orange)
            Text(text)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    // MARK: - Category Picker

    private var categories: [(String, String, [FoodItem])] {
        var result: [(String, String, [FoodItem])] = []
        if !stage.meats.isEmpty { result.append(("肉蛋鱼", "🥩", stage.meats)) }
        if !stage.staples.isEmpty { result.append(("面食主食", "🍚", stage.staples)) }
        if !stage.vegetables.isEmpty { result.append(("蔬菜", "🥦", stage.vegetables)) }
        if !stage.fruits.isEmpty { result.append(("水果", "🍎", stage.fruits)) }
        return result
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, cat in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedCategory = index
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Text(cat.1)
                                .font(.callout)
                            Text(cat.0)
                                .font(.subheadline)
                                .fontWeight(selectedCategory == index ? .semibold : .regular)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(selectedCategory == index ? Color.orange : Color(.tertiarySystemGroupedBackground))
                        .foregroundStyle(selectedCategory == index ? .white : .primary)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 16)
    }

    // MARK: - Category Content

    @ViewBuilder
    private var categoryContent: some View {
        let cats = categories
        if !cats.isEmpty && selectedCategory < cats.count {
            let items = cats[selectedCategory].2
            VStack(spacing: 8) {
                ForEach(items) { item in
                    foodItemRow(item)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
        }
    }

    private func foodItemRow(_ item: FoodItem) -> some View {
        HStack(spacing: 12) {
            Text(item.icon)
                .font(.title2)
                .frame(width: 40, height: 40)
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(item.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Pairings

    private var pairingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader(icon: "fork.knife", title: "搭配推荐", color: .green)
            ForEach(stage.pairings) { pairing in
                pairingCard(pairing)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    private func pairingCard(_ pairing: MealPairing) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(pairing.title)
                .font(.subheadline)
                .fontWeight(.semibold)
            FlowLayout(spacing: 6) {
                ForEach(pairing.ingredients, id: \.self) { ingredient in
                    Text(ingredient)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                }
            }
            Text(pairing.note)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Avoid

    private var avoidSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "xmark.octagon", title: "不能吃", color: .red)
            ForEach(stage.avoid, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.top, 2)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(icon: "lightbulb", title: "小贴士", color: .yellow)
            ForEach(stage.tips, id: \.self) { tip in
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                        .padding(.top, 2)
                    Text(tip)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.top, 20)
    }

    // MARK: - Helpers

    private func sectionHeader(icon: String, title: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(title)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}

// MARK: - Flow Layout

private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, origin) in result.origins.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (origins: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var origins: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (origins, CGSize(width: maxWidth, height: y + rowHeight))
    }
}
