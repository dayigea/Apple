import Foundation
import OSLog

/// 主 App 与 Widget Extension 共享的常量。
enum AppGroup {
    static let identifier = "group.com.personal.babytimeline"

    private static let log = Logger(subsystem: "com.personal.babytimeline", category: "AppGroup")

    /// 当前是否真正用上了 App Group 共享容器。
    /// false 时主 App 和 Widget 各写各的 Documents，**Widget 永远读不到 App 的数据**。
    static var isUsingSharedContainer: Bool {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) != nil
    }

    /// 共享 App Group 容器里的 SwiftData 数据库 URL。
    /// 主 App 和 Widget 都用这个路径初始化 ModelContainer，确保读到同一份数据。
    ///
    /// 如果 App Group 还没在 Xcode Signing & Capabilities 里配好，
    /// 会退化到各自 target 的 Documents 目录——此时主 App 和 Widget 各写各的，互相看不到。
    /// 这里会打日志（Console.app 里搜 subsystem `com.personal.babytimeline`）提醒。
    /// 注意：以前 DEBUG 下会 assertionFailure，但 widget 扩展崩了之后整个 widget 就废了，
    /// 现在改成只记日志 + 在 App 的 About 页面用 UI 兜底告知。
    static var sharedStoreURL: URL {
        if let groupURL = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: identifier) {
            let url = groupURL.appending(path: "BabyTimeline.store")
            log.info("Using App Group container: \(url.path, privacy: .public)")
            return url
        }
        let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appending(path: "BabyTimeline.store")
        log.error("App Group '\(identifier, privacy: .public)' NOT available — falling back to Documents/. 主 App 和 Widget 看不到对方的数据！请在 Xcode → Signing & Capabilities 里给两个 target 都勾上 App Groups。Fallback path: \(url.path, privacy: .public)")
        return url
    }
}
