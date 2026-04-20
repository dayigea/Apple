# 苹果长大了 · BabyTimeline

给女儿做的 iOS 私人成长时间线 App。

## 做什么

- **读取手机相册里生日之后的照片**，按年龄阶段自动分组，生成一条成长时间线
- **认人**（可选，推荐开启）：用 Vision 为女儿的**一张主参考照 + 若干张补充参考照**生成人脸指纹，扫描相册时**只保留含她本人的照片**。多张补充参考专门用来应对「父母和孩子脸型相近」的情况
- **排除人脸**：把爸爸/妈妈/其他家人的正脸照加入黑名单，扫描时用对比匹配过滤掉「更像别人而不是女儿」的照片，显著降低误判
- **只纳入含人脸的照片**（即便没开认人，风景、截图、空镜也会被自动过滤）
- **自动识别画面内容**（`VNClassifyImageRequest`），生成中文标签：宝宝、食物、户外、生日蛋糕…… 不需要手动打字
- **自动读取拍摄时间 + GPS**，用 `CLGeocoder` 把坐标反查成「北京市朝阳区」这样的中文地名
- **成长里程碑**：
  - 手动记录「第一次走路 / 第一次喊妈妈」等关键时刻，可绑一张对应照片
  - **按月龄自动建议**：内置一份 WHO/CDC 发育参考目录（抬头/翻身/独坐/爬行/独立走路……），宝宝到了对应月龄就会在里程碑 Tab 底部列出「建议记录」，点一下自动预填标题、日期、说明
  - **自动关联照片**：`MilestoneContentAnalyzer` 会从里程碑**标题本身**反推应该在照片 `autoTags` 里命中哪些 Vision 中文标签（例：「第一个生日」→ 生日 / 生日蛋糕 / 蛋糕 / 派对；「第一次走路」→ 走路；「第一次咯咯笑」→ 微笑），`MilestonePhotoMatcher` 再按"先内容命中、后日期最近"两阶段挑一张。手写标题也走同一条推导，不需要手工维护对照表
  - **根据照片自动生成说明**：新建里程碑时有「根据照片生成说明」按钮，会读取已绑定照片的 Vision 内容标签 + 拍摄年龄 + 地点，拼出一段中文描述（例：`"1 岁时，在 北京市朝阳区 拍的。照片里能看到 生日蛋糕、蛋糕、微笑。"`），你可以在此基础上继续改
  - **生日自动识别**：扫描相册时如果某张照片正好落在女儿生日周年 ±3 天内，自动帮你创建「第一个生日 / 第二个生日 / …」里程碑并绑定这张照片
- **完全本地、完全私人**：所有数据都在 App 沙盒里，照片本体始终留在系统相册，**不上传任何服务器**

## 技术栈

- SwiftUI + Swift 5.9
- SwiftData（本地持久化）
- Photos / PhotosUI（相册访问）
- Vision（人脸检测、场景分类、人脸指纹）
- CoreLocation（GPS 反地理编码）
- 最低 iOS 17.0

## 目录结构

