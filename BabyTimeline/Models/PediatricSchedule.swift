import Foundation

// MARK: - 数据结构

/// 儿保 / 疫苗的时间表条目（静态数据，不直接落库）。
struct PediatricEvent: Identifiable, Hashable {
    let id: String  // 全局唯一，例 "checkup.18m" / "vaccine.dtp.4"
    let title: String
    let kind: Kind
    let category: Category
    let ageMonths: Int  // 推荐月龄
    let detail: String?  // 一句话补充说明，比如「国家免疫规划程序」

    enum Kind {
        case checkup
        case vaccine
    }

    enum Category {
        case wellBaby   // 儿保
        case required   // 一类（国家免疫规划，免费）
        case optional   // 二类（自费可选）
    }

    /// "1 月" / "1 岁 6 月"
    var ageLabel: String {
        if ageMonths < 12 { return "\(ageMonths) 月" }
        let years = ageMonths / 12
        let months = ageMonths % 12
        return months == 0 ? "\(years) 岁" : "\(years) 岁 \(months) 月"
    }
}

// MARK: - 全量数据
//
// 来源：
// - 儿保：国家基本公共卫生服务规范第三版「0–6 岁儿童健康管理」
// - 一类疫苗：国家免疫规划疫苗儿童免疫程序（2021 年版）
// - 二类疫苗：列出最常见可选疫苗，仅作参考

enum PediatricSchedule {

    static let events: [PediatricEvent] = (checkups + vaccines).sorted {
        $0.ageMonths != $1.ageMonths ? $0.ageMonths < $1.ageMonths : $0.title < $1.title
    }

    static var checkups: [PediatricEvent] {
        [
            .init(id: "checkup.1m", title: "1 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 1,
                  detail: "新生儿访视，量身高体重头围、体格检查、喂养指导"),
            .init(id: "checkup.3m", title: "3 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 3,
                  detail: "体格检查、神经发育评估"),
            .init(id: "checkup.6m", title: "6 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 6,
                  detail: "辅食添加指导、贫血筛查"),
            .init(id: "checkup.8m", title: "8 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 8,
                  detail: "DDST 发育筛查"),
            .init(id: "checkup.12m", title: "12 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 12,
                  detail: "周岁体检 + 血常规、视力筛查"),
            .init(id: "checkup.18m", title: "18 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 18,
                  detail: "语言 / 大动作 / 社交评估"),
            .init(id: "checkup.24m", title: "24 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 24,
                  detail: "2 岁体检 + 涂氟（部分地区）"),
            .init(id: "checkup.30m", title: "30 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 30,
                  detail: nil),
            .init(id: "checkup.36m", title: "36 月儿保", kind: .checkup, category: .wellBaby, ageMonths: 36,
                  detail: "3 岁体检 + 视力筛查 + 涂氟"),
        ]
    }

