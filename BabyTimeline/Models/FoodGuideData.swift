import Foundation

// MARK: - 数据结构

struct FoodStage: Identifiable {
    let id: String
    let monthRange: String
    let title: String
    let subtitle: String
    let icon: String
    let texture: String
    let feedingFrequency: String
    let dailyMilk: String
    let meats: [FoodItem]
    let staples: [FoodItem]
    let vegetables: [FoodItem]
    let fruits: [FoodItem]
    let pairings: [MealPairing]
    let avoid: [String]
    let tips: [String]
    let weeklyPlan: WeeklyMealPlan?

    init(
        id: String,
        monthRange: String,
        title: String,
        subtitle: String,
        icon: String,
        texture: String,
        feedingFrequency: String,
        dailyMilk: String,
        meats: [FoodItem],
        staples: [FoodItem],
        vegetables: [FoodItem],
        fruits: [FoodItem],
        pairings: [MealPairing],
        avoid: [String],
        tips: [String],
        weeklyPlan: WeeklyMealPlan? = nil
    ) {
        self.id = id
        self.monthRange = monthRange
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.texture = texture
        self.feedingFrequency = feedingFrequency
        self.dailyMilk = dailyMilk
        self.meats = meats
        self.staples = staples
        self.vegetables = vegetables
        self.fruits = fruits
        self.pairings = pairings
        self.avoid = avoid
        self.tips = tips
        self.weeklyPlan = weeklyPlan
    }
}

struct FoodItem: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let icon: String
}

struct MealPairing: Identifiable {
    let id = UUID()
    let title: String
    let ingredients: [String]
    let note: String
}

struct DailyMealPlan: Identifiable {
    let id = UUID()
    let day: String
    let breakfast: String
    let morningSnack: String
    let lunch: String
    let afternoonSnack: String
    let dinner: String
}

struct WeeklyMealPlan {
    let summary: String
    let days: [DailyMealPlan]
}

// MARK: - 全量数据

enum FoodGuideData {

    static let stages: [FoodStage] = [
        stage4to6,
        stage7to8,
        stage9to10,
        stage11to12,
        stage13to15,
        stage16to18,
        stage19to24,
    ]

    static func currentStage(birthday: Date) -> FoodStage? {
        let months = Calendar.current.dateComponents([.month], from: birthday, to: .now).month ?? 0
        return stages.first { stage in
            let parts = stage.id.split(separator: "-").compactMap { Int($0) }
            guard parts.count == 2 else { return false }
            return months >= parts[0] && months <= parts[1]
        }
    }

    // MARK: - 4–6 月龄

    private static let stage4to6 = FoodStage(
        id: "4-6",
        monthRange: "4–6 月龄",
        title: "辅食初期",
        subtitle: "第一口辅食，从含铁米粉开始",
        icon: "leaf.circle.fill",
        texture: "细腻泥糊状，可用母乳或配方奶调稀",
        feedingFrequency: "每天 1–2 次辅食",
        dailyMilk: "600–800 mL 奶量",
        meats: [],
        staples: [
            FoodItem(name: "强化铁米粉", detail: "第一口辅食首选，10倍粥过筛", icon: "🍚"),
        ],
        vegetables: [
            FoodItem(name: "南瓜泥", detail: "甜味温和，宝宝接受度高", icon: "🎃"),
            FoodItem(name: "红薯泥", detail: "富含膳食纤维和维生素A", icon: "🍠"),
            FoodItem(name: "土豆泥", detail: "口感绵密，容易消化", icon: "🥔"),
            FoodItem(name: "胡萝卜泥", detail: "富含β-胡萝卜素", icon: "🥕"),
            FoodItem(name: "西兰花泥", detail: "富含维生素C和叶酸", icon: "🥦"),
        ],
        fruits: [
            FoodItem(name: "苹果泥", detail: "温和不刺激", icon: "🍎"),
            FoodItem(name: "香蕉泥", detail: "天然甜味，入口即化", icon: "🍌"),
            FoodItem(name: "梨泥", detail: "水分充足，清甜爽口", icon: "🍐"),
            FoodItem(name: "牛油果泥", detail: "富含优质脂肪和钾", icon: "🥑"),
        ],
        pairings: [
            MealPairing(
                title: "米粉 + 南瓜泥",
                ingredients: ["强化铁米粉", "南瓜泥"],
                note: "最基础的第一餐搭配，补铁 + 维生素A"
            ),
            MealPairing(
                title: "米粉 + 苹果泥",
                ingredients: ["强化铁米粉", "苹果泥"],
                note: "米粉偏淡，加苹果泥提升接受度"
            ),
            MealPairing(
                title: "红薯泥 + 米粉",
                ingredients: ["红薯泥", "强化铁米粉"],
                note: "红薯的甜味让宝宝更愿意尝试"
            ),
        ],
        avoid: [
            "蜂蜜（肉毒杆菌风险，1岁前禁止）",
            "纯牛奶/鲜奶作为主要饮品",
            "盐、糖、酱油等调味料",
            "整颗坚果（窒息风险）",
            "果汁（1岁前不建议）",
        ],
        tips: [
            "每次只引入一种新食物，观察2–3天排除过敏",
            "起步每餐1–2勺（5–10mL），慢慢加到30–60mL",
            "继续每日补充维生素D 400IU",
            "不要强迫喂食，让宝宝自己决定吃多少",
        ]
    )

