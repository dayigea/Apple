import SwiftData
import SwiftUI
import UserNotifications

/// 主页：今日宝宝 dashboard。
/// 打开 App 就能看到——三餐、本周学习目标、待办、那时候的照片、最近萌句。
struct TodayView: View {
    let baby: Baby

    @Environment(\.modelContext) private var context
    @Query private var photos: [PhotoEntry]
    @Query private var pediatricRecords: [PediatricRecord]
    @Query private var babyWords: [BabyWord]

    @State private var refreshTrigger = UUID()
    @State private var showingAddWord = false
    @State private var streakCount = 0
    @State private var showNotifBanner = false
    @State private var permissionStatus: UNAuthorizationStatus = .notDetermined

    private var digest: DailyDigest {
        DailyDigestService.compute(
            for: baby,
            pediatricRecords: pediatricRecords,
            babyWords: babyWords,
            photos: photos
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    headerCard
                    if showNotifBanner {
                        notifBanner
                    }
                    quickActionsRow
                    if let meal = digest.mealSuggestion {
                        mealCard(meal)
                    }
                    if !digest.developmentTips.isEmpty {
                        developmentCard
                    } else {
                        developmentEmptyCard
                    }
                    if !digest.pediatricDue.isEmpty {
                        pediatricCard
                    }
                    if !digest.photoMemories.isEmpty {
                        memoryCard
                    } else if photos.isEmpty {
                        memoryEmptyCard
                    }
                    wordsCard
                    reflectionCard
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .id(refreshTrigger)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("今日宝宝")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingAddWord) {
                NavigationStack {
                    BabyDictionaryEditView(word: nil)
                }
            }
            .refreshable {
                refreshTrigger = UUID()
            }
            .task {
                streakCount = OpenStreak.recordOpen()
                permissionStatus = await DailyNotificationScheduler.currentAuthorizationStatus()
                showNotifBanner = !DailyNotificationScheduler.isEnabled
                    && !OpenStreak.notifPromptDismissed
                    && permissionStatus != .denied
                    && streakCount >= 2
            }
        }
    }

    // MARK: - Header

    private var headerCard: some View {
        let age = DailyDigestService.ageText(birthday: baby.birthday, at: .now)
        let weekday: String = {
            let f = DateFormatter()
            f.locale = Locale(identifier: "zh_CN")
            f.dateFormat = "M月d日 EEEE"
            return f.string(from: .now)
        }()
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(greeting)
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                if streakCount >= 2 {
                    HStack(spacing: 3) {
                        Image(systemName: "flame.fill")
                            .foregroundStyle(.orange)
                            .font(.caption)
                        Text("\(streakCount) 天")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.orange)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.14))
                    .clipShape(Capsule())
                }
            }
            HStack(spacing: 8) {
                Text(weekday)
                Text("·")
                Text("\(baby.name.isEmpty ? "宝宝" : baby.name) \(age)")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color.accentColor.opacity(0.18), Color.accentColor.opacity(0.05)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - 通知 opt-in banner

    private var notifBanner: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "bell.badge.fill")
                .font(.title3)
                .foregroundStyle(.yellow)
            VStack(alignment: .leading, spacing: 4) {
                Text("每天准时提醒一下？")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("固定时间推送当天的三餐建议、可学的发育目标和体检待办。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    Button {
                        Task { await enableNotifications() }
                    } label: {
                        Text("好，开启")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.accentColor)
                            .foregroundStyle(.white)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    Button {
                        OpenStreak.notifPromptDismissed = true
                        withAnimation { showNotifBanner = false }
                    } label: {
                        Text("不用了")
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .foregroundStyle(.secondary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(
            LinearGradient(
                colors: [Color.yellow.opacity(0.18), Color.orange.opacity(0.08)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func enableNotifications() async {
        let granted = await DailyNotificationScheduler.requestPermission()
        if granted {
            DailyNotificationScheduler.isEnabled = true
            await DailyNotificationScheduler.rescheduleIfNeeded(
                baby: baby,
                pediatricRecords: pediatricRecords,
                babyWords: babyWords,
                photos: photos
            )
            OpenStreak.notifPromptDismissed = true
            withAnimation { showNotifBanner = false }
            let gen = UINotificationFeedbackGenerator()
            gen.notificationOccurred(.success)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<11: return "早上好 ☀️"
        case 11..<14: return "中午好 🍚"
        case 14..<18: return "下午好 🌤"
        case 18..<22: return "晚上好 🌙"
        default: return "夜深了 🌃"
        }
    }

    // MARK: - Quick actions

    private var quickActionsRow: some View {
        HStack(spacing: 10) {
            quickButton(icon: "text.bubble.fill", title: "记萌句", tint: .teal) {
                showingAddWord = true
            }
            NavigationLink {
                PediatricView(baby: baby)
            } label: {
                quickButtonContent(icon: "stethoscope", title: "查体检", tint: .pink)
            }
            .buttonStyle(.plain)

            NavigationLink {
                GrowthChartView(baby: baby)
            } label: {
                quickButtonContent(icon: "ruler.fill", title: "记测量", tint: .indigo)
            }
            .buttonStyle(.plain)

            NavigationLink {
                FoodGuideView(baby: baby)
            } label: {
                quickButtonContent(icon: "fork.knife", title: "看食谱", tint: .green)
            }
            .buttonStyle(.plain)
        }
    }

    private func quickButton(
        icon: String,
        title: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            quickButtonContent(icon: icon, title: title, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func quickButtonContent(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(tint)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: - Empty states

    private var developmentEmptyCard: some View {
        NavigationLink {
            DevelopmentChecklistView(baby: baby)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text("当前阶段全部勾完了！")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("看看下一个月龄会有什么变化")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var memoryEmptyCard: some View {
        NavigationLink {
            SettingsView(baby: baby)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title3)
                    .foregroundStyle(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("还没有照片")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text("去设置 → 宝宝照片 导入相册，「那时候」才能给你回忆")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 每日反思

    private var reflectionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
                Text("今天聊聊")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            Text(dailyPrompt)
                .font(.callout)
                .foregroundStyle(.primary)
                .padding(.vertical, 4)
            Button {
                showingAddWord = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.pencil")
                    Text("记下来")
                }
                .font(.caption)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.yellow.opacity(0.18))
                .foregroundStyle(.orange)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var dailyPrompt: String {
        let prompts = [
            "宝宝今天最爱玩什么？",
            "今天有没有说一句让你忍不住笑的话？",
            "今天宝宝最让你欣慰的瞬间是什么？",
            "今天有没有发现宝宝又会了一件新事？",
            "今天的午睡多长？精神怎么样？",
            "今天宝宝最爱吃的菜是？",
            "今天和宝宝出门去了哪里？",
            "宝宝今天的情绪如何？为什么？",
            "今天宝宝最喜欢的绘本/玩具是？",
            "今天是不是有了第一次的什么？",
            "今天和家里谁玩得最开心？",
        ]
        let day = Calendar.current.dateComponents([.year, .dayOfYear], from: .now)
        let seed = (day.year ?? 0) * 366 + (day.dayOfYear ?? 0)
        return prompts[seed % prompts.count]
    }

    // MARK: - 三餐推荐

    private func mealCard(_ meal: DailyDigest.MealSuggestion) -> some View {
        NavigationLink {
            FoodGuideView(baby: baby)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.green)
                    Text("今日三餐")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Text(meal.dayLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 6) {
                    mealRow(emoji: "☀️", label: "早", text: meal.breakfast)
                    if let snack = meal.morningSnack {
                        mealRow(emoji: "🍎", label: "加", text: snack, dimmed: true)
                    }
                    mealRow(emoji: "🍱", label: "午", text: meal.lunch, emphasis: true)
                    if let snack = meal.afternoonSnack {
                        mealRow(emoji: "🥛", label: "加", text: snack, dimmed: true)
                    }
                    mealRow(emoji: "🌙", label: "晚", text: meal.dinner)
                }

                Text("基于 \(meal.stageTitle) · 点查看完整食谱")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func mealRow(
        emoji: String,
        label: String,
        text: String,
        emphasis: Bool = false,
        dimmed: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(emoji).font(.callout)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 16, alignment: .leading)
            Text(text)
                .font(emphasis ? .subheadline : .footnote)
                .fontWeight(emphasis ? .semibold : .regular)
                .foregroundStyle(dimmed ? .secondary : .primary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    // MARK: - 这周学一学（发育清单）

    private var developmentCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                DevelopmentChecklistView(baby: baby)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                    Text("这周学一学")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            VStack(spacing: 8) {
                ForEach(digest.developmentTips) { item in
                    devItemRow(item)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func devItemRow(_ item: DevelopmentItem) -> some View {
        let isDone = baby.isDevelopmentItemCompleted(item.id)
        return Button {
            baby.toggleDevelopmentItem(item.id)
            try? context.save()
            let gen = UIImpactFeedbackGenerator(style: .light)
            gen.impactOccurred()
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isDone ? Color.purple : Color.secondary.opacity(0.5))
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline)
                        .strikethrough(isDone, color: .secondary)
                        .foregroundStyle(.primary)
                    if let detail = item.detail {
                        Text(detail)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer(minLength: 4)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .background(isDone ? Color.purple.opacity(0.05) : Color(.tertiarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - 体检 / 疫苗待办

    private var pediatricCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "bell.badge")
                    .foregroundStyle(.orange)
                Text("别忘了")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            VStack(spacing: 6) {
                ForEach(digest.pediatricDue) { event in
                    NavigationLink {
                        PediatricEventDetailView(event: event, existing: nil)
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: event.kind == .checkup ? "stethoscope" : "syringe")
                                .foregroundStyle(event.kind == .checkup ? .blue : .pink)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(event.title)
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                Text("推荐 \(event.ageLabel) · 点击记录完成")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(Color(.tertiarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - 那时候的照片

    private var memoryCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "clock.arrow.circlepath")
                    .foregroundStyle(.indigo)
                Text("那时候")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
            }
            HStack(spacing: 10) {
                ForEach(digest.photoMemories) { mem in
                    memoryItem(mem)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    @ViewBuilder
    private func memoryItem(_ mem: DailyDigest.PhotoMemory) -> some View {
        let entry = photos.first { $0.assetLocalId == mem.assetLocalId }
        Group {
            if let entry {
                NavigationLink {
                    PhotoDetailView(baby: baby, entry: entry)
                } label: {
                    memoryContent(mem)
                }
                .buttonStyle(.plain)
            } else {
                memoryContent(mem)
            }
        }
    }

    private func memoryContent(_ mem: DailyDigest.PhotoMemory) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            AsyncPHAssetImage(localIdentifier: mem.assetLocalId, size: .thumbnail(160))
                .aspectRatio(1, contentMode: .fill)
                .frame(maxWidth: .infinity)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            Text(mem.label)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
            Text(mem.ageAtThen)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - 最近萌句

    private var wordsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            NavigationLink {
                BabyDictionaryView()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .foregroundStyle(.teal)
                    Text("最近萌句")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)

            if digest.recentWords.isEmpty {
                Text("点这里去记录第一句宝宝说的话吧")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                VStack(spacing: 6) {
                    ForEach(digest.recentWords) { word in
                        HStack(alignment: .top, spacing: 8) {
                            Text("「")
                                .foregroundStyle(.teal)
                                .font(.headline)
                            Text(word.text)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                            Text("」")
                                .foregroundStyle(.teal)
                                .font(.headline)
                            Spacer()
                            Text(formatShortDate(word.dateSaid))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func formatShortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_CN")
        f.dateFormat = "M月d日"
        return f.string(from: date)
    }
}
