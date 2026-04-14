# 苹果长大了 · BabyTimeline

给女儿做的 iOS 私人成长时间线 App。

## 做什么

- **读取手机相册里生日之后的照片**，按年龄阶段自动分组，生成一条成长时间线
- **认人**（可选，推荐开启）：用 Vision 为女儿的一张参考照生成人脸指纹，之后扫描相册时**只保留含她本人的照片**
- **只纳入含人脸的照片**（即便没开认人，风景、截图、空镜也会被自动过滤）
- **自动识别画面内容**（`VNClassifyImageRequest`），生成中文标签：宝宝、食物、户外、生日蛋糕…… 不需要手动打字
- **自动读取拍摄时间 + GPS**，用 `CLGeocoder` 把坐标反查成「北京市朝阳区」这样的中文地名
- **成长里程碑**：手动记录「第一次走路 / 第一次喊妈妈」等关键时刻，可绑一张对应照片
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
    │   ├── FaceRecognitionService.swift    # 人脸检测 + 认人指纹
    │   ├── PhotoLibraryService.swift
    │   ├── MetadataExtractor.swift
    │   ├── GeocodingService.swift
    │   └── PhotoImporter.swift
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
   - 如果发现混进了别人（爸爸/妈妈/爷爷奶奶）→ 滑块调「严格」一点

## 三个 Tab

| Tab | 作用 |
| --- | --- |
| **时间线** | 按「新生儿 / 1–3 月 / 3–6 月 / 6–12 月 / 1–1.5 岁 / 1.5–2 岁 / 2–3 岁…」分组展示照片。点缩略图进详情页，可看大图、年龄、地点、自动标签，可写备注、加星收藏 |
| **里程碑** | 手动记录「第一次翻身 / 第一次走路 / 第一次叫妈妈」等关键事件，可绑定时间线里的一张照片 |
| **设置** | 修改宝宝资料、**设置认人照片 + 阈值**、重新扫描相册、清空记录 |

## 认人是怎么工作的

1. 你选一张女儿本人的正脸照 →
2. Vision `VNDetectFaceRectanglesRequest` 找最大的人脸 →
3. 在人脸区域外扩 20%（包括头发/下巴）上跑 `VNGenerateImageFeaturePrintRequest` →
4. 得到一个 `VNFeaturePrintObservation`，用 `NSKeyedArchiver` 归档后存进 `Baby.referenceFacePrintData`
5. 扫描候选照片时，对每张脸都算一个同样的指纹，用 `computeDistance` 和参考指纹比距离
6. 距离 ≤ 阈值 → 判定为「女儿本人」→ 纳入时间线

阈值默认 **18**，可以在设置里用滑块在 10–30 之间调。
越小越严格（更少漏别人，但可能漏掉一些自家娃），越大越宽松。

> 注意：`VNGenerateImageFeaturePrintRequest` 并不是专门的人脸识别模型，精度不如 FaceNet/ArcFace。
> 不过对同一个小朋友在相近时间段的照片，匹配效果通常够用，**而且不需要任何额外模型文件**。
> 小朋友脸型变化大的话，可以每过半年换一张更新的认人照。

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

**Q: 认人把爸爸妈妈的脸也混进来了？**
认人阈值太宽松。去设置 → 认人，把滑块往「严格」方向拖（比如调到 14–16），然后重新扫描。

**Q: 把某张具体照片从时间线里移除？**
目前没做「隐藏单张」。临时方案：设置 → 清空时间线记录 → 重新扫描。或者直接在系统相册里删掉原图。

**Q: 为什么不把 `.xcodeproj` 提交到 Git？**
`.xcodeproj/project.pbxproj` 是一个不断变化的大文件，Git diff 基本没法读。`project.yml` 才几十行、人能看懂，改动一目了然。用 `./bootstrap.sh` 或 `xcodegen generate` 随时重新生成即可。

---

## 给别人用（分发）

iOS App 没有 Android 那种"发个 apk 文件就行"的自由 —— 必须经过 Apple 的签名体系。能不能给别人用 / 怎么给，**完全取决于你愿不愿意花 $99/年开发者账号**。下面把所有路径列清楚：

### 选项 A：免费 Apple ID（你现在的状态）
**只能装到「跟你登录同一个 Apple ID 的设备」上。** 给别人用只有两个不太优雅的办法：
- 让对方在他自己的 Mac 上，用**你的 Apple ID** 登录 Xcode → 拿这份代码 → build 装到他自己的 iPhone。需要他有 Mac、有数据线、要折腾。
- 或者你拿过他的 iPhone，用你的 Mac + 你的 Apple ID build 一次装上去。证书 **7 天后过期**，过期后他这个 App 打不开 → 你得再拿过来 build 一次。
- ❌ 不支持远程发个链接就能装。

