import SwiftData
import SwiftUI

/// 主界面：三个 Tab — 时间线 / 里程碑 / 设置。
struct MainTabView: View {

    let baby: Baby

    var body: some View {
        TabView {
            TimelineView(baby: baby)
                .tabItem {
                    Label("时间线", systemImage: "photo.stack")
                }

            MilestoneListView(baby: baby)
                .tabItem {
                    Label("里程碑", systemImage: "star.circle")
                }

            SettingsView(baby: baby)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}
