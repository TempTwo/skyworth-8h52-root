# walkman-tv（随便听）在创维 8H52_G3 上的适配

> 上游：<https://github.com/SincereXing/walkman-tv>（Apache-2.0，Kotlin + Compose for TV 的原生 Android TV 音乐播放器）
> 电视：创维 8H52_G3 / Hi3751V551 / Android 5.1.1（API 22）/ armeabi-v7a / 1.5 GB 内存
> 适配日期：2026-10-21

## 0. 仓库策略

同 Aerial 一样：**不往上游仓库提交任何改动**。本机改动以补丁形式放在本仓库：

```
patches/walkman-tv-api22.patch      # 相对上游 main 的完整 diff（3 个文件，+8 行）
```

本机编译目录在仓库外的 `../walkman-tv`（clone 自上游），改动留在本地工作区，不推送。

## 1. 这个 App 是什么

- 面向大屏、遥控器友好的 **Android TV 音乐播放器**（Compose for TV，暗色界面、大封面、逐行滚动歌词、旋转黑胶）
- 用 **洛雪音乐（lx-music）v4 自定义源的 JS 解析协议**，并扩展了更多音质档位（SQ / Hi-Res）
- 内置聚合源：**酷我 / 网易云 / 酷狗 / QQ音乐** 的推荐歌单、排行榜、搜索
- 本地音乐导入（SAF / 文件浏览器）、歌单管理、手机扫码搜索与输入、手机设置页
- 上游版本 1.4.2（versionCode 33）

## 2. 适配了什么（为什么不能直接装）

上游要求 **minSdk 23（Android 6.0）**，这台电视是 **API 22**，所以要改三处：

| 改动 | 原因 |
| --- | --- |
| `build.gradle`：`minSdkVersion 23 → 22` | 电视是 API 22 |
| `app/build.gradle`：Media3 `1.10.1 → 1.8.0` | **Media3 1.9+ 要求 minSdk 23**，不降版本 manifest 合并就会失败（1.8 是最后支持 API 21 的版本） |
| `app/build.gradle`：`coreLibraryDesugaringEnabled true` + `desugar_jdk_libs:2.1.5` | API 22 没有 `java.time`，脱糖后 Media3/OkHttp 内部照常用 |
| `gradle-wrapper.properties`：Gradle `8.8-all → 8.14.3-bin` | 只是构建环境（8.8 的压缩包在当前网络下反复下载失败；8.14.3 与 AGP 8.6 兼容） |

应用代码**一行没改**：上游对 `SDK_INT` 的防护本来就写得很到位（`SettingsScreen.kt`、`LocalImportDialog.kt`、`UpdateManager.kt` 里的版本判断），
运行时权限走 androidx 的 `ActivityResultContracts.RequestPermission`（API 22 上权限安装时即授予，不会弹框）。

## 3. 编译

```bash
git clone https://github.com/SincereXing/walkman-tv.git
cd walkman-tv
git apply /path/to/patches/walkman-tv-api22.patch

export JAVA_HOME=$(/usr/libexec/java_home -v 17)
export ANDROID_HOME=~/Library/Android/sdk
./gradlew assembleRelease
# 产物: app/build/outputs/apk/release/walkman-tv-1.4.2-{universal,armeabi-v7a,arm64-v8a,x86_64}-release.apk
```

这台电视是 32 位 ARM，装 **armeabi-v7a** 或 **universal** 都可以（universal 18.8 MB / armeabi-v7a 17.0 MB）。

```sh
./tools/tv-adb.sh push <apk> /data/local/tmp/walkman.apk
./tools/tv-adb.sh shell 'pm install -r /data/local/tmp/walkman.apk'
```

## 4. 电视上的实测（2026-10-21）

| 项 | 结果 |
| --- | --- |
| 安装 | ✅ universal 包一次装上 |
| 启动 | ✅ 无崩溃（minSdk 22 / Media3 1.8 / Compose for TV 都正常） |
| 首页推荐 | ✅ 酷我 / 网易云 / 酷狗 / QQ音乐 的推荐歌单、封面、轮播图都出来了 |
| 排行榜 / 歌单 / 搜索 | ✅ 可用 |
| 歌曲列表 | ✅ 曲目、歌手、时长、**SQ / Hi-Res 音质角标** 正常 |
| 播放 | ✅ **全屏播放器正常**：黑胶旋转、逐行滚动歌词、波形动画、进度条推进、格式角标 `STD · MP3 128kbps` |
| 解码 | ✅ 走电视硬解 `OMX.hisi.audio.decoder.mp3`，音频 HAL 正常出流 |
| 内存 | ✅ 进程常驻约 190 MB，系统可用内存仍有 800 MB+ |

**已知限制**：不配置洛雪自定义音源时，**在线歌曲只能播 11 秒试听片段**（免费源的通病），
歌单/歌词/界面都正常，完整歌曲需要在「设置 → 音源」里填入自己的洛雪 v4 自定义源（JS 文件地址）。
本地音乐导入走电视本机目录，不受这个限制。

## 5. 顺带一提：红果 TV（hongguoTV）为什么没继续做

同一天试了 <https://github.com/N3urda/hongguoTV> 的 Kotlin 原生版（红果短剧客户端），
适配到 API 22 本身没问题（降 minSdk + 换 `getSystemService(Class)` + 换 `PriorityQueue(Comparator)` + 换
`ConnectivityManager.getActiveNetwork()`，首页/搜索/详情/选集在电视上都正常）。

**但播放接口是字节/番茄的内部接口，2026-10-13 起大批用户同时报"无法播放"**（上游 issue #16/#17/#19），
取流入口 `/novel/player/multi_video_model/v1/` 变成「HTTP 200 + 空响应体」，
社区补丁（换 `preload/v1/` + 简化签名 + 随机 device_id）到 10-18 还能用，**今天（10-21）又收紧了**——
连 onedrama 的实现逐字节复刻后也是 200 空体。这类接口上游会来回开关，我们改不动，因此放弃这条线，
电视上已把 `com.hongguotv.nativeapp` 卸载。
