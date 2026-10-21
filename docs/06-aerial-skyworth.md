# Aerial 桌面在创维 8H52_G3 上的适配

> 上游：<https://github.com/pengchujin/aerial-tv>（MIT，Kotlin + Jetpack Compose 的 tvOS 风格电视桌面）
> 本机用的版本：1.18（versionCode 20），`standard` flavor，自己编译。
> 电视：创维 8H52_G3 / Hi3751V551 / Android 5.1.1（API 22）/ armeabi-v7a

## 0. 仓库策略（重要）

* **不向上游 `pengchujin/aerial-tv` 提交任何改动**，也不在上面开 PR。
* 本机 fork `TempTwo/aerial-tv` 保持**与上游逐字节一致**（只做镜像，方便以后拉上游更新）。
* 我们自己的改动以**补丁文件**的形式放在本仓库：

  ```
  patches/aerial-8h52-adapt.patch
  ```

  里面是相对上游 `main` 的完整 diff（8 个文件，+312 行）。

* 本机编译目录：仓库外的 `../aerial-tv`（clone 自上游），改动放在本地分支
  `skyworth-8h52-adapt` 上，**不推送**。

## 1. 编译

```bash
git clone https://github.com/pengchujin/aerial-tv   # 或用本机的镜像
cd aerial-tv
git checkout skyworth-8h52-adapt                   # 本机分支，含适配改动
# 或者从上游拉下来后打补丁：
#   git apply /path/to/patches/aerial-8h52-adapt.patch

export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export ANDROID_HOME=~/Library/Android/sdk
echo "sdk.dir=$ANDROID_HOME" > local.properties
./gradlew assembleStandardRelease
# 产物: app/build/outputs/apk/standard/release/app-standard-release.apk
```

需要 **SDK Platform 36 + Build-Tools 36**（`compileSdk = 36`）。
上游的签名密钥在 `local/`（不在版本库），没有它会回落到本机 debug key ——
首次安装没问题，之后要覆盖安装就得一直用同一个 key。

装 `standard` 版（带 HOME intent-filter）。这台电视的固件不拦带 HOME 的包，不需要 `guard` 版。

## 2. 装到电视

```bash
./tools/tv-adb.sh push <apk> /data/local/tmp/aerial.apk
./tools/tv-adb.sh shell 'pm install -r /data/local/tmp/aerial.apk'
```

## 3. 设为开机桌面

创维的 HOME 不由系统决定，而是厂商自己的 `sky_launcher` 服务读配置：

```xml
<!-- /system/pcfg/8H52_G3/config/general_config.xml 与 /data/ccos/general_config.xml 两处都要改 -->
<config name="DEFAULT_HOMEPAGE" value="app.orchard.tv/app.orchard.tv.MainActivity"/>
```

```sh
setprop persist.service.homepage.pkg app.orchard.tv
setprop persist.service.homepage.cls app.orchard.tv.MainActivity
setprop persist.service.starthomepage 1
```

改完重启，厂商的 `sky_launcher` 就会拉起它：

```
I/sky_launcher: ----parser---- DEFAULT_HOMEPAGE:app.orchard.tv/app.orchard.tv.MainActivity
I/ActivityManager: START u0 { cmp=app.orchard.tv/.MainActivity} from uid 0 on display 0
```

写 `/system` 要 root → 用 `tools/tv-root.py`（guardctl 通道，不需要 U 盘）。

顺带要设的项：

```sh
appops set app.orchard.tv SYSTEM_ALERT_WINDOW allow   # 开机后能自己弹到前台
appops set app.orchard.tv WRITE_SETTINGS allow        # 亮度调节
settings put secure screensaver_components app.orchard.tv/app.orchard.tv.dream.AerialDream
```

## 4. 我们改了什么（两处 bug）

### 4.1 「应用信息」点不动 → 改成 Aerial 自己画

**根因**：这台电视**没有装 AOSP 的 Settings**（`com.android.settings` 不存在，厂商用自己的
`com.coocaa.os.softsettings`），所以系统的应用详情页根本不存在：

```sh
$ am start -a android.settings.APPLICATION_DETAILS_SETTINGS -d package:com.emby.tv
Error: Activity not started, unable to resolve Intent { act=android.settings.APPLICATION_DETAILS_SETTINGS ... }
```

菜单里的「应用信息」原来直接发这个 Intent，结果什么都没发生（看起来就是"不可用"）。

**改法**（`MainActivity.kt`）：先看系统 Intent 能不能解析，能就照旧打开系统页（小米/TCL 行为不变），
不能就打开 Aerial 自己的应用信息面板（新增 `ui/home/AppInfoSheet.kt`）：

* 图标、名称、包名
* 版本（versionName + versionCode）、大小、安装时间
* 按钮：启动 / 卸载（可卸载的 App 才有）/ 关闭

### 4.2 个性化面板里二维码压住左侧内容

**根因**：壁纸那一行是 `LazyRow`，整体 `offset(x = -10.dp)`（给聚焦卡片放大 8% 留位置），
但行**没有裁剪**，超出右边界的第 4 张缩略图被画到了右边「用手机设置」二维码卡片的下面。

**改法**（`WallpaperSheet.kt`）：给这一行加 `clipToBounds()`，多出来的卡片在列边界被裁掉，
和二维码卡片之间留出空隙。

### 4.3 没有改的

* **长按菜单里的「卸载」保留**（用户要求）。它本来就只对可卸载的 App 显示
  （`removable = !system`，系统 App 不给卸载项）。
* 桌面自己不出现在应用网格里：上游代码已经 `found.remove(context.packageName)`，
  实测网格里确实没有 Aerial 的图标。

## 5. 顺带清理

原来的两个桌面都卸掉了，电视上现在只剩 Aerial 一个桌面：

| 包 | 处理 |
| --- | --- |
| `com.oversea.aslauncher`（早期用来转发到新桌面的同名壳） | 已卸载；厂商原版 AS Launcher 的 APK 留底在 `backup-tv/aslauncher-orig.apk` |
| `com.gathin.tvhome`（CleanYourTV 适配版，备选桌面） | 已卸载；APK 留底在 `apk/tvhome-clean-your-tv-2.5-zhCN.apk` |
| `app.orchard.tv`（Aerial） | **当前桌面** |

## 6. 这台电视上 Aerial 的实测（2026-10-21）

| 项 | 结果 |
| --- | --- |
| `adb install` | ✅ 无校验链，直接装上 |
| 开机自动接管 HOME | ✅ 重启后 `mResumedActivity = app.orchard.tv/.MainActivity` |
| 首页渲染 | ✅ 时钟、日期、天气（九江）、必应壁纸、应用网格 |
| 遥控器焦点 | ✅ 方向键正常，滚下去时钟收进状态栏 |
| 航拍屏保 | ✅ 能播，中文字幕正常 |
| 长按菜单 | ✅ 移动 / 隐藏 / 应用信息 / 卸载 |
| 应用信息 | ✅ 修复后显示 Aerial 自己的面板（版本/大小/安装时间/启动/卸载） |
| 个性化面板 | ✅ 修复后二维码不再压住左侧壁纸 |
| 崩溃 | ✅ 无（只有两条 `Unknown permission` 警告，API 22 不认识那两个权限） |

**注意**：厂商 `/system/etc/init.bigfish.sh` 开机会把时间设成 2017-01-01，
刚开机一两分钟桌面上的时钟是错的（8:00），联网后系统自己校回来。