```
Apple/
├── project.yml                 # XcodeGen 配置（也是 Info.plist 的真相源）
├── bootstrap.sh                # 一键准备脚本（macOS）
├── run-on-device.sh            # 一键 build + 装到 iPhone 上
├── cleanup-xcode.sh            # 清理 Xcode 磁盘占用的脚本
├── scripts/
│   └── make-app-icon.py        # 重新生成 App 图标
├── README.md
└── BabyTimeline/
    ├── BabyTimelineApp.swift   # @main
    ├── RootView.swift
    ├── Info.plist              # 不要手改！由 project.yml 生成
    ├── Assets.xcassets/
    │   └── AppIcon.appiconset/AppIcon.png
    ├── Models/
    │   ├── Baby.swift
    │   ├── PhotoEntry.swift
    │   └── Milestone.swift
    ├── Services/
    │   ├── AgeCalculator.swift
    │   ├── ImageAnalysisService.swift      # 场景分类 → 中文标签
    │   ├── FaceRecognitionService.swift    # 人脸检测 + 认人指纹 + 对比匹配
    │   ├── PhotoLibraryService.swift
    │   ├── MetadataExtractor.swift
    │   ├── GeocodingService.swift
    │   ├── PhotoImporter.swift             # 扫相册 + 生日自动建里程碑
    │   ├── PhotoMilestoneSuggester.swift   # 从时间线照片内容直接生成里程碑建议
    │   ├── MilestoneContentAnalyzer.swift  # 从标题反推关键词 + 根据照片生成备注
    │   └── MilestonePhotoMatcher.swift     # 先按内容关键词再按日期，两阶段自动配照片
    └── Views/
        ├── SetupView.swift
        ├── MainTabView.swift
        ├── Timeline/
        │   ├── TimelineView.swift
        │   ├── TimelineSectionHeader.swift
        │   └── TimelinePhotoCell.swift
        ├── PhotoDetail/
        │   ├── PhotoDetailView.swift
        │   └── AsyncPHAssetImage.swift
        ├── Milestones/
        │   ├── MilestoneListView.swift
        │   └── MilestoneEditView.swift
        └── Settings/
            └── SettingsView.swift
```

## 我需要什么授权？

### Apple 账号
- **免费 Apple ID 就够**，不需要 $99/年的开发者账号
- 免费账号的唯一限制：装到真机上**证书 7 天有效**，过期重新 build 一次就行。自用完全够

### 工具
- **Mac**（macOS 13+ 保险）
- **Xcode**（App Store 免费，首次打开会自动装 iOS SDK）
- 一根连 iPhone 的数据线

### App 运行时权限（Info.plist 已配置，会自动弹窗）
- **相册权限** — 读照片做时间线
- **位置权限** — 把照片里的 GPS 反查成中文地名

### 第三方服务
- **完全不需要**。没有后端、没有 API key、没有注册任何东西

---

## 怎么跑起来（最快路径）

### ⚠️ 如果您的 Mac 磁盘空间紧张，先看这里

Xcode 本身 **~15 GB**，但**模拟器 runtime 每个 iOS 版本额外 ~8 GB**，这是大头。
好消息：**这个项目只跑真机（您自己的 iPhone），完全不需要模拟器。** 可以这样最小化磁盘占用：

1. **第一次装 Xcode 时**（从 App Store 或 developer.apple.com 下的 XIP）：
   - 装完第一次打开 Xcode 会弹「选择要下载的平台」
   - **全部取消勾选 / 点 Cancel / 关掉这个窗口**，iOS SDK 已经在 Xcode.app 里了，不需要下载任何额外 runtime
2. **如果已经装了模拟器 runtime**，用项目根目录下的清理脚本看看占用，并可选清理：
   ```bash
   ./cleanup-xcode.sh           # 只打印占用报告（不删任何东西）
   ./cleanup-xcode.sh --clean   # 真正清理模拟器、DerivedData、缓存
   ```
3. **只保留您 iPhone 当前 iOS 版本对应的 DeviceSupport**（清理脚本会告诉您怎么手动删）

这样整个 Xcode 磁盘占用可以压到 **~15 GB**。

### 方案 A：一键脚本（推荐）

在 Mac 终端进入本项目目录，执行：

```bash
./bootstrap.sh
```

脚本会：
1. 检查 Xcode / Homebrew
2. 装 XcodeGen（如果还没装）
3. 根据 `project.yml` 生成 `BabyTimeline.xcodeproj`
4. 用 Xcode 自动打开项目

然后在 Xcode 里：
1. 顶部蓝色项目图标 → `BabyTimeline` target → **Signing & Capabilities**
2. **Team** 选自己的 Apple ID
3. 如果提示 Bundle Identifier 冲突，把 `com.personal.babytimeline` 改成 `com.自己的名字.babytimeline`
4. 用数据线连 iPhone → 顶部设备选自己的 iPhone → **Cmd + R**
5. iPhone 第一次装完会「不受信任的开发者」：
   - **设置 → 通用 → VPN 与设备管理 → 选自己的 Apple ID → 信任**
   - 回到主屏再点图标打开

### 方案 B：手动三条命令

