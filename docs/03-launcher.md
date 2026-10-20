# 桌面（Launcher）选型

## 1. 结论

| 桌面 | 包名 | 结果 |
| --- | --- | --- |
| **AS Launcher** ✅ | `com.oversea.aslauncher` | **采用**，已设为开机自启桌面 |
| FLauncher | `me.efesser.flauncher` | 可用但界面朴素，按要求移除 |
| LTvLauncher | `com.leanbitlab.ltvL` | API 22 上启动即崩，按要求移除 |

## 2. AS Launcher（当前使用）

* 版本 `1.1.0.2`，`targetSdk=26`，ABI `armeabi-v7a`，在 Android 5.1 上运行正常。
* 入口：`com.oversea.aslauncher/.ui.main.MainActivity`。
* 中文界面、星空壁纸、常用应用区、桌面自带设置入口。

设为开机自启需要同时改三处（缺一不可）：

```xml
<!-- /system/pcfg/8H52_G3/config/general_config.xml 与 /data/ccos/general_config.xml -->
<config name="DEFAULT_HOMEPAGE" value="com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity"/>
```

```sh
setprop persist.service.homepage.pkg com.oversea.aslauncher
setprop persist.service.homepage.cls com.oversea.aslauncher.ui.main.MainActivity
setprop persist.service.starthomepage 1
```

厂商开机流程每次都从配置里读 `DEFAULT_HOMEPAGE`，所以改配置即改开机桌面；
属性只是为了运行期立刻生效。

## 3. FLauncher（备选，MIT 开源）

* 源码 <https://gitlab.com/flauncher/flauncher>，最新版本 0.18.0（2023-04，之后停更）。
* Flutter 写的，API 21+ 可跑，是这台机器上最稳的开源桌面。
* 想换回来的话：把 APK 装回去，再把 `DEFAULT_HOMEPAGE` 改回
  `me.efesser.flauncher/me.efesser.flauncher.MainActivity`。

## 4. LTvLauncher（高版本、人气旺，但本机不兼容）

* 仓库 <https://github.com/leanbitlab-org/LtvLauncher>（≈400 star，2026-10 仍在更新），
  提供 `armeabi-v7a` 包，APK 的 `minSdkVersion=21`，**按理应该能装**。
* 实测安装成功，但一启动就崩：

```
E/AndroidRuntime: FATAL EXCEPTION: main
java.lang.NoClassDefFoundError: Failed resolution of: Landroid/app/usage/NetworkStatsManager;
    at b1.r.a(SourceFile:1)
    at com.leanbitlab.ltvL.MainActivity.m(SourceFile:1)
Caused by: ClassNotFoundException: Didn't find class "android.app.usage.NetworkStatsManager"
```

`android.app.usage.NetworkStatsManager` 是 **API 23** 才有的类，电视是 API 22。
这是上游的兼容性 bug（状态栏"流量统计"功能没做版本判断）。

想用的话有两条路：

1. **打补丁**：用 `apktool` 反编译 → 在 `b1/r.smali` 的方法入口加
   `Build.VERSION.SDK_INT < 23` 判断 → 重打包签名；
2. **改源码重编**：clone 仓库，在调 `NetworkStatsManager` 的 Java/Kotlin 侧加版本判断，
   `flutter build apk --target-platform android-arm`（需要 Flutter SDK，minSdk 保持 21）。

> 本仓库不内置被修改的第三方 APK，请自行按上述步骤处理。

## 5. 其它备选（未安装）

* Projectivy Launcher —— 界面最漂亮，但最低 API 要求高，5.1 基本无望。
* ATV Launcher / Wolf Launcher —— 商业/小众，5.1 可用但资料少。
