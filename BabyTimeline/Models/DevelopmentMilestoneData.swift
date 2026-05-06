import Foundation

// MARK: - 数据结构

struct DevelopmentStage: Identifiable {
    let id: String
    let monthRange: String
    let title: String
    let icon: String
    let categories: [DevelopmentCategory]

    var allItems: [DevelopmentItem] {
        categories.flatMap { $0.items }
    }
}

struct DevelopmentCategory: Identifiable {
    let id: String
    let name: String
    let icon: String
    let tint: DevTint
    let items: [DevelopmentItem]
}

struct DevelopmentItem: Identifiable {
    /// 全局唯一 id，格式 `<stage>.<cat>.<key>`
    let id: String
    let title: String
    let detail: String?
}

enum DevTint: String {
    case motor    // 大动作
    case fine     // 精细动作
    case language // 语言
    case cognitive// 认知
    case social   // 社交
}

// MARK: - 全量数据
//
// 来源综合：WHO Window of Achievement、AAP / CDC 发育里程碑、
// 《0–6 岁儿童发育里程碑指南》。每个阶段挑 8–12 项最容易观察到的，
// 不做穷举，避免家长焦虑。

enum DevelopmentMilestoneData {

    static let stages: [DevelopmentStage] = [
        stage0to3,
        stage4to6,
        stage7to9,
        stage10to12,
        stage13to18,
        stage19to24,
        stage25to36,
    ]

