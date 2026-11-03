# 创维 8H52_G3（Hi3751V551）Root 与桌面替换指南

针对创维 `8H52_G3` / 海思 `Hi3751V551` / Android 5.1.1（API 22）电视的
免解锁 Root、桌面替换与开机自动化工具箱。所有步骤在实物上完整验证过。

> 请在 AI 指导下执行；**ROOT 有风险，操作请谨慎！**

> ## ⚠️ WARN：ROOT 有风险，动手前先读完这篇
>
> 1. **ROOT 有风险，可能变砖**。这不是吓唬人：本项目作者就曾因清理脚本匹配逻辑
>    写错、误删 25 个已安装系统 APK，电视卡死在 logo，靠 recovery 整包刷原厂固件
>    才救回（见 [`docs/08-brick-recovery.md`](docs/08-brick-recovery.md)）。
> 2. Root 会**失去保修**，且会被厂商判定为非正常使用产品。
> 3. Root 会把电视的攻击面扩大（远程 ADB、root 任务通道都可能被人利用），
>    **家庭共享网络上不要随意开启 root 调试通道**，用完必须关闭。
> 4. 只对**自己有处置权的电视**操作；是别人/全家人在用的电视，先征得同意，
>    任何会动用户数据的步骤（恢复出厂、清 /data）加倍谨慎。
> 5. 本仓库**不刷机、不解锁 bootloader、不改 boot 分区**；但任何第三方工具链
>    都无法给"不会变砖"打保票——厂商 OTA、固件差异、手滑都可能出事。
> 6. **开始之前，先读第 1 节"救砖"**，把原厂固件包下下来留底再动手。
> 7. 一切后果**自行承担**——你操作，你负责。

---

## 0. 适用机型

| 项 | 值 |
| --- | --- |
| 型号 | 创维 8H52_G3 |
| SoC | Hi3751V551 |
| Android | 5.1.1（API 22），ABI armeabi-v7a（仅 32 位） |
| SELinux | **Disabled**（本方案成立的前提，`getenforce` 实测确认） |
| 有利条件 | `ro.secure=1` 但 SELinux 关闭 → setuid 生效；厂商出厂自带 root 后门 |

其他机型没有专门适配，只能参考思路，方案细节固件相关，风险自担。

本方案在这台电视上验证时的固件历程：出厂 V022 → 误删事故后整包刷回
V017.012.060 → 自动 OTA 升到 **V020.006.110**，全部兼容；下文有一处由固件
版本导致的差异（guard 通道，见 2.4）。

---

## 1. 先读：万一搞崩了，怎么救

### 1.1 恢复阶梯（由轻到重）

| 症状 | 处理 |
| --- | --- |
| 换的桌面不好用/进不去，想回原厂 | `./tools/run-task.sh ./payload/tasks/90_restore_stock.sh`（恢复厂商配置 + 启回原桌面） |
| Root 失效了（OTA 覆盖了 `/system`） | 重新 `make-usb.sh` 做盘 → 插电视 → `setprop ctl.start boot-shell` 重新装 su |
| 误删文件后开机异常，但系统还能进 | 停手。用任务通道把备份恢复回去（**删除前必须做过备份**） |
| **卡 logo / 无法开机** | ↓ 整包刷原厂固件（1.2） |

### 1.2 变砖恢复：recovery 刷原厂固件（已实测，2 小时救回）

**固件来源**（2026-11-03 实测可用，632 MB，HTTP 200）：

```
http://update01.skyworth-cloud.com/pup/8H52_G3_V017.012.060_9_online.zip
```

下载要点（这个 CDN 在家宽/有代理的网络下 DNS 解析常被干扰，建议照下法直连 IP）：

```bash
# 用 8.8.8.8 解析 CDN 真实 IP，然后直连（部分网络下反而更快，也可能不通，多试几个 IP）
dig +short update01.skyworth-cloud.com.cdn20.com @8.8.8.8   # 任选一个返回的 IP
curl -o fw.zip --resolve update01.skyworth-cloud.com:80:<CDN_IP> \
     http://update01.skyworth-cloud.com/pup/8H52_G3_V017.012.060_9_online.zip
```

> 若是最常见的家用 OpenClash 场景，注意它常见 fake-IP 响应（`198.18.x.x`），
> 此时直接 `curl` 会"解析"到一个不存在的地址。**用 `--resolve`** 指定真实 CDN IP。

