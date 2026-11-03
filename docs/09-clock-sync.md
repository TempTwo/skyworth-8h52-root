# 开机自动校时（系统时间持久化）

> 记录时间：2026-10-23
> 现象：这台 8H52 没有任何 RTC（`/dev/rtc*`、`/sys/class/rtc`、`/dev/alarm` 全无），
> 固件 `/system/etc/init.bigfish.sh` 第 19 行每次开机执行
> `busybox date -s 201701010000.00`，把内核时钟写死回 2017-01-01 08:00
> （logcat 时间戳、TVBox 右上角，全系统一致错）。
> 桌面 Aerial 的屏显时钟走自己的 HTTP 校时，所以只有它是对的——其余 App 都错。

## 方案（一次性系统改动，已验证）

`init.bigfish.sh` 里删掉 2017 那行，改为开机后台拉起
`/system/etc/timesync.sh`：等默认路由出现后，向**网关的 clash HTTP API
（:9090）**发 `GET /version`，用响应头 `Date:`（RFC1123，GMT）换算 epoch，
`busybox date -s @<epoch>` 一次性写内核时钟。备选源：网关 ：80/:8080 的
HTTP Date 头、网关 UDP NTP（123）。全程 LAN 直连——这台电视的
busybox DNS（裸 UDP 53）和 shell 侧出站 WAN 套接字都被软路由的
OpenClash 拦掉，但网关本身永远可达，且网关自身时钟是 NTP 保准的。

网络细节实测（2026-10-23）：

| 探测 | 结果 |
| --- | --- |
| `busybox nslookup www.baidu.com` | ❌ 解析失败（UDP 53 被拦） |
| `busybox wget http://110.242.68.66/` | ❌ 卡在 Connecting（shell 出站被丢） |
| App 内 HTTP（走 netd 代理路径） | ✅ 正常 |
| `nc 192.168.0.1:9090` Date 头 | ✅ 正确 GMT 时间 |

## 电视上的现状

| 文件 | 说明 |
| --- | --- |
| `/system/etc/init.bigfish.sh` | 已补丁，md5 `0ab6c065841cdf727b426d25f94266f2`（原版留底 md5 `3fc4f9eb389a197c4409c5de1c3fa5d4`） |
| `/system/etc/timesync.sh` | 校时脚本，md5 `1c5e8613de745eb820dd614abd3c201f`，0755 root:root |
| `/data/local/tmp/init.bigfish.sh.bak` | 改动前的厂商原版 |
| `/data/local/tmp/boot_clock.log` | timesync 的落盘日志（只在真正改时钟时写） |
| `/mnt/usb/sda1/payload/` | U 盘上的原件：`timesync.sh`、`init.bigfish.sh.new`、`init.bigfish.sh.orig`、`tasks/80_sync_boot_clock.sh` |

bigfish 的改动只有一处（原第 19 行）：

```sh
# NO RTC on this board - the stock line pinned the clock to 2017 on every boot.
# The kernel clock is synced to the home router over the LAN instead, no DNS,
# no WAN sockets: /system/etc/timesync.sh (log: /data/local/tmp/boot_clock.log).
busybox sh /system/etc/timesync.sh &
```

## 安装方式（不重启电视，走 boot-shell 通道 C）

前提：U 盘在位（内含 `payload/timesync.sh` + `payload/init.bigfish.sh.new`
+ `payload/tasks/80_sync_boot_clock.sh`，md5 与 `payload/` 仓库内一致）、
`/data/local/tmp/pending_task.sh` 指向该任务。

```sh
./tools/tv-adb.sh push payload/timesync.sh /data/local/tmp/stage/           # 先 adb push（二进制安全）
./tools/tv-adb.sh shell 'su -c "cp /data/local/tmp/stage/* /mnt/usb/sda1/payload/."'
./tools/tv-adb.sh shell 'setprop ctl.start boot-shell'                      # init root 全 caps 跑 payload
./tools/tv-adb.sh shell 'busybox cat /data/local/tmp/boot_task.log'         # 看 clock task 段
```

之后重启即生效（无需 U 盘参与：bigfish 直接连网关，不再依赖 U 盘）。

## 验证记录（2026-10-23 实测）

1. `ctl.start boot-shell`：日志显示 `uid=0(root)`，两文件按预期 md5 装入，
   实时校时一行 `clock already within 60s (via (gateway :9090 ...))`；
2. 重启电视：adb 回来后 `date` = `Fri Oct 23 14:11:12 CST 2026`（开机后
   内核起点是 `01-01 08:00`，timesync 在路由就绪后一次写对）；
   桌面校时日志 `clock corrected by -998ms`（App 自己的 HTTP 校时与系统一致）；
3. 桌面截图：`10月23日 星期五 丙午年九月十四 14:14`，TVBox 右上角同源
   （内核时钟）正确。

## 回滚

改 `/system` 需要完整 root：**U 盘 boot-shell 通道**（`run-task.sh`），不依赖 U 盘的
guard/tvroot 通道在这版固件上已失效，见下方括号说明与仓库 README §2.4。

```sh
# 把下面内容存为 /data/local/tmp/uninstall-clock-task.sh 再 run-task.sh 执行
#   mount -o rw,remount /system
#   cp /data/local/tmp/init.bigfish.sh.bak /system/etc/init.bigfish.sh
#   rm -f /system/etc/timesync.sh
#   chown 0:0 /system/etc/init.bigfish.sh; chmod 755 /system/etc/init.bigfish.sh
#   mount -o ro,remount /system

./tools/run-task.sh /data/local/tmp/uninstall-clock-task.sh
```

> 固件版本注记（2026-10-23，V020.006.110 实测）：厂商守护进程
> `coocaa_guard` 已改用抽象 socket `coocaa_guard_ctrl_cmd`
> （客户端需 24 字节地址长度，见 `tools/gaddr.c`），旧路径
> `/data/ccos/guard.sock` 不存在；且 `/system/bin/skybusybox` 缺失导致
> guard 的 `start_telnetd`/`shellexec` 静默失败——**"不插 U 盘的完整
> root 通道"已不可用，改 /system 一律走 U 盘 boot-shell**。

## 风险与边界

* **网关不在线时**：timesync 轮询约 20 分钟后放弃，内核时钟停留在内核起点
  （`01-01 08:00`）——和网恢复后需重启电视（或手动 `date -s`）。属已知边界。
* 路由时钟本身漂移的话，电视跟着漂（同源）。clash 服务的 Date 头精度为秒。
* 固件 OTA 若重刷 `init.bigfish.sh` 会覆盖补丁：md5 变了就按「安装方式」重跑一次。
* `/data/local/tmp/pending_task.sh` 是持久触点：U 盘插着的话，电视每次开机
  bootcomplete 都会重跑 80 号任务（幂等，已装过只是「refresh only」+ 实时校时，
  无副作用）；拔掉 U 盘也不影响校时（bigfish 直接连网关）。
