# 第三方 APK

本仓库**不分发**任何第三方 APK（版权原因）。请自行从官方渠道下载：

| 用途 | 项目 | 链接 | 说明 |
| --- | --- | --- | --- |
| 备选桌面 | FLauncher 0.18.0 | <https://gitlab.com/flauncher/flauncher> | API 21+，本机验证可用 |
| 高版本桌面 | LTvLauncher | <https://github.com/leanbitlab-org/LtvLauncher/releases> | 2026 版在 API 22 上崩溃，见 `docs/03-launcher.md` |
| 媒体客户端 | Jellyfin for Android TV | <https://jellyfin.org/downloads/> | 0.19.10 已在电视上验证安装 |

安装方法（需要 ADB）：

```sh
adb install -r <apk>
```

电视直连 192.168.0.9:5555 不通时，用 `tools/tv-adb.sh`（内含本地 TCP 代理）。