    // MARK: - 7–8 月龄

    private static let stage7to8 = FoodStage(
        id: "7-8",
        monthRange: "7–8 月龄",
        title: "味觉探索期",
        subtitle: "引入肉类，从泥到粗泥过渡",
        icon: "fork.knife.circle.fill",
        texture: "稠泥/粗泥，可保留小颗粒",
        feedingFrequency: "每天 2–3 次辅食 + 1–2 次加餐",
        dailyMilk: "600 mL 以上",
        meats: [
            FoodItem(name: "鸡肉泥", detail: "最温和的白肉，过敏风险低", icon: "🍗"),
            FoodItem(name: "猪肉泥", detail: "富含铁和锌", icon: "🥩"),
            FoodItem(name: "猪肝泥", detail: "补铁最佳来源，每周1–2次", icon: "🫀"),
            FoodItem(name: "鳕鱼泥", detail: "白身鱼优先，DHA丰富", icon: "🐟"),
            FoodItem(name: "蛋黄", detail: "从1/4个开始，富含卵磷脂", icon: "🥚"),
        ],
        staples: [
            FoodItem(name: "7倍粥", detail: "比初期更稠，锻炼吞咽", icon: "🍚"),
            FoodItem(name: "烂面条", detail: "煮烂切碎成短段", icon: "🍜"),
            FoodItem(name: "小米粥", detail: "富含B族维生素", icon: "🌾"),
            FoodItem(name: "嫩豆腐泥", detail: "优质植物蛋白", icon: "🧈"),
        ],
        vegetables: [
            FoodItem(name: "菠菜泥", detail: "含铁量高，焯水去草酸", icon: "🥬"),
            FoodItem(name: "小白菜泥", detail: "钙含量较高的叶菜", icon: "🥬"),
            FoodItem(name: "冬瓜泥", detail: "清淡好消化", icon: "🫛"),
            FoodItem(name: "丝瓜泥", detail: "水分充足，口感滑嫩", icon: "🥒"),
        ],
        fruits: [
            FoodItem(name: "蓝莓压泥", detail: "花青素丰富", icon: "🫐"),
            FoodItem(name: "桃泥", detail: "应季水果，维C丰富", icon: "🍑"),
            FoodItem(name: "木瓜泥", detail: "含消化酶，助消化", icon: "🥭"),
        ],
        pairings: [
            MealPairing(
                title: "猪肉南瓜粥",
                ingredients: ["猪肉泥", "南瓜泥", "7倍粥"],
                note: "经典荤素搭配，补铁+维A"
            ),
            MealPairing(
                title: "鳕鱼西兰花面",
                ingredients: ["鳕鱼泥", "西兰花泥", "烂面条"],
                note: "DHA + 维C，促进铁吸收"
            ),
            MealPairing(
                title: "鸡肉胡萝卜粥",
                ingredients: ["鸡肉泥", "胡萝卜泥", "7倍粥"],
                note: "温和白肉搭配，适合初次吃肉的宝宝"
            ),
            MealPairing(
                title: "猪肝菠菜粥",
                ingredients: ["猪肝泥", "菠菜泥", "7倍粥"],
                note: "双重补铁组合，菠菜需先焯水"
            ),
        ],
        avoid: [
            "蜂蜜（仍禁止至1岁）",
            "盐糖调味料（仍不添加）",
            "蛋清（可在8月龄后或确认不过敏后引入）",
            "整颗坚果、整颗葡萄",
        ],
        tips: [
            "开始给入口即化的手指食物（泡芙、软烂香蕉条）",
            "训练用杯子喝水",
            "让宝宝坐餐椅，建立进餐规律",
            "肉蛋鱼每日总量25–50g（生重）",
        ]
    )

