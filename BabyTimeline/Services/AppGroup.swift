import Foundation

/// 主 App 与 Widget Extension 共享的常量。
enum AppGroup {
    static let identifier = "group.com.personal.babytimeline"

    /// 共享 App Group 容器里的 SwiftData 数据库 URL。
    /// 主 App 和 Widget 都用这个路径初始化 ModelContainer，确保读到同一份数据。
    static var sharedStoreURL: URL {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier)!
            .appending(path: "BabyTimeline.store")
    }
}