    static var vaccines: [PediatricEvent] {
        [
            // 出生
            .init(id: "vaccine.hepb.1", title: "乙肝 第 1 针", kind: .vaccine, category: .required, ageMonths: 0, detail: "出生 24 小时内"),
            .init(id: "vaccine.bcg", title: "卡介苗", kind: .vaccine, category: .required, ageMonths: 0, detail: "出生时接种"),
            // 1 月
            .init(id: "vaccine.hepb.2", title: "乙肝 第 2 针", kind: .vaccine, category: .required, ageMonths: 1, detail: nil),
            // 2 月
            .init(id: "vaccine.ipv.1", title: "脊灰灭活 第 1 针", kind: .vaccine, category: .required, ageMonths: 2, detail: nil),
            // 3 月
            .init(id: "vaccine.ipv.2", title: "脊灰灭活 第 2 针", kind: .vaccine, category: .required, ageMonths: 3, detail: nil),
            .init(id: "vaccine.dtp.1", title: "百白破 第 1 针", kind: .vaccine, category: .required, ageMonths: 3, detail: nil),
            // 4 月
            .init(id: "vaccine.opv.1", title: "脊灰减毒 第 1 剂", kind: .vaccine, category: .required, ageMonths: 4, detail: nil),
            .init(id: "vaccine.dtp.2", title: "百白破 第 2 针", kind: .vaccine, category: .required, ageMonths: 4, detail: nil),
            // 5 月
            .init(id: "vaccine.dtp.3", title: "百白破 第 3 针", kind: .vaccine, category: .required, ageMonths: 5, detail: nil),
            // 6 月
            .init(id: "vaccine.hepb.3", title: "乙肝 第 3 针", kind: .vaccine, category: .required, ageMonths: 6, detail: nil),
            .init(id: "vaccine.menA.1", title: "A 群流脑 第 1 针", kind: .vaccine, category: .required, ageMonths: 6, detail: nil),
            // 8 月
            .init(id: "vaccine.mmr.1", title: "麻腮风（MMR）第 1 针", kind: .vaccine, category: .required, ageMonths: 8, detail: nil),
            .init(id: "vaccine.je.1", title: "乙脑减毒 第 1 针", kind: .vaccine, category: .required, ageMonths: 8, detail: nil),
            // 9 月
            .init(id: "vaccine.menA.2", title: "A 群流脑 第 2 针", kind: .vaccine, category: .required, ageMonths: 9, detail: nil),
            // 18 月
            .init(id: "vaccine.dtp.4", title: "百白破 第 4 针（加强）", kind: .vaccine, category: .required, ageMonths: 18, detail: nil),
            .init(id: "vaccine.hepa.1", title: "甲肝（减毒）", kind: .vaccine, category: .required, ageMonths: 18, detail: nil),
            // 2 岁
            .init(id: "vaccine.je.2", title: "乙脑减毒 第 2 针", kind: .vaccine, category: .required, ageMonths: 24, detail: nil),
            // 3 岁
            .init(id: "vaccine.menAC.1", title: "A+C 群流脑 第 1 针", kind: .vaccine, category: .required, ageMonths: 36, detail: nil),
            // 4 岁
            .init(id: "vaccine.opv.2", title: "脊灰减毒 第 2 剂", kind: .vaccine, category: .required, ageMonths: 48, detail: nil),
            // 6 岁
            .init(id: "vaccine.dt", title: "白破", kind: .vaccine, category: .required, ageMonths: 72, detail: "百白破第 5 剂的替代"),
            .init(id: "vaccine.menAC.2", title: "A+C 群流脑 第 2 针", kind: .vaccine, category: .required, ageMonths: 72, detail: nil),
            .init(id: "vaccine.je.3", title: "乙脑减毒 第 3 针", kind: .vaccine, category: .required, ageMonths: 72, detail: nil),

            // 二类（自费可选）
            .init(id: "vaccine.opt.rota", title: "轮状病毒（自费）", kind: .vaccine, category: .optional, ageMonths: 2, detail: "推荐 2、4、6 月各一剂；防腹泻"),
            .init(id: "vaccine.opt.pcv13.1", title: "13 价肺炎 第 1 针（自费）", kind: .vaccine, category: .optional, ageMonths: 2, detail: "国产 / 进口；2、4、6 月接种 + 12–15 月加强"),
            .init(id: "vaccine.opt.hib", title: "Hib（自费）", kind: .vaccine, category: .optional, ageMonths: 2, detail: "5 合 1 已包含"),
            .init(id: "vaccine.opt.varicella.1", title: "水痘 第 1 针（自费）", kind: .vaccine, category: .optional, ageMonths: 12, detail: "12 月可种，4 岁加强"),
            .init(id: "vaccine.opt.flu", title: "流感（自费）", kind: .vaccine, category: .optional, ageMonths: 6, detail: "每年秋季接种，6 月以上可种"),
            .init(id: "vaccine.opt.evf71", title: "手足口（EV71，自费）", kind: .vaccine, category: .optional, ageMonths: 6, detail: "6 月–5 岁接种，2 剂间隔 1 月"),
        ]
    }
}
