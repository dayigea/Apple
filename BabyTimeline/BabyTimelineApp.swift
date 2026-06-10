import SwiftData
import SwiftUI

@main
struct BabyTimelineApp: App {

    /// 整个 App 的 SwiftData 容器。持久化所有本地数据。
    let modelContainer: ModelContainer

    @Environment(\.scenePhase) private var scenePhase

    init() {
        do {
            let schema = Schema([
                Baby.self,
                PhotoEntry.self,
                Milestone.self,
                GrowthRecord.self,
                PediatricRecord.self,
                BabyWord.self,
            ])
            let config = ModelConfiguration(
                schema: schema,
                url: AppGroup.sharedStoreURL,
                cloudKitDatabase: .none
            )
            modelContainer = try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("无法创建 SwiftData 容器：\(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
        .onChange(of: scenePhase) { _, newValue in
            if newValue == .active {
                Task { await rescheduleDailyNotifications() }
            }
        }
    }

    /// 每次 App 切到前台时刷新未来 14 天的本地通知。
    /// 把"用最新数据算今天/明天该提醒什么"放到 App 启动时一次性做完。
    @MainActor
    private func rescheduleDailyNotifications() async {
        guard DailyNotificationScheduler.isEnabled else { return }
        let context = ModelContext(modelContainer)
        guard let baby = (try? context.fetch(FetchDescriptor<Baby>()))?.first else { return }
        let photos = (try? context.fetch(FetchDescriptor<PhotoEntry>())) ?? []
        let pediatric = (try? context.fetch(FetchDescriptor<PediatricRecord>())) ?? []
        let words = (try? context.fetch(FetchDescriptor<BabyWord>())) ?? []
        await DailyNotificationScheduler.rescheduleIfNeeded(
            baby: baby,
            pediatricRecords: pediatric,
            babyWords: words,
            photos: photos
        )
    }
}