    // MARK: - 9–10 月龄

    private static let stage9to10 = FoodStage(
        id: "9-10",
        monthRange: "9–10 月龄",
        title: "咀嚼训练期",
        subtitle: "碎粒小块状，大量引入手指食物",
        icon: "hand.pinch.fill",
        texture: "碎粒状/小软块，训练咀嚼能力",
        feedingFrequency: "每天 3 次正餐 + 1–2 次加餐",
        dailyMilk: "500–600 mL",
        meats: [
            FoodItem(name: "牛肉碎", detail: "铁锌含量最高的红肉", icon: "🥩"),
            FoodItem(name: "虾仁碎", detail: "去虾线剁碎，高蛋白", icon: "🦐"),
            FoodItem(name: "三文鱼碎", detail: "DHA含量极高", icon: "🐟"),
            FoodItem(name: "全蛋", detail: "蒸蛋羹最易消化", icon: "🥚"),
            FoodItem(name: "鸡肉碎", detail: "从泥升级为碎粒状", icon: "🍗"),
        ],
        staples: [
            FoodItem(name: "软烂小馄饨", detail: "皮薄馅软，锻炼咀嚼", icon: "🥟"),
            FoodItem(name: "面包片", detail: "撕成小块或切条", icon: "🍞"),
            FoodItem(name: "馒头片", detail: "切薄片让宝宝抓着啃", icon: "🫓"),
            FoodItem(name: "软米饭", detail: "从粥过渡到饭", icon: "🍚"),
            FoodItem(name: "原味酸奶", detail: "无糖，富含钙和益生菌", icon: "🥛"),
        ],
        vegetables: [
            FoodItem(name: "西红柿丁", detail: "去皮切小丁，维C丰富", icon: "🍅"),
            FoodItem(name: "玉米碎", detail: "碾碎后食用，膳食纤维", icon: "🌽"),
            FoodItem(name: "蘑菇碎", detail: "切碎煮烂，鲜味天然", icon: "🍄"),
            FoodItem(name: "胡萝卜条", detail: "煮软做手指食物", icon: "🥕"),
            FoodItem(name: "西兰花小朵", detail: "煮软让宝宝抓着吃", icon: "🥦"),
        ],
        fruits: [
            FoodItem(name: "草莓", detail: "切小块，维C之王", icon: "🍓"),
            FoodItem(name: "猕猴桃", detail: "切丁，维C极高", icon: "🥝"),
            FoodItem(name: "葡萄", detail: "必须纵切成4瓣！防窒息", icon: "🍇"),
            FoodItem(name: "火龙果", detail: "切丁，富含膳食纤维", icon: "🐉"),
        ],
        pairings: [
            MealPairing(
                title: "牛肉番茄软饭",
                ingredients: ["牛肉碎", "西红柿丁", "软米饭"],
                note: "番茄的维C促进牛肉铁的吸收"
            ),
            MealPairing(
                title: "三文鱼蔬菜馄饨",
                ingredients: ["三文鱼碎", "胡萝卜碎", "小馄饨皮"],
                note: "DHA + 维A，一口吃到两种营养"
            ),
            MealPairing(
                title: "虾仁蒸蛋",
                ingredients: ["虾仁碎", "全蛋", "少许温水"],
                note: "双倍蛋白质，口感嫩滑"
            ),
            MealPairing(
                title: "蘑菇鸡肉粥",
                ingredients: ["蘑菇碎", "鸡肉碎", "软米饭"],
                note: "天然鲜味，不用加盐也好吃"
            ),
        ],
        avoid: [
            "蜂蜜（仍禁止至1岁）",
            "盐糖（仍不添加）",
            "整颗葡萄/樱桃番茄（窒息风险，必须切开）",
            "爆米花、硬糖",
            "腌制食品、加工肉类",
        ],
        tips: [
            "这是咀嚼能力的关键窗口期，不要一直喂泥",
            "鼓励自主进食——允许脏乱",
            "和家人同桌吃饭，培养社交化进餐",
            "肉蛋鱼虾每日总量约50g",
        ]
    )

