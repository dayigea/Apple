import CoreGraphics
import Foundation
import Vision

/// 场景分类：把一张 CGImage 送给 Vision，得到中文化的内容标签。
/// 人脸检测与认人匹配都在 `FaceRecognitionService` 里，本服务只负责内容分类。
enum ImageAnalysisService {

    // MARK: - 场景分类

    // 阈值放低（0.30 → 0.20）+ 上限放宽（5 → 8）：
    // - Vision 内置约 1300 个分类，多数照片只有少数 tag 能跨过 0.30，导致打出来
    //   的标签经常只剩 "宝宝/室内/户外" 这种最泛的几条，里程碑触发词（雪、
    //   海滩、蛋糕 …）会因为差一点点的置信度被滤掉
    // - 阈值降到 0.20 让中等置信度的内容（"狗"、"草地"、"派对" …）也能参与匹配；
    //   同时把上限从 5 扩到 8，防止低置信度的强信号被高置信度的废话挤出去
    // - 副作用：备注里偶尔会冒出不完全准的标签，但 `MilestoneContentAnalyzer`
    //   只取前 4 个（按置信度降序），平均看不到太多噪声
    private static let minConfidence: Float = 0.20
    private static let maxTagCount = 8

    /// 返回一组已翻译成中文的场景标签，按 confidence 降序去重。
    static func classifyScene(_ image: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let gate = ContinuationGate()
            let request = VNClassifyImageRequest { request, _ in
                guard let observations = request.results as? [VNClassificationObservation] else {
                    if gate.open() { continuation.resume(returning: []) }
                    return
                }
                // 过滤低置信度 + 去重 + 翻译为中文
                var seen = Set<String>()
                var tags: [String] = []
                for obs in observations where obs.confidence >= minConfidence {
                    guard let cn = TagTranslator.translate(obs.identifier) else { continue }
                    if seen.insert(cn).inserted {
                        tags.append(cn)
                        if tags.count >= maxTagCount { break }
                    }
                }
                if gate.open() { continuation.resume(returning: tags) }
            }
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
                if gate.open() { continuation.resume(returning: []) }
            } catch {
                if gate.open() { continuation.resume(returning: []) }
            }
        }
    }
}

// MARK: - 英文分类标识 -> 中文

/// Vision 的 `VNClassifyImageRequest` 内置了约 1300 个英文分类标识。
/// 我们只翻译育儿场景下出镜率最高的一批，其它命中则忽略（宁可少不要滥）。
enum TagTranslator {

    static func translate(_ identifier: String) -> String? {
        mapping[identifier]
    }

    /// 全量中文 tag 集合。供 `MilestoneContentAnalyzer` 做"标题包含哪些 tag"的推导。
    static func allChineseTags() -> Set<String> {
        Set(mapping.values)
    }

