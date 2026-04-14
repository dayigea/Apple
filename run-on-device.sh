#!/usr/bin/env bash
#
# run-on-device.sh — 从命令行把 BabyTimeline 构建并安装到你连接的 iPhone
#
# 一次性前置条件（只做一次）：
#   1. 已经装了 Xcode（这个脚本不会帮你装）
#   2. 打开 Xcode 一次 → Xcode 菜单 → Settings → Accounts
#      → 点左下角 + → Apple ID → 用你自己的 Apple ID 登录
#      （这一步没法用命令行替代，Apple ID 登录会触发双因素认证）
#   3. 登录后看到你的 Personal Team 就可以关掉 Xcode
#   4. iPhone 用数据线连上，点「信任这台电脑」
#   5. iPhone 上打开开发者模式：
#      设置 → 隐私与安全性 → 开发者模式 → 开（会重启 iPhone）
#
# 然后每次想装新版本，就跑这个脚本：
#   ./run-on-device.sh
#
# 它会：
#   - 自动发现你的 Team ID
#   - 自动发现连接的 iPhone
#   - xcodegen 生成项目
#   - xcodebuild 构建
#   - xcrun devicectl 安装到 iPhone
#
# 装完之后第一次打开会提示「不受信任的开发者」，去：
#   设置 → 通用 → VPN 与设备管理 → 选你自己的 Apple ID → 信任
# 然后回到主屏点图标就能跑了。

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

# ─────────────────────────────────────────────────────────
# 0. 平台检查
# ─────────────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || fail "这个脚本只能在 Mac 上跑。"

# ─────────────────────────────────────────────────────────
# 1. Xcode 检查
# ─────────────────────────────────────────────────────────
xcode-select -p >/dev/null 2>&1 || fail "没找到 Xcode。请先装 Xcode。"
ok "Xcode: $(xcodebuild -version | head -1)"

# ─────────────────────────────────────────────────────────
# 2. XcodeGen 检查
# ─────────────────────────────────────────────────────────
if ! command -v xcodegen >/dev/null 2>&1; then
    info "没装 XcodeGen，尝试用 brew 安装…"
    if ! command -v brew >/dev/null 2>&1; then
        fail "没装 Homebrew。先装 Homebrew 或手动装 XcodeGen：https://github.com/yonaskolb/XcodeGen"
    fi
    brew install xcodegen
fi
ok "XcodeGen: $(xcodegen --version 2>&1 | head -1)"

# ─────────────────────────────────────────────────────────
# 3. 发现 Team ID（前提：Xcode Settings → Accounts 加过 Apple ID）
# ─────────────────────────────────────────────────────────
info "从钥匙串发现 Apple Development 签名身份…"
IDENTITIES=$(security find-identity -v -p codesigning 2>/dev/null || true)

if [[ -z "$IDENTITIES" ]] || ! grep -q "Apple Development" <<< "$IDENTITIES"; then
    cat <<EOF

${RED}❌ 没找到 Apple Development 签名身份${RESET}

你需要先做这件事（只做一次）：

  1. 打开 Xcode：  open /Applications/Xcode.app
  2. 菜单 Xcode → Settings…  → 选 Accounts 标签
  3. 左下角 + → Apple ID → 用你自己的 Apple ID 登录
  4. 登录后左边会出现你的名字，右边能看到 "Personal Team"
  5. 关掉 Xcode
  6. 再跑这个脚本

如果你已经加过 Apple ID 但这里还是找不到：
  - 在 Xcode Accounts 页面选中你的 Apple ID
  - 点右下角 "Manage Certificates..."
  - 点左下角 + → "Apple Development"
  - 创建一张新证书，就会写进钥匙串
EOF
    exit 1
fi

# 从 "Apple Development: name (TEAMID)" 里抓 10 位 Team ID
TEAM_ID=$(grep "Apple Development" <<< "$IDENTITIES" \
    | head -1 \
    | sed -E 's/.*\(([A-Z0-9]{10})\).*/\1/')

if [[ -z "$TEAM_ID" || "${#TEAM_ID}" -ne 10 ]]; then
    warn "无法从签名身份里解析出 Team ID："
    grep "Apple Development" <<< "$IDENTITIES"
    fail "请手动编辑 project.yml，把 DEVELOPMENT_TEAM 填上 10 位 Team ID。"
fi
ok "Team ID: $TEAM_ID"

# ─────────────────────────────────────────────────────────
# 4. 找连接的 iPhone
# ─────────────────────────────────────────────────────────
info "扫描连接的 iPhone…"
# xcrun devicectl 列设备 (Xcode 15+)
DEVICES_JSON=$(mktemp)
trap 'rm -f "$DEVICES_JSON"' EXIT

