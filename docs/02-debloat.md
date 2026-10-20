# 精简清单

原则：**只做可逆操作**，不删系统分区里的 APK、不动 `system/vendor`，
任何一步都能用 `pm install-existing <pkg>` 还原。

执行方式（两种通道）：

```sh
# 通道 A：init root 通道（推荐，能改 /system、清 /data 残留）
./tools/run-task.sh ./payload/tasks/20_debloat.sh        # 冻结
./tools/run-task.sh ./payload/tasks/30_block_upgrade.sh  # 阻断回灌
./tools/run-task.sh ./payload/tasks/40_uninstall_bloat.sh # 卸载 + 清残留
./tools/run-task.sh ./payload/tasks/99_reboot.sh          # 重启生效

# 通道 B：普通 ADB shell
adb shell 'pm disable-user --user 0 com.tianci.movieplatform'
```

## 1. 已卸载（对当前用户）

| 包名 | 原位置 | 处理方式 | 说明 |
| --- | --- | --- | --- |
| `com.tianci.movieplatform` | `/data/app` 更新 + `/system/vendor/ccos/app/SkyMovie` | `pm uninstall --user 0` | 酷开自带桌面/影视，含 `RecallBootReceiver` 自启动召回 |
| `com.tianci.appstore` | `/data/app` 更新 | `pm uninstall --user 0` | 自带应用商店（推广/下载入口） |
| `com.coocaa.skycast.tool` | 纯 `/data/app` | `pm uninstall`（彻底） | **内置 EmergencyUpgradeEngine，会偷偷重装酷开桌面** |
| `com.coocaa.tvmanager` | `/data/app` 更新 | `pm uninstall --user 0` | 电视管家（清理/推广入口） |
| `com.tianci.user` | `/data/app` 更新 | `pm uninstall --user 0` | 天瓷用户中心（登录/推广） |
| `com.skyworth.angel.voice` | `/data/app` 更新 | `pm uninstall --user 0` | 语音助手（误触发、后台常驻） |
| `com.coocaa.theme_package_ccos_nine` | `/system/vendor/ccos/app/GoldenFaithTheme` | `pm uninstall --user 0` | 酷开主题包 |
| `com.android.htmlviewer` | `/system/app/HTMLViewer` | `pm uninstall --user 0` | HTML 浏览器 |
| `com.android.backupconfirm` | `/system/priv-app/BackupRestoreConfirmation` | `pm uninstall --user 0` | 备份确认 |
| `com.android.sharedstoragebackup` | `/system/priv-app/SharedStorageBackup` | `pm uninstall --user 0` | 共享存储备份 |
| `com.android.location.fused` | `/system/priv-app/FusedLocation` | `pm uninstall --user 0` | 融合定位（电视无 GPS） |
| `com.xu.homeguard` | 第三方 | `pm uninstall`（彻底） | 临时兜底桌面 |
| `me.efesser.flauncher` | 第三方 | `pm uninstall`（彻底） | FLauncher（已换 AS Launcher） |
| `com.leanbitlab.ltvL` | 第三方 | `pm uninstall`（彻底） | LTvLauncher（API 22 崩溃） |

> **"卸载"到底卸掉了什么**
>
> * 纯第三方包（只有 `/data/app` 一份）：APK 被删除，**彻底消失**。
> * 系统包 / 系统包更新：`pm uninstall --user 0` 把包标记为"对 user 0 未安装"，
>   图标消失、无法启动、无法被其它应用拉起；但 `/system` 里的原版 APK **仍在**
>   （厂商 OTA 或恢复出厂会把它装回来）。
> * 想让它在系统层面也彻底没有，需要改 `/system`（root 可做，但收益小、风险高，
>   本项目默认不做，见文末"深度清除"）。

### 恢复某个包

```sh
adb shell 'pm install-existing com.tianci.movieplatform'   # 恢复系统原版
adb shell 'pm enable com.tianci.movieplatform'               # 顺带解除冻结
```

## 2. 空间收益

`/data`（本机只有 4.1G，非常紧张）：

| 阶段 | 空闲 |
| --- | --- |
| 精简前 | 519 MB |
| 卸载后 | **1.2 GB**（+约 680 MB） |

`/system` 仍有 610 MB 空闲，不紧张，所以没必要去动系统分区里的 APK。

## 3. 明确保留（不要动）

| 包名 | 原因 |
| --- | --- |
| `com.tianci.system` | 系统核心 |
| `com.tianci.tv` / `com.tianci.localmedia` | 电视输入源 / 本地媒体播放 |
| `com.tianci.de` | 桌面环境服务，系统 UI 依赖 |
| `com.coocaa.os.ccosservice` | 中心服务（含 `guard.sock` root 守护） |
| `com.coocaa.os.softsettings` | 软设置（系统设置依赖） |
| `com.coocaa.sky.ccapi` | 核心 API |
| `com.coocaa.miracast` | 无线投屏（想彻底去掉可自行卸载） |
| `com.skyworth.setting` | 系统设置 |
| `com.skyworth.tianciime` | 输入法（Jellyfin 登录需要） |
| `com.skyworth.iSwitchDtvService` / `skyworth.dtvLoader` / `com.loostone.tuning` | 搜台与切换 |
| `com.hisilicon.*` / `com.android.*` 核心 | 厂商与系统基础组件 |
| `com.coocaa.factory` | 工厂菜单，**留着当救命通道** |

## 4. 广告相关

| 手段 | 状态 |
| --- | --- |
| `BOOT_AD=false` | ✅ 写入 `/system/pcfg/8H52_G3/config/general_config.xml` 与 `/data/ccos/general_config.xml` |
| `SUPPORT_SCREENSAVER=false` | ✅ |
| `Need_CooCaa_Auto_Jump_Home=false` | ✅ 不再自动跳酷开主页 |
| `persist.sys.bootvideo.time=0` / `persist.sys.ad.boot.exist=0` | ✅ 属性 |
| hosts 屏蔽 `apk-sky-fs.coocaa.ottcn.com` | ✅ 阻断紧急升级包下载 |
| 路由器 AdGuard Home 屏蔽广告域名 | ➕ 建议在软路由上配（不影响系统） |

## 5. 深度清除（可选，高风险）

想让系统包在**系统层面**也消失，需要 root 改 `/system`：

```sh
# 例：把主题包从系统里摘掉（改名而不是删除，可随时改回）
mount -o rw,remount /system
mv /system/vendor/ccos/app/GoldenFaithTheme/GoldenFaithTheme.apk \
   /system/vendor/ccos/app/GoldenFaithTheme/GoldenFaithTheme.apk.disabled
mount -o ro,remount /system
```

风险：包管理器开机扫描会报缺失、厂商服务可能依赖这些包、`/system` 损坏可能导致开不了机。
本项目默认**不做**这一步；如果一定要做，请先备份 `/system` 对应目录，并保留
`com.coocaa.factory` 工厂菜单作为救命通道。

## 6. 复查命令

```sh
./tools/tv-adb.sh shell 'pm list packages'      # 当前已安装
./tools/tv-adb.sh shell 'pm list packages -d'   # 被冻结的
./tools/tv-adb.sh shell 'pm list packages -u'   # 卸载了但系统里还在
./tools/tv-adb.sh shell 'df /data'              # 空间
```
