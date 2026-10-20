# Skyworth 8H52_G3 (Hi3751V551) Root 工具箱

针对创维 `8H52_G3` / `Hi3751V551` / Android 5.1.1 (API 22) 电视的免解锁 Root、精简与桌面替换工具。

**已在本机完整验证**：Root ✅ ｜ 换桌面 ✅ ｜ 去开机广告 ✅ ｜ 精简应用 ✅ ｜ 开机自启桌面 ✅

---

## 0. 成果一览

| 项目 | 状态 | 说明 |
| --- | --- | --- |
| Root | ✅ | `/system/xbin/su`（setuid root，armeabi-v7a 静态二进制），重启后依然有效 |
| 开机自启桌面 | ✅ | `com.oversea.aslauncher`（AS Launcher），已写入厂商配置 `DEFAULT_HOMEPAGE` |
| 开机广告 | ✅ | `BOOT_AD=false` + `SUPPORT_SCREENSAVER=false` + `Need_CooCaa_Auto_Jump_Home=false` |
| 自带桌面 | ✅ 已冻结 | `com.tianci.movieplatform`（含召回组件 `RecallBootReceiver`） |
| 应用商店 | ✅ 已冻结 | `com.tianci.appstore` |
| 紧急升级回灌 | ✅ 已阻断 | 禁用 `com.coocaa.skycast.tool` + hosts 屏蔽 `apk-sky-fs.coocaa.ottcn.com` |
| 其它冗余 | ✅ 已禁用 | 电视管家 / 用户中心 / 语音 / 主题包 / 投屏工具等 11 项，全部可逆 |
| 桌面备选 | ✅ | FLauncher 已装可用；LTvLauncher 在 API 22 上会崩溃（见 `docs/03-launcher.md`） |

> ⚠️ 本项目不刷机、不解锁 bootloader、不改 boot 分区。系统分区只写入一个 `su` 文件和一份配置，
> 任何一步都可以通过 `docs/04-recovery.md` 的方法回滚。

---

## 1. Root 原理（一句话）

这台机器的 `init.rc` 里留着厂商自用的 **root 后门服务**：

```
service boot-shell /system/bin/hisi_boot_shell.sh
    class core
    user root
    oneshot
    disabled

on property:dev.bootcomplete=1
    start boot-shell
```

`/system/bin/hisi_boot_shell.sh` 会扫描 `df | grep mnt/usb`，找到 U 盘后**以 root 身份 source
U 盘根目录下的 `hi_boot_shell.sh`**。也就是说：**插上 U 盘 = 拿到 init 上下文的 root**。

本仓库把这条链路做成了标准流程：

```
U 盘 (FAT32)
 ├── su                # ARMv7 静态 setuid-root 二进制
 ├── hi_boot_shell.sh  # 厂商脚本 source 的入口
 └── payload/tasks/*.sh # 需要以 init root 执行的任务
```

配合 ADB 侧 `setprop ctl.start boot-shell` 可以在**不重启**的情况下随时触发一次 root 任务。

详细原理、能力边界与踩坑记录见 [`docs/01-root-method.md`](docs/01-root-method.md)。

---

## 2. 目录结构

```
skyworth-8h52-root/
├── README.md
├── LICENSE
├── docs/
│   ├── 01-root-method.md   # 原理、能力边界、踩坑
│   ├── 02-debloat.md       # 精简清单与回滚方式
│   ├── 03-launcher.md      # 桌面选型与兼容性分析
│   └── 04-recovery.md      # 救砖 / 还原原厂
├── tools/
│   ├── tv-adb.sh           # ADB 入口（自带 TCP 代理 + 断线重试）
│   ├── tv-adb-proxy.py     # 127.0.0.1:15555 -> 192.168.0.9:5555 转发
│   ├── make-usb.sh         # 一键格式化 U 盘并写入 payload
│   ├── build-su.sh         # 交叉编译 ARMv7 静态 su
│   ├── patch-config.py     # 批量改厂商 general_config.xml
│   ├── run-task.sh         # 把任务推到电视并通过 boot-shell 以 root 执行
│   └── deploy.sh           # 一键：配置桌面 + 精简 + 校验
├── payload/
│   ├── hi_boot_shell.sh    # 写入 U 盘的入口脚本
│   ├── su.c / su           # setuid-root 源码与预编译二进制
│   └── tasks/              # 以 init root 执行的脚本
└── apk/README.md           # 第三方 APK 只给下载链接，不随仓库分发
```

---

## 3. 快速开始

### 3.1 准备（一次性）

```bash
cd tools
./build-su.sh          # 编译 ARMv7 静态 su（有 zig / clang 任意一个即可）
```

### 3.2 制作启动 U 盘

```bash
cd tools
./make-usb.sh                  # 自动识别外置可移动磁盘
./make-usb.sh --disk /dev/disk5 # 或手动指定
```

脚本会：把磁盘格式化成 **FAT32 + MBR**（卷标 `TVROOT`）→ 写入 `su` / `hi_boot_shell.sh` / `payload` → 安全弹出。
> 会清空该 U 盘，请勿指向 Mac 内置盘。