if xcrun devicectl list devices --json-output "$DEVICES_JSON" >/dev/null 2>&1; then
    DEVICE_UDID=$(/usr/bin/python3 -c "
import json, sys
with open('$DEVICES_JSON') as f:
    data = json.load(f)
for d in data.get('result', {}).get('devices', []):
    props = d.get('deviceProperties', {})
    conn = d.get('connectionProperties', {})
    if props.get('osVersionNumber', '').startswith(('17', '18', '19', '26')) \
       and 'iPhone' in props.get('name', '') \
       and conn.get('tunnelState') in ('connected', 'unavailable'):
        print(d.get('identifier', ''))
        sys.exit(0)
" 2>/dev/null || true)
fi

# 如果 devicectl 没给出结果，退回用 xctrace
if [[ -z "${DEVICE_UDID:-}" ]]; then
    DEVICE_UDID=$(xcrun xctrace list devices 2>&1 \
        | grep -iE "iphone" \
        | grep -v -i "simulator" \
        | head -1 \
        | sed -E 's/.*\(([A-F0-9-]+)\)[[:space:]]*$/\1/')
fi

if [[ -z "${DEVICE_UDID:-}" ]]; then
    cat <<EOF

${RED}❌ 没检测到连接的 iPhone${RESET}

检查清单：
  1. 数据线接牢
  2. iPhone 上点过「信任这台电脑」
  3. iOS 16 及以上开过开发者模式：
       设置 → 隐私与安全性 → 开发者模式 → 开
  4. iPhone 不在锁屏状态

试一下：
  xcrun devicectl list devices
  xcrun xctrace list devices
EOF
    exit 1
fi
ok "发现 iPhone: $DEVICE_UDID"

# ─────────────────────────────────────────────────────────
# 5. 生成 Xcode 项目
# ─────────────────────────────────────────────────────────
info "xcodegen generate…"
xcodegen generate

[[ -d BabyTimeline.xcodeproj ]] || fail "项目生成失败"
ok "BabyTimeline.xcodeproj 已生成"

# ─────────────────────────────────────────────────────────
# 6. xcodebuild 构建
# ─────────────────────────────────────────────────────────
info "xcodebuild 构建 (destination=$DEVICE_UDID)…"
echo "这一步可能要几分钟，第一次尤其慢（SwiftData/Vision 要索引）。"

BUILD_LOG=$(mktemp)
trap 'rm -f "$DEVICES_JSON" "$BUILD_LOG"' EXIT

set +e
xcodebuild \
    -project BabyTimeline.xcodeproj \
    -scheme BabyTimeline \
    -configuration Debug \
    -destination "generic/platform=iOS" \
    -derivedDataPath build \
    -allowProvisioningUpdates \
    DEVELOPMENT_TEAM="$TEAM_ID" \
    CODE_SIGN_STYLE=Automatic \
    build 2>&1 | tee "$BUILD_LOG"
BUILD_STATUS=${PIPESTATUS[0]}
set -e

if [[ $BUILD_STATUS -ne 0 ]]; then
    echo
    fail "xcodebuild 失败。把上面的报错拷给 Claude，我帮你修。"
fi
ok "构建成功"

# ─────────────────────────────────────────────────────────
# 7. 找出 .app 产物
# ─────────────────────────────────────────────────────────
APP_PATH=$(find build -name "BabyTimeline.app" -path "*iphoneos*" | head -1)
[[ -n "$APP_PATH" && -d "$APP_PATH" ]] || fail "找不到 BabyTimeline.app 产物"
ok "产物: $APP_PATH"

# ─────────────────────────────────────────────────────────
# 8. 安装到设备
# ─────────────────────────────────────────────────────────
info "安装到 iPhone…"
if xcrun devicectl device install app --device "$DEVICE_UDID" "$APP_PATH"; then
    ok "安装完成"
else
    warn "devicectl 安装失败，试试旧的 ios-deploy…"
    if command -v ios-deploy >/dev/null 2>&1; then
        ios-deploy --id "$DEVICE_UDID" --bundle "$APP_PATH"
    else
        fail "请手动在 Xcode 里 Cmd+R 一次，或 brew install ios-deploy"
    fi
fi

cat <<EOF

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${GREEN}✅ 全部完成！${RESET}

去 iPhone 主屏找「苹果长大了」这个 App。

第一次打开可能提示「不受信任的开发者」：
  设置 → 通用 → VPN 与设备管理 → 选你自己的 Apple ID → 信任
然后回主屏再点图标就能跑。

以后想更新代码：
  git pull
  ./run-on-device.sh
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
