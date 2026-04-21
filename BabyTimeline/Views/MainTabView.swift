import SwiftData
import SwiftUI

/// 主界面：四个 Tab — 时间线 / 里程碑 / 成长 / 设置。
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

            GrowthHubView(baby: baby)
                .tabItem {
                    Label("成长", systemImage: "chart.xyaxis.line")
                }

            SettingsView(baby: baby)
                .tabItem {
                    Label("设置", systemImage: "gearshape")
                }
        }
    }
}
