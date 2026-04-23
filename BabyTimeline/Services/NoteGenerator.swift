import Foundation

/// 纯本地的「有温度」文案生成器。
///
/// 把照片的 autoTags + 年龄 + 地点组合成一段自然中文，
/// 同一组输入每次生成时随机抽取模板，避免千篇一律。
///
/// 设计思路：
/// 1. 先按标签组合匹配**场景模板**（"公园+狗" → 专属句式），命中率最高的场景优先
/// 2. 匹配不到场景就退化到**通用模板**（随机挑一句开头 + 标签列举）
/// 3. 根据月龄自动切换语气：0-6个月温柔、6-18个月活泼、18个月以上有故事感
enum NoteGenerator {

    // MARK: - 公开接口

    /// 给一张照片生成一段有温度的中文描述。
    static func generate(for photo: PhotoEntry, baby: Baby) -> String {
        let age = AgeCalculator.age(birthday: baby.birthday, at: photo.creationDate)
        let tags = Set(photo.autoTags)
        let place = photo.placeName?.trimmingCharacters(in: .whitespaces)
        let hasPlace = !(place?.isEmpty ?? true)

        // 1. 尝试场景模板
        if let scene = matchScene(tags: tags, age: age, place: place) {
            return scene
        }

        // 2. 通用模板
        return genericNote(tags: tags, age: age, place: place, hasPlace: hasPlace)
    }

    // MARK: - 场景模板

    private struct SceneTemplate {
        let requiredTags: Set<String>
        let templates: [String]
    }