    // MARK: - 11–12 月龄

    private static let stage11to12 = FoodStage(
        id: "11-12",
        monthRange: "11–12 月龄",
        title: "接轨家庭饮食",
        subtitle: "几乎所有常见食物都可以尝试",
        icon: "house.circle.fill",
        texture: "碎丁/小块状，接近成人但更软更小",
        feedingFrequency: "每天 3 次正餐 + 2 次加餐",
        dailyMilk: "400–600 mL",
        meats: [
            FoodItem(name: "各种鱼类", detail: "避免高汞鱼（旗鱼、鲨鱼）", icon: "🐟"),
            FoodItem(name: "虾/蟹", detail: "如无过敏可少量尝试", icon: "🦀"),
            FoodItem(name: "猪/牛/羊肉", detail: "切碎丁或肉丝", icon: "🥩"),
            FoodItem(name: "鸡蛋", detail: "每天1个全蛋", icon: "🥚"),
        ],
        staples: [
            FoodItem(name: "软米饭", detail: "可以吃正常软饭了", icon: "🍚"),
            FoodItem(name: "意面", detail: "煮软切短段", icon: "🍝"),
            FoodItem(name: "小饺子", detail: "自制馅料更健康", icon: "🥟"),
            FoodItem(name: "小松饼", detail: "香蕉/南瓜松饼，无糖", icon: "🥞"),
            FoodItem(name: "花生酱", detail: "稀释涂抹，引入过敏原", icon: "🥜"),
            FoodItem(name: "芝麻酱", detail: "拌面拌菜，补钙佳品", icon: "🫘"),
        ],
        vegetables: [
            FoodItem(name: "各类时蔬", detail: "尽量每天3–4种蔬菜", icon: "🥗"),
            FoodItem(name: "豆类", detail: "红豆绿豆煮烂压碎", icon: "🫘"),
            FoodItem(name: "海带", detail: "切碎，富含碘", icon: "🌿"),
        ],
        fruits: [
            FoodItem(name: "各类水果", detail: "切适口大小即可", icon: "🍎"),
        ],
        pairings: [
            MealPairing(
                title: "番茄牛肉意面",
                ingredients: ["牛肉碎", "西红柿", "意面"],
                note: "经典搭配，铁+维C"
            ),
            MealPairing(
                title: "芝麻酱拌面",
                ingredients: ["芝麻酱", "面条", "黄瓜丝"],
                note: "补钙神器，大人小孩都爱吃"
            ),
            MealPairing(
                title: "鲜虾蔬菜饺子",
                ingredients: ["虾仁", "胡萝卜", "香菇", "饺子皮"],
                note: "一口一个，营养全面"
            ),
            MealPairing(
                title: "三文鱼炒饭",
                ingredients: ["三文鱼碎", "鸡蛋", "青豆", "软米饭"],
                note: "DHA + 蛋白质 + 碳水，均衡一餐"
            ),
        ],
        avoid: [
            "蜂蜜（满1岁后可少量尝试）",
            "仍建议少盐少糖（可极少量调味）",
            "整颗坚果（3岁前窒息风险，须磨碎）",
            "高汞鱼（旗鱼、鲨鱼、方头鱼）",
        ],
        tips: [
            "辅食热量应占全日总热量约50%",
            "1岁后可引入纯牛奶（全脂）作为饮品",
            "1岁后停用奶瓶，完全过渡到杯子",
            "每日：肉鱼虾50–75g、蔬菜100g、水果100g",
        ]
    )

    // MARK: - 13–15 月龄