V017 是这个机芯系列**唯一能从官方 CDN 下载到的版本**（即使电视出厂是
更新的版本号），同板号同机芯，足以把 `/system` 整个恢复成原厂；电视会随后
自动 OTA 升回能拿到的最新版。命名规律与包内容解析见
[`docs/08-brick-recovery.md`](docs/08-brick-recovery.md)。

**操作步骤**：

1. U 盘（**FAT32**）根目录放固件包，**两个文件名都放一份**，recovery 只认这两个：
   * `update.zip`（改名固件包）
   * `8H52_G3.zip`（本板专属名，recovery 按板号找）
2. Mac 上**先推出 U 盘**（macOS 挂着时电视读不到）；电视**断电**（非待机）插上 U 盘；
3. 插回电源，**立刻长按遥控器「主页/Home」键**不放，直到出 recovery 菜单；
4. 选 **「使用U盘或SD卡升级」**；
5. 等 10～20 分钟，**中途别断电、别拔盘**；完成后选「重启」。
6. 重启后若 U 盘里还插着本仓库的启动盘，root/桌面/时钟补丁会自动重新装上（见 §4）。

> 一个官方包里的小坑：V017 的 `updater-script` 会因为包里缺 `skyworth.img`
> 在中途 abort，但 **`/system` 分区在那之前（L27）已刷完**，救砖目的
> 已达成；recovery/atv/factory 分区不动（本来也没坏）。
> 详见 [`docs/08-brick-recovery.md`](docs/08-brick-recovery.md)。

### 1.3 我想彻底回到没 Root 的出厂状态

```bash
./tools/run-task.sh ./payload/tasks/90_restore_stock.sh   # 配置/包/hosts 全部还原
./tools/tv-adb.sh shell 'su -c "rm -f /system/xbin/su"'   # 删 su（REMOVE_SU=1 分支也做）
```

或直接走 1.2 整包刷回（最彻底，数据也清）。

---

## 2. Root

### 2.1 原理（厂商自留的后门，不 patch boot 分区）

厂商出厂脚本 `/system/bin/hisi_boot_shell.sh` 由 init 以 **root** 启动：

```text
service boot-shell /system/bin/hisi_boot_shell.sh
    class core
    user root
    oneshot
    disabled

on property:dev.bootcomplete=1
    start boot-shell
```

脚本逻辑概括：`df | grep mnt/usb` 找 U 盘 → **以 root 身份 source U 盘根目录的
`hi_boot_shell.sh`**。所以：**插上 U 盘 = init 上下文的完整 root**，且不用拆机、
不用解锁、不改 boot 分区。

本仓库把它做成标准链路：

```text
U 盘 (FAT32)
 ├── su (ARMv7 静态 setuid-root 二进制, payload/su.c 源码)
 ├── hi_boot_shell.sh (入口: 修静态 IP → 装 su → 任务调度 → 自愈)
 └── payload/tasks/*.sh (要 init root 执行的任务)
```

触发方式两种：**插着 U 盘开机**（init 自动跑）或**已开机时
`setprop ctl.start boot-shell`**（不重启电视也能触发，普通 shell 用户可写 `ctl.*`）。

### 2.2 上手步骤（已验证）

```bash
cd tools
./make-usb.sh                  # 做 U 盘：自动识别外置磁盘，FAT32+MBR，卷标 TVROOT
                               # ⚠️ 会清空该 U 盘

# U 盘插到电视 USB 口；确认电视已挂载：df | grep mnt/usb
./tv-adb.sh shell 'setprop ctl.start boot-shell'
./tv-adb.sh shell 'busybox tail -30 /data/local/tmp/boot_task.log'   # 看任务日志
./tv-adb.sh shell '/system/xbin/su -c id'                            # 期望 uid=0(root)
```

Root 成功后 `/system/xbin/su` 固化在 `/system` 里，重启不丢（直到 OTA 覆盖）。

之后起任务全走统一入口（不重启执行一条命令）：

```bash
cd tools
./run-task.sh ../payload/tasks/20_debloat.sh   # 推到 /data/local/tmp/pending_task.sh
                                               # → 推 U 盘 → 触发 boot-shell → 打印日志
```

### 2.3 能力边界（重要：为什么有的命令 su 会 Permission denied）

`su` 是 uid 0，但从 ADB 起的进程继承 adbd 的 capability bounding set（实测
`CapBnd: 0xc0` = 只有 SETUID/SETGID）。bounding set 只能减不能加，因此：