    static func currentStage(birthday: Date) -> DevelopmentStage? {
        let months = Calendar.current.dateComponents([.month], from: birthday, to: .now).month ?? 0
        return stages.first { stage in
            let parts = stage.id.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return false }
            return months >= parts[0] && months <= parts[1]
        }
    }

    // MARK: 0–3 月

    private static let stage0to3 = DevelopmentStage(
        id: "0-3",
        monthRange: "0–3 月龄",
        title: "新生儿期",
        icon: "moon.zzz.fill",
        categories: [
            DevelopmentCategory(id: "0-3.motor", name: "大动作", icon: "figure.arms.open", tint: .motor, items: [
                .init(id: "0-3.motor.lift-head", title: "趴着能抬头到 45°", detail: nil),
                .init(id: "0-3.motor.track-eyes", title: "眼睛追视移动物体", detail: nil),
            ]),
            DevelopmentCategory(id: "0-3.fine", name: "精细动作", icon: "hand.raised.fill", tint: .fine, items: [
                .init(id: "0-3.fine.open-hands", title: "双手能张开（不全是握拳）", detail: nil),
                .init(id: "0-3.fine.grasp-reflex", title: "触觉抓握反射", detail: "手指碰到物体会自动握住"),
            ]),
            DevelopmentCategory(id: "0-3.language", name: "语言", icon: "waveform", tint: .language, items: [
                .init(id: "0-3.lang.respond-sound", title: "对声音有反应", detail: nil),
                .init(id: "0-3.lang.coo", title: "发出咕咕声 / 元音音节", detail: nil),
            ]),
            DevelopmentCategory(id: "0-3.cognitive", name: "认知", icon: "brain", tint: .cognitive, items: [
                .init(id: "0-3.cog.gaze-faces", title: "注视人脸", detail: nil),
                .init(id: "0-3.cog.color-toys", title: "对鲜艳颜色的玩具感兴趣", detail: nil),
            ]),
            DevelopmentCategory(id: "0-3.social", name: "社交", icon: "face.smiling", tint: .social, items: [
                .init(id: "0-3.soc.smile", title: "自发性微笑（约 6–8 周）", detail: nil),
                .init(id: "0-3.soc.calm-when-held", title: "被抱起会安静下来", detail: nil),
            ]),
        ]
    )

    // MARK: 4–6 月

    private static let stage4to6 = DevelopmentStage(
        id: "4-6",
        monthRange: "4–6 月龄",
        title: "翻身探索期",
        icon: "arrow.triangle.2.circlepath",
        categories: [
            DevelopmentCategory(id: "4-6.motor", name: "大动作", icon: "figure.arms.open", tint: .motor, items: [
                .init(id: "4-6.motor.roll", title: "翻身（仰卧 → 俯卧）", detail: nil),
                .init(id: "4-6.motor.prone-push", title: "趴着能撑起上半身", detail: nil),
                .init(id: "4-6.motor.brief-sit", title: "短暂独坐（手撑地）", detail: nil),
            ]),
            DevelopmentCategory(id: "4-6.fine", name: "精细动作", icon: "hand.raised.fill", tint: .fine, items: [
                .init(id: "4-6.fine.reach", title: "主动伸手抓物", detail: nil),
                .init(id: "4-6.fine.transfer", title: "双手之间传递玩具", detail: nil),
            ]),
            DevelopmentCategory(id: "4-6.language", name: "语言", icon: "waveform", tint: .language, items: [
                .init(id: "4-6.lang.laugh", title: "笑出声 / 大笑", detail: nil),
                .init(id: "4-6.lang.babble", title: "牙牙学语（ba-ba, ma-ma 但无意义）", detail: nil),
            ]),
            DevelopmentCategory(id: "4-6.cognitive", name: "认知", icon: "brain", tint: .cognitive, items: [
                .init(id: "4-6.cog.find-source", title: "找声音来源", detail: nil),
                .init(id: "4-6.cog.mirror", title: "对镜中自己感兴趣", detail: nil),
            ]),
            DevelopmentCategory(id: "4-6.social", name: "社交", icon: "face.smiling", tint: .social, items: [
                .init(id: "4-6.soc.know-familiar", title: "认得熟悉的人", detail: nil),
                .init(id: "4-6.soc.excited", title: "看见照看者会兴奋", detail: nil),
            ]),
        ]
    )

    // MARK: 7–9 月

    private static let stage7to9 = DevelopmentStage(
        id: "7-9",
        monthRange: "7–9 月龄",
        title: "爬行学坐期",
        icon: "figure.child",
        categories: [
            DevelopmentCategory(id: "7-9.motor", name: "大动作", icon: "figure.arms.open", tint: .motor, items: [
                .init(id: "7-9.motor.sit-stable", title: "独坐稳", detail: nil),
                .init(id: "7-9.motor.crawl", title: "匍匐爬行 / 手膝爬", detail: nil),
                .init(id: "7-9.motor.pull-stand", title: "扶物站起来", detail: nil),
            ]),
            DevelopmentCategory(id: "7-9.fine", name: "精细动作", icon: "hand.raised.fill", tint: .fine, items: [
                .init(id: "7-9.fine.pincer", title: "拇食指捏取小物", detail: nil),
                .init(id: "7-9.fine.self-feed", title: "自己用手抓食物吃", detail: nil),
            ]),
            DevelopmentCategory(id: "7-9.language", name: "语言", icon: "waveform", tint: .language, items: [
                .init(id: "7-9.lang.repeat-syllable", title: "重复音节（ba-ba / ma-ma）", detail: nil),
                .init(id: "7-9.lang.respond-name", title: "听到名字会回头", detail: nil),
            ]),
            DevelopmentCategory(id: "7-9.cognitive", name: "认知", icon: "brain", tint: .cognitive, items: [
                .init(id: "7-9.cog.object-permanence", title: "找被遮挡的玩具", detail: "物体恒存性出现"),
                .init(id: "7-9.cog.imitate", title: "模仿大人简单动作", detail: nil),
            ]),
            DevelopmentCategory(id: "7-9.social", name: "社交", icon: "face.smiling", tint: .social, items: [
                .init(id: "7-9.soc.stranger-anxiety", title: "对陌生人警惕（认生）", detail: nil),
                .init(id: "7-9.soc.peekaboo", title: "玩躲猫猫", detail: nil),
            ]),
        ]
    )

    // MARK: 10–12 月

    private static let stage10to12 = DevelopmentStage(
        id: "10-12",
        monthRange: "10–12 月龄",
        title: "扶走 / 第一步",
        icon: "figure.walk",
        categories: [
            DevelopmentCategory(id: "10-12.motor", name: "大动作", icon: "figure.arms.open", tint: .motor, items: [
                .init(id: "10-12.motor.cruise", title: "扶家具走（cruise）", detail: nil),
                .init(id: "10-12.motor.walk-with-help", title: "牵手走几步", detail: nil),
                .init(id: "10-12.motor.first-step", title: "🎉 第一次独立迈步", detail: "通常 11–14 月之间"),
            ]),
            DevelopmentCategory(id: "10-12.fine", name: "精细动作", icon: "hand.raised.fill", tint: .fine, items: [
                .init(id: "10-12.fine.put-in", title: "把东西放进容器", detail: nil),
                .init(id: "10-12.fine.precise-pinch", title: "精准拇食指捏小颗粒", detail: nil),
            ]),
            DevelopmentCategory(id: "10-12.language", name: "语言", icon: "waveform", tint: .language, items: [
                .init(id: "10-12.lang.first-word", title: "🎉 第一个有意义的词", detail: "通常是「妈妈」「爸爸」"),
                .init(id: "10-12.lang.understand-no", title: "听懂「不可以」", detail: nil),
            ]),
            DevelopmentCategory(id: "10-12.cognitive", name: "认知", icon: "brain", tint: .cognitive, items: [
                .init(id: "10-12.cog.wave-bye", title: "模仿挥手再见", detail: nil),
                .init(id: "10-12.cog.know-objects", title: "知道几个常见物品的名字", detail: nil),
            ]),
            DevelopmentCategory(id: "10-12.social", name: "社交", icon: "face.smiling", tint: .social, items: [
                .init(id: "10-12.soc.clap", title: "玩拍手 / 互动游戏", detail: nil),
                .init(id: "10-12.soc.affection", title: "对喜爱的人主动亲密", detail: nil),
            ]),
        ]
    )

    // MARK: 13–18 月

    private static let stage13to18 = DevelopmentStage(
        id: "13-18",
        monthRange: "13–18 月龄",
        title: "幼儿初期",
        icon: "figure.run",
        categories: [
            DevelopmentCategory(id: "13-18.motor", name: "大动作", icon: "figure.arms.open", tint: .motor, items: [
                .init(id: "13-18.motor.walk-stable", title: "走得稳", detail: nil),
                .init(id: "13-18.motor.squat-pickup", title: "自己蹲下捡东西", detail: nil),
                .init(id: "13-18.motor.walk-backward", title: "倒退着走几步", detail: nil),
                .init(id: "13-18.motor.stairs-help", title: "扶着上楼梯", detail: nil),
            ]),
            DevelopmentCategory(id: "13-18.fine", name: "精细动作", icon: "hand.raised.fill", tint: .fine, items: [
                .init(id: "13-18.fine.spoon", title: "用勺子吃（会洒）", detail: nil),
                .init(id: "13-18.fine.stack-2-3", title: "堆 2–3 块积木", detail: nil),
                .init(id: "13-18.fine.turn-pages", title: "自己翻书页", detail: nil),
                .init(id: "13-18.fine.scribble", title: "涂鸦", detail: nil),
            ]),
            DevelopmentCategory(id: "13-18.language", name: "语言", icon: "waveform", tint: .language, items: [
                .init(id: "13-18.lang.6-10-words", title: "会说 6–10 个词", detail: nil),
                .init(id: "13-18.lang.point-bodyparts", title: "能指认 3+ 身体部位", detail: nil),
                .init(id: "13-18.lang.follow-simple", title: "听懂简单指令（把球给我）", detail: nil),
            ]),
            DevelopmentCategory(id: "13-18.cognitive", name: "认知", icon: "brain", tint: .cognitive, items: [
                .init(id: "13-18.cog.imitate-chores", title: "模仿做家务（扫地、打电话）", detail: nil),
                .init(id: "13-18.cog.pretend-play", title: "装扮游戏（喂娃娃、给娃娃盖被）", detail: nil),
                .init(id: "13-18.cog.object-use", title: "知道常用物品的用途（梳子梳头）", detail: nil),
            ]),
            DevelopmentCategory(id: "13-18.social", name: "社交", icon: "face.smiling", tint: .social, items: [
                .init(id: "13-18.soc.know-name", title: "知道自己的名字", detail: nil),
                .init(id: "13-18.soc.self-recognition", title: "对镜中自己有反应", detail: nil),
                .init(id: "13-18.soc.attachment", title: "有依恋物（毯子、玩偶）", detail: nil),
            ]),
        ]
    )

    // MARK: 19–24 月

    private static let stage19to24 = DevelopmentStage(
        id: "19-24",
        monthRange: "19–24 月龄",
        title: "词汇爆发期",
        icon: "text.bubble.fill",
        categories: [
            DevelopmentCategory(id: "19-24.motor", name: "大动作", icon: "figure.arms.open", tint: .motor, items: [
                .init(id: "19-24.motor.run", title: "会跑（不太稳）", detail: nil),
                .init(id: "19-24.motor.jump", title: "双脚同时跳", detail: nil),
                .init(id: "19-24.motor.climb-chair", title: "自己爬上椅子", detail: nil),
                .init(id: "19-24.motor.stairs-rail", title: "一手扶栏杆下楼梯", detail: nil),
            ]),
            DevelopmentCategory(id: "19-24.fine", name: "精细动作", icon: "hand.raised.fill", tint: .fine, items: [
                .init(id: "19-24.fine.stack-4-6", title: "堆 4–6 块积木", detail: nil),
                .init(id: "19-24.fine.undress", title: "自己脱袜子 / 帽子", detail: nil),
                .init(id: "19-24.fine.spoon-clean", title: "用勺子吃不洒", detail: nil),
            ]),
            DevelopmentCategory(id: "19-24.language", name: "语言", icon: "waveform", tint: .language, items: [
                .init(id: "19-24.lang.50-words", title: "🎉 50+ 个词", detail: "词汇爆炸期"),
                .init(id: "19-24.lang.two-word", title: "说 2 个词的短句（妈妈抱）", detail: nil),
                .init(id: "19-24.lang.own-name", title: "会说自己的名字", detail: nil),
                .init(id: "19-24.lang.echo", title: "重复听到的新词", detail: nil),
            ]),
            DevelopmentCategory(id: "19-24.cognitive", name: "认知", icon: "brain", tint: .cognitive, items: [
                .init(id: "19-24.cog.match-shapes", title: "配对简单形状", detail: nil),
                .init(id: "19-24.cog.big-small", title: "区分大 / 小", detail: nil),
                .init(id: "19-24.cog.complex-pretend", title: "复杂装扮游戏", detail: nil),
            ]),
            DevelopmentCategory(id: "19-24.social", name: "社交", icon: "face.smiling", tint: .social, items: [
                .init(id: "19-24.soc.express-emotion", title: "用词表达情绪（高兴、生气）", detail: nil),
                .init(id: "19-24.soc.parallel-play", title: "和小朋友各玩各的（平行游戏）", detail: nil),
                .init(id: "19-24.soc.say-no", title: "学会说不", detail: "自我意识萌芽"),
            ]),
        ]
    )

    // MARK: 25–36 月

    private static let stage25to36 = DevelopmentStage(
        id: "25-36",
        monthRange: "25–36 月龄",
        title: "自主表达期",
        icon: "person.fill.questionmark",
        categories: [
            DevelopmentCategory(id: "25-36.motor", name: "大动作", icon: "figure.arms.open", tint: .motor, items: [
                .init(id: "25-36.motor.alt-stairs", title: "双脚交替上下楼梯", detail: nil),
                .init(id: "25-36.motor.run-stable", title: "短距离跑稳", detail: nil),
                .init(id: "25-36.motor.stand-one-leg", title: "单脚站 1 秒", detail: nil),
                .init(id: "25-36.motor.tricycle", title: "骑三轮车（脚踏）", detail: nil),
            ]),
            DevelopmentCategory(id: "25-36.fine", name: "精细动作", icon: "hand.raised.fill", tint: .fine, items: [
                .init(id: "25-36.fine.put-on-shoes", title: "自己穿鞋（不分左右）", detail: nil),
                .init(id: "25-36.fine.scissors", title: "用儿童剪刀（大人辅助）", detail: nil),
                .init(id: "25-36.fine.draw-circle", title: "画圆圈", detail: nil),
                .init(id: "25-36.fine.unscrew", title: "拧开瓶盖", detail: nil),
            ]),
            DevelopmentCategory(id: "25-36.language", name: "语言", icon: "waveform", tint: .language, items: [
                .init(id: "25-36.lang.200-words", title: "200+ 词", detail: nil),
                .init(id: "25-36.lang.three-word", title: "说 3 个词的短句", detail: nil),
                .init(id: "25-36.lang.ask-what", title: "会问这是什么？", detail: nil),
                .init(id: "25-36.lang.nursery-rhyme", title: "记得简单儿歌", detail: nil),
            ]),
            DevelopmentCategory(id: "25-36.cognitive", name: "认知", icon: "brain", tint: .cognitive, items: [
                .init(id: "25-36.cog.count-3", title: "口数 1–3", detail: nil),
                .init(id: "25-36.cog.match-color", title: "配对相同颜色", detail: nil),
                .init(id: "25-36.cog.classify", title: "按类别分组（动物 / 食物）", detail: nil),
            ]),
            DevelopmentCategory(id: "25-36.social", name: "社交", icon: "face.smiling", tint: .social, items: [
                .init(id: "25-36.soc.share", title: "尝试分享（有时）", detail: nil),
                .init(id: "25-36.soc.cooperate", title: "和小朋友合作游戏", detail: nil),
                .init(id: "25-36.soc.say-want", title: "用语言表达需要（我要…）", detail: nil),
            ]),
        ]
    )
}

extension DevTint {
    var color: String {
        // 名字而已，UI 里映射到 SwiftUI Color
        rawValue
    }
}
