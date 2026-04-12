#!/usr/bin/env bash
#
# BabyTimeline 一键准备脚本（只在 macOS 上运行）
# 作用：检查环境 → 装 XcodeGen（如果没装）→ 生成 BabyTimeline.xcodeproj → 打开 Xcode
#
# 用法：在 Mac 终端进入本项目目录，执行
#     ./bootstrap.sh
#

set -euo pipefail

BOLD=$'\033[1m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
RESET=$'\033[0m'

info()  { printf "${BOLD}▶ %s${RESET}\n" "$*"; }
ok()    { printf "${GREEN}✅ %s${RESET}\n" "$*"; }
warn()  { printf "${YELLOW}⚠️  %s${RESET}\n" "$*"; }
fail()  { printf "${RED}❌ %s${RESET}\n" "$*" >&2; exit 1; }

# 1. 必须是 macOS
if [[ "$(uname -s)" != "Darwin" ]]; then
    fail "这个 App 是 iOS 原生项目，必须在 Mac 上用 Xcode 构建。"
fi

# 2. 必须有 Xcode
if ! xcode-select -p >/dev/null 2>&1; then
    fail "没检测到 Xcode。请先到 App Store 免费下载 Xcode，打开一次完成初始化，再跑这个脚本。"
fi
ok "Xcode: $(xcode-select -p)"

# 3. 必须有 Homebrew（用来装 XcodeGen）
if ! command -v brew >/dev/null 2>&1; then
    warn "没装 Homebrew。请先安装 Homebrew："
    echo "    /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    echo "装完后再跑本脚本。"
    exit 1
fi
ok "Homebrew: $(brew --version | head -1)"

# 4. XcodeGen
if ! command -v xcodegen >/dev/null 2>&1; then
    info "正在安装 XcodeGen…"
    brew install xcodegen
fi
ok "XcodeGen: $(xcodegen --version)"

# 5. 生成项目
info "根据 project.yml 生成 BabyTimeline.xcodeproj …"
xcodegen generate

if [[ ! -d "BabyTimeline.xcodeproj" ]]; then
    fail "生成失败，检查上面的 XcodeGen 报错。"
fi
ok "项目已生成"

# 6. 打开 Xcode
info "用 Xcode 打开项目…"
open BabyTimeline.xcodeproj

cat <<'EOF'

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
下一步在 Xcode 里要做的（只做一次）：

  1. 左侧蓝色项目图标 → BabyTimeline target → 顶部 Signing & Capabilities
  2. Team 下拉里选你自己的 Apple ID（免费账号也行）
  3. Bundle Identifier 如果提示冲突，改成：
        com.yourname.babytimeline
     （把 yourname 换成你自己随便起的名，不必真能对外访问）
  4. 用数据线把 iPhone 连到 Mac
  5. iPhone 上可能要「信任这台电脑」
  6. Xcode 顶部设备栏把模拟器换成你的 iPhone
  7. 按 Cmd + R 构建并安装到 iPhone
  8. 首次运行时 iPhone 上要去：
        设置 → 通用 → VPN 与设备管理 → 选你自己的 Apple ID → 信任
     然后回到 App 点图标再打开一次

进入 App 之后：
  - 填姓名、生日 → 开始记录
  - 相册权限弹窗 → 允许
  - App 自动扫描（几千张照片可能要几分钟）
  - 进「设置 → 认人」选一张女儿的正脸照（推荐）
  - 回到「设置」点「重新扫描相册」→ 只保留女儿本人的照片
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
