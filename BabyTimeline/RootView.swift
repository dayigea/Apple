import SwiftData
import SwiftUI

/// 根视图：根据 SwiftData 里是否已有宝宝记录，分发到 Setup 或主界面。
struct RootView: View {

    @Query private var babies: [Baby]

    var body: some View {
        if let baby = babies.first {
            MainTabView(baby: baby)
        } else {
            SetupView()
        }
    }
}
