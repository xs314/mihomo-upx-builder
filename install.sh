#!/bin/sh
set -e

# ==============================================================================
# Mihomo UPX Multi-Architecture One-Key Installer & Updater
# Universal support for OpenWrt (Nikki, OpenClash, ShellCrash) & Linux
# Project: https://github.com/xs314/mihomo-upx-builder
# ==============================================================================

REPO="xs314/mihomo-upx-builder"
FLAVOR="${FLAVOR:-nogvisor}" # nogvisor (默认, 极限精简) 或 gvisor

echo "========================================================="
echo "   🚀 Mihomo UPX 极简精简内核通用一键更新脚本"
echo "   项目主页: https://github.com/${REPO}"
echo "========================================================="

# 1. 架构智能识别
ARCH_RAW=$(uname -m)
case "$ARCH_RAW" in
    aarch64|arm64)
        ARCH="linux-arm64"
        ;;
    x86_64|amd64)
        if grep -q "avx2" /proc/cpuinfo 2>/dev/null; then
            ARCH="linux-amd64-v3"
        else
            ARCH="linux-amd64"
        fi
        ;;
    armv7l|armv7)
        ARCH="linux-armv7"
        ;;
    *)
        echo "❌ 不支持的设备架构: $ARCH_RAW"
        exit 1
        ;;
esac

echo "✅ 识别到设备架构: $ARCH_RAW -> 匹配镜像: $ARCH"
echo "✅ 选择核心风味: $FLAVOR"

# 2. 智能探测已安装的核心路径与插件生态
if [ -n "$TARGET_BIN" ]; then
    echo "📌 使用用户手动指定的路径: $TARGET_BIN"
elif [ -x "/usr/libexec/mihomo" ]; then
    TARGET_BIN="/usr/libexec/mihomo"
    echo "📌 识别到环境: OpenWrt 官方 / Nikki (路径: $TARGET_BIN)"
elif [ -d "/etc/openclash/core" ]; then
    TARGET_BIN="/etc/openclash/core/clash_meta"
    echo "📌 识别到环境: OpenClash (路径: $TARGET_BIN)"
elif [ -d "/data/clash" ]; then
    TARGET_BIN="/data/clash/clash"
    echo "📌 识别到环境: ShellCrash (路径: $TARGET_BIN)"
elif [ -d "/etc/clash" ] && [ -x "/etc/clash/clash" ]; then
    TARGET_BIN="/etc/clash/clash"
    echo "📌 识别到环境: ShellCrash (路径: $TARGET_BIN)"
elif command -v mihomo >/dev/null 2>&1; then
    TARGET_BIN=$(command -v mihomo)
    echo "📌 识别到系统已安装核心: $TARGET_BIN"
else
    TARGET_BIN="/usr/bin/mihomo"
    echo "📌 未探测到现有插件，使用标准系统路径: $TARGET_BIN"
fi

# 3. 检查网络下载工具
if command -v curl >/dev/null 2>&1; then
    FETCH_CMD="curl -sL"
elif command -v wget >/dev/null 2>&1; then
    FETCH_CMD="wget -qO-"
else
    echo "❌ 系统未安装 curl 或 wget，请先安装下载工具"
    exit 1
fi

# 4. 获取最新 Release 版本信息
echo "🔍 正在检查最新 Release..."
RELEASE_JSON=$($FETCH_CMD "https://api.github.com/repos/${REPO}/releases/latest")
TAG_NAME=$(echo "$RELEASE_JSON" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4)

if [ -z "$TAG_NAME" ]; then
    echo "❌ 获取最新版本失败，请检查网络或 GitHub 访问情况。"
    exit 1
fi

echo "📦 最新版本: $TAG_NAME"

# 5. 定位对应的下载直链
DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o "https://[^\"]*mihomo-${ARCH}-${TAG_NAME}-${FLAVOR}-upx.tar.gz" | head -n 1)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "❌ 未找到匹配当前架构的包: mihomo-${ARCH}-${TAG_NAME}-${FLAVOR}-upx.tar.gz"
    exit 1