    private static let stage13to15 = FoodStage(
        id: "13-15",
        monthRange: "13–15 月龄",
        title: "家庭饮食过渡",
        subtitle: "刚满一岁，向家庭餐过渡，仍需软烂",
        icon: "house.fill",
        texture: "小块/小段，软烂为主，便于咀嚼",
        feedingFrequency: "三餐两点（3正餐 + 2加餐）",
        dailyMilk: "400–500 mL（可引入全脂纯牛奶）",
        meats: [
            FoodItem(name: "猪牛羊肉", detail: "切小丁或剁碎，炖煮至软", icon: "🥩"),
            FoodItem(name: "鸡鸭肉", detail: "去皮去骨，切小块", icon: "🍗"),
            FoodItem(name: "鱼类", detail: "每周2–3次，仔细去刺", icon: "🐟"),
            FoodItem(name: "虾仁", detail: "去虾线切碎或剁泥", icon: "🦐"),
            FoodItem(name: "鸡蛋", detail: "每天1个，蒸/煮/炒均可", icon: "🥚"),
        ],
        staples: [
            FoodItem(name: "软米饭", detail: "比成人软一些", icon: "🍚"),
            FoodItem(name: "面条/面片", detail: "煮软切短", icon: "🍜"),
            FoodItem(name: "小馒头/花卷", detail: "撕成小块", icon: "🫓"),
            FoodItem(name: "红薯/土豆", detail: "蒸熟压泥或切丁", icon: "🍠"),
            FoodItem(name: "燕麦粥", detail: "煮稠加奶或水果", icon: "🌾"),
        ],
        vegetables: [
            FoodItem(name: "深色蔬菜", detail: "菠菜、西兰花、胡萝卜（切碎）", icon: "🥦"),
            FoodItem(name: "浅色蔬菜", detail: "白菜、冬瓜、莲藕（切丁煮软）", icon: "🥬"),
            FoodItem(name: "菌菇类", detail: "香菇、平菇切碎", icon: "🍄"),
            FoodItem(name: "豆制品", detail: "嫩豆腐、内酯豆腐", icon: "🧈"),
        ],
        fruits: [
            FoodItem(name: "各类应季水果", detail: "切小丁，每天1–2种", icon: "🍎"),
            FoodItem(name: "蓝莓/草莓", detail: "对半切，富含花青素", icon: "🫐"),
        ],
        pairings: [
            MealPairing(
                title: "西红柿鸡蛋软面",
                ingredients: ["西红柿丁", "鸡蛋", "细面条"],
                note: "经典开胃面，番茄维C促进铁吸收"
            ),
            MealPairing(
                title: "三文鱼蔬菜软饭",
                ingredients: ["三文鱼碎", "西兰花碎", "胡萝卜丁", "软米饭"],
                note: "DHA + 维C + 维A，营养均衡"
            ),
            MealPairing(
                title: "牛肉土豆焖饭",
                ingredients: ["牛肉碎", "土豆丁", "胡萝卜丁", "米饭"],
                note: "补铁补能量，省时一锅出"
            ),
            MealPairing(
                title: "鸡肉香菇粥",
                ingredients: ["鸡肉碎", "香菇碎", "大米"],
                note: "天然鲜味，少调味也好吃"
            ),
        ],
        avoid: [
            "整颗坚果（3岁前须磨碎或做酱）",
            "整颗葡萄/小番茄（必须切4瓣）",
            "含糖饮料、果汁",
            "高盐高糖零食（薯片、饼干等）",
            "每日盐 < 1.5g",
        ],
        tips: [
            "1岁后可引入全脂纯牛奶（每日 ≤ 500 mL）",
            "完全停用奶瓶，过渡到吸管杯/敞口杯",
            "每日：肉鱼虾 50–75g、蔬菜 100–150g、水果 100–150g",
            "每餐 20–30 分钟，吃完就撤盘",
        ],
        weeklyPlan: weeklyPlan13to15
    )

    // MARK: - 16–18 月龄

