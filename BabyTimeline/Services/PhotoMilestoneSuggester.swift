import Foundation

/// 基于「时间线里的照片内容」自动组装里程碑建议。
///
/// 跟以前那套「按月龄从写死的 MilestoneCatalog 里挑」最大的不同：
/// **建议必须有真照片做证据**——只有当某张照片的 Vision 自动标签里出现某个触发
/// 词（比如 `雪` / `海滩` / `蛋糕` / `狗`）时，才会出现「第一次见到雪 / 第一次去
/// 海边 …」这样的建议条目。建议的日期、绑定照片、自动备注全部从那张照片里来，
/// 不再凭空生成。
///
/// 数据来源：`PhotoEntry.autoTags`（Vision 场景分类的中文标签，
/// 见 `TagTranslator`）。规则本身仍然是一份手写小目录（见下方
/// `PhotoMilestoneSuggester.rules`），但它只声明「触发词 → 标题/图标」的映射，
/// 不再硬编码"应该在 N 月龄出现"——什么时候出现完全由照片说了算。
enum PhotoMilestoneSuggester {

    // MARK: - 规则定义

    enum Category: String, CaseIterable, Identifiable {
        case activity   // 活动
        case place      // 地点
        case nature     // 风景 / 动物
        case food       // 美食
        case event      // 节日 / 活动

        var id: String { rawValue }

        var label: String {
            switch self {
            case .activity: return "活动"
            case .place:    return "地点"
            case .nature:   return "动物 / 风景"
            case .food:     return "美食"
            case .event:    return "节日"
            }
        }
    }

    struct Rule {
        /// 任意一个触发词出现在 `PhotoEntry.autoTags` 里就算命中。
        let triggerTags: Set<String>
        /// 生成的里程碑标题，例如 "第一次见到雪"。
        let title: String
        /// SF Symbol 名称（用于建议列表里没有照片时的占位图标）。
        let icon: String
        let category: Category
    }

