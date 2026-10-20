# 精简清单

原则：**只做可逆操作**（`pm disable-user`），不删系统 APK、不动 `system/vendor`，
任何一步都能用 `pm enable` 还原（见 `docs/04-recovery.md`）。

## 1. 已冻结（disable-user，可恢复）

| 包名 | 作用 | 冻结原因 |
| --- | --- | --- |
| `com.tianci.movieplatform` | 酷开自带桌面/影视 | 与新桌面冲突；含 `RecallBootReceiver` 自启动召回 |
| `com.tianci.appstore` | 自带应用商店 | 推广/下载入口 |
| `com.coocaa.skycast.tool` | 投屏工具 | **内置 EmergencyUpgradeEngine，会偷偷重装酷开桌面** |
| `com.coocaa.theme_package_ccos_nine` | 酷开主题包 | 桌面已换，主题无用 |
| `com.coocaa.tvmanager` | 电视管家 | 清理/推广入口 |
| `com.tianci.user` | 天瓷用户中心 | 登录/推广入口 |
| `com.skyworth.angel.voice` | 语音助手 | 误触发、后台常驻 |
| `com.android.location.fused` | 融合定位 | 电视无 GPS |
| `com.android.htmlviewer` | HTML 浏览器 | 无用 |
| `com.android.backupconfirm` | 备份确认 | 无用 |
| `com.android.sharedstoragebackup` | 共享存储备份 | 无用 |

## 2. 已卸载（第三方应用）

| 包名 | 说明 |
| --- | --- |
| `com.xu.homeguard` | 临时兜底桌面，已由正式桌面替代 |
| `me.efesser.flauncher` | FLauncher，按要求移除 |
| `com.leanbitlab.ltvL` | LTvLauncher，API 22 上会崩溃，按要求移除 |

> 卸载第三方包是可逆的：保留 APK 重新 `adb install` 即可。

## 3. 明确保留（不要动）

| 包名 | 原因 |
| --- | --- |
| `com.tianci.system` | 系统核心 |
| `com.tianci.tv` | 电视信号/输入源 |
| `com.tianci.localmedia` | 本地媒体播放 |
| `com.tianci.de` | 桌面环境服务，系统 UI 依赖 |
| `com.coocaa.os.ccosservice` | 中心服务（含 `guard.sock` root 守护） |
| `com.coocaa.os.softsettings` | 软设置（系统设置依赖） |
| `com.coocaa.sky.ccapi` | 核心 API |
| `com.coocaa.miracast` | 无线投屏（想彻底去掉可自行 disable） |
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

## 5. 复查命令

```sh
adb shell 'pm list packages -d'                       # 当前被冻结的包
adb shell 'pm enable com.tianci.movieplatform'        # 恢复某个包
adb shell 'pm list packages -3'                       # 第三方应用
```
