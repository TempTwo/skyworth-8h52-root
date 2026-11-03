# 第三方 APK

本仓库**不分发**任何第三方 APK（版权原因）。请自行从官方渠道下载：

| 用途 | 项目 | 链接 | 说明 |
| --- | --- | --- | --- |
| 备选桌面 | FLauncher 0.18.0 | <https://gitlab.com/flauncher/flauncher> | API 21+，本机验证可用 |
| 高版本桌面 | LTvLauncher | <https://github.com/leanbitlab-org/LtvLauncher/releases> | 2026 版在 API 22 上启动即崩（实测） |
| 媒体客户端 | Jellyfin for Android TV | <https://jellyfin.org/downloads/> | 0.19.10 已在电视上验证安装 |

安装方法（需要 ADB）：

```sh
adb install -r <apk>
```

电视直连 192.168.0.9:5555 不通时，用 `tools/tv-adb.sh`（内含本地 TCP 代理）。

## Aerial 桌面（当前使用的桌面）

`app.orchard.tv`（Aerial，MIT）**不在本仓库分发**：它是基于上游
<https://github.com/pengchujin/aerial-tv> 自己编译的，改动以补丁形式放在
[`patches/aerial-8h52-adapt.patch`](../patches/aerial-8h52-adapt.patch)，
编译与安装步骤见仓库根目录 [`README.md`](../README.md) 第 3 节。
本机编译好的 APK 放在 `apk/aerial-standard-1.18-api22.apk`（被 .gitignore 排除，不入库）。