```bash
brew install xcodegen        # 只要一次
xcodegen generate
open BabyTimeline.xcodeproj
```

剩下步骤同方案 A。

---

## 第一次使用

1. 打开 App → 欢迎页：填 **姓名 / 生日 / 性别 / （可选）头像** → 开始
2. 允许相册权限 → App 开始首次扫描（只扫生日之后的图片）
3. 扫描完成后进入 **时间线** Tab
4. **强烈建议再去设置 → 认人**：
   - 选一张女儿本人、清晰正脸的照片作为「认人基准」
   - 点 **重新扫描相册** → 这次只会保留含女儿本人的照片
   - 如果发现漏掉了不少 → 滑块调「宽松」一点
   - 如果发现混进了别人（爸爸/妈妈/爷爷奶奶）→ 两种办法任选其一：
     1. 滑块调「严格」一点（比如从 18 降到 14–16）
     2. 或者去下面的 **排除人脸** 区，选一张那个家人的正脸照 → **重新扫描相册**。
        对比匹配算法会把「更像爸爸/妈妈而不是像女儿」的照片直接过滤掉，
        比单纯调阈值精准得多。可以加多张（爸爸、外公、外婆……）

## 三个 Tab

| Tab | 作用 |
| --- | --- |
| **时间线** | 按「新生儿 / 1–3 月 / 3–6 月 / 6–12 月 / 1–1.5 岁 / 1.5–2 岁 / 2–3 岁…」分组展示照片。点缩略图进详情页，可看大图、年龄、地点、自动标签，可写备注、加星收藏 |
| **里程碑** | 上半是「已记录」——父母手动填过的；下半是「建议记录」——按宝宝实际月龄从内置发育目录里挑出的事件，点一下直接预填标题/日期/说明，并**自动从时间线里配一张内容匹配的照片**（例如「第一个生日」会优先找带「生日蛋糕 / 派对」标签的照片，没有再按日期最近挑）。新建里程碑改日期时照片绑定也会自动跟着换，直到你主动手选为止 |
| **设置** | 修改宝宝资料、**设置认人照片 + 阈值**、**管理排除人脸**、重新扫描相册（增量新增）、**重新应用过滤规则**（复核已有照片）、清空记录 |

## 认人是怎么工作的

1. 你选一张女儿本人的正脸照作为**主参考** →
2. 可选：再追加几张不同角度 / 不同月龄的女儿照作为**补充参考**（设置 → 女儿补充参考照）
3. 对每张参考照，Vision `VNDetectFaceRectanglesRequest` 找最大的人脸，在 bbox 外扩 20%
   的 ROI 上跑 `VNGenerateImageFeaturePrintRequest` → 得到一个 `VNFeaturePrintObservation`，
   用 `NSKeyedArchiver` 归档后分别存进 `Baby.referenceFacePrintData` / `Baby.extraPositiveFacePrintsRawJSON`
4. 扫描候选照片时，对每张脸都算一个同样的指纹，用 `computeDistance` 和**所有正参考**比距离
5. `positiveDist = min(对所有正参考的距离)`
6. `positiveDist ≤ 阈值` → 判定为「女儿本人」→ 纳入时间线

阈值默认 **18**，可以在设置里用滑块在 10–30 之间调。
越小越严格（更少漏别人，但可能漏掉一些自家娃），越大越宽松。

### 为什么建议多张补充参考

`VNGenerateImageFeaturePrintRequest` 不是专门的人脸识别模型，精度不如 FaceNet/ArcFace，
而**亲子的脸型本来就相似**——单张正脸主参考经常让女儿和妈妈的 `positiveDist`
卡在相近的区间，很难稳定分出来。多放几张不同姿势（正脸、侧脸、笑）和不同月龄
（6 个月、1 岁）的女儿参考后，真正是女儿的候选脸只要和其中**任意一张**参考足够像，
`positiveDist` 就会显著下降；而父母的脸是另外一张脸，不会因为多了几张女儿参考
就变得更像。建议 3–5 张，每半年左右补一张新照片。

