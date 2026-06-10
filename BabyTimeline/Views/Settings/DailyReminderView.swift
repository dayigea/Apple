import SwiftData
import SwiftUI
import UserNotifications

/// 每日提醒设置：开关 + 时间。每天定时推送一条本地通知，
/// 带当天的三餐建议、可学的发育目标和体检待办。
struct DailyReminderView: View {

    let baby: Baby

    @Environment(\.modelContext) private var context
    @Query private var photos: [PhotoEntry]
    @Query private var pediatricRecords: [PediatricRecord]
    @Query private var babyWords: [BabyWord]

    @State private var isEnabled: Bool = DailyNotificationScheduler.isEnabled
    @State private var time: Date = {
        var comps = DateComponents()
        comps.hour = DailyNotificationScheduler.reminderHour
        comps.minute = DailyNotificationScheduler.reminderMinute
        return Calendar.current.date(from: comps) ?? .now
    }()
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined
    @State private var showSettingsAlert = false

    var body: some View {
        Form {
            Section {
                Toggle("每天定时推送", isOn: $isEnabled)
                    .onChange(of: isEnabled) { _, newValue in
                        Task { await handleToggle(newValue) }
                    }
                if isEnabled {
                    DatePicker(
                        "提醒时间",
                        selection: $time,
                        displayedComponents: .hourAndMinute
                    )
                    .onChange(of: time) { _, _ in
                        saveTime()
                        Task { await reschedule() }
                    }
                }
            } footer: {
                if permissionStatus == .denied {
                    Text("通知权限被拒绝。去「设置 → 苹果长大了 → 通知」打开后再回来。")
                        .foregroundStyle(.orange)
                } else {
                    Text("通知是本地生成的，不会上传任何数据。每天会带上当天的三餐建议、可学的发育目标和体检提醒。")
                }
            }

            if isEnabled {
                Section("预览") {
                    let digest = DailyDigestService.compute(
                        for: baby,
                        pediatricRecords: pediatricRecords,
                        babyWords: babyWords,
                        photos: photos
                    )
                    if let meal = digest.mealSuggestion {
                        previewRow(icon: "fork.knife", text: "🍱 午餐：\(meal.lunch)")
                    }
                    if let tip = digest.developmentTips.first {
                        previewRow(icon: "sparkles", text: "💡 这周可以陪宝宝：\(tip.title)")
                    }
                    if let due = digest.pediatricDue.first {
                        previewRow(icon: "bell.badge", text: "📋 别忘了：\(due.title)")
                    }
                }
            }
        }
        .navigationTitle("每日提醒")
        .navigationBarTitleDisplayMode(.inline)
        .alert("需要通知权限", isPresented: $showSettingsAlert) {
            Button("去设置") {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
            Button("取消", role: .cancel) {
                isEnabled = false
                DailyNotificationScheduler.isEnabled = false
            }
        } message: {
            Text("请到「设置 → 苹果长大了 → 通知」打开权限。")
        }
        .task {
            permissionStatus = await DailyNotificationScheduler.currentAuthorizationStatus()
        }
    }

    // MARK: - Actions

    private func handleToggle(_ enabled: Bool) async {
        if enabled {
            let granted = await DailyNotificationScheduler.requestPermission()
            if !granted {
                showSettingsAlert = true
                return
            }
            DailyNotificationScheduler.isEnabled = true
            saveTime()
            await reschedule()
        } else {
            DailyNotificationScheduler.isEnabled = false
            DailyNotificationScheduler.cancelAll()
        }
        permissionStatus = await DailyNotificationScheduler.currentAuthorizationStatus()
    }

    private func saveTime() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        DailyNotificationScheduler.reminderHour = comps.hour ?? 9
        DailyNotificationScheduler.reminderMinute = comps.minute ?? 0
    }

    private func reschedule() async {
        await DailyNotificationScheduler.rescheduleIfNeeded(
            baby: baby,
            pediatricRecords: pediatricRecords,
            babyWords: babyWords,
            photos: photos
        )
    }

    private func previewRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(.yellow)
                .frame(width: 18)
            Text(text)
                .font(.subheadline)
        }
    }
}