    private static func matchScene(
        tags: Set<String>,
        age: AgeCalculator.Age,
        place: String?
    ) -> String? {
        let placePart = place.map { "在\($0)" } ?? ""
        let agePart = age.localized

        // 场景按优先级排（越具体越靠前）
        let scenes: [(required: Set<String>, generate: () -> String)] = [
            // —— 生日 ——
            (["生日蛋糕"], {
                pick([
                    "\(agePart)的生日！\(placePart)吹蜡烛的样子好认真。",
                    "生日快乐！\(agePart)了，\(placePart)蛋糕前面笑得好开心。",
                    "\(agePart)的小寿星，\(placePart)第一次自己吹蜡烛。",
                ])
            }),
            (["蛋糕", "派对"], {
                pick([
                    "\(agePart)的小派对，\(placePart)蛋糕比脸还大。",
                    "\(placePart)的小聚会，\(agePart)的宝贝第一次戴派对帽。",
                ])
            }),

            // —— 动物 ——
            (["狗", "公园"], {
                pick([
                    "\(agePart)，\(placePart)遇到了一只狗，好奇地盯着看。",
                    "\(placePart)散步，\(agePart)的小朋友第一次敢摸小狗了。",
                    "\(agePart)，\(placePart)追着小狗跑，虽然还走不太稳。",
                ])
            }),
            (["狗"], {
                pick([
                    "\(agePart)，第一次和小狗面对面，又好奇又有点怕。",
                    "\(agePart)见到了汪星人，眼睛都亮了。",
                ])
            }),
            (["猫"], {
                pick([
                    "\(agePart)，第一次见到猫咪，伸手就想摸。",
                    "\(agePart)的宝宝遇到了一只猫，蹲下来看了好久。",
                ])
            }),
            (["鸟"], {
                pick([
                    "\(agePart)，抬头看到了小鸟，指着叽叽喳喳地叫。",
                    "\(agePart)，\(placePart)发现了小鸟，一直追着看。",
                ])
            }),
            (["蝴蝶"], {
                pick([
                    "\(agePart)，\(placePart)遇到了蝴蝶，追着跑了好远。",
                    "\(agePart)，第一次看到蝴蝶飞，眼睛都不舍得眨。",
                ])
            }),
            (["大象"], {
                pick([
                    "\(agePart)，第一次见到真的大象！比想象中大好多。",
                    "\(agePart)，\(placePart)站在大象面前，整个人都愣住了。",
                ])
            }),
            (["熊猫"], {
                pick([
                    "\(agePart)，看到了真正的大熊猫，一直不肯走。",
                    "\(agePart)第一次见到国宝，趴在栏杆上看了好久。",
                ])
            }),

            // —— 海边 / 沙滩 ——
            (["海滩", "沙子"], {
                pick([
                    "\(agePart)第一次踩沙滩，\(placePart)光着脚丫玩沙子。",
                    "\(placePart)的沙滩，\(agePart)的宝宝第一次摸到了海水。",
                ])
            }),
            (["海滩"], {
                pick([
                    "\(agePart)，第一次去海边！\(placePart)浪花打过来笑得好大声。",
                    "\(agePart)，\(placePart)看海，风把头发吹得乱乱的。",
                ])
            }),
            (["海"], {
                pick([
                    "\(agePart)，\(placePart)第一次看到大海，一直指着远方。",
                    "\(agePart)，终于见到了大海，\(placePart)拍下了这个瞬间。",
                ])
            }),

            // —— 雪 ——
            (["雪"], {
                pick([
                    "\(agePart)，\(placePart)第一次见到雪！伸手去接雪花。",
                    "\(agePart)的冬天，\(placePart)一脚踩进雪里，愣了一下然后咯咯笑。",
                    "下雪了！\(agePart)的宝宝\(placePart)玩雪，手冻得红红的还不肯回去。",
                ])
            }),

            // —— 彩虹 ——
            (["彩虹"], {
                pick([
                    "\(agePart)，\(placePart)雨后看到了彩虹，小手一直指着天上。",
                    "\(agePart)第一次看到彩虹，\"那是什么呀？\"",
                ])
            }),

            // —— 游乐场 ——
            (["游乐场"], {
                pick([
                    "\(agePart)，\(placePart)第一次去游乐场，什么都想玩。",
                    "\(agePart)的小冒险家，\(placePart)游乐场里跑来跑去。",
                ])
            }),

            // —— 游泳 ——
            (["游泳"], {
                pick([
                    "\(agePart)，第一次下水！一开始有点害怕，后来就不肯上来了。",
                    "\(agePart)的小鱼，\(placePart)第一次游泳。",
                ])
            }),
            (["泳池"], {
                pick([
                    "\(agePart)，\(placePart)第一次玩水，拍得水花四溅。",
                    "\(agePart)的夏天，泳池里泡着不肯出来。",
                ])
            }),

            // —— 食物 ——
            (["冰淇淋"], {
                pick([
                    "\(agePart)，第一口冰淇淋！眼睛瞪得大大的。",
                    "\(agePart)第一次吃冰淇淋，吃得满脸都是。",
                ])
            }),
            (["西瓜"], {
                pick([
                    "\(agePart)的夏天，啃西瓜啃得满脸汁。",
                    "\(agePart)，第一次吃西瓜，甜到眯起眼睛。",
                ])
            }),
            (["草莓"], {
                pick([
                    "\(agePart)，第一次吃草莓，酸得皱了一下鼻子。",
                    "\(agePart)的小吃货，一口一个草莓。",
                ])
            }),
            (["蛋糕"], {
                pick([
                    "\(agePart)，\(placePart)第一次吃蛋糕，奶油糊了一脸。",
                    "\(agePart)的宝宝遇到了蛋糕，两只手都不够用。",
                ])
            }),
            (["饺子"], {
                pick([
                    "\(agePart)，第一次吃饺子！自己拿着往嘴里塞。",
                    "\(agePart)的小馋猫，\(placePart)包饺子的时候偷吃了一个。",
                ])
            }),
            (["面条", "意面"], {
                pick([
                    "\(agePart)，吃面条吃得满嘴都是，但是好开心。",
                    "\(agePart)的宝宝跟面条搏斗中，面条赢了。",
                ])
            }),
            (["披萨"], {
                pick([
                    "\(agePart)，第一次吃披萨，芝士拉丝拉了好长。",
                    "\(agePart)的小吃货\(placePart)遇到了人生第一块披萨。",
                ])
            }),

            // —— 走路/跑 ——
            (["走路"], {
                if age.totalMonths <= 15 {
                    return pick([
                        "\(agePart)，迈出了人生的第一步！摇摇晃晃但特别勇敢。",
                        "\(agePart)终于学会走路了，虽然走两步就要扶一下。",
                        "\(agePart)，从爬到走，这一步等了好久。",
                    ])
                } else {
                    return pick([
                        "\(agePart)，\(placePart)走得越来越稳了。",
                        "\(agePart)的小探险家，\(placePart)到处走来走去。",
                    ])
                }
            }),
            (["跑步"], {
                pick([
                    "\(agePart)，会跑了！\(placePart)跑得摇摇晃晃但停不下来。",
                    "\(agePart)，从走到跑，拦都拦不住。",
                ])
            }),

            // —— 乐器 ——
            (["钢琴"], {
                pick([
                    "\(agePart)，\(placePart)第一次摸到钢琴，小手按下去的表情好认真。",
                    "\(agePart)的小音乐家，在钢琴前面叮叮咚咚。",
                ])
            }),
            (["吉他"], {
                pick([
                    "\(agePart)，抱着比自己还大的吉他，像个小摇滚明星。",
                    "\(agePart)，第一次拨吉他的弦，咯咯笑个不停。",
                ])
            }),

            // —— 画画 ——
            (["画画", "绘画"], {
                pick([
                    "\(agePart)，第一幅「画作」诞生了，虽然看不出画的啥。",
                    "\(agePart)的小画家，\(placePart)拿着画笔到处涂。",
                ])
            }),

            // —— 书 ——
            (["书本", "读书"], {
                pick([
                    "\(agePart)，\(placePart)安安静静地翻书，虽然拿反了。",
                    "\(agePart)的阅读时光，一页一页翻得很认真。",
                ])
            }),

            // —— 睡觉 ——
            (["睡觉"], {
                if age.totalMonths <= 6 {
                    return pick([
                        "\(agePart)，睡着的样子像个小天使。",
                        "\(agePart)的宝宝，睡得好香好安静。",
                        "安安静静的\(agePart)，睡梦中的小脸蛋。",
                    ])
                } else {
                    return pick([
                        "\(agePart)，玩累了终于睡着了，姿势好搞笑。",
                        "\(agePart)的午睡时间，怎么都叫不醒。",
                    ])
                }
            }),

            // —— 花 ——
            (["花"], {
                pick([
                    "\(agePart)，\(placePart)蹲下来看花，小鼻子凑上去闻了闻。",
                    "\(agePart)，看到花就要伸手摘，拦都拦不住。",
                ])
            }),

            // —— 草地 ——
            (["草地"], {
                pick([
                    "\(agePart)，\(placePart)第一次光脚踩草地，痒得直缩脚。",
                    "\(agePart)，在草地上打滚，笑得咯咯响。",
                ])
            }),

            // —— 山 ——
            (["山"], {
                pick([
                    "\(agePart)，\(placePart)第一次看见山，\"好大呀！\"",
                    "\(agePart)的小登山家，\(placePart)走了好远都不喊累。",
                ])
            }),

            // —— 烟花 ——
            (["烟花"], {
                pick([
                    "\(agePart)，\(placePart)第一次看烟花，一开始被吓了一跳，后来越看越兴奋。",
                    "\(agePart)的夜晚，天上开满了花，眼睛里映着五颜六色的光。",
                ])
            }),

            // —— 圣诞 ——
            (["圣诞节"], {
                pick([
                    "\(agePart)的第一个圣诞节！\(placePart)收到了什么礼物呢？",
                    "圣诞快乐！\(agePart)的宝贝，\(placePart)圣诞树前拍的。",
                ])
            }),

            // —— 露营 ——
            (["露营"], {
                pick([
                    "\(agePart)，\(placePart)第一次露营，帐篷比家还好玩。",
                    "\(agePart)的小野人，第一次在外面过夜。",
                ])
            }),

            // —— 风筝 ——
            (["风筝"], {
                pick([
                    "\(agePart)，\(placePart)放风筝，一直仰着头看天上。",
                    "\(agePart)第一次放风筝，跑得比风筝还开心。",
                ])
            }),
        ]

        for scene in scenes {
            if scene.required.isSubset(of: tags) {
                var text = scene.generate()
                // 清理空的地点占位
                text = text.replacingOccurrences(of: "在 ", with: "")
                    .replacingOccurrences(of: "，，", with: "，")
                if text.hasPrefix("，") { text = String(text.dropFirst()) }
                return text.trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // MARK: - 通用模板

    private static func genericNote(
        tags: Set<String>,
        age: AgeCalculator.Age,
        place: String?,
        hasPlace: Bool
    ) -> String {
        let agePart = age.localized
        let meaningful = tags.subtracting([
            "宝宝", "小朋友", "人物", "人像", "婴儿", "自拍",
            "室内", "户外", "家具", "家", "衣服",
        ])

        let tagList = meaningful.sorted().prefix(3).joined(separator: "、")

        // 根据月龄选语气
        if age.totalMonths <= 6 {
            // 温柔风
            return buildSoft(agePart: agePart, place: place, tagList: tagList)
        } else if age.totalMonths <= 18 {
            // 活泼风
            return buildLively(agePart: agePart, place: place, tagList: tagList)
        } else {
            // 故事风
            return buildStorytelling(agePart: agePart, place: place, tagList: tagList)
        }
    }

    private static func buildSoft(agePart: String, place: String?, tagList: String) -> String {
        let openers = [
            "\(agePart)的小宝贝，安安静静的一天。",
            "\(agePart)，小小的世界，大大的眼睛。",
            "\(agePart)，每一天都在悄悄长大。",
        ]
        var text = pick(openers)
        if let p = place, !p.isEmpty {
            text += "在\(p)拍的。"
        }
        if !tagList.isEmpty {
            text += pick([
                "镜头里是\(tagList)。",
                "那天有\(tagList)的陪伴。",
            ])
        }
        return text
    }

    private static func buildLively(agePart: String, place: String?, tagList: String) -> String {
        let openers = [
            "\(agePart)了，每天都有新发现！",
            "\(agePart)，好奇心爆棚的阶段。",
            "\(agePart)的小探险家，到处都想看看。",
        ]
        var text = pick(openers)
        if let p = place, !p.isEmpty {
            text += pick([
                "这天在\(p)。",
                "\(p)留下了小脚印。",
            ])
        }
        if !tagList.isEmpty {
            text += pick([
                "遇到了\(tagList)。",
                "照片里有\(tagList)的身影。",
            ])
        }
        return text
    }

    private static func buildStorytelling(agePart: String, place: String?, tagList: String) -> String {
        let openers = [
            "\(agePart)，已经是个小大人了。",
            "\(agePart)的日常，越来越有自己的主意。",
            "\(agePart)，回头看这些照片一定会笑。",
        ]
        var text = pick(openers)
        if let p = place, !p.isEmpty {
            text += pick([
                "那天去了\(p)。",
                "在\(p)的一天。",
            ])
        }
        if !tagList.isEmpty {
            text += pick([
                "记录下了\(tagList)。",
                "一起经历了\(tagList)。",
            ])
        }
        return text
    }

    // MARK: - 工具

    private static func pick(_ options: [String]) -> String {
        options.randomElement() ?? options[0]
    }
}