    private static let stage16to18 = FoodStage(
        id: "16-18",
        monthRange: "16–18 月龄",
        title: "自主进食萌芽",
        subtitle: "咀嚼成熟，鼓励自己用勺、自己吃",
        icon: "hand.raised.fill",
        texture: "接近家人饭菜，切小切短",
        feedingFrequency: "三餐两点，与家人同桌",
        dailyMilk: "400–500 mL",
        meats: [
            FoodItem(name: "红肉", detail: "猪牛羊切丝/小块", icon: "🥩"),
            FoodItem(name: "禽肉", detail: "鸡腿肉、鸡胸肉撕条", icon: "🍗"),
            FoodItem(name: "鱼虾", detail: "每周2–3次鱼，补DHA", icon: "🐟"),
            FoodItem(name: "鸡蛋", detail: "每天1个，多种做法", icon: "🥚"),
            FoodItem(name: "动物肝脏", detail: "每周1次，补铁补维A", icon: "🫀"),
        ],
        staples: [
            FoodItem(name: "米饭", detail: "正常软硬度", icon: "🍚"),
            FoodItem(name: "意面/面条", detail: "各种形状切短", icon: "🍝"),
            FoodItem(name: "馒头/包子", detail: "自制低盐馅", icon: "🫓"),
            FoodItem(name: "红薯/玉米", detail: "粗细搭配，膳食纤维", icon: "🌽"),
            FoodItem(name: "全麦面包", detail: "选低糖低盐款", icon: "🍞"),
        ],
        vegetables: [
            FoodItem(name: "深色蔬菜", detail: "占蔬菜量的一半以上", icon: "🥦"),
            FoodItem(name: "根茎类", detail: "莲藕、山药、芋头", icon: "🥔"),
            FoodItem(name: "菌菇豆制品", detail: "香菇、豆腐、豆干", icon: "🍄"),
            FoodItem(name: "海带紫菜", detail: "切碎，补碘", icon: "🌿"),
        ],
        fruits: [
            FoodItem(name: "应季水果", detail: "每天1–2种，注意切小", icon: "🍎"),
            FoodItem(name: "酸奶配水果", detail: "无糖酸奶+果丁，加餐首选", icon: "🥣"),
        ],
        pairings: [
            MealPairing(
                title: "西红柿牛肉意面",
                ingredients: ["牛肉丝", "西红柿", "短意面"],
                note: "锻炼用叉子的好选择"
            ),
            MealPairing(
                title: "蒸鱼配彩蔬米饭",
                ingredients: ["鲈鱼/鳕鱼", "西兰花", "胡萝卜", "米饭"],
                note: "清蒸保留营养，去刺再上桌"
            ),
            MealPairing(
                title: "胡萝卜玉米排骨粥",
                ingredients: ["排骨", "胡萝卜", "甜玉米", "大米"],
                note: "炖煮 1 小时，骨汤补钙"
            ),
            MealPairing(
                title: "什锦鸡肉菜饭",
                ingredients: ["鸡腿肉", "香菇", "胡萝卜", "豌豆", "米饭"],
                note: "一锅炖，蛋白质蔬菜碳水齐全"
            ),
        ],
        avoid: [
            "整颗坚果（3岁前仍须磨碎）",
            "含糖饮料、含咖啡因饮品",
            "腌制、烟熏、加工肉类（火腿肠等）",
            "高汞鱼（旗鱼、鲨鱼、方头鱼）",
            "每日盐 < 1.5g",
        ],
        tips: [
            "挑食高发期——被拒食物可能要提供 10–15 次才接受",
            "鼓励自己用勺/叉，允许吃得脏乱",
            "不用食物当奖惩，不追着喂",
            "进餐时不看电视/手机，专心吃饭",
            "每日：肉鱼虾 50–75g、蔬菜 100–150g、水果 100–150g",
        ],
        weeklyPlan: weeklyPlan16to18
    )

    // MARK: - 19–24 月龄

