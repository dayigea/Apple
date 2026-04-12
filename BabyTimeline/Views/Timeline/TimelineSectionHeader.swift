import SwiftUI

/// 时间线每一段的标题栏。
struct TimelineSectionHeader: View {
    let stage: AgeCalculator.Stage
    let count: Int

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(stage.title)
                .font(.headline)
                .foregroundStyle(.primary)
            Spacer()
            Text("\(count) 张")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
