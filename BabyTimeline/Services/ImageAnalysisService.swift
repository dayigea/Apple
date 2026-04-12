import CoreGraphics
import Foundation
import Vision

/// 对一张图片做人脸检测 + 场景分类。
/// - 人脸检测结果用于「是否纳入时间线」的硬性过滤
/// - 场景分类结果翻译为中文标签，作为照片自动内容摘要
enum ImageAnalysisService {

    struct Result {
        let faceCount: Int
        /// 中文标签，已按 confidence 降序去重
        let tags: [String]
    }

    /// 对单张 CGImage 做分析。纯异步，可在后台队列调用。
    static func analyze(_ image: CGImage) async -> Result {
        async let faces = detectFaces(image)
        async let tags = classifyScene(image)
        return Result(faceCount: await faces, tags: await tags)
    }

    // MARK: - 人脸检测

    private static func detectFaces(_ image: CGImage) async -> Int {
        await withCheckedContinuation { continuation in
            let request = VNDetectFaceRectanglesRequest { request, _ in
                let count = (request.results as? [VNFaceObservation])?.count ?? 0
                continuation.resume(returning: count)
            }
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: 0)
            }
        }
    }

    // MARK: - 场景分类

    private static let minConfidence: Float = 0.30
    private static let maxTagCount = 5

    private static func classifyScene(_ image: CGImage) async -> [String] {
        await withCheckedContinuation { continuation in
            let request = VNClassifyImageRequest { request, _ in
                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: [])
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
                continuation.resume(returning: tags)
            }
            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(returning: [])
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

    // 键按字母顺序排列，便于维护
    private static let mapping: [String: String] = [
        // —— 人物 ——
        "baby": "宝宝",
        "child": "小朋友",
        "people": "人物",
        "person": "人物",
        "portrait": "人像",

        // —— 食物 ——
        "bread": "面包",
        "cake": "蛋糕",
        "candy": "糖果",
        "cookie": "饼干",
        "dessert": "甜点",
        "drink": "饮品",
        "food": "食物",
        "fruit": "水果",
        "ice_cream": "冰淇淋",
        "meal": "餐食",
        "milk": "牛奶",
        "noodle": "面条",
        "rice": "米饭",
        "snack": "零食",
        "soup": "汤",
        "vegetable": "蔬菜",

        // —— 玩具与用品 ——
        "ball": "皮球",
        "balloon": "气球",
        "book": "书本",
        "doll": "娃娃",
        "stuffed_animal": "毛绒玩具",
        "teddy": "泰迪熊",
        "toy": "玩具",
        "toy_block": "积木",

        // —— 动物 / 宠物 ——
        "bird": "鸟",
        "cat": "猫",
        "dog": "狗",
        "fish": "鱼",
        "pet": "宠物",
        "rabbit": "兔子",

        // —— 地点 & 场景 ——
        "airport": "机场",
        "aquarium": "水族馆",
        "beach": "海滩",
        "bedroom": "卧室",
        "car_interior": "车内",
        "city": "城市",
        "classroom": "教室",
        "countryside": "乡村",
        "field": "田野",
        "forest": "森林",
        "garden": "花园",
        "grass": "草地",
        "home": "家",
        "indoor": "室内",
        "kitchen": "厨房",
        "lake": "湖泊",
        "living_room": "客厅",
        "mall": "商场",
        "meadow": "草地",
        "mountain": "山",
        "museum": "博物馆",
        "ocean": "海",
        "office": "办公室",
        "outdoor": "户外",
        "park": "公园",
        "playground": "游乐场",
        "pool": "泳池",
        "restaurant": "餐厅",
        "river": "河",
        "road": "路",
        "sea": "海边",
        "shop": "商店",
        "sky": "天空",
        "snow": "雪",
        "street": "街道",
        "supermarket": "超市",
        "water": "水",
        "zoo": "动物园",

        // —— 自然元素 ——
        "cloud": "云",
        "flower": "花",
        "leaf": "树叶",
        "plant": "植物",
        "rain": "雨",
        "sunset": "日落",
        "tree": "树",

        // —— 家具与日常 ——
        "bathtub": "浴缸",
        "bed": "床",
        "chair": "椅子",
        "crib": "婴儿床",
        "furniture": "家具",
        "highchair": "餐椅",
        "sofa": "沙发",
        "stroller": "婴儿车",
        "table": "桌子",

        // —— 活动 ——
        "birthday": "生日",
        "birthday_cake": "生日蛋糕",
        "eating": "吃饭",
        "party": "派对",
        "playing": "玩耍",
        "reading": "读书",
        "sleeping": "睡觉",
        "swimming": "游泳",
        "travel": "旅行",
        "walking": "走路",

        // —— 交通 ——
        "airplane": "飞机",
        "bicycle": "自行车",
        "boat": "船",
        "bus": "公交车",
        "car": "汽车",
        "motorcycle": "摩托车",
        "train": "火车",
        "vehicle": "车辆",

        // —— 节日 ——
        "christmas": "圣诞节",
        "halloween": "万圣节",
        "holiday": "节日",
        "new_year": "新年",
        "wedding": "婚礼",

        // —— 其它 ——
        "clothes": "衣服",
        "glasses": "眼镜",
        "hat": "帽子",
        "shoes": "鞋子",
        "smile": "微笑",
    ]
}
