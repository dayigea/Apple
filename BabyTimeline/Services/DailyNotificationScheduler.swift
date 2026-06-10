import Foundation
import OSLog
import SwiftData
import UserNotifications

/// 每日推送本地通知：
/// - 用户在设置里启用 + 选时间
/// - 每次 App 打开时重新排好未来 14 天的通知（每天一条，带当天三餐建议）
/// - 通知不依赖 App Group / 服务器，纯本地
enum DailyNotificationScheduler {

    private static let log = Logger(subsystem: "com.personal.babytimeline", category: "Notification")

    static let enabledKey = "dailyReminder.enabled"
    static let hourKey = "dailyReminder.hour"
    static let minuteKey = "dailyReminder.minute"
    static let categoryId = "babyDaily"
    static let notificationIdPrefix = "babyDaily."

    static var isEnabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? false }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    static var reminderHour: Int {
        get { UserDefaults.standard.object(forKey: hourKey) as? Int ?? 9 }
        set { UserDefaults.standard.set(newValue, forKey: hourKey) }
    }

    static var reminderMinute: Int {
        get { UserDefaults.standard.object(forKey: minuteKey) as? Int ?? 0 }
        set { UserDefaults.standard.set(newValue, forKey: minuteKey) }
    }

    /// 申请权限。返回是否已授予。
    static func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .badge, .sound])
            return granted
        } catch {
            log.error("Notification permission error: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    static func currentAuthorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    /// 取消所有 daily 通知。
    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { reqs in
            let ids = reqs.map { $0.identifier }.filter { $0.hasPrefix(notificationIdPrefix) }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    /// 根据当前 Baby + 现在的数据，重新排好未来 14 天的每日通知。
    /// 没启用就先取消。
    @MainActor
    static func rescheduleIfNeeded(
        baby: Baby,
        pediatricRecords: [PediatricRecord],
        babyWords: [BabyWord],
        photos: [PhotoEntry]
    ) async {
        cancelAll()
        guard isEnabled else { return }

        let status = await currentAuthorizationStatus()
        guard status == .authorized || status == .provisional else { return }

        let center = UNUserNotificationCenter.current()
        let calendar = Calendar(identifier: .gregorian)
        var scheduled = 0

        for daysAhead in 0..<14 {
            guard let date = calendar.date(byAdding: .day, value: daysAhead, to: Date.now) else { continue }
            // 把日期设到今天/那天的设定时间
            var comps = calendar.dateComponents([.year, .month, .day], from: date)
            comps.hour = reminderHour
            comps.minute = reminderMinute
            guard let fireDate = calendar.date(from: comps), fireDate > .now else { continue }

            let digest = DailyDigestService.compute(
                for: baby,
                date: fireDate,
                pediatricRecords: pediatricRecords,
                babyWords: babyWords,
                photos: photos
            )

            let content = UNMutableNotificationContent()
            content.title = title(for: digest, baby: baby)
            content.body = body(for: digest)
            content.sound = .default
            content.categoryIdentifier = categoryId

            let trigger = UNCalendarNotificationTrigger(
                dateMatching: comps,
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: notificationIdPrefix + identifier(for: fireDate),
                content: content,
                trigger: trigger
            )
            do {
                try await center.add(request)
                scheduled += 1
            } catch {
                log.error("Schedule failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        log.info("Scheduled \(scheduled) daily notifications")
    }

    // MARK: - 内容

    private static func title(for digest: DailyDigest, baby: Baby) -> String {
        let age = DailyDigestService.ageText(birthday: baby.birthday, at: digest.date)
        let name = baby.name.isEmpty ? "宝宝" : baby.name
        return "\(name) 今天 \(age) ✨"
    }

    private static func body(for digest: DailyDigest) -> String {
        var lines: [String] = []
        if let meal = digest.mealSuggestion {
            lines.append("🍱 午餐：\(meal.lunch)")
        }
        if let tip = digest.developmentTips.first {
            lines.append("💡 这周可以陪宝宝：\(tip.title)")
        }
        if let due = digest.pediatricDue.first {
            lines.append("📋 别忘了：\(due.title)")
        }
        if lines.isEmpty {
            lines.append("打开看看宝宝今天的内容 ✨")
        }
        return lines.joined(separator: "\n")
    }

    private static func identifier(for date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