> 补充参考照跟主参考照一样都只会在本地生成一个几 KB 的特征指纹，不会上传任何地方，
> 也不需要额外的 Core ML 模型文件。

### 排除人脸（对比匹配）是怎么工作的

光靠一个阈值判断「是不是女儿」经常不够用 —— 比如妈妈的脸对「女儿的参考指纹」
距离是 16，阈值是 18，就会被错当成女儿。解决方法是**加一张妈妈本人的正脸照作为排除样本**。

具体逻辑（`FaceRecognitionService.matchResult`）：

1. 对候选照片里每张脸都算一个特征指纹 `candidate`
2. 计算 `positiveDist = computeDistance(candidate, 女儿的参考指纹)`
3. 如果 `positiveDist > threshold` → 直接不命中（太不像女儿）
4. 对每一张排除人脸算 `negativeDist`，取最小值 `negativeMinDist`
5. 命中条件：**`positiveDist + margin < negativeMinDist`**
   —— 也就是「这张脸比任何一张排除人脸都更像女儿」

所以还是拿妈妈错判的例子：
- `positiveDist`（到女儿）= 16
- `negativeMinDist`（到妈妈本人）= 10
- 16 < 10 **不成立** → 不命中 → 不会被当成女儿

这个对比式匹配比单纯调严阈值精准得多：你可以把阈值保持在宽松一些的 18，
同时把真正会混进来的家人作为排除样本加进去，既不漏女儿，又不误收家人。

加排除人脸的入口在：**设置 → 排除人脸 → 加一张不是女儿的脸**。
可以加任意多张（爸爸、妈妈、外公、外婆……）。

加完之后两件事都要做一次：
- **重新扫描相册**：增量，把之前被错排除在外、但按新规则其实该纳入的新拍照片补进来（一般主要影响以后新拍的）
- **重新应用过滤规则**：用当前设置复核**已经在时间线里**的每一张照片——增量扫描不会动已入库的，所以只有这一步能把时间线里已有的误判（比如你自己的照片）清掉。不匹配的会被删，绑定的里程碑会自动解绑但里程碑本身保留。

此外，过滤器默认会：忽略占画面 < 0.3% 的小背景脸，并逐张脸独立判定——只要有任意一张脸通过阈值、且严格比任何排除脸更像女儿，就算这张照片含女儿。亲子脸型天然相近，默认 `contrastMargin = 0` 只要求"严格更像女儿"，余量设大会把真女儿也挡在外面。这些默认值在 `FaceRecognitionService.matchResult` 里。

### 里程碑自动建议 / 自动生日是怎么工作的

三套互补的机制，都**不上云、不用 AI 模型**，纯本地规则：

1. **从照片内容直接生成建议（`PhotoMilestoneSuggester`）**
   - 不再按月龄硬塞「该到 X 月了，要不要记一下抬头」之类的提示——所有建议都必须有**真实照片证据**做支撑
   - 内置一份「触发词 → 标题/图标」规则表（约 30 条）：
     - 活动类：`走路 → 第一次走路`、`游泳 → 第一次游泳`、`飞机 → 第一次坐飞机` …
     - 地点类：`海滩 → 第一次去海边`、`动物园 → 第一次去动物园`、`雪 → 第一次见到雪` …
     - 动物：`狗/猫/鸟/鱼/兔子 → 第一次见到 …`
     - 美食：`蛋糕 → 第一次吃蛋糕`
     - 节日：`圣诞节 / 新年 / 万圣节 / 婚礼 / 派对 → 第一次过 / 参加 …`
   - 算法：把时间线照片按时间正序排，对每条规则找出**最早一张** `autoTags` 命中触发词的照片，用那张照片的拍摄日期作为里程碑日期、那张照片作为绑定照片、`MilestoneContentAnalyzer.generatedNote` 拼出来的中文作为备注
   - 已经手动记录过同名里程碑的规则会自动跳过
   - UI 里建议按分类（活动 / 地点 / 动物 / 美食 / 节日）分 Section 展示，每条都带缩略图——你看到的就是那张证据照片
   - 点一下 → 跳到 `MilestoneEditView`，**标题 / 日期 / 说明 / 绑定照片** 全都已经填好了，确认就保存

