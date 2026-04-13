#!/usr/bin/env bash
#
# cleanup-xcode.sh — 精简 Xcode 占用磁盘的清理脚本
#
# 干什么：
#   - 打印各个 Xcode 相关目录的占用
#   - 删除所有 iOS 模拟器 runtime（真机开发用不到）
#   - 删除所有已创建但未用的模拟器设备
#   - 删除 DerivedData 编译缓存
#   - 删除历史 Archives 和 iOS DeviceSupport 旧版本
#
# 安全性：所有删除前都会打印它要干什么，可以 Ctrl+C 中止
#
# 用法：
#   ./cleanup-xcode.sh            # 只打印占用报告
#   ./cleanup-xcode.sh --clean    # 真正执行清理
#

set -euo pipefail

BOLD=$'\033[1m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
RED=$'\033[0;31m'
RESET=$'\033[0m'

DRY_RUN=1
if [[ "${1:-}" == "--clean" ]]; then
    DRY_RUN=0
fi

info()  { printf "${BOLD}▶ %s${RESET}\n" "$*"; }
ok()    { printf "${GREEN}✅ %s${RESET}\n" "$*"; }
warn()  { printf "${YELLOW}⚠️  %s${RESET}\n" "$*"; }

du_or_zero() {
    if [[ -e "$1" ]]; then
        du -sh "$1" 2>/dev/null | awk '{print $1}'
    else
        echo "(无)"
    fi
}

# 1. 磁盘总览
info "磁盘使用情况"
df -h / | tail -1 | awk '{printf "  磁盘：%s / %s 已用，%s 可用\n", $3, $2, $4}'
echo

# 2. 各个关键目录
info "Xcode 相关目录占用"
printf "  %-50s %s\n" "/Applications/Xcode.app"                         "$(du_or_zero /Applications/Xcode.app)"
printf "  %-50s %s\n" "~/Library/Developer/CoreSimulator/Devices"        "$(du_or_zero "$HOME/Library/Developer/CoreSimulator/Devices")"
printf "  %-50s %s\n" "~/Library/Developer/CoreSimulator/Caches"         "$(du_or_zero "$HOME/Library/Developer/CoreSimulator/Caches")"
printf "  %-50s %s\n" "~/Library/Developer/Xcode/DerivedData"            "$(du_or_zero "$HOME/Library/Developer/Xcode/DerivedData")"
printf "  %-50s %s\n" "~/Library/Developer/Xcode/iOS DeviceSupport"     "$(du_or_zero "$HOME/Library/Developer/Xcode/iOS DeviceSupport")"
printf "  %-50s %s\n" "~/Library/Developer/Xcode/Archives"               "$(du_or_zero "$HOME/Library/Developer/Xcode/Archives")"
printf "  %-50s %s\n" "~/Library/Caches/com.apple.dt.Xcode"              "$(du_or_zero "$HOME/Library/Caches/com.apple.dt.Xcode")"
# Xcode 15+ 的模拟器 runtime 新位置
printf "  %-50s %s\n" "/Library/Developer/CoreSimulator/Volumes"         "$(du_or_zero /Library/Developer/CoreSimulator/Volumes)"
echo

if [[ $DRY_RUN -eq 1 ]]; then
    warn "当前是预览模式，没有删除任何东西。"
    warn "要真正执行清理，再跑一次：./cleanup-xcode.sh --clean"
    exit 0
fi

# 3. 真正的清理
info "开始清理…"

# 3.1 删除所有模拟器 runtime（Xcode 15+ 的命令）
if command -v xcrun >/dev/null 2>&1; then
    info "删除所有 iOS 模拟器 runtime"
    # 列出再删
    xcrun simctl runtime list 2>/dev/null | awk '/iOS/ {print $NF}' | while read -r id; do
        [[ -n "$id" ]] && xcrun simctl runtime delete "$id" 2>/dev/null || true
    done
    ok "runtime 清理完成"

    info "删除所有模拟器设备"
    xcrun simctl delete all 2>/dev/null || true
    ok "设备清理完成"
fi

# 3.2 清 DerivedData
if [[ -d "$HOME/Library/Developer/Xcode/DerivedData" ]]; then
    info "清空 DerivedData"
    rm -rf "$HOME/Library/Developer/Xcode/DerivedData"/*
    ok "DerivedData 已清"
fi

# 3.3 清 Archives（历史归档，一般没用了）
if [[ -d "$HOME/Library/Developer/Xcode/Archives" ]]; then
    info "清空 Archives"
    rm -rf "$HOME/Library/Developer/Xcode/Archives"/*
    ok "Archives 已清"
fi

# 3.4 清 Xcode 缓存
if [[ -d "$HOME/Library/Caches/com.apple.dt.Xcode" ]]; then
    info "清空 Xcode 缓存"
    rm -rf "$HOME/Library/Caches/com.apple.dt.Xcode"/*
    ok "Xcode 缓存已清"
fi

# 3.5 清 CoreSimulator 缓存
if [[ -d "$HOME/Library/Developer/CoreSimulator/Caches" ]]; then
    info "清空 CoreSimulator 缓存"
    rm -rf "$HOME/Library/Developer/CoreSimulator/Caches"/*
    ok "CoreSimulator 缓存已清"
fi

# 3.6 iOS DeviceSupport 比较敏感，不自动删。告诉用户自己决定。
if [[ -d "$HOME/Library/Developer/Xcode/iOS DeviceSupport" ]]; then
    echo
    warn "iOS DeviceSupport 里是调试真机用的符号表，每个 iOS 版本一份。"
    warn "只保留你 iPhone 当前 iOS 版本的那一份即可（比如 17.5 / 18.0）。"
    warn "删除命令示例："
    echo "    ls ~/Library/Developer/Xcode/iOS\\ DeviceSupport/"
    echo "    rm -rf ~/Library/Developer/Xcode/iOS\\ DeviceSupport/16.*"
fi

echo
info "清理后的占用"
df -h / | tail -1 | awk '{printf "  磁盘：%s / %s 已用，%s 可用\n", $3, $2, $4}'
echo
ok "清理完成"
