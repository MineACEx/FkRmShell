<p align="center">
  <img src="https://img.shields.io/badge/Android-10--16-3DDC84?style=for-the-badge&logo=android&logoColor=white" alt="Android">
  <img src="https://img.shields.io/badge/Root-Required-FF6B6B?style=for-the-badge&logo=android&logoColor=white" alt="Root">
  <img src="https://img.shields.io/badge/Shell-POSIX-4EAA25?style=for-the-badge&logo=gnu-bash&logoColor=white" alt="Shell">
  <img src="https://img.shields.io/badge/License-MIT-blue?style=for-the-badge" alt="License">
</p>

<p align="center">
  <a href="https://github.com/MineACEx/FkRmShell/releases">
    <img src="https://img.shields.io/github/v/release/MineACEx/FkRmShell?style=for-the-badge&logo=github&label=Download%20Latest&color=FFD700" alt="GitHub Release">
  </a>
  <a href="https://github.com/MineACEx/FkRmShell/stargazers">
    <img src="https://img.shields.io/github/stars/MineACEx/FkRmShell?style=for-the-badge&logo=github&color=yellow" alt="Stars">
  </a>
</p>

<h1 align="center">🛡️ FkRmShell</h1>

<p align="center"><strong>Brick-Script Start &mdash; 专为 Android 打造的静态格机脚本检测工具</strong></p>

<p align="center">
  <sub>全程<strong>不执行</strong>任何待检测脚本 &middot; 纯文本静态分析 &middot; 零风险守护设备安全</sub>
</p>

---

## ⚡ 核心优势

<table>
  <tr>
   <td width="50%">
      <h3>🔒 零风险静态检测</h3>
      <p>全程<strong>不执行</strong>待检测脚本，仅通过正则匹配、文本解码与模式识别进行静态分析。你的设备绝不会因为检测过程而受到任何损害。</p>
    </td>
    <td width="50%">
      <h3>🎭 多层加密自动解包</h3>
      <p>自动识别并递归解包 <strong>Gzip 压缩</strong>、<strong>Base64 编码</strong>、以及 <strong>Gzip+Base64 链式嵌套</strong> 的混淆脚本，最多支持 5 层深度递归。</p>
    </td>
  </tr>
  <tr>
   <td width="50%">
      <h3>🧩 内联 Base64 智能解码</h3>
      <p>精准识别 <code>echo "..." | base64 -d</code> 管道隐藏模式，<strong>自动提取并解码</strong>内嵌的 Base64 载荷，解码后立即进行危险模式匹配。</p>
    </td>
    <td width="50%">
      <h3>🔍 独立编码块探测</h3>
      <p>Gzip 解压产物中常见独立 Base64 块（≥60 字符的纯编码行），同样会被自动发现、解码、并检测隐藏的危险命令。</p>
    </td>
  </tr>
  <tr>
   <td width="50%">
      <h3>🧠 混淆特征识别</h3>
      <p>检测 7 种常见混淆手段：<code>eval</code> 动态执行、变量拼接、printf 十六进制转义、xxd 反向解码、OpenSSL 运行时解密等。</p>
    </td>
    <td width="50%">
      <h3>⚡ 大文件闪电扫描</h3>
      <p>超过 10MB 的大文件自动截取前 10MB 采样分析，秒级出结果。超大二进制文件通过 <code>strings</code> 提取可读字符串后分析。</p>
    </td>
  </tr>
</table>

<table>
  <tr>
   <td width="50%">
      <h3>📱 文件管理器自适应</h3>
      <p>专为 <strong>文件管理器 Root 直接执行</strong>场景优化。自动探测自身路径、自动创建 <code>script/</code> 目录、无需命令行传参、执行完毕后暂停等待查看结果。</p>
    </td>
    <td width="50%">
      <h3>🎨 彩色加粗终端输出</h3>
      <p>多色语义化终端界面：白色标题、蓝色信息、绿色安全、黄色可疑、红色危险、红底白字严重警告。结果一目了然。</p>
    </td>
  </tr>
</table>

---

## 📊 检测能力矩阵

### 严重级别 — 立即告警

| 类别 | 检测模式 |
|------|----------|
| **分区删除** | `rm -rf /data` `/sdcard` `/system` `/vendor` `/product` `/persist` `/nv` `/firmware` `/modem` `/cache` |
| **块设备覆写** | `dd if=/dev/zero of=/dev/block/...` `/dev/urandom` `/dev/null` 覆写分区 |
| **Bootloader 破坏** | `dd` 写入 `boot` `aboot` `recovery` `xbl` `tz` `sbl` `rpm` `hyp` `modemst` 等关键分区 |
| **格式化命令** | `mkfs.*` `mke2fs` `make_ext4fs` `make_f2fs` `newfs_msdos` `mkdosfs` |
| **Fastboot 擦除** | `fastboot erase` `fastboot format` `fastboot -w` |
| **重定向覆写** | `cat` / `cp` / `tee` / `>` 写入 `/dev/block/` |
| **分区表破坏** | `fdisk delete` `parted rm` `sgdisk -d` `wipefs` `blkdiscard` |
| **加密锁定** | `vdc cryptfs enablecrypto` `changepw` |
| **恢复出厂** | `recovery --wipe_data` `wipe data` |