2. **生日照片自动建里程碑（`PhotoImporter.maybeCreateBirthdayMilestone`）**
   - 扫描相册时每张照片走完认人后，检查拍摄日期与女儿生日周年日的差：
     - 差值 ≤ 3 天 → 触发
     - 算好这是第几个生日（用 `Calendar.dateComponents([.year], ...)`）
     - 查 SwiftData 里有没有同标题的 `Milestone`（用 `#Predicate`），没有就新建
     - 把当前这张照片的 `localIdentifier` 绑定过去

3. **内容感知的照片自动匹配（`MilestoneContentAnalyzer` + `MilestonePhotoMatcher`）**
   - 这条服务的是**手动新建里程碑**——你自己输标题，App 帮你从时间线挑张最贴切的照片
   - 关键词不需要手工列：`MilestoneContentAnalyzer.inferredKeywords(forTitle:)` 从**标题本身**推：
     1. 扫 `TagTranslator` 里已翻译的中文 Vision 标签集，标题子串命中的 tag 全加进来
        （标题「第一个生日」直接命中 `"生日"`；「第一次微笑」命中 `"微笑"`）
     2. 查一小张同义词表把标题词根扩展到 Vision 标签
        （`"跑" → "走路"`、`"骑三轮车" → "自行车"`、`"咯咯笑" → "微笑"`、
        `"吃辅食 / 自己吃饭" → "吃饭/食物/餐椅/餐食"`、`"生日" → 补上 "生日蛋糕/蛋糕/派对"`）
   - `MilestonePhotoMatcher.bestMatch(for:in:preferringKeywords:)` 两阶段挑选：
     1. 先只看 `PhotoEntry.autoTags` 命中任一关键词的照片，在子集里按 `|照片日期 − 里程碑日期|` 最小
     2. 没有任何内容命中就退化到全库按日期最近

4. **根据照片自动生成备注（`MilestoneContentAnalyzer.generatedNote`）**
   - 新建里程碑时，备注区底下有一颗「根据照片生成说明」按钮
   - 按了以后会读取当前绑定照片的内容：Vision `autoTags`（过滤掉"宝宝/室内/户外"这类太泛的）+ 拍摄当刻的年龄 + `placeName`（地点反查结果）
   - 拼成一段自然中文，例如：
     - `"1 岁时，在 北京市朝阳区 拍的。照片里能看到 生日蛋糕、蛋糕、微笑。"`
     - `"6 个月时拍的。照片里能看到 餐椅、食物。"`
     - 信息实在不够就只留 `"1 岁 2 个月时拍的。"`
   - 生成的文字会覆盖备注框，用户可以在此基础上继续改

想加更多自动建议，直接往 `PhotoMilestoneSuggester.rules` 数组尾部追加一条 `Rule(...)` 就行——只要触发词在 `TagTranslator` 里能翻译出来，立刻生效。**没有任何远程配置，改了之后重装 App 即生效。**

## 隐私

- **所有数据都在本地**，SwiftData 的 sqlite 存在 App 沙盒里
- **照片本体从不复制**，App 只存系统相册里每张照片的 `PHAsset.localIdentifier` 引用
- **没有任何网络请求**，除了 `CLGeocoder` 反查地名时系统会联网（只传坐标）
- **不会修改你的相册**，全程只读

## 不做 / 可后续加

第一版刻意不做的事：

- ❌ 云同步 / 多设备
- ❌ 账号登录
- ❌ 多宝宝
- ❌ 视频支持
- ❌ 社交分享
- ❌ App Store 上架

## 常见问题

**Q: 扫描速度太慢？**
每张照片要走一次 Vision 人脸检测 + 可选的人脸指纹匹配 + 场景分类。几千张照片大概要几分钟，后台跑就好。只会第一次跑全量，之后都是增量（按 `PHAsset.localIdentifier` 去重）。

