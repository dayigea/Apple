# BabyTimeline · 宝贝时光

给女儿做的 iOS 私人成长时间线 App。

## 做什么

- **读取手机相册里生日之后的照片**，按年龄阶段自动分组，生成一条成长时间线
- **只纳入含人脸的照片**（用 Vision 框架做人脸检测过滤），自动把风景、截图、别人的照片挡在外面
- **自动识别画面内容**（`VNClassifyImageRequest`），生成中文标签：宝宝、食物、户外、生日蛋糕…… 不需要手动打字
- **自动读取拍摄时间 + GPS**，用 `CLGeocoder` 把坐标反查成「北京市朝阳区」这样的中文地名
- **成长里程碑**：手动记录「第一次走路 / 第一次喊妈妈」等关键时刻，可绑一张对应照片
- **完全本地、完全私人**：所有数据都在 App 沙盒里，照片本体始终留在系统相册，**不上传任何服务器**

## 技术栈

- SwiftUI + Swift 5.9
- SwiftData（本地持久化）
- Photos / PhotosUI（相册访问）
- Vision（人脸检测 + 场景分类）
- CoreLocation（GPS 反地理编码）
- 最低 iOS 17.0

## 目录结构

```
Apple/
├── project.yml                 # XcodeGen 配置
├── README.md
└── BabyTimeline/
    ├── BabyTimelineApp.swift   # @main
    ├── RootView.swift
    ├── Info.plist
    ├── Assets.xcassets/
    ├── Models/
    │   ├── Baby.swift
    │   ├── PhotoEntry.swift
    │   └── Milestone.swift
    ├── Services/
    │   ├── AgeCalculator.swift
    │   ├── ImageAnalysisService.swift
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

## 如何跑起来

整个项目用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 描述，不把 `.xcodeproj` 提交到 Git，这样 diff 更干净。

### 1. 安装 XcodeGen（只需一次）

```bash
brew install xcodegen
```

### 2. 生成 Xcode 项目

在项目根目录（包含 `project.yml` 的目录）执行：

```bash
xcodegen generate
```

会生成一个 `BabyTimeline.xcodeproj`。

### 3. 用 Xcode 打开

```bash
open BabyTimeline.xcodeproj
```

### 4. 签名

- 打开 Xcode → 选中 `BabyTimeline` target → **Signing & Capabilities**
- Team 选自己的 Apple ID（免费账号也能真机运行，证书有效期 7 天，到期重新 build 即可）

### 5. 真机运行

- 用数据线连上自己的 iPhone
- 顶部设备栏选自己的 iPhone
- Cmd + R

## 第一次使用

1. 打开 App → 欢迎页
2. 填写 **姓名 / 生日 / 性别 / （可选）头像**
3. 系统弹窗请求相册权限 → 允许
4. App 开始扫描相册，对每张生日之后的照片做 Vision 分析：
   - 没有人脸的照片直接跳过
   - 有人脸的照片写入本地数据库，并带上中文场景标签
5. 扫描完成后进入 **时间线** Tab，按年龄阶段看照片

## 三个 Tab

| Tab | 作用 |
| --- | --- |
| **时间线** | 按「新生儿 / 1–3 月 / 3–6 月 / 6–12 月 / 1–1.5 岁 / 1.5–2 岁 / 2–3 岁…」分组展示含人脸的照片。点缩略图进详情页，可看大图、年龄、地点、自动标签，可写备注、加星收藏 |
| **里程碑** | 手动记录「第一次翻身 / 第一次走路 / 第一次叫妈妈」等关键事件，可绑定时间线里的一张照片 |
| **设置** | 修改宝宝资料、重新扫描相册、清空记录 |

## 隐私

- **所有数据都在本地**，SwiftData 的 sqlite 存在 App 沙盒里
- **照片本体从不复制**，App 只存系统相册里每张照片的 `PHAsset.localIdentifier` 引用
- **没有任何网络请求**，除了 `CLGeocoder` 反查地名时系统会联网
- **不会修改你的相册**，只读

## 不做 / 后续可加

第一版刻意不做的事：

- ❌ 云同步 / 多设备
- ❌ 账号登录
- ❌ 多宝宝
- ❌ 视频支持
- ❌ 社交分享
- ❌ App Store 上架
- ❌ 人脸识别（当前只做人脸**检测**，不区分是不是女儿本人；如果需要可以后续加一张参考头像做 `VNGenerateFaceFeaturePrint` 匹配）

## 常见问题

**Q: 扫描速度太慢？**
每张照片要走一次 Vision 人脸检测 + 场景分类，几千张照片大概要几分钟，后台跑就好。只会在第一次跑全量，以后都是增量（按 `PHAsset.localIdentifier` 去重）。

**Q: 有些生日之后的照片没出现在时间线？**
两种情况：
1. 照片里没检测到人脸（Vision 认为没有）
2. 照片是拍摄时间被改过的（`creationDate` 早于生日）

可以去设置页「重新扫描相册」再试一次。

**Q: 想把某张照片从时间线里删掉？**
目前没做「隐藏单张」，但「设置 → 清空时间线记录」之后重新扫描相当于重置。也可以直接在系统相册里删掉那张原图再重新扫描。

**Q: 为什么要用 XcodeGen 而不是直接把 `.xcodeproj` 提交？**
`.xcodeproj/project.pbxproj` 是一个不断变化的大文件，Git diff 非常难读。`project.yml` 才几十行、人能读懂，改动一目了然。
