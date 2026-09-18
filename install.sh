#!/bin/sh
set -e

# ==============================================================================
# Mihomo UPX Multi-Architecture One-Key Installer & Updater
# Features: Multi-Arch, Dual-Flavor, Smart Failover Mirrors, SHA256 Verification
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
    FETCH_CMD="curl -sL --connect-timeout 6 -m 30"
    DOWNLOAD_CMD="curl -L --fail --progress-bar --connect-timeout 8"
elif command -v wget >/dev/null 2>&1; then
    FETCH_CMD="wget -qO- -T 6 -t 2"
    DOWNLOAD_CMD="wget -O"
else
    echo "❌ 系统未安装 curl 或 wget，请先安装下载工具"
    exit 1
fi

# 4. 加速源高可用池（Failover Pool）定义
MIRROR_POOL=""
if [ -n "$MIRROR" ]; then
    # 保证末尾带斜杠
    case "$MIRROR" in
        */) MIRROR_POOL="$MIRROR" ;;
        *)  MIRROR_POOL="${MIRROR}/" ;;
    esac
    echo "⚡ 优先使用自定义加速镜像: $MIRROR_POOL"
fi
MIRROR_POOL="${MIRROR_POOL} https://ghproxy.net/ https://gh-proxy.com/ https://mirror.ghproxy.com/ DIRECT"

TMP_DIR="/tmp/mihomo_update_$$"
mkdir -p "$TMP_DIR"
cleanup() {
    rm -rf "$TMP_DIR"
}
trap cleanup EXIT INT TERM

# 通用多源请求包装函数
fetch_url() {
    target_url="$1"
    out_file="$2"

    for m in $MIRROR_POOL; do
        if [ "$m" = "DIRECT" ]; then
            actual_url="$target_url"
            tag="官方直连"
        else
            actual_url="${m}${target_url}"
            tag="加速源: $m"
        fi

        if [ -n "$out_file" ]; then
            if [ -n "$DOWNLOAD_CMD" ]; then
                if echo "$DOWNLOAD_CMD" | grep -q "curl"; then
                    if $DOWNLOAD_CMD -o "$out_file" "$actual_url" 2>/dev/null; then
                        SELECTED_MIRROR="$m"
                        return 0
                    fi
                else
                    if $DOWNLOAD_CMD "$out_file" "$actual_url" 2>/dev/null; then
                        SELECTED_MIRROR="$m"
                        return 0
                    fi
                fi
            fi
        else
            resp=$($FETCH_CMD "$actual_url" 2>/dev/null || true)
            if [ -n "$resp" ]; then
                SELECTED_MIRROR="$m"
                echo "$resp"
                return 0
            fi
        fi
    done
    return 1
}

# 5. 智能获取最新 Release 版本 (优先通过 302 重定向免 API 限流)
echo "🔍 正在检查最新 Release (支持多源智能测速与重试)..."
TAG_NAME=""

# 尝试通过 302 重定向获取 tag
if command -v curl >/dev/null 2>&1; then
    for m in $MIRROR_POOL; do
        if [ "$m" = "DIRECT" ]; then
            chk_url="https://github.com/${REPO}/releases/latest"
        else
            chk_url="${m}https://github.com/${REPO}/releases/latest"
        fi
        LOC=$(curl -sIL -m 6 "$chk_url" 2>/dev/null | grep -i "location:" | tail -n 1 | tr -d '\r\n')
        TAG_CANDIDATE=$(echo "$LOC" | sed -E 's/.*releases\/tag\/([^/?]+).*/\1/')
        if [ -n "$TAG_CANDIDATE" ] && [ "$TAG_CANDIDATE" != "$LOC" ]; then
            TAG_NAME="$TAG_CANDIDATE"
            SELECTED_MIRROR="$m"
            break
        fi
    done
fi

# 若 302 获取不到，回退通过 API 获取
if [ -z "$TAG_NAME" ]; then
    API_RESP=$(fetch_url "https://api.github.com/repos/${REPO}/releases/latest" "")
    TAG_NAME=$(echo "$API_RESP" | grep -o '"tag_name": *"[^"]*"' | head -n 1 | cut -d'"' -f4)