**Q: 生日之后的一些照片没出现在时间线？**
按下面顺序排查：
1. 照片里没检测到人脸 → Vision 认为没有（侧脸、背影、脸太小都可能）
2. 开了认人：照片里虽然有人，但不是女儿本人 → 正常行为，或把阈值调宽松
3. 照片的 `creationDate` 早于生日 → 调整日期后重新扫描

**Q: 认人把爸爸妈妈的脸也混进来了？/ 我跟我女儿脸型比较像，怎么办？**
三件事，推荐按顺序都做一下：
1. **设置 → 女儿补充参考照**：多放几张女儿不同角度 / 不同月龄的照片（正脸、侧脸、笑、6 个月 / 1 岁…）。匹配时 `positiveDist` 取对所有参考的最小值——女儿的脸更容易命中，父母脸不会跟着变像。建议 3–5 张。这是解决亲子相像问题的**主要手段**。
2. **设置 → 排除人脸**：把你（妈妈/爸爸）自己的正脸照加进去，可以多张不同角度。对比式匹配会自动把「更像你而不是像女儿」的照片过滤掉。
3. **可选**：把「匹配严格程度」滑块往「严格」拖一些（比如从 18 调到 14–16）。通常做了 1 和 2 之后不需要再动这个。

加完上面任意一项之后，如果时间线里已经有误判，去 **设置 → 重新应用过滤规则**——「重新扫描相册」是增量的，不会复核已入库的照片。

**Q: 加了排除人脸，但我自己的照片还是留在时间线里？**
`重新扫描相册` 是增量的——已经入库的照片在扫描时会直接跳过，所以**后加**的排除人脸 / 调严的阈值只影响以后新拍的照片，对已经在库里的误判没用。
正确流程：
1. 设置 → **排除人脸**，把误判你变成女儿的那张脸加进去
2. 设置 → **重新应用过滤规则**（就在「重新扫描相册」下面）——这一步会用当前的认人 / 排除 / 阈值重新复核每一条已有记录，不匹配的会被从时间线里删掉，绑定的里程碑会自动解绑但不会被删
3. 如果某张具体照片还是想手动清掉：直接点开它 → 右上角「…」 → **从时间线里移除**

**Q: 时间线里出现了一些不相干的照片（路人合影、背景人物等）？**
默认的过滤已经：忽略占画面 < 0.3% 的小脸、并逐张脸独立判定，要求至少一张脸通过阈值并严格比任何排除脸更像女儿（`contrastMargin = 0`；亲子脸型天然相近，margin 设大会把真女儿也挡掉）。如果还有漏网的：
1. 找一张被误判的里程碑照片里**不是女儿**的那张脸，去「排除人脸」里加进去
2. 点「重新应用过滤规则」让它生效
3. 单张精修：在照片详情页 → 「…」→ 「从时间线里移除」

**Q: 为什么某些里程碑没有出现在「建议记录」区？**
- 时间线里还没有触发词对应的照片（比如 "第一次见到雪" 得等你拍过一张 Vision 能认出 "雪" 的照片）
- 你已经手动记过同名的里程碑了，系统不再重复建议
- Vision 虽然拍到了但没把场景识别到对应标签（识别率取决于照片构图，不是每张都能命中）——可以自己手动新建，标题一样会走内容关键词匹配帮你挑照片
- 规则表里还没收录这条 —— 可以在 `BabyTimeline/Services/PhotoMilestoneSuggester.swift` 的 `rules` 里自己加

**Q: 生日照自动建的里程碑想删掉怎么办？**
里程碑 Tab → 左滑那一行 → 删除。跟手动建的里程碑没区别，绑定的照片也会随之解绑（但不会动系统相册里的原图）。

**Q: 把某张具体照片从时间线里移除？**
点开照片 → 右上角「…」菜单 → **从时间线里移除**。只会删 App 里的这条记录，系统相册的原图不会动；如果有里程碑绑在这张照片上，也会自动解绑（里程碑本身保留，显示成未绑定照片状态，可以之后再手动选一张）。

**Q: 为什么不把 `.xcodeproj` 提交到 Git？**
`.xcodeproj/project.pbxproj` 是一个不断变化的大文件，Git diff 基本没法读。`project.yml` 才几十行、人能看懂，改动一目了然。用 `./bootstrap.sh` 或 `xcodegen generate` 随时重新生成即可。

