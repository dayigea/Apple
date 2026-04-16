import Foundation

/// 标准发育里程碑目录。
///
/// 这些不是医学建议，只是一份常见的儿科发育参考（来自 WHO / CDC 公开资料的平均区间）。
/// 每个宝宝节奏不同，这里只用来**提醒**父母「大概到了可以记录这个事件的月龄」，
/// 具体日期完全由父母自己填。
///
/// 我们按"预计达到月龄"升序排，Suggester 会在时间线里把
/// "宝宝实际月龄已经 >= expectedMonths 且还没被手动记录"的条目作为"建议"展示。
///
/// > 注意：条目本身**不**再声明"这个里程碑该匹配哪些照片标签"。
/// > 那件事交给 `MilestoneContentAnalyzer.inferredKeywords(forTitle:)`——
/// > 它会从标题自己 + 一张小同义词表里推导出来，这样新增/改名里程碑时
/// > 不用再回来这里补 `photoKeywords`。
enum MilestoneCatalog {

    struct Entry: Identifiable, Hashable {
        /// 稳定 ID：用 title 做主键（同一条目在版本更新中语义一致）
        var id: String { title }
        /// 建议月龄（从出生开始算），作为触发下限
        let expectedMonths: Int
        /// 显示名，例如 "第一次翻身"
        let title: String
        /// 更长的说明 / 父母看的参考文字
        let detail: String
        /// 用于图标的 SF Symbol 名称
        let icon: String
    }

    /// 全量目录。新增条目时直接往下加就行；删/改只要注意 `title` 作为 ID 别乱动。
    static let all: [Entry] = [
        Entry(expectedMonths: 1,  title: "第一次抬头",        detail: "大约 1 个月时，趴着能短暂抬头看看世界。",               icon: "figure.child"),
        Entry(expectedMonths: 2,  title: "第一次微笑",        detail: "约 6–8 周开始有回应性的社交微笑，不再只是反射。",     icon: "face.smiling"),
        Entry(expectedMonths: 3,  title: "第一次咯咯笑",      detail: "约 3 个月出声笑，对声音、表情有反馈。",                 icon: "speaker.wave.2"),
        Entry(expectedMonths: 4,  title: "第一次翻身",        detail: "约 4 个月从俯卧翻到仰卧或反过来。",                     icon: "arrow.2.circlepath"),
        Entry(expectedMonths: 5,  title: "第一次认生",        detail: "约 5 个月开始分辨熟人与陌生人。",                       icon: "eye"),
        Entry(expectedMonths: 6,  title: "第一次独坐",        detail: "约 6 个月可以独自坐稳一小会儿。",                       icon: "figure.seated.side"),
        Entry(expectedMonths: 6,  title: "第一次吃辅食",      detail: "约 6 个月开始添加辅食，第一口米糊/菜泥。",              icon: "fork.knife"),
        Entry(expectedMonths: 7,  title: "长第一颗牙",        detail: "多数宝宝 6–8 个月长出第一颗门牙。",                     icon: "mouth"),
        Entry(expectedMonths: 8,  title: "第一次爬行",        detail: "约 7–10 个月学会爬，形态因娃而异。",                    icon: "figure.run"),
        Entry(expectedMonths: 9,  title: "第一次叫爸爸妈妈",  detail: "约 9 个月开始发出「爸爸」「妈妈」的音节。",            icon: "text.bubble"),
        Entry(expectedMonths: 10, title: "第一次扶站",        detail: "约 10 个月扶着家具站起来。",                            icon: "figure.stand"),
        Entry(expectedMonths: 12, title: "第一次独立走路",    detail: "约 1 岁左右迈出人生第一步。",                           icon: "figure.walk"),
        Entry(expectedMonths: 12, title: "第一个生日",        detail: "宝宝的 1 岁生日！一般会拍很多合影和蛋糕。",             icon: "birthday.cake"),
        Entry(expectedMonths: 14, title: "第一次认识颜色",    detail: "约 14 个月开始对颜色、形状表现出辨识。",                icon: "paintpalette"),
        Entry(expectedMonths: 15, title: "第一次自己吃饭",    detail: "约 1 岁 3 个月尝试自己用勺子吃饭。",                    icon: "fork.knife.circle"),
        Entry(expectedMonths: 18, title: "第一次跑",          detail: "约 1 岁半开始摇摇晃晃地跑。",                           icon: "figure.run.circle"),
        Entry(expectedMonths: 18, title: "第一次说短句",      detail: "约 1 岁半开始把两个词拼在一起，例如「要奶」「妈妈抱」。", icon: "text.quote"),
        Entry(expectedMonths: 24, title: "第二个生日",        detail: "宝宝的 2 岁生日。",                                     icon: "birthday.cake"),
        Entry(expectedMonths: 24, title: "第一次双脚跳",      detail: "约 2 岁可以双脚同时离地跳一下。",                       icon: "figure.jumprope"),
        Entry(expectedMonths: 30, title: "第一次会说自己名字",detail: "约 2 岁半可以说出自己的名字。",                         icon: "person.text.rectangle"),
        Entry(expectedMonths: 36, title: "第三个生日",        detail: "宝宝的 3 岁生日。",                                     icon: "birthday.cake"),
        Entry(expectedMonths: 36, title: "第一次骑三轮车",    detail: "约 3 岁可以控制简单的三轮车。",                         icon: "bicycle"),
    ]

    /// 按 title 查找一条建议条目。`PhotoImporter` 自动创建的生日 Milestone
    /// 以及用户从"建议"里一键填写的 Milestone，都能通过 title 定位回 catalog。
    static func entry(forTitle title: String) -> Entry? {
        all.first { $0.title == title }
    }
}