### 选项 B：$99/年 Apple Developer Program + TestFlight ⭐推荐
**这是给家人朋友用的最优解，没有之一。** 步骤：

1. 去 https://developer.apple.com/programs 注册个人账号，付 $99（≈¥700/年）
2. Xcode 里把项目的 Team 切到这个付费账号
3. `Product → Archive` → `Distribute App → TestFlight & App Store`
4. Xcode 自动上传到 App Store Connect
5. 在 https://appstoreconnect.apple.com 给这个 build 加测试员：
   - **内部测试**（最多 100 人，他们必须在你的 App Store Connect 团队里）
   - **外部测试**（最多 10000 人，**只要邮箱**就行，对方不需要 Apple ID 在你团队里）
6. 把 TestFlight 邀请链接发给老婆/外公外婆/任何想用的人
7. 对方手机上装一个免费的「TestFlight」App → 点你的链接 → 一键安装「苹果长大了」

好处：
- 对方完全不用碰 Mac、Xcode、数据线、UDID
- Build 在 TestFlight 上 **90 天有效**（不是 7 天）
- 你 push 新版本，对方 TestFlight 里点一下「更新」就好
- 比上 App Store 简单太多（不用过 App Review 的隐私评估）

成本：$99/年 + 一次性 30 分钟操作。

### 选项 C：$99 + Ad Hoc
跟 B 差不多但更原始：你收集每个用户的 iPhone **UDID**（设备唯一码），在开发者后台手动加进 provisioning profile，build 出 `.ipa`，发给对方让他用 Apple Configurator / Finder 装。**没有任何理由在 2025 年还选 Ad Hoc，TestFlight 完虐它。**

### 选项 D：上架 App Store
也是 $99/年同一个账号，但需要：
- 提交 App Review（首次审核 1–3 天，可能被拒要改）
- 写 App Store 描述、隐私政策、截图
- 这个 App 用了相册和位置，App Review 要求**详细解释为什么需要**

如果你只是想给认识的人用，**不要走这条路，纯纯给自己找罪受**。直接 TestFlight 就够。

### 选项 E：用别人的付费账号
如果你有朋友/同事已经是 Apple 开发者，可以请他帮你上传 TestFlight，把外部测试员加成你的家人邮箱。零成本，但你得求人。

### 我的推荐

| 受众 | 推荐 |
| --- | --- |
| 只你自己用 | **不花钱**，按现在的方式 7 天重 build 一次 |
| 给一两个家人（妈妈、老公） | **$99/年 + TestFlight**，一劳永逸 |
| 想给十几个家人朋友 | 同上，TestFlight |
| 真打算让陌生人下载 | 上 App Store，准备好被审核折腾 |

**对你这个使用场景（女儿成长记录 + 想分享给家人），结论是：买一年 Apple Developer Program，走 TestFlight。** 一年 ¥700 换全家无痛安装、无痛更新、build 90 天有效，完全值得。

### 如果走 TestFlight，代码这边需要改什么？

几乎不用改，但有几点要注意：
1. **Bundle Identifier 必须全网唯一**：现在 `com.personal.babytimeline` 是占位的，改成 `com.你的英文名.appletimeline` 之类的（在 `project.yml` 的 `PRODUCT_BUNDLE_IDENTIFIER` 里改）
2. **CFBundleVersion** 每次上传都要递增（1 → 2 → 3 …）。在 `project.yml` 的 `info.properties.CFBundleVersion` 里改
3. **App Icon** 必须有 1024×1024 PNG，**没透明通道**。本仓库已经用 `scripts/make-app-icon.py` 自动生成，TestFlight 不会拒
4. **Privacy Manifest**：iOS 17+ 上传 TestFlight 时 Apple 会要求声明隐私使用。我们用了 Photos / Location / Vision，对应在 App Store Connect 的「数据使用」表里如实勾选即可，App 自身的 Info.plist 已经写了 `NSPhotoLibraryUsageDescription` / `NSLocationWhenInUseUsageDescription`

## 改 App 图标

```bash
python3 scripts/make-app-icon.py
```

会重新生成 `BabyTimeline/Assets.xcassets/AppIcon.appiconset/AppIcon.png`。想改样式直接编辑那个脚本里的颜色、形状参数，或者你也可以**直接把自己设计好的 1024×1024 PNG 命名成 `AppIcon.png` 放进 `BabyTimeline/Assets.xcassets/AppIcon.appiconset/` 替换掉**，然后 `xcodegen generate` + Xcode 重新 build 就生效了。

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
