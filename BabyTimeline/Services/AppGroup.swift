import Foundation

/// 主 App 与 Widget Extension 共享的常量。
enum AppGroup {
    static let identifier = "group.com.personal.babytimeline"

    /// 共享 App Group 容器里的 SwiftData 数据库 URL。
    /// 主 App 和 Widget 都用这个路径初始化 ModelContainer，确保读到同一份数据。
    ///
    /// 如果 App Group 还没在 Xcode Signing & Capabilities 里配好，
    /// 会退化到 App 自己的 Documents 目录，避免崩溃。
    static var sharedStoreURL: URL {
        if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            return groupURL.appending(path: "BabyTimeline.store")
        }
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "BabyTimeline.store")
    }
}