**Q: 拉了新代码后 Xcode 报 `Cannot find 'XXX' in scope`？**
99% 是因为新代码加了新的 `.swift` 文件，但你本地的 `BabyTimeline.xcodeproj` 还是旧的。**必须在项目根目录跑一次 `xcodegen generate`** 让 XcodeGen 把新文件加进 target sources，然后 Xcode 里 `⇧⌘K`（Clean Build Folder）再 `⌘R` 重新 build 就好了。这是 XcodeGen 流程的固定动作 —— 每次 `git pull` 之后、每次你自己增删 Swift 文件之后，都要跑一次。

---

## 给家人用（TestFlight 分发）

> **决定：走 TestFlight。** 既然只想给家人用（老婆、外公外婆、自己爸妈），
> 花 ¥700/年的 Apple Developer Program 换「TestFlight 链接一点就装、90 天有效、
> 自动更新、家人完全不用碰 Mac/数据线」是目前唯一值得的路径。下面先给最省事的步骤清单，
> 再把其他可选方案列在底下作为对照。

### TestFlight 一次性准备（30 分钟）

1. **注册 Apple Developer Program**
   - 打开 https://developer.apple.com/programs 用你现在的 Apple ID 登录
   - 个人账号（Individual），一年 99 USD（≈ ¥700）
   - 信用卡付款后 Apple 会审核身份，**一般几小时到一天**就通过

2. **改 Bundle Identifier**（必须全网唯一）
   - 打开 `project.yml`，找到：
     ```yaml
     PRODUCT_BUNDLE_IDENTIFIER: com.personal.babytimeline
     ```
   - 改成你自己的反向域名，例如 `com.yingying.babytimeline`
     （随便起，只要没人注册过 App Store Connect 会告诉你，换一个就行）
   - 终端里跑 `xcodegen generate` 重新生成 project

3. **在 App Store Connect 创建一个 App 记录**
   - 打开 https://appstoreconnect.apple.com → 我的 App → 左上角「+」→ 新建 App
   - 平台选 iOS、Bundle ID 选刚才改的那个、SKU 随便填（例如 `babytimeline-private`）
   - 主要语言选「简体中文」
   - 点创建 → 什么都不用填，直接关掉这一页。**这一步只是预占 Bundle ID，不是真要上架。**

4. **Xcode 里切到付费 Team**
   - `Xcode → Settings → Accounts`，确认你的 Apple ID 已经加入 Developer Program
   - 打开 `BabyTimeline.xcodeproj` → 顶部蓝色图标 → `BabyTimeline` target → Signing & Capabilities
   - **Team** 选你的付费账号（名字后面会有「Apple Development」）

5. **Archive 并上传**
   - Xcode 顶部设备选「Any iOS Device (arm64)」（**不要**选模拟器，否则 Archive 菜单是灰的）
   - 菜单 `Product → Archive` → 等 build 完会弹出 Organizer 窗口
   - 选中刚 archive 出的那个 build → `Distribute App` → `TestFlight & App Store` → `Upload`
   - 一路下一步，**Automatic signing** 就行，Xcode 自己处理证书
   - 上传成功后要在 App Store Connect 后台等 **5–15 分钟的处理时间**（会收邮件）

6. **在 App Store Connect 加测试员**
   - https://appstoreconnect.apple.com → 我的 App → 苹果长大了 → 左边 **TestFlight** Tab
   - **最快路径 = 内部测试**：右侧「内部群组」点「+」创建群组 → 加测试员 → 填家人邮箱
     （**前提是这些邮箱已经作为成员加到你的团队里了**，在 https://appstoreconnect.apple.com/access/users 加）
     - 限制：最多 100 人、要他们的 Apple ID 在你团队里
     - 好处：**审核免了**，上传完直接能装
   - **更省事 = 外部测试**：同页「外部群组」新建群组 → 填家人邮箱（无需进团队）
     - 限制：第一次提交这个 App 时 Apple 会做一次 5–24 小时的 Beta App Review（比正式 App Review 宽松很多），之后的 build 一般不再审
     - 好处：**只要邮箱**就行，家人用自己的 Apple ID 装就可以，最贴近「发个链接」的体验
     - 最多 10000 人