| 操作 | ADB `su -c` | U 盘 boot-shell（init root） |
| --- | --- | --- |
| 改 `/system` 文件、remount rw | ❌ | ✅ |
| 读 `/data/ccos`（0700 system） | ❌ | ✅ |
| `pm disable-user` / `pm uninstall --user 0` | ✅ | ✅ |
| `setprop persist.*` | ✅ | ✅ |
| 删应用数据 / 全 /data | 部分 | ✅ |

**结论**：日常操作（冻结包、设属性、装应用）用 `su` 就够；**涉及系统分区或
厂商私有目录的改动（比如换桌面、打时钟补丁）必须走 U 盘 boot-shell**，即
`./tools/run-task.sh <task>`。

### 2.4 guard 通道的历史（旧文件提到，现已在该固件上失效，别踩）

本仓库早期文档介绍过第二条 root 通道：厂商守护进程
`coocaa_guard` 监听 socket、用 `tools/guardctl`/`/system/xbin/tvroot` 无 U 盘触发
root telnetd（完整 capability）。**2026-10-23 在 V020.006.110 上实测：**

* `/data/ccos/guard.sock` 已不存在（守护进程改成了抽象 socket，名字变了），
  旧客户端 `guardctl`/`tvroot` 连不上（代码仍留在仓库，仅作历史记录）；
* 守护进程改用抽象 socket 后的连接姿势见 `tools/gaddr.c`
  （说明见 [`docs/09-clock-sync.md`](docs/09-clock-sync.md)），但如今也只对
  输入事件类命令有用；
* `start_telnetd`/`shellexec` 因系统里缺 `/system/bin/skybusybox` 而静默失败。

**结论：这条通道现已用不了，唯一完整 root 是 U 盘 boot-shell**（反而更保险，
不依赖厂商守护进程的版本变动，V017/V020 两个固件都实测可用）。
`tools/gaddr.c` 是当时逆向出的抽象 socket 客户端，仅为参考留档。

### 2.5 ADB 连不上时

`adb root` 不可用（`ro.secure=1`，adbd 重启回 shell 用户）。macOS 直连电视
5555 可能被路由策略拦：用 `tools/tv-adb-proxy.py`
（127.0.0.1:15555 → 电视:5555 本地转发）绕过。

---

## 3. 换桌面（Aerial）

### 3.1 目前采用的桌面

