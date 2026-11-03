# 第三方 APK

本仓库**不分发**任何第三方 APK（版权原因），只给出处。

## Aerial 桌面（本机使用，直接可装）

`app.orchard.tv`（tvOS 风格桌面，MIT）——在
[pengchujin/aerial-tv](https://github.com/pengchujin/aerial-tv) 上针对
**创维 8H52_G3** 二次修改后的完整源码与 Releases 都在：

👉 **<https://github.com/TempTwo/aerial-tv-skyworth>**

* Releases 页有可直接安装的 APK（v1.20 / v1.21，均已在 8H52_G3 实测）；
* 与上游同一个签名 key，`adb install -r` 即可覆盖升级、数据不丢；
* 安装与设为开机桌面（`DEFAULT_HOMEPAGE`）的完整步骤见仓库根
  [`README.md`](../README.md) 第 3 节。

## 其它已在电视上验证过的 APK

| 用途 | 项目 | 链接 | 说明 |
| --- | --- | --- | --- |
| 媒体客户端 | Jellyfin for Android TV | <https://jellyfin.org/downloads/> | 0.19.10 已实测 |
| 音乐播放器 | walkman-tv（随便听） | 适配实录见 [`docs/07-walkman-tv.md`](../docs/07-walkman-tv.md) | 适配源码/补丁见 `patches/` |

电视直连 192.168.0.9:5555 不通时，用 `tools/tv-adb.sh`（内含本地 TCP 代理）。