7. **家人的使用流程**
   - 家人收邮件 → 点邀请链接 → 提示装 TestFlight App（免费）→ 装完再点一次链接 → 一键安装「苹果长大了」
   - 90 天内有效，不用再碰 Mac/Xcode/数据线/证书这些词

### 后续每次更新

代码改完想让家人用到新版本：

1. 把 `project.yml` 里 `CFBundleVersion` 加 1（**每次上传必须递增**，`1 → 2 → 3 …`，版本号可以重复但 build 号不能）
2. `xcodegen generate`
3. Xcode 里 `Product → Archive → Distribute App → TestFlight`
4. 等处理完（5–15 分钟），家人的 TestFlight App 里会自动弹出更新提示

### TestFlight 要注意的细节

- **App Icon** 必须有 1024×1024 PNG、**无透明通道**。本仓库 `scripts/make-app-icon.py` 生成的已经符合要求
- **Privacy Manifest**：iOS 17+ 上传时 Apple 会要求声明隐私使用。我们用了相册 / 位置 / Vision：
  - Info.plist（由 `project.yml` 生成）已经写了 `NSPhotoLibraryUsageDescription` / `NSLocationWhenInUseUsageDescription`
  - App Store Connect 后台的「App 隐私」表里如实勾选：相册「读取」、位置「反查地名」
  - 无需第三方 SDK 所以 `PrivacyInfo.xcprivacy` 文件可以不加
- **不要上架 App Store**。App Store Connect 里那个 App 记录一直保持「准备提交」状态就行，
  TestFlight 的内部 / 外部测试群组是独立的流程，不需要你点「提交审核上架」

---

### 其他（不推荐的）分发方式

下面这些只是让你心里有底，**给家人用的话按上面 TestFlight 走就行，不用往下看**。

- **免费 Apple ID（现状）**：只能装到「跟你同一个 Apple ID 登录」的设备。
  你得拿过家人的 iPhone 用自己的 Mac build 一次，证书 7 天过期。**7 天后又得拿过来。** 不现实。
- **Ad Hoc（付费 Developer 但不走 TestFlight）**：收集家人每台 iPhone 的 UDID，
  手动加进 provisioning profile，build `.ipa`，用 Apple Configurator / Finder 推给对方。
  **2025 年没理由还选 Ad Hoc，TestFlight 完虐它。**
- **App Store 上架**：同样 $99/年账号，但需要过 App Review、写隐私政策、写商店描述、做截图。
  相册 + 位置权限会被 Review 要求详细解释。**只给家人用的话纯纯自找罪受。**
- **用别人的付费账号**：有朋友是 Apple 开发者能帮你上传 TestFlight。零成本，但得求人。

## 改 App 图标

```bash
python3 scripts/make-app-icon.py
```

当前图标：暖奶油色背景 + 红色真实苹果形状（双瓣果身 + 顶部凹陷 + 棕色果柄 + 嫩绿叶子 + 左上高光/右下暗面）。纯 PIL 几何绘制，不依赖任何位图素材。

会重新生成 `BabyTimeline/Assets.xcassets/AppIcon.appiconset/AppIcon.png`。想改颜色或大小直接编辑脚本顶部的颜色常量和 `apple_radius`；或者**直接把自己设计好的 1024×1024 PNG 命名成 `AppIcon.png` 放进同目录替换**，然后 `xcodegen generate` + Xcode 重新 build 就生效了。

唯一要求：
- 必须是 **1024×1024** 像素
- 必须是 **PNG**
- **不能有透明通道**（必须是纯 RGB，不能是 RGBA）

## 改 App 名字

在 `project.yml` 里改这一行：
```yaml
CFBundleDisplayName: 苹果长大了
```
然后 `xcodegen generate` 重新 build。`CFBundleDisplayName` 是桌面图标下面那行字，可以是任意 Unicode 字符（包括中文、emoji）。