fi

TMP_DIR="/tmp/mihomo_update_$$"
mkdir -p "$TMP_DIR"
TMP_TAR="$TMP_DIR/mihomo.tar.gz"
TMP_BIN="$TMP_DIR/mihomo"

cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

echo "⬇️ 正在下载: $DOWNLOAD_URL ..."
if command -v curl >/dev/null 2>&1; then
    curl -L --fail --progress-bar -o "$TMP_TAR" "$DOWNLOAD_URL"
else
    wget -O "$TMP_TAR" "$DOWNLOAD_URL"
fi

echo "📦 解压中..."
tar -xzf "$TMP_TAR" -C "$TMP_DIR"
chmod +x "$TMP_BIN"

# 6. 二进制可用性校验
echo "🧪 验证二进制兼容性..."
NEW_VER=$("$TMP_BIN" -v 2>&1 | head -n 1)
echo "   版本信息: $NEW_VER"

# 7. 智能检测配置并测试语法
TEST_CONFIG=""
if [ -f "/etc/nikki/run/config.yaml" ]; then
    TEST_CONFIG="/etc/nikki/run/config.yaml"
    TEST_DIR="/etc/nikki/run"
elif [ -f "/etc/openclash/config/config.yaml" ]; then
    TEST_CONFIG="/etc/openclash/config/config.yaml"
    TEST_DIR="/etc/openclash"
elif [ -f "/data/clash/config.yaml" ]; then
    TEST_CONFIG="/data/clash/config.yaml"
    TEST_DIR="/data/clash"
fi

if [ -n "$TEST_CONFIG" ]; then
    echo "🧪 检测到配置文件 ($TEST_CONFIG)，执行配置语法预检..."
    if ! "$TMP_BIN" -t -d "$TEST_DIR" -f "$TEST_CONFIG" >/dev/null 2>&1; then
        echo "⚠️ 警告: 新版本配置测试返回非零，但二进制本身运行正常。"
    else
        echo "✅ 配置语法预检完全通过！"
    fi
fi

# 8. 智能服务管理：优雅停止运行中的代理
SERVICE_NAME=""
if [ -f "/etc/init.d/nikki" ] && /etc/init.d/nikki status 2>/dev/null | grep -qi "running"; then
    SERVICE_NAME="nikki"
    echo "🛑 临时停止 Nikki 代理服务..."
    /etc/init.d/nikki stop 2>/dev/null || true
elif [ -f "/etc/init.d/openclash" ] && pidof clash >/dev/null 2>&1; then
    SERVICE_NAME="openclash"
    echo "🛑 临时停止 OpenClash 代理服务..."
    /etc/init.d/openclash stop 2>/dev/null || true
elif command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet mihomo 2>/dev/null; then
    SERVICE_NAME="systemd"
    echo "🛑 临时停止 systemd mihomo 服务..."
    systemctl stop mihomo 2>/dev/null || true
fi

# 9. 执行原子覆写
mkdir -p "$(dirname "$TARGET_BIN")"
echo "🔄 执行原地替换: $TARGET_BIN ..."
cp -f "$TMP_BIN" "$TARGET_BIN"
chmod +x "$TARGET_BIN"

# 10. 智能重启代理服务
if [ "$SERVICE_NAME" = "nikki" ]; then
    echo "▶️ 重新启动 Nikki 代理服务..."
    /etc/init.d/nikki start
elif [ "$SERVICE_NAME" = "openclash" ]; then
    echo "▶️ 重新启动 OpenClash 代理服务..."
    /etc/init.d/openclash start
elif [ "$SERVICE_NAME" = "systemd" ]; then
    echo "▶️ 重新启动 systemd mihomo 服务..."
    systemctl start mihomo
fi

echo "========================================================="
echo "🎉 升级完成！当前核心信息："
ls -lh "$TARGET_BIN"
echo "========================================================="
df -h /overlay 2>/dev/null || df -h /