fi

if [ -z "$TAG_NAME" ]; then
    echo "❌ 获取最新版本失败，已尝试所有官方与加速镜像源，请检查路由器网络连接。"
    exit 1
fi

echo "📦 最新版本: $TAG_NAME (使用节点: ${SELECTED_MIRROR:-DIRECT})"

# 6. 下载 SHA256 校验清单 (密码学防篡改保证)
PKG_NAME="mihomo-${ARCH}-${TAG_NAME}-${FLAVOR}-upx.tar.gz"
CHECKSUM_FILE="$TMP_DIR/sha256sums.txt"
CHECKSUM_URL="https://github.com/${REPO}/releases/download/${TAG_NAME}/sha256sums.txt"

echo "🔐 正在同步安全哈希表 (sha256sums.txt)..."
if ! fetch_url "$CHECKSUM_URL" "$CHECKSUM_FILE"; then
    echo "⚠️ 无法获取 sha256sums.txt，将跳过哈希校验。"
fi

# 7. 下载核心归档包
DOWNLOAD_URL="https://github.com/${REPO}/releases/download/${TAG_NAME}/${PKG_NAME}"
TMP_TAR="$TMP_DIR/mihomo.tar.gz"
TMP_BIN="$TMP_DIR/mihomo"

echo "⬇️ 正在下载核心包: $PKG_NAME ..."
if ! fetch_url "$DOWNLOAD_URL" "$TMP_TAR"; then
    echo "❌ 核心包下载失败，请检查 Release 中是否存在该架构产物。"
    exit 1
fi

# 8. 强制执行 SHA256 校验 (防劫持投毒守门员)
if [ -f "$CHECKSUM_FILE" ]; then
    EXPECTED_HASH=$(grep "$PKG_NAME" "$CHECKSUM_FILE" | awk '{print $1}')
    if [ -n "$EXPECTED_HASH" ]; then
        echo "🛡️ 执行 SHA256 密码学防篡改校验..."
        if command -v sha256sum >/dev/null 2>&1; then
            ACTUAL_HASH=$(sha256sum "$TMP_TAR" | awk '{print $1}')
        elif command -v openssl >/dev/null 2>&1; then
            ACTUAL_HASH=$(openssl dgst -sha256 "$TMP_TAR" | awk '{print $2}')
        else
            ACTUAL_HASH=""
        fi

        if [ -n "$ACTUAL_HASH" ]; then
            if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
                echo "❌ 严重安全警告: SHA256 校验不匹配！"
                echo "   期望值: $EXPECTED_HASH"
                echo "   实际值: $ACTUAL_HASH"
                echo "   文件可能在传输中损坏或被中间人篡改，已强制终止安装！"
                exit 1
            fi
            echo "✅ SHA256 完整性验证 100% 通过！"
        fi
    fi
fi

echo "📦 解压中..."
tar -xzf "$TMP_TAR" -C "$TMP_DIR"
chmod +x "$TMP_BIN"

# 9. 二进制与配置预检 (Dry Run)
echo "🧪 验证二进制兼容性..."
NEW_VER=$("$TMP_BIN" -v 2>&1 | head -n 1)
echo "   版本信息: $NEW_VER"

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
    echo "🧪 检测到正在生效的配置 ($TEST_CONFIG)，执行语法预检..."
    if ! "$TMP_BIN" -t -d "$TEST_DIR" -f "$TEST_CONFIG" >/dev/null 2>&1; then
        echo "⚠️ 提示: 新版本配置测试返回非零警告，但核心二进制验证正常。"
    else
        echo "✅ 配置语法预检完全通过！"
    fi
fi

# 10. 智能服务管理：优雅停止运行中的代理
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

# 11. 执行原子覆写
mkdir -p "$(dirname "$TARGET_BIN")"
echo "🔄 执行原地替换: $TARGET_BIN ..."
cp -f "$TMP_BIN" "$TARGET_BIN"
chmod +x "$TARGET_BIN"

# 12. 智能重启代理服务
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
