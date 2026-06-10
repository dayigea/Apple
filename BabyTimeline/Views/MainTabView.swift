import SwiftData
import SwiftUI

/// 主界面：今日 / 时间线 / 成长 / 里程碑 / 设置。
struct MainTabView: View {

    let baby: Baby

    var body: some View {
        TabView {
            TodayView(baby: baby)
                .tabItem {
                    Label("今日", systemImage: "sun.max.fill")
                }

            TimelineView(baby: baby)
                .tabItem {
                    Label("时间线", systemImage: "photo.stack")
                }

            GrowthHubView(baby: baby)
                .tabItem {
                    Label("成长", systemImage: "chart.xyaxis.line")
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