**Aerial**（tvOS 风格：大时钟/天气/壁纸/应用网格/控制中心/航拍屏保/
遥控器长按菜单）——**适配源码与可安装包都在并提供 Releases**：
[pengchujin/aerial-tv](https://github.com/pengchujin/aerial-tv)（上游，MIT）
→ 二次修改版 [TempTwo/aerial-tv-skyworth](https://github.com/TempTwo/aerial-tv-skyworth)：

* Releases 提供**可直接 `adb install` 的 APK**（`aerial-skyworth-8h52-v1.20.apk`、
  `v1.21.apk`，均已在创维 8H52_G3 实测），与上游同一个签名 key，`-r` 可覆盖升级；
* v1.21 新增：无 Key 多源天气（移植 Quiet TV）、时钟直取系统时间；
  v1.20 为和风天气 + 联网校时，**电视上当前运行 1.20**；
* 适配内容：无系统 Settings 时的「应用信息」自绘面板、个性化面板二维码与
  壁纸行重叠修复、创维背光控制等（详见该仓库 README）。

备选桌面（历史实测，仅作参考）：CleanYourTV（自适配到 API 22）可用但已卸载、
FLauncher 可用但界面朴素、LTvLauncher **API 22 上启动即崩**（不推荐）。

### 3.2 安装（下载 APK）或编译

**推荐直接用 Releases**：

```bash
curl -LO https://github.com/TempTwo/aerial-tv-skyworth/releases/latest/download/aerial-skyworth-8h52-v1.21.apk
./tools/tv-adb.sh push aerial-skyworth-8h52-v1.21.apk /data/local/tmp/aerial.apk
./tools/tv-adb.sh shell 'pm install -r /data/local/tmp/aerial.apk'          # 覆盖升级保数据
# 电视上的版本比 APK 高时（需降级）改用：pm install -r -d ...
./tools/tv-adb.sh shell 'cmd package compile -m speed -f app.orchard.tv'   # AOT 提速，务必做
```

要自己编译就 clone 适配仓库（编译参数见其 README）：

```bash
git clone https://github.com/TempTwo/aerial-tv-skyworth
cd aerial-tv-skyworth
# 需要 SDK Platform 36 + Build-Tools 36；签名 key 说明见该仓库 README
```

### 3.3 设为开机桌面（关键：改厂商配置，不是改系统 HOME）

创维的 HOME 由厂商 `sky_launcher` 服务按配置里的 `DEFAULT_HOMEPAGE` 决定，
**两处配置都要改**（一处在 `/system` 里，需要 U 盘 boot-shell 通道）：

```xml
<!-- /system/pcfg/8H52_G3/config/general_config.xml 与 /data/ccos/general_config.xml -->
<config name="DEFAULT_HOMEPAGE" value="app.orchard.tv/app.orchard.tv.MainActivity"/>
```

```sh
setprop persist.service.homepage.pkg app.orchard.tv
setprop persist.service.homepage.cls app.orchard.tv.MainActivity
setprop persist.service.starthomepage 1
```

`./tools/run-task.sh ../payload/tasks/10_set_homepage.sh` 一条命令做全套。
验证：`adb shell dumpsys window | grep mResumedActivity` 应看到
`app.orchard.tv/.MainActivity`。

顺带设置（API 22 无运行时权限，appops/settings 这些能用）：

```sh
appops set app.orchard.tv SYSTEM_ALERT_WINDOW allow    # 开机后自己弹到前台
appops set app.orchard.tv WRITE_SETTINGS allow         # 亮度调节
settings put secure screensaver_components \
    app.orchard.tv/app.orchard.tv.dream.AerialDream    # 系统屏保指向 Aerial
```

### 3.4 开机广告同关（deploy.sh 顺带做）

改 `general_config.xml`：`BOOT_AD=false`、`SUPPORT_SCREENSAVER=false`、
`Need_CooCaa_Auto_Jump_Home=false`。跑
`./tools/deploy.sh --homepage app.orchard.tv/app.orchard.tv.MainActivity`
一键完成 3.3 + 3.4 + 精简（见 [docs/02-debloat.md](docs/02-debloat.md)）。

### 3.5 原厂桌面回退

```bash
./tools/run-task.sh ./payload/tasks/90_restore_stock.sh
```

恢复配置、启用所有被冻结的酷开/天翼包、把
`persist.service.homepage.*` 指回 `com.tianci.movieplatform`、去掉
`/system/etc/hosts` 里我们加的屏蔽行。

---

## 4. 开机自动化（U 盘自愈）

### 4.1 `payload/hi_boot_shell.sh` 做什么

每次插着 U 盘开机（或每逢您用 `setprop ctl.start boot-shell` 触发）自动：

1. 配静态 IP（厂商的静态 IP 配置依赖被精简的"软设置"App，不配 adb 就连不上）；
2. 修/校验厂商 boot-shell 脚本（防 CRLF 污染，见 §5 第 2 条）；
3. 装 `su`（setuid root）；
4. 装 U 盘上的 `aerial.apk` 并把 `DEFAULT_HOMEPAGE` 指过去；
5. 清理悬空包记录（避免 PackageManager 追着不存在的 APK 使开机卡 logo）；
6. 执行 `/data/local/tmp/pending_task.sh`（如果存在）。

### 4.2 重刷固件后怎么办

U 盘留着，开机后自愈链路自动重装 su、桌面、配置——**这就是为什么"永远保留
U 盘"**。时钟补丁也一样，重跑 80 号任务即可：

```bash
./tools/run-task.sh ../payload/tasks/80_sync_boot_clock.sh
```

### 4.3 其他任务

仓库 `payload/tasks/` 当前还有（用法同上，`run-task.sh`）：`20_debloat`（冻结
冗余包）、`30_block_upgrade`（阻断酷开紧急升级回灌）、`40_uninstall_bloat`
（卸载冗余包 + 清 /data）、`90_restore_stock`（回滚原厂）、`99_reboot`。
任务清单与取舍详述在 [docs/02-debloat.md](docs/02-debloat.md)。

---

## 5. 操作红线（每一条都是踩坑人的真金白银）

以下都是**真实事故换来的**，请当纪律而不是建议：

1. **不要删任何 `android.uid.system`（uid 1000）共享组的 APK**。创维酷开一系包
   共享该 uid，删掉任意一个都会使整个共享组的签名校验失效，
   `com.tianci.system` 和你自己装的桌面**一起起不来 → 变砖**。精简这类包
   **只用 `pm disable-user` / `pm uninstall --user 0`**（冻结，APK 留着）。
   独立 uid 的包才能删 APK。见 [docs/08-brick-recovery.md](docs/08-brick-recovery.md) §7。
2. **二进制/脚本传电视一律 `adb push` / `adb pull`**。`adb shell cat > 文件`
   会把 LF 变 CRLF，导致厂商 boot-shell 脚本 syntax error、U 盘 root 通道整个
   失效（2026-10 亲历，自己用 cat 把脚本写坏过一次）。
3. **动手前先备份，且校验备份可读**（`tar -tf` 能列出才算备份成功）。
4. **改 `/system` 的脚本，装上去之前先 `sh -n` 语法校验**（本仓库任务脚本
   内置了这一步，自写脚本也要照做）。
5. **U 盘永远留着**：它既是 root 通道（§2），也是救砖通道（§1.2），更是
   重刷固件后的自愈通道（§4.2）。
6. **开机时钟**：本机已通过 `/system/etc/init.bigfish.sh` 补丁 + U 盘任务
   建立了开机自动校时（全 App 的系统时间都跟着纠正），原理与回滚见
   [docs/09-clock-sync.md](docs/09-clock-sync.md)。重刷固件后重跑一次
   `payload/tasks/80_sync_boot_clock.sh` 即可。

---

## 6. 目录结构

```text
skyworth-8h52-root/
├── README.md                  # 本篇
├── docs/
│   ├── 02-debloat.md          # 精简清单/冻结清单/回滚
│   ├── 07-walkman-tv.md       # 第三方音乐播放器 API 22 适配实录
│   ├── 08-brick-recovery.md   # 变砖事故复盘 + 原厂固件包详解（§1 救砖的依据）
│   └── 09-clock-sync.md       # 开机自动校时补丁（免手动 date -s）
├── payload/
│   ├── hi_boot_shell.sh       # U 盘入口脚本（含自愈逻辑）
│   ├── hisi_boot_shell.sh.orig/.fixed   # 厂商脚本留底/修复版
│   ├── timesync.sh            # 开机校时脚本（docs/09）
│   ├── init.bigfish.sh.orig/.new        # 时钟补丁的原版与补丁版
│   ├── su.c / su              # setuid-root 源码（30 行 C）与预编译
│   └── tasks/                 # 以 init root 执行的任务（见 §4.3）
├── patches/                   # 对第三方项目的本机补丁（不提上游）
│   └── walkman-tv-api22.patch  # （Aerial 的适配已独立成 TempTwo/aerial-tv-skyworth）
├── tools/
│   ├── tv-adb.sh              # ADB 唯一入口（本地转发+重试）
│   ├── tv-adb-proxy.py        # 127.0.0.1:15555 -> 电视:5555
│   ├── make-usb.sh            # 一键做启动盘
│   ├── run-task.sh            # 任务推 TV + 以 init root 执行 + 读日志
│   ├── deploy.sh              # 一键：换桌面 + 关广告 + 精简 + 校验
│   ├── build-su.sh / build-guardctl.sh   # 交叉编译小工具（zig/clang）
│   ├── cleanup-*.sh           # 精简/清理工具（匹配逻辑已修正）
│   ├── gaddr.c                # guard 抽象 socket 客户端（仅历史参考，见 §2.4）
│   ├── inkeys.c / root-run.sh / rescue-recovery.sh 等   # 调试留档工具
│   ├── tv-root.py             # guardctl 通道助手（现在的固件上不可用，存档）
└── apk/README.md              # 第三方 APK 只给链接不随仓库分发（版权原因）
```

---

## 7. 安全与合规

* 本仓库不包含任何厂商 APK、固件或解密密钥；`payload/su` 是本项目自写的 30 行 C。
* 工具默认只在本机 `127.0.0.1` 开端口；U 盘脚本不含任何联网行为。
* 救砖所需的**官方固件包**不在本仓库，从创维官方 CDN 下载（§1.2 的 URL）。
* 本指南仅供参考，供用户恢复**自己购买、自己有处置权的电视**的性能与体验；
  由此产生的保修、责任问题不予担保。**ROOT 有风险，动手前三思**。

---

## 8. 致谢

* 厂商固件自带的 `hisi_boot_shell.sh`（未修改，仅利用其既有行为）
* [Aerial (pengchujin/aerial-tv)](https://github.com/pengchujin/aerial-tv) —— 上游桌面；
  本机的二次修改版见 [TempTwo/aerial-tv-skyworth](https://github.com/TempTwo/aerial-tv-skyworth)
* [walkman-tv](https://github.com/SincereXing/walkman-tv) 等开源 TV 项目
* [FLauncher](https://gitlab.com/flauncher/flauncher)、CleanYourTV —— 桌面备选
* 本文 §5 红线的每一条，都来自把事故写成文档的自觉 —— 愿每个动手的人先读再动