    // 键按字母顺序排列，便于维护。Vision 内置约 1300 个英文分类标识，
    // 我们尽量翻译育儿场景下出镜率高的、能触发里程碑的，其它命中则忽略。
    private static let mapping: [String: String] = [
        // —— 人物 / 表情 ——
        "baby": "宝宝",
        "child": "小朋友",
        "infant": "婴儿",
        "kid": "小朋友",
        "people": "人物",
        "person": "人物",
        "portrait": "人像",
        "selfie": "自拍",
        "smile": "微笑",
        "smiling": "微笑",
        "laughing": "笑",
        "crying": "哭",

        // —— 食物 ——
        "apple": "苹果",
        "banana": "香蕉",
        "berry": "莓果",
        "biscuit": "饼干",
        "bread": "面包",
        "breakfast": "早餐",
        "cake": "蛋糕",
        "candy": "糖果",
        "cheese": "奶酪",
        "chocolate": "巧克力",
        "cookie": "饼干",
        "dessert": "甜点",
        "dim_sum": "点心",
        "drink": "饮品",
        "dumpling": "饺子",
        "egg": "鸡蛋",
        "food": "食物",
        "fruit": "水果",
        "grape": "葡萄",
        "hamburger": "汉堡",
        "hot_dog": "热狗",
        "ice_cream": "冰淇淋",
        "juice": "果汁",
        "lemon": "柠檬",
        "lunch": "午餐",
        "mango": "芒果",
        "meal": "餐食",
        "milk": "牛奶",
        "noodle": "面条",
        "orange": "橙子",
        "pasta": "意面",
        "pizza": "披萨",
        "rice": "米饭",
        "salad": "沙拉",
        "sandwich": "三明治",
        "snack": "零食",
        "soup": "汤",
        "strawberry": "草莓",
        "sushi": "寿司",
        "tea": "茶",
        "vegetable": "蔬菜",
        "watermelon": "西瓜",
        "yogurt": "酸奶",

        // —— 玩具与用品 ——
        "ball": "皮球",
        "balloon": "气球",
        "block": "积木",
        "book": "书本",
        "doll": "娃娃",
        "kite": "风筝",
        "lego": "积木",
        "puzzle": "拼图",
        "stuffed_animal": "毛绒玩具",
        "stuffed_toy": "毛绒玩具",
        "teddy": "泰迪熊",
        "toy": "玩具",
        "toy_block": "积木",

        // —— 动物 / 宠物 ——
        "bear": "熊",
        "bee": "蜜蜂",
        "bird": "鸟",
        "butterfly": "蝴蝶",
        "cat": "猫",
        "chicken": "鸡",
        "cow": "牛",
        "deer": "鹿",
        "dog": "狗",
        "duck": "鸭子",
        "elephant": "大象",
        "fish": "鱼",
        "fox": "狐狸",
        "frog": "青蛙",
        "giraffe": "长颈鹿",
        "goat": "山羊",
        "horse": "马",
        "lion": "狮子",
        "monkey": "猴子",
        "panda": "熊猫",
        "penguin": "企鹅",
        "pet": "宠物",
        "pig": "猪",
        "rabbit": "兔子",
        "sheep": "羊",
        "squirrel": "松鼠",
        "tiger": "老虎",
        "turtle": "乌龟",
        "whale": "鲸鱼",
        "zebra": "斑马",

        // —— 地点 & 场景 ——
        "airport": "机场",
        "amusement_park": "游乐园",
        "aquarium": "水族馆",
        "beach": "海滩",
        "bedroom": "卧室",
        "bridge": "桥",
        "car_interior": "车内",
        "castle": "城堡",
        "church": "教堂",
        "city": "城市",
        "classroom": "教室",
        "countryside": "乡村",
        "downtown": "市区",
        "farm": "农场",
        "field": "田野",
        "forest": "森林",
        "fountain": "喷泉",
        "garden": "花园",
        "grass": "草地",
        "harbor": "港口",
        "hill": "小山",
        "home": "家",
        "hotel": "酒店",
        "indoor": "室内",
        "island": "岛屿",
        "kitchen": "厨房",
        "lake": "湖泊",
        "library": "图书馆",
        "lighthouse": "灯塔",
        "living_room": "客厅",
        "mall": "商场",
        "meadow": "草地",
        "monument": "纪念碑",
        "mountain": "山",
        "museum": "博物馆",
        "ocean": "海",
        "office": "办公室",
        "outdoor": "户外",
        "palace": "宫殿",
        "park": "公园",
        "playground": "游乐场",
        "pond": "池塘",
        "pool": "泳池",
        "restaurant": "餐厅",
        "river": "河",
        "road": "路",
        "sea": "海边",
        "shop": "商店",
        "sky": "天空",
        "snow": "雪",
        "stadium": "体育馆",
        "station": "车站",
        "street": "街道",
        "supermarket": "超市",
        "temple": "寺庙",
        "theater": "剧院",
        "tower": "塔",
        "valley": "山谷",
        "village": "村庄",
        "water": "水",
        "waterfall": "瀑布",
        "zoo": "动物园",

        // —— 自然元素 ——
        "cloud": "云",
        "fog": "雾",
        "flower": "花",
        "leaf": "树叶",
        "moon": "月亮",
        "plant": "植物",
        "rain": "雨",
        "rainbow": "彩虹",
        "rock": "岩石",
        "sand": "沙子",
        "star": "星星",
        "sun": "太阳",
        "sunrise": "日出",
        "sunset": "日落",
        "tree": "树",
        "wave": "海浪",

        // —— 家具与日常 ——
        "bathtub": "浴缸",
        "bed": "床",
        "blanket": "毛毯",
        "bottle": "奶瓶",
        "chair": "椅子",
        "crib": "婴儿床",
        "furniture": "家具",
        "highchair": "餐椅",
        "lamp": "灯",
        "mirror": "镜子",
        "pacifier": "奶嘴",
        "pillow": "枕头",
        "sofa": "沙发",
        "stroller": "婴儿车",
        "table": "桌子",
        "towel": "毛巾",

        // —— 活动 ——
        "birthday": "生日",
        "birthday_cake": "生日蛋糕",
        "camping": "露营",
        "climbing": "爬山",
        "dancing": "跳舞",
        "drawing": "画画",
        "eating": "吃饭",
        "exercise": "运动",
        "fishing": "钓鱼",
        "hiking": "远足",
        "jumping": "跳跃",
        "painting": "绘画",
        "party": "派对",
        "playing": "玩耍",
        "reading": "读书",
        "riding": "骑行",
        "running": "跑步",
        "singing": "唱歌",
        "skating": "滑冰",
        "skiing": "滑雪",
        "sleeping": "睡觉",
        "sport": "运动",
        "surfing": "冲浪",
        "swimming": "游泳",
        "travel": "旅行",
        "walking": "走路",
        "writing": "写字",

        // —— 乐器 / 音乐 ——
        "drum": "鼓",
        "guitar": "吉他",
        "musical_instrument": "乐器",
        "piano": "钢琴",
        "violin": "小提琴",

        // —— 交通 ——
        "airplane": "飞机",
        "bicycle": "自行车",
        "boat": "船",
        "bus": "公交车",
        "car": "汽车",
        "ferry": "渡轮",
        "helicopter": "直升机",
        "motorcycle": "摩托车",
        "scooter": "滑板车",
        "skateboard": "滑板",
        "ship": "船",
        "subway": "地铁",
        "taxi": "出租车",
        "train": "火车",
        "tram": "电车",
        "vehicle": "车辆",

        // —— 节日 ——
        "christmas": "圣诞节",
        "easter": "复活节",
        "fireworks": "烟花",
        "halloween": "万圣节",
        "holiday": "节日",
        "lantern": "灯笼",
        "new_year": "新年",
        "thanksgiving": "感恩节",
        "wedding": "婚礼",

        // —— 衣物 / 配饰 ——
        "backpack": "背包",
        "boots": "靴子",
        "clothes": "衣服",
        "coat": "外套",
        "costume": "服装",
        "dress": "裙子",
        "glasses": "眼镜",
        "hat": "帽子",
        "scarf": "围巾",
        "shoes": "鞋子",
        "sock": "袜子",
        "swimsuit": "泳衣",
        "umbrella": "伞",
    ]
}