    /// 全部规则。新增一条直接往下加；删/改时小心 `title` 是 `Milestone.title` 的
    /// 主键（已记录里程碑按 title 去重，title 一改就会重新冒出来）。
    ///
    /// 选词原则：
    /// - 不放太泛的标签（"宝宝/人物/室内"已在标签翻译层就被过滤过一轮，不会作为建议触发）
    /// - 一条规则可以列多个同义词，命中任一即视为该里程碑（如 "海滩" / "海" / "海边"）
    /// - 标题用「第一次 …」开头，跟手动里程碑的语感一致
    static let rules: [Rule] = [
        // —— 活动 ——
        Rule(triggerTags: ["走路"],            title: "第一次走路",       icon: "figure.walk",         category: .activity),
        Rule(triggerTags: ["跑步"],            title: "第一次跑步",       icon: "figure.run",          category: .activity),
        Rule(triggerTags: ["跳舞"],            title: "第一次跳舞",       icon: "figure.dance",        category: .activity),
        Rule(triggerTags: ["跳跃"],            title: "第一次跳起来",     icon: "figure.jumprope",     category: .activity),
        Rule(triggerTags: ["游泳", "泳池"],    title: "第一次游泳",       icon: "figure.pool.swim",    category: .activity),
        Rule(triggerTags: ["读书", "书本"],    title: "第一次读书",       icon: "book",                category: .activity),
        Rule(triggerTags: ["画画", "绘画"],    title: "第一次画画",       icon: "paintbrush",          category: .activity),
        Rule(triggerTags: ["唱歌"],            title: "第一次唱歌",       icon: "music.mic",           category: .activity),
        Rule(triggerTags: ["自行车"],          title: "第一次骑车",       icon: "bicycle",             category: .activity),
        Rule(triggerTags: ["滑板", "滑板车"],  title: "第一次玩滑板",     icon: "skateboard",          category: .activity),
        Rule(triggerTags: ["旅行"],            title: "第一次旅行",       icon: "suitcase",            category: .activity),
        Rule(triggerTags: ["飞机"],            title: "第一次坐飞机",     icon: "airplane",            category: .activity),
        Rule(triggerTags: ["火车"],            title: "第一次坐火车",     icon: "tram",                category: .activity),
        Rule(triggerTags: ["船", "渡轮"],      title: "第一次坐船",       icon: "ferry",               category: .activity),
        Rule(triggerTags: ["地铁"],            title: "第一次坐地铁",     icon: "tram.fill",           category: .activity),
        Rule(triggerTags: ["露营"],            title: "第一次露营",       icon: "tent",                category: .activity),
        Rule(triggerTags: ["远足", "爬山"],    title: "第一次远足",       icon: "figure.hiking",       category: .activity),
        Rule(triggerTags: ["钓鱼"],            title: "第一次钓鱼",       icon: "fish",                category: .activity),
        Rule(triggerTags: ["滑冰"],            title: "第一次滑冰",       icon: "figure.skating",      category: .activity),
        Rule(triggerTags: ["滑雪"],            title: "第一次滑雪",       icon: "figure.skiing.downhill", category: .activity),
        Rule(triggerTags: ["风筝"],            title: "第一次放风筝",     icon: "wind",                category: .activity),
        Rule(triggerTags: ["拼图"],            title: "第一次玩拼图",     icon: "puzzlepiece",         category: .activity),
        Rule(triggerTags: ["积木"],            title: "第一次玩积木",     icon: "square.stack.3d.up",  category: .activity),

        // —— 乐器 ——
        Rule(triggerTags: ["钢琴"],            title: "第一次弹钢琴",     icon: "pianokeys",           category: .activity),
        Rule(triggerTags: ["吉他"],            title: "第一次摸吉他",     icon: "guitars",             category: .activity),
        Rule(triggerTags: ["鼓"],              title: "第一次打鼓",       icon: "music.note",          category: .activity),
        Rule(triggerTags: ["乐器"],            title: "第一次接触乐器",   icon: "music.note",          category: .activity),

        // —— 地点 ——
        Rule(triggerTags: ["海滩", "海", "海边", "海浪"], title: "第一次去海边", icon: "beach.umbrella", category: .place),
        Rule(triggerTags: ["动物园"],          title: "第一次去动物园",   icon: "pawprint",            category: .place),
        Rule(triggerTags: ["游乐场", "游乐园"], title: "第一次去游乐场",  icon: "figure.play",         category: .place),
        Rule(triggerTags: ["公园"],            title: "第一次去公园",     icon: "tree",                category: .place),
        Rule(triggerTags: ["水族馆"],          title: "第一次去水族馆",   icon: "fish",                category: .place),
        Rule(triggerTags: ["博物馆"],          title: "第一次去博物馆",   icon: "building.columns",    category: .place),
        Rule(triggerTags: ["图书馆"],          title: "第一次去图书馆",   icon: "books.vertical",      category: .place),
        Rule(triggerTags: ["餐厅"],            title: "第一次下馆子",     icon: "fork.knife",          category: .place),
        Rule(triggerTags: ["商场", "超市"],    title: "第一次逛商场",     icon: "cart",                category: .place),
        Rule(triggerTags: ["农场"],            title: "第一次去农场",     icon: "tortoise",            category: .place),
        Rule(triggerTags: ["山"],              title: "第一次见到山",     icon: "mountain.2.fill",     category: .place),
        Rule(triggerTags: ["瀑布"],            title: "第一次看瀑布",     icon: "drop.fill",           category: .place),
        Rule(triggerTags: ["湖泊"],            title: "第一次去湖边",     icon: "drop",                category: .place),
        Rule(triggerTags: ["森林"],            title: "第一次进森林",     icon: "tree.fill",           category: .place),
        Rule(triggerTags: ["草地", "田野"],    title: "第一次踩到草地",   icon: "leaf",                category: .place),
        Rule(triggerTags: ["花园"],            title: "第一次去花园",     icon: "camera.macro",        category: .place),
        Rule(triggerTags: ["桥"],              title: "第一次过桥",       icon: "road.lanes",          category: .place),
        Rule(triggerTags: ["城堡"],            title: "第一次去城堡",     icon: "building.2",          category: .place),
        Rule(triggerTags: ["寺庙", "教堂"],    title: "第一次去庙宇",     icon: "building.2.fill",     category: .place),

        // —— 自然 / 风景 ——
        Rule(triggerTags: ["雪"],              title: "第一次见到雪",     icon: "snowflake",           category: .nature),
        Rule(triggerTags: ["雨"],              title: "第一次淋雨",       icon: "cloud.rain",          category: .nature),
        Rule(triggerTags: ["彩虹"],            title: "第一次见到彩虹",   icon: "rainbow",             category: .nature),
        Rule(triggerTags: ["日出"],            title: "第一次看日出",     icon: "sunrise",             category: .nature),
        Rule(triggerTags: ["日落"],            title: "第一次看日落",     icon: "sunset",              category: .nature),
        Rule(triggerTags: ["月亮"],            title: "第一次看月亮",     icon: "moon",                category: .nature),
        Rule(triggerTags: ["星星"],            title: "第一次看星星",     icon: "sparkles",            category: .nature),
        Rule(triggerTags: ["花"],              title: "第一次看花开",     icon: "camera.macro",        category: .nature),
        Rule(triggerTags: ["沙子"],            title: "第一次玩沙子",     icon: "circle.grid.cross",   category: .nature),

        // —— 动物 ——
        Rule(triggerTags: ["狗"],              title: "第一次见到小狗",   icon: "pawprint.fill",       category: .nature),
        Rule(triggerTags: ["猫"],              title: "第一次见到小猫",   icon: "pawprint.fill",       category: .nature),
        Rule(triggerTags: ["鸟"],              title: "第一次见到小鸟",   icon: "bird",                category: .nature),
        Rule(triggerTags: ["鱼"],              title: "第一次见到鱼",     icon: "fish",                category: .nature),
        Rule(triggerTags: ["兔子"],            title: "第一次见到兔子",   icon: "hare",                category: .nature),
        Rule(triggerTags: ["大象"],            title: "第一次见到大象",   icon: "pawprint",            category: .nature),
        Rule(triggerTags: ["熊猫"],            title: "第一次见到熊猫",   icon: "pawprint",            category: .nature),
        Rule(triggerTags: ["长颈鹿"],          title: "第一次见到长颈鹿", icon: "pawprint",            category: .nature),
        Rule(triggerTags: ["猴子"],            title: "第一次见到猴子",   icon: "pawprint",            category: .nature),
        Rule(triggerTags: ["马"],              title: "第一次见到马",     icon: "pawprint",            category: .nature),
        Rule(triggerTags: ["牛"],              title: "第一次见到牛",     icon: "pawprint",            category: .nature),
        Rule(triggerTags: ["羊", "山羊"],      title: "第一次见到羊",     icon: "pawprint",            category: .nature),
        Rule(triggerTags: ["鸭子"],            title: "第一次见到鸭子",   icon: "bird",                category: .nature),
        Rule(triggerTags: ["蝴蝶"],            title: "第一次见到蝴蝶",   icon: "ant",                 category: .nature),
        Rule(triggerTags: ["企鹅"],            title: "第一次见到企鹅",   icon: "bird",                category: .nature),
        Rule(triggerTags: ["乌龟"],            title: "第一次见到乌龟",   icon: "tortoise",            category: .nature),

        // —— 美食 ——
        Rule(triggerTags: ["蛋糕", "生日蛋糕"], title: "第一次吃蛋糕",   icon: "birthday.cake",       category: .food),
        Rule(triggerTags: ["冰淇淋"],          title: "第一次吃冰淇淋",   icon: "fork.knife",          category: .food),
        Rule(triggerTags: ["水果"],            title: "第一次吃水果",     icon: "leaf.fill",           category: .food),
        Rule(triggerTags: ["西瓜"],            title: "第一次吃西瓜",     icon: "leaf.fill",           category: .food),
        Rule(triggerTags: ["草莓"],            title: "第一次吃草莓",     icon: "leaf.fill",           category: .food),
        Rule(triggerTags: ["苹果"],            title: "第一次吃苹果",     icon: "applelogo",           category: .food),
        Rule(triggerTags: ["香蕉"],            title: "第一次吃香蕉",     icon: "leaf.fill",           category: .food),
        Rule(triggerTags: ["巧克力"],          title: "第一次吃巧克力",   icon: "fork.knife",          category: .food),
        Rule(triggerTags: ["披萨"],            title: "第一次吃披萨",     icon: "fork.knife",          category: .food),
        Rule(triggerTags: ["面条", "意面"],    title: "第一次吃面条",     icon: "fork.knife",          category: .food),
        Rule(triggerTags: ["饺子"],            title: "第一次吃饺子",     icon: "fork.knife",          category: .food),
        Rule(triggerTags: ["寿司"],            title: "第一次吃寿司",     icon: "fork.knife",          category: .food),

        // —— 节日 / 活动 ——
        Rule(triggerTags: ["派对"],            title: "第一次参加派对",   icon: "party.popper",        category: .event),
        Rule(triggerTags: ["圣诞节"],          title: "第一次过圣诞",     icon: "gift",                category: .event),
        Rule(triggerTags: ["新年"],            title: "第一次过新年",     icon: "fireworks",           category: .event),
        Rule(triggerTags: ["万圣节"],          title: "第一次过万圣节",   icon: "moon.stars",          category: .event),
        Rule(triggerTags: ["复活节"],          title: "第一次过复活节",   icon: "leaf",                category: .event),
        Rule(triggerTags: ["婚礼"],            title: "第一次参加婚礼",   icon: "heart",               category: .event),
        Rule(triggerTags: ["烟花"],            title: "第一次看烟花",     icon: "fireworks",           category: .event),
        Rule(triggerTags: ["灯笼"],            title: "第一次提灯笼",     icon: "lightbulb",           category: .event),
    ]

