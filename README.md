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
  - **`nogvisor`（默认，极限体积版，~10MB）**：剥离 Google gVisor 用户态协议栈，依赖 Linux 原生系统网络栈（System Stack）。内存消耗极少，吞吐性能极高，适合 OpenWrt / Nikki / OpenClash / 经典透明代理。
  - **`gvisor`（全功能版，~14MB）**：保留完整 gVisor 用户态网络栈，适合需要 `tun.stack: mixed` 或 `gvisor` 的复杂环境。
- ⚡ **多主流架构覆盖**：覆盖 ARM64、AMD64、AMD64-v3 (AVX2)、ARMv7。
- 🚀 **国内免梯极速安装**：内置高可用加速镜像池（自动故障转移 Failover），即使在“断网/无代理”的路由器上也能秒拉升级。
- 🛡️ **SHA256 密码学强制校验**：每次安装均强制比对官方哈希，100% 免疫任何第三方镜像劫持或篡改投毒。
- 🔄 **全生态通用自适应**：智能识别并适配 **Nikki**、**OpenClash**、**ShellCrash** 及原生 Linux 系统环境。

---

## ⚡ 路由器一键安装 / 原地热更新

在路由器终端（SSH）中，根据你的网络环境执行一行命令即可：

### 🇨🇳 中国大陆环境（推荐，无需梯子，内置多镜像高可用加速）：
```bash
sh -c "$(curl -fsSL https://ghproxy.net/https://raw.githubusercontent.com/xs314/mihomo-upx-builder/master/install.sh)"
```

### 🌐 全球通用环境（海外 / 路由器当前已有可用代理）：
```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/xs314/mihomo-upx-builder/master/install.sh)"
```

---

## 💡 进阶使用参数

你可以通过在命令前添加环境变量来自定义安装行为：

| 参数 | 说明 | 示例 |
| :--- | :--- | :--- |
| `FLAVOR=gvisor` | 安装带 gVisor 完整协议栈的版本（默认为 `nogvisor` 极简版） | `FLAVOR=gvisor sh -c "$(curl ...)"` |
| `TARGET_BIN=/path` | 手动指定内核安装路径（默认自动探测 Nikki / OpenClash / ShellCrash） | `TARGET_BIN=/etc/clash/core sh -c "$(curl ...)"` |
| `MIRROR=https://...` | 自定义你的私有加速前缀（支持 Cloudflare Workers 反代） | `MIRROR=https://my-proxy.com sh -c "$(curl ...)"` |

> **TUN 协议栈特别说明**：
> - 如果使用 `nogvisor` 极简版，请确保代理插件中的 TUN 协议栈设置为 `system`（系统原生网络栈）。
> - 以 Nikki 为例快速配置：
>   ```bash
>   uci set nikki.mixin.tun_stack='system'
>   uci commit nikki
>   /etc/init.d/nikki restart
>   ```

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