### 3.3 首次 Root

1. U 盘插到电视 USB 口，确认电视已挂载（电视上 `df | grep mnt/usb`）。
2. 在电脑上：

```bash
cd tools
./tv-adb.sh shell 'setprop ctl.start boot-shell'
./tv-adb.sh shell 'cat /data/local/tmp/boot_task.log'   # 查看 root 任务日志
./tv-adb.sh shell '/system/xbin/su -c id'              # 期望 uid=0(root)
```

3. Root 成功后 `/system/xbin/su` 永久存在，重启不丢。

### 3.4 执行任意 root 任务

```bash
cd tools
./run-task.sh ../payload/tasks/20_debloat.sh      # 推送并以 init root 执行
```

`run-task.sh` 会自动：推送任务到 `/data/local/tmp/pending_task.sh` → 推送 U 盘入口 → 触发
`boot-shell` → 打印 `/data/local/tmp/boot_task.log`。

### 3.5 换桌面 / 精简（一条命令）

```bash
cd tools
./deploy.sh --homepage com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity
```

---

## 4. 能力边界（务必阅读）

`su` 虽然是 `uid=0`，但从 ADB 启动时继承的是 adbd 的 **capability bounding set = 0xc0**
（只有 `CAP_SETUID` / `CAP_SETGID`），因此：

| 操作 | `su -c` | boot-shell（init root） |
| --- | --- | --- |
| 改 `/system` 文件、remount rw | ❌ | ✅ |
| 读 `/data/ccos`（700 system） | ❌ | ✅ |
| `pm disable/uninstall` | ✅ | ✅ |
| 删应用数据、写 `/data` | 部分 | ✅ |
| `setprop` | ✅ | ✅ |

**结论**：日常用 `su`；涉及系统分区或厂商私有目录的改动一律走 `run-task.sh`（boot-shell）。

---

## 5. 实战处理过程（时间线）

下面是这台电视上真实跑过的完整流程，可直接照抄：

| # | 动作 | 手段 | 结果 |
| --- | --- | --- | --- |
| 1 | 环境侦查 | `getprop` / `dumpsys` | SELinux 关闭、`ro.debuggable=1`、唯一 setuid root 是 `procrank` |
| 2 | 找提权入口 | 读 `/system/bin/init.rc` | 发现厂商后门 `service boot-shell`（`user root`） |
| 3 | 分析后门逻辑 | 读 `hisi_boot_shell.sh` | 它会以 root source U 盘根目录的 `hi_boot_shell.sh` |
| 4 | 打通 ADB | `tools/tv-adb-proxy.py` | macOS 直连 `192.168.0.9:5555` 不通，改走本地转发 |
| 5 | 准备 U 盘 | `tools/make-usb.sh` | FAT32 + MBR，卷标 `TVROOT` |
| 6 | 编译 su | `tools/build-su.sh`（zig musl 静态） | 8 KB ARMv7 ELF，电视上实测可执行 |
| 7 | 首次 root | `setprop ctl.start boot-shell` | `/system/xbin/su` 装好，`su -c id` → `uid=0(root)` |
| 8 | 换桌面配置 | `payload/tasks/10_set_homepage.sh` | 改 `/system/pcfg/.../general_config.xml` + `/data/ccos/general_config.xml` + `persist.service.homepage.*` |
| 9 | 冻结酷开桌面 | `payload/tasks/20_debloat.sh` | `pm disable-user` 桌面/应用商店/管家/用户中心/语音等 |
| 10 | 阻断回灌 | `payload/tasks/30_block_upgrade.sh` | 发现 `skycast.tool` 的 EmergencyUpgradeEngine 会重装桌面 → 冻结 + 删包 + hosts 屏蔽 |
| 11 | 重启验收 | `reboot` + `dumpsys activity` | `mResumedActivity` = 目标桌面，root 仍在 |
| 12 | 桌面选型 | 试装 LTvLauncher | API 22 崩溃（`NetworkStatsManager` API 23）→ 改用 AS Launcher |
| 13 | 收尾 | 卸载旧桌面、禁用冗余包、导出 Jellyfin 配置 | 电视进入纯净状态 |

每一步都可以回滚，见 [`docs/04-recovery.md`](docs/04-recovery.md)。

## 6. 安全声明

- 本仓库不包含任何厂商 APK、固件或解密密钥；`payload/su` 是本项目自写的 30 行 C。
- 工具默认只在 `127.0.0.1` 开端口，U 盘里的脚本不含任何联网行为。
- 使用前请先阅读 [`docs/04-recovery.md`](docs/04-recovery.md)，确保知道怎么退回去。

## 7. 致谢

- 厂商固件自带的 `hisi_boot_shell.sh`（未修改，仅利用其既有行为）
- [FLauncher](https://gitlab.com/flauncher/flauncher) —— 备选桌面
- [LTvLauncher](https://github.com/leanbitlab-org/LtvLauncher) —— 高版本桌面（API 22 需打补丁，详见 docs）
