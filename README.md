# Mihomo UPX Multi-Arch Builder 🚀

[![Build Status](https://github.com/xs314/mihomo-upx-builder/actions/workflows/build.yml/badge.svg)](https://github.com/xs314/mihomo-upx-builder/actions/workflows/build.yml)
[![GitHub Release](https://img.shields.io/github/v/release/xs314/mihomo-upx-builder?color=blue&logo=github)](https://github.com/xs314/mihomo-upx-builder/releases)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL_3.0-green.svg)](https://github.com/MetaCubeX/mihomo/blob/Alpha/LICENSE)

自动同步上游 [MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo) 官方更新，多架构交叉编译、符号表剥离、并通过 **UPX 极限加壳压缩** 的极简精简版本。

专为 **OpenWrt、小容量 Flash 路由器（16M / 32M / 64M）及轻量级嵌入式设备** 打造，将原版约 **55 MB** 的庞大二进制压缩至 **9 ~ 14 MB**，彻底告别 Flash 闪存撑爆的烦恼！

---

## ✨ 核心特性

- 🤖 **全自动云端同步**：每天定时检测上游 Release，新版本发布时自动触发 Actions 编译并发布 Release。
- 📉 **极限体积瘦身**：Go 编译期剥离符号表（`-s -w`）+ UPX `--best --lzma` 加壳，体积直降 **75% ~ 80%**。
- 🧩 **双风味（Dual Flavor）设计**：
  - **`nogvisor`（默认，极限体积版，~10MB）**：剥离 Google gVisor 用户态协议栈，依赖 Linux 原生系统网络栈（System Stack）。内存消耗极少，吞吐性能极高，适合 OpenWrt / Nikki / 经典透明代理。
  - **`gvisor`（全功能版，~14MB）**：保留完整 gVisor 用户态网络栈，适合需要 `tun.stack: mixed` 或 `gvisor` 的复杂环境。
- ⚡ **多主流架构覆盖**：覆盖 ARM64、AMD64、AMD64-v3 (AVX2)、ARMv7。
- 🛡️ **安全完整性校验**：所有 Release 均附带 `sha256sums.txt` 校验和。

---

## ⚡ 路由器一键安装 / 原地热更新

在 OpenWrt 终端（通过 SSH 连接到路由器）执行如下命令，即可**自动识别架构、下载最新版本、原地替换并重启服务**：

### 1. 默认安装 `nogvisor` 极限精简版（推荐，内存闪存双轻量）：
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/xs314/mihomo-upx-builder/master/install.sh)"
```

### 2. 指定安装 `gvisor` 全功能版：
```bash
FLAVOR=gvisor sh -c "$(curl -fsSL https://raw.githubusercontent.com/xs314/mihomo-upx-builder/master/install.sh)"
```

> **注意（关于 TUN 协议栈配置）**：
> - 如果使用 `nogvisor` 版本，请确保你的代理插件（如 Nikki）的 TUN 协议栈设置为 `system`（系统原生网络栈）。
>   - 在 Nikki / OpenWrt 中快速设置：
>     ```bash
>     uci set nikki.mixin.tun_stack='system'
>     uci commit nikki
>     /etc/init.d/nikki restart
>     ```

---

## 📦 架构选型对照表

| 架构命名 | 对应硬件平台 / 芯片 | 常见设备 |
| :--- | :--- | :--- |
| **`linux-arm64`** | 高通 IPQ60xx/50xx、联发科 MT7981/MT7986/MT7988、RK3399/RK3568/RK3588 | 红米 AX6000、360 T7、树莓派 4/5、友善 R2S/R4S/R5S、N1 盒子 |
| **`linux-amd64`** | Intel / AMD 64位通用处理器 | J1900、J4125、工控软路由、PVE/ESXi 虚拟机 |
| **`linux-amd64-v3`** | 较新 x86 处理器 (支持 AVX/AVX2) | Intel N100 / N305、第 8 代酷睿及以上、AMD Zen |
| **`linux-armv7`** | 32位 ARM Cortex-A7 / A9 / A15 | 华硕 AC86U、网件 R7000、高通 IPQ4019、树莓派 2/3 (32位) |

---

## 🤝 致谢与鸣谢

- 核心代理框架：[MetaCubeX/mihomo](https://github.com/MetaCubeX/mihomo)
- 可执行文件压缩工具：[UPX: the Ultimate Packer for eXecutables](https://upx.github.io/)