    // MARK: - 建议结果

    /// 一条候选建议：来自某张真实照片 + 对应的规则。
    /// 用户点一下就能转成正式 `Milestone`，标题 / 日期 / 备注 / 绑定照片全部预填。
    struct Suggestion: Identifiable {
        let rule: Rule
        let photo: PhotoEntry
        /// 由 `NoteGenerator.generate` 拼出来的中文备注。
        let note: String

        var id: String { rule.title }
        var title: String { rule.title }
        var icon: String { rule.icon }
        var category: Category { rule.category }
        var date: Date { photo.creationDate }
        var assetLocalId: String { photo.assetLocalId }
    }

    // MARK: - 算法

    /// 给定时间线照片和已有里程碑，按规则找出每条规则对应的**最早一张**命中照片，
    /// 跳过已被手动记录过的标题，输出建议列表。
    ///
    /// - Parameter photos: 时间线全部 `PhotoEntry`（按时间排序与否都行，本函数自己会排）
    /// - Parameter baby: 用来生成自动备注里的年龄段
    /// - Parameter existing: 已有里程碑，用 `title` 严格匹配去重
    /// - Returns: 按 `Suggestion.date` 升序的建议列表
    static func suggestions(
        from photos: [PhotoEntry],
        baby: Baby,
        existing milestones: [Milestone]
    ) -> [Suggestion] {
        guard !photos.isEmpty else { return [] }

        // 已记录里程碑的标题，规则一旦命中已记录就跳过，避免重复推荐
        let recordedTitles = Set(milestones.map { $0.title })

        // 时间正序找「第一张」用
        let chronological = photos.sorted { $0.creationDate < $1.creationDate }

        var result: [Suggestion] = []
        for rule in rules where !recordedTitles.contains(rule.title) {
            guard let firstHit = chronological.first(where: { entry in
                !rule.triggerTags.isDisjoint(with: entry.autoTags)
            }) else { continue }

            let note = NoteGenerator.generate(for: firstHit, baby: baby)
            result.append(Suggestion(rule: rule, photo: firstHit, note: note))
        }

        return result.sorted { $0.date < $1.date }
    }

    /// 按分类把建议分组，UI 用 Section 渲染。空分类不出现在结果里。
    static func grouped(_ suggestions: [Suggestion]) -> [(category: Category, items: [Suggestion])] {
        Category.allCases.compactMap { cat in
            let items = suggestions.filter { $0.category == cat }
            return items.isEmpty ? nil : (cat, items)
        }
    }
}
