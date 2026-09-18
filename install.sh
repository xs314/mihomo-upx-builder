#!/bin/sh
set -e

# ==============================================================================
# Mihomo UPX Multi-Architecture One-Key Installer & Updater for OpenWrt
# Project: https://github.com/xs314/mihomo-upx-builder
# ==============================================================================

REPO="xs314/mihomo-upx-builder"
TARGET_BIN="${TARGET_BIN:-/usr/libexec/mihomo}"
FLAVOR="${FLAVOR:-nogvisor}" # nogvisor (默认, 极限精简) 或 gvisor

echo "========================================================="
echo "   🚀 Mihomo UPX 极简精简内核一键热更新脚本"
echo "   项目地址: https://github.com/${REPO}"
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

# 2. 检查网络下载工具
if command -v curl >/dev/null 2>&1; then
    FETCH_CMD="curl -sL"
elif command -v wget >/dev/null 2>&1; then
    FETCH_CMD="wget -qO-"
else
    echo "❌ 系统未安装 curl 或 wget，请先执行 apk add curl 或 opkg install curl"
    exit 1
fi

# 3. 获取最新版本信息
echo "🔍 正在检查最新 Release..."
RELEASE_JSON=$($FETCH_CMD "https://api.github.com/repos/${REPO}/releases/latest")
TAG_NAME=$(echo "$RELEASE_JSON" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4)

if [ -z "$TAG_NAME" ]; then
    echo "❌ 获取最新版本失败，请检查网络或 GitHub 访问情况。"
    exit 1
fi

echo "📦 最新版本: $TAG_NAME"

# 4. 定位对应的下载直链
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

# 5. 测试新二进制兼容性
echo "🧪 验证二进制可用性..."
NEW_VER=$("$TMP_BIN" -v 2>&1 | head -n 1)
echo "   版本信息: $NEW_VER"

if [ -f "/etc/nikki/run/config.yaml" ]; then
    echo "🧪 测试配置语法兼容性..."
    if ! "$TMP_BIN" -t -d /etc/nikki/run -f /etc/nikki/run/config.yaml >/dev/null 2>&1; then
        echo "⚠️ 警告: 新版本配置测试返回非零，请检查配置兼容性。"
    else
        echo "✅ 配置语法测试通过！"
    fi
fi

# 6. 安全热替换
echo "🔄 执行原地热替换: $TARGET_BIN ..."
if [ -f "/etc/init.d/nikki" ]; then
    echo "🛑 临时停止 Nikki 代理服务..."
    /etc/init.d/nikki stop 2>/dev/null || true
fi

cp -f "$TMP_BIN" "$TARGET_BIN"
chmod +x "$TARGET_BIN"

if [ -f "/etc/init.d/nikki" ]; then
    echo "▶️ 重新启动 Nikki 代理服务..."
    /etc/init.d/nikki start
fi

echo "========================================================="
echo "🎉 升级完成！当前核心信息："
ls -lh "$TARGET_BIN"
echo "========================================================="
df -h /overlay 2>/dev/null || df -h /
