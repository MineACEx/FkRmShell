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
      <p>专为 <strong>文件管理器 Root 直接执行</strong>场景优化。通过 <code>UpdateAPP.sh</code> 一键拉取最新云端脚本并执行，自动下载依赖工具，无需手动部署。</p>
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
你的根目录/                     ← 例如 /data/Rmfuck/ 或 /sdcard/FkRmShell/
├── bin/                         ← 工具目录 (base64, gunzip, gzip, vim 等)
├── script/                      ← 把待检测脚本扔进这里
│   ├── 可疑1.sh
│   └── 可疑2.sh
├── logs/                        ← 运行日志 (自动生成)
└── UpdateAPP/                   ← 启动器目录
    ├── UpdateAPP.sh             ← 主启动脚本 (执行这个)
    └── bin/
        └── busybox              ← busybox 二进制
```

### 使用方法

**方式一：文件管理器直接执行（推荐）**

1. 将整个项目文件夹放到 `/data/` 或任意位置
2. 给予UpdateAPP.sh 777权限
3. 将待检测脚本放入 `script/` 文件夹
4. 进入 `UpdateAPP/` 目录，点击 `UpdateAPP.sh`
5. 选择「Root 模式执行」
6. 脚本会自动：
   - 检查依赖，缺失则自动从网络下载
   - 拉取最新云端检测脚本
   - 进入交互菜单，按提示选择检测模式

**方式二：终端命令行**

```sh
# 进入 UpdateAPP 目录，Root 执行
su -c "sh .UpdateAPP.sh"
```

### 工作流程

```
UpdateAPP.sh 启动
  │
  ├─ 阶段1: 检查依赖 (./bin/vim, ./bin/gzip)
  │     └─ 缺失 → 自动下载 main.zip → 解压到 ./bin/
  │
  ├─ 阶段2: 下载远程脚本
  │     └─ wget 拉取 GitHub Pages 最新版 → 保存到 ./.bash
  │
  └─ 阶段3: 执行远程脚本
        └─ 子shell隔离运行, stdin 正常可用, read 可交互
```

### 环境变量 (远程脚本可用)

| 变量 | 值 | 说明 |
|------|-----|------|
| `$ROOT` | `UpdateAPP.sh 所在目录` | 例如 `/sdcard/FkRmShell/UpdateAPP` |
| `$PARENT` | `ROOT 的上级目录` | 例如 `/sdcard/FkRmShell` |
| `$PARENT/bin` | 工具目录 | base64, gunzip, gzip 等 |
| `$PARENT/script` | 待扫描脚本目录 | 你的 `.sh` 文件放这里 |

> 远程脚本使用 `$ROOT` / `$PARENT` 获取目录路径，**不要用 `$0` / `dirname` / `realpath`**，因为管道执行模式下 `$0` 不可靠。

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
> 检测过程在脚本所在目录中进行，临时文件执行后自动清理。
>
> 不要以任何方式执行被标记为"危险"的脚本文件。

---

## 📄 License

MIT &copy; MineACEx

---

<p align="center">
  <sub>如果你觉得这个工具有用，请给个 ⭐ Star</sub>
</p>