### 可疑级别 — 建议审查

| 类别 | 检测模式 |
|------|----------|
| **系统挂载** | `mount -o remount,rw` 重新挂载分区为可写 |
| **SELinux** | `setenforce 0` 关闭安全策略 |
| **权限变更** | `chmod 777` 修改 `/system` `/data` `/vendor` 权限 |
| **刷机模式** | `reboot bootloader` `recovery` `edl` `fastboot` |
| **批量删除** | `find -exec rm` 批量文件删除 |
| **块设备读取** | `dd if=/dev/block/... of=*.img` (可能为备份，需人工确认) |

---

## 🚀 快速开始

<p align="center">
  <a href="https://github.com/MineACEx/FkRmShell/releases">
    <img src="https://img.shields.io/badge/⬇%20Download-Latest%20Release-FFD700?style=for-the-badge&logo=github" alt="Download">
  </a>
</p>

### 目录结构

```
你的工作目录/
├── Start.sh          ← 主检测脚本
├── bin/                 ← 可选：二进制工具 (base64, gunzip, strings)
└── script/              ← 把待检测脚本扔进这个文件夹
    ├── 可疑1.sh
    └── 可疑2.sh
```

### 使用方法

**方式一：文件管理器直接执行（推荐）**

1. 用支持 Root 的文件管理器（MT Manager / Root Explorer）打开脚本所在目录
2. 将待检测脚本放入 `script/` 文件夹
3. 点击 `Start.sh`，选择「Root 模式执行」
4. 按交互菜单选择检测模式
5. 等待扫描完成，按回车退出

**方式二：终端命令行**

```sh
# 批量扫描 script/ 目录
su -c "sh /path/to/Start.sh"

# 扫描指定文件
su -c "sh /path/to/Start.sh -f /sdcard/可疑脚本.sh"
```

### 二进制工具（可选但推荐）

| 工具 | 作用 | 缺失影响 |
|------|------|----------|
| `base64` | Base64 解密 | 无法检测 Base64 编码脚本 |
| `gunzip` / `gzip` | Gzip 解压 | 无法检测 Gzip 压缩脚本 |
| `strings` | 二进制字符串提取 | 无法检测 ELF/二进制格式脚本 |
| `od` / `hexdump` / `xxd` | 文件魔数检测 | 无法精确识别 Gzip 文件头 |

> 将上述工具放入 `bin/` 目录即可自动识别。大多数 Android 系统的 toybox 已自带 `base64` 和 `gunzip`。

---

## 🔬 检测流程

```
📄 待检测脚本
  │
  ├─ 🔍 文件类型识别 (Gzip魔数 / Base64纯度 / 二进制)
  │
  ├─ 🗜️ Gzip 解压 (支持多层)
  │       │
  │       └─ 解压后立即检测内嵌 Base64 ← NEW
  │
  ├─ 🔓 Base64 全文解码 (支持嵌套)
  │       │
  │       └─ 解码后再次检测内嵌 Base64
  │
  ├─ 🎯 内联 Base64 双重检测
  │     ├─ 类型A: echo "..." | base64 -d 管道模式
  │     └─ 类型B: ≥60字符纯Base64独立编码块
  │
  ├─ 🧩 混淆特征识别 (7种)
  │
  └─ 🚨 危险模式匹配 (30+规则)
        │
        ├─ ✅ 安全
        ├─ ⚠️ 可疑
        └─ 🛑 危险 → 立即告警
```

---

## 📱 兼容性

| 项目 | 说明 |
|------|------|
| **操作系统** | Android 10 — 16 (SDK 29–36) |
| **Shell 解释器** | `/system/bin/sh` (mksh)、bash、dash 均兼容 |
| **权限要求** | Root 权限 (推荐) |
| **执行方式** | 文件管理器 Root 执行 / 终端 `su -c` |

---

## ⚠️ 安全声明

> **本工具仅进行静态文本分析，全程不会执行任何待检测脚本。**
>
> 所有解码/解压操作均在隔离的临时目录 (`/data/local/tmp/`) 中进行，检测完毕后自动清理。
>
> 不要以任何方式执行被标记为"危险"的脚本文件。

---

## 📄 License

MIT &copy; MineACEx

---

<p align="center">
  <sub>如果你觉得这个工具有用，请给个 ⭐ Star</sub>
</p>
