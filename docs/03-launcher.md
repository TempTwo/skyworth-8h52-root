# 桌面（Launcher）选型

## 1. 结论

| 桌面 | 包名 | 结果 |
| --- | --- | --- |
| **Aerial** ✅ | `app.orchard.tv` | **采用**，已设为开机自启桌面（2026-10-21 起） |
| CleanYourTV | `com.gathin.tvhome` | 备选，保留在系统里可随时切回 |
| AS Launcher | `com.oversea.aslauncher` | 早期使用；现在被同名转发壳占位，入口仍指向 CleanYourTV |
| FLauncher | `me.efesser.flauncher` | 可用但界面朴素，已移除 |
| LTvLauncher | `com.leanbitlab.ltvL` | API 22 上启动即崩，已移除 |

## 2. Aerial（当前使用）

tvOS 风格的 Android TV 桌面：时钟/天气/壁纸/应用网格、控制中心、航拍屏保、遥控器长按菜单。
上游 <https://github.com/pengchujin/aerial-tv>（MIT），本机 fork：<https://github.com/TempTwo/aerial-tv>。

* 版本 `1.18`（versionCode 20），`minSdk 21`，Kotlin + Jetpack Compose 1.9.5。
* 入口：`app.orchard.tv/.MainActivity`。
* 本机适配说明（创维这台电视的 HOME 机制、权限、屏保、时钟）见 fork 里的
  [`docs/devices/skyworth-8h52-g3.md`](https://github.com/TempTwo/aerial-tv/blob/main/docs/devices/skyworth-8h52-g3.md)。

### 2.1 编译

```bash
git clone https://github.com/TempTwo/aerial-tv
cd aerial-tv
export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export ANDROID_HOME=~/Library/Android/sdk
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew assembleStandardRelease
# 产物: app/build/outputs/apk/standard/release/app-standard-release.apk
```

需要 SDK Platform 36 + Build-Tools 36。上游的签名密钥在 `local/`（不在版本库），
没有它会回落到本机 debug key —— 首次安装没问题，之后想覆盖安装就得一直用同一个 key。

装 `standard` 版（带 HOME intent-filter）。这台电视的固件不拦带 HOME 的包，不需要 `guard` 版。

### 2.2 设为开机桌面（关键：改厂商配置，不是改系统 HOME）

创维的 HOME 由厂商自己的 `sky_launcher` 服务决定，它读配置里的 `DEFAULT_HOMEPAGE`：

```xml
<!-- /system/pcfg/8H52_G3/config/general_config.xml 与 /data/ccos/general_config.xml 两处都要改 -->
<config name="DEFAULT_HOMEPAGE" value="app.orchard.tv/app.orchard.tv.MainActivity"/>
```

```sh
setprop persist.service.homepage.pkg app.orchard.tv
setprop persist.service.homepage.cls app.orchard.tv.MainActivity
setprop persist.service.starthomepage 1
```

改完重启，`sky_launcher` 就会拉起它：

```
I/sky_launcher: ----parser---- DEFAULT_HOMEPAGE:app.orchard.tv/app.orchard.tv.MainActivity
I/ActivityManager: START u0 { cmp=app.orchard.tv/.MainActivity} from uid 0 on display 0
```

配置文件在 `/system` 里，写它要 root → 用 `tools/run-task.sh`（插 U 盘）或者
`tools/tv-root.py`（guardctl 通道，不需要 U 盘）。

### 2.3 顺带要设的项

```sh
# 开机后能自己弹到前台
appops set app.orchard.tv SYSTEM_ALERT_WINDOW allow
# 亮度调节
appops set app.orchard.tv WRITE_SETTINGS allow
# 系统屏保用航拍
settings put secure screensaver_components app.orchard.tv/app.orchard.tv.dream.AerialDream
```

API 22 上没有运行时权限，`pm grant` 基本用不上（会报
`It is required by the application`）；`WRITE_SECURE_SETTINGS` 是 signature 权限也改不了，
但这台电视不用 Home Guard，所以不需要它。

### 2.4 实测（2026-10-21，Android 5.1.1 / API 22）

| 项 | 结果 |
| --- | --- |
| `adb install` | ✅ 无校验链，直接装上 |
| 开机自动接管 | ✅ 重启后 `mResumedActivity = app.orchard.tv/.MainActivity` |
| 首页渲染 | ✅ 时钟、日期、天气、必应壁纸、应用网格 |
| 遥控器焦点 | ✅ 方向键正常，滚下去时钟收进状态栏 |
| 航拍屏保 | ✅ 能播，中文字幕正常 |
| 崩溃 | ✅ 无（只有两条 `Unknown permission` 警告，API 22 不认识那两个权限） |

**注意**：厂商 `/system/etc/init.bigfish.sh` 开机会把时间设成 2017-01-01，
刚开机一两分钟桌面上的时钟是错的（8:00），联网后系统自己校回来。

## 3. 备选：CleanYourTV（`com.gathin.tvhome`）

* CleanYourTV 源码自行编译适配：`minSdk 26→22`、`compileSdk 35`、开启 core library desugaring、
  14 处高版本 API 加版本判断、删除 19 个语言目录只留简体中文。
* 入口：`com.gathin.tvhome/.MainActivity`。
* 仍装在电视上（526 KB），想切回去只要把 `DEFAULT_HOMEPAGE` 改回
  `com.gathin.tvhome/com.gathin.tvhome.MainActivity` 再重启。

## 4. 历史：AS Launcher

* 版本 `1.1.0.2`，`targetSdk=26`，ABI `armeabi-v7a`，在 Android 5.1 上运行正常。
* 入口：`com.oversea.aslauncher/.ui.main.MainActivity`。
* 现在这个包名被一个**同名转发壳**占着：壳启动后转跳到 `com.gathin.tvhome/.MainActivity` 再 finish，
  用来在还不能写 `/system` 配置时先让厂商的 `sky_launcher` 跳到新桌面。
* 厂商原版 AS Launcher 的 APK 留底在 `backup-tv/aslauncher-orig.apk`（15 MB）。
  写了 `DEFAULT_HOMEPAGE` 之后这个壳已经没有用途，可以卸掉壳再把原版装回去（**需要确认后再做**）。