    private static let stage19to24 = FoodStage(
        id: "19-24",
        monthRange: "19–24 月龄",
        title: "自主进食期",
        subtitle: "和家人吃同样的饭菜（减盐减油版）",
        icon: "star.circle.fill",
        texture: "与成人一致，切成适口大小",
        feedingFrequency: "三餐两点，与家人同桌",
        dailyMilk: "400–500 mL",
        meats: [
            FoodItem(name: "各种肉类", detail: "丝/片/小块均可", icon: "🥩"),
            FoodItem(name: "鱼虾", detail: "每周2–3次", icon: "🐟"),
            FoodItem(name: "鸡蛋", detail: "每天1个，各种做法", icon: "🥚"),
        ],
        staples: [
            FoodItem(name: "米饭", detail: "正常饭", icon: "🍚"),
            FoodItem(name: "面食", detail: "面条、馒头、饼等", icon: "🍜"),
            FoodItem(name: "全谷物", detail: "糙米、全麦面包（占主食1/4–1/3）", icon: "🌾"),
            FoodItem(name: "薯类", detail: "红薯、紫薯、土豆", icon: "🍠"),
        ],
        vegetables: [
            FoodItem(name: "深色蔬菜", detail: "增加占比，深绿/橙红色", icon: "🥦"),
            FoodItem(name: "各类时蔬", detail: "每天至少3–4种", icon: "🥗"),
        ],
        fruits: [
            FoodItem(name: "各类水果", detail: "每天1–2种，注意切小", icon: "🍎"),
        ],
        pairings: [
            MealPairing(
                title: "家常炒饭",
                ingredients: ["米饭", "鸡蛋", "虾仁", "青菜碎", "胡萝卜丁"],
                note: "碳水+蛋白+蔬菜一锅出"
            ),
            MealPairing(
                title: "牛肉西兰花配全麦面包",
                ingredients: ["牛肉丝", "西兰花", "全麦面包"],
                note: "铁+维C+全谷物"
            ),
            MealPairing(
                title: "紫菜蛋花汤 + 小馒头",
                ingredients: ["紫菜", "鸡蛋", "虾皮", "小馒头"],
                note: "碘+钙+蛋白质，清淡开胃"
            ),
            MealPairing(
                title: "什锦蔬菜鸡肉煲",
                ingredients: ["鸡腿肉", "土豆", "胡萝卜", "玉米", "香菇"],
                note: "一锅炖，适合全家一起吃"
            ),
        ],
        avoid: [
            "整颗坚果（3岁前仍须磨碎）",
            "整颗葡萄（须纵切为4瓣）",
            "含咖啡因食物/饮料",
            "生鱼片等生食",
            "每日盐 < 2g",
        ],
        tips: [
            "练习使用勺子和叉子",
            "2岁后可过渡到低脂牛奶（有肥胖倾向时）",
            "不看电视/手机进餐",
            "每日蔬菜150–200g、水果100–150g、肉鱼虾50–75g",
        ]
    )

    // MARK: - 一周食谱：13–15 月龄

    private static let weeklyPlan13to15 = WeeklyMealPlan(
        summary: "刚过一岁，主食仍偏软，肉切碎或剁泥。每日总奶量 400–500 mL，可分配在加餐和睡前。",
        days: [
            DailyMealPlan(
                day: "周一",
                breakfast: "燕麦粥 + 半个蒸蛋 + 蓝莓数颗",
                morningSnack: "全脂牛奶 150 mL + 香蕉半根",
                lunch: "西红柿鸡蛋软面 + 西兰花碎",
                afternoonSnack: "无糖酸奶 + 苹果丁",
                dinner: "鸡肉香菇软米饭 + 胡萝卜丁"
            ),
            DailyMealPlan(
                day: "周二",
                breakfast: "小米粥 + 馒头小块 + 牛油果泥",
                morningSnack: "全脂牛奶 150 mL",
                lunch: "三文鱼碎软饭 + 蒸南瓜",
                afternoonSnack: "蒸红薯 + 梨丁",
                dinner: "牛肉土豆焖饭（碎丁版）"
            ),
            DailyMealPlan(
                day: "周三",
                breakfast: "南瓜小米粥 + 蒸蛋 + 草莓",
                morningSnack: "全脂牛奶 150 mL + 全麦面包小块",
                lunch: "番茄牛肉软面 + 菠菜碎",
                afternoonSnack: "无糖酸奶 + 蓝莓",
                dinner: "鳕鱼蔬菜粥 + 豆腐丁"
            ),
            DailyMealPlan(
                day: "周四",
                breakfast: "燕麦+牛奶+香蕉泥 + 蒸蛋",
                morningSnack: "苹果丁 + 米饼",
                lunch: "猪肉冬瓜软饭 + 蘑菇碎",
                afternoonSnack: "全脂牛奶 150 mL",
                dinner: "虾仁碎蛋羹 + 软饭 + 西兰花"
            ),
            DailyMealPlan(
                day: "周五",
                breakfast: "红薯小米粥 + 半个蒸蛋",
                morningSnack: "全脂牛奶 150 mL + 蒸南瓜",
                lunch: "鸡肉胡萝卜软饭 + 嫩豆腐",
                afternoonSnack: "无糖酸奶 + 火龙果丁",
                dinner: "番茄鸡蛋软面 + 菠菜碎"
            ),
            DailyMealPlan(
                day: "周六",
                breakfast: "牛奶燕麦糊 + 蓝莓 + 蒸蛋",
                morningSnack: "梨丁 + 米饼",
                lunch: "三文鱼蔬菜软饭（西兰花+胡萝卜）",
                afternoonSnack: "全脂牛奶 150 mL",
                dinner: "猪肝菠菜软面（每周1次）+ 豆腐"
            ),
            DailyMealPlan(
                day: "周日",
                breakfast: "南瓜粥 + 馒头片 + 香蕉",
                morningSnack: "无糖酸奶 + 苹果丁",
                lunch: "牛肉番茄烩饭 + 西兰花碎",
                afternoonSnack: "全脂牛奶 150 mL + 蒸红薯",
                dinner: "鸡肉蘑菇软饭 + 冬瓜丁"
            ),
        ]
    )

