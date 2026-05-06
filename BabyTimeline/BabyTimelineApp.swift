import SwiftData
import SwiftUI

@main
struct BabyTimelineApp: App {

    /// 整个 App 的 SwiftData 容器。持久化所有本地数据。
    let modelContainer: ModelContainer

    init() {
        do {
            let schema = Schema([
                Baby.self,
                PhotoEntry.self,
                Milestone.self,
                GrowthRecord.self,
                PediatricRecord.self,
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
    }
}