    // MARK: - 一周食谱：16–18 月龄

    private static let weeklyPlan16to18 = WeeklyMealPlan(
        summary: "咀嚼能力成熟，可与家人吃同样的菜（减盐版）。鼓励自己用勺、自己拿手指食物。",
        days: [
            DailyMealPlan(
                day: "周一",
                breakfast: "牛奶 + 全麦面包 + 蒸蛋 + 蓝莓",
                morningSnack: "苹果丁 + 原味米饼",
                lunch: "西红柿牛肉短意面 + 西兰花",
                afternoonSnack: "无糖酸奶 + 草莓",
                dinner: "蒸鳕鱼 + 米饭 + 胡萝卜玉米"
            ),
            DailyMealPlan(
                day: "周二",
                breakfast: "小米南瓜粥 + 包子（自制低盐）",
                morningSnack: "牛奶 + 香蕉",
                lunch: "鸡腿肉香菇焖饭 + 油菜",
                afternoonSnack: "蒸红薯 + 梨丁",
                dinner: "番茄鸡蛋面 + 嫩豆腐"
            ),
            DailyMealPlan(
                day: "周三",
                breakfast: "燕麦牛奶粥 + 蒸蛋 + 牛油果",
                morningSnack: "无糖酸奶 + 蓝莓",
                lunch: "排骨胡萝卜玉米粥 + 紫菜蛋花",
                afternoonSnack: "全麦面包 + 牛奶",
                dinner: "三文鱼炒饭（鸡蛋+青豆+胡萝卜）"
            ),
            DailyMealPlan(
                day: "周四",
                breakfast: "馒头 + 蒸蛋 + 牛奶 + 草莓",
                morningSnack: "苹果丁 + 米饼",
                lunch: "牛肉土豆咖喱饭（无添加儿童咖喱）+ 西兰花",
                afternoonSnack: "无糖酸奶 + 猕猴桃丁",
                dinner: "虾仁蔬菜小馄饨 + 紫菜汤"
            ),
            DailyMealPlan(
                day: "周五",
                breakfast: "红薯小米粥 + 蒸蛋 + 蓝莓",
                morningSnack: "牛奶 + 香蕉",
                lunch: "鸡肉蘑菇饭 + 莲藕排骨汤",
                afternoonSnack: "蒸玉米 + 火龙果",
                dinner: "猪肝菠菜面（每周1次）+ 豆腐"
            ),
            DailyMealPlan(
                day: "周六",
                breakfast: "牛奶燕麦 + 全麦面包 + 蒸蛋",
                morningSnack: "无糖酸奶 + 草莓",
                lunch: "什锦鸡肉菜饭（鸡腿+香菇+豌豆+胡萝卜）",
                afternoonSnack: "苹果丁 + 米饼",
                dinner: "鲈鱼蒸豆腐 + 米饭 + 西兰花"
            ),
            DailyMealPlan(
                day: "周日",
                breakfast: "南瓜粥 + 包子 + 牛奶",
                morningSnack: "梨丁 + 全麦饼干",
                lunch: "牛肉番茄意面 + 紫菜蛋花汤",
                afternoonSnack: "无糖酸奶 + 蓝莓",
                dinner: "虾仁蛋炒饭 + 油菜 + 山药排骨汤"
            ),
        ]
    )
}
