# 两条 root 通道（不插 U 盘也能拿 root）

> 记录时间：2026-10-21
> 起因：厂商的 `/system/bin/hisi_boot_shell.sh` 被误写成 CRLF，`init` 起不来 `boot-shell` 服务，
> 原来的"插 U 盘拿 root"通道断掉。本文记录**不依赖 U 盘**的第二条通道，以及原通道的修复方法。

---

## 0. 结论速览

| 通道 | 是否需要 U 盘 | 能力 | 恢复方式 |
| --- | --- | --- | --- |
| A. `su` | ❌ | uid=0，但只有 `CAP_SETUID/CAP_SETGID`（0xc0） | 自带 |
| B. `coocaa_guard` socket → telnetd | ❌ | **完整 root（CapEff=0x3fffffffff）** | `su -c "/system/xbin/tvroot"` |
| C. 厂商 `boot-shell` 服务 | ✅ | 完整 root | 插 U 盘 / `setprop ctl.start boot-shell` |

固化在设备上的文件：

| 路径 | 说明 |
| --- | --- |
| `/system/xbin/su` | setuid-root 二进制（通道 A 的入口） |
| `/system/xbin/guardctl` | 通道 B 的客户端（连守护进程 socket 下发命令） |
| `/system/xbin/tvroot` | 一键起 root telnetd（`su -c "/system/xbin/tvroot"` → telnet 4149） |
| `/system/bin/hisi_boot_shell.sh` | **已修复**的厂商脚本（纯 LF，语法校验通过） |
| `/system/etc/hisi_boot_shell.sh.fixed` | 修好的副本，坏了就拷回去 |
| `/system/etc/hisi_boot_shell.sh.orig` | 厂商原版留底（纯 LF） |

> 通道 B **不随重启消失**：`su` 与 `guardctl` 都在 `/system` 里，重启后照样能用。

---

## 1. 通道 B 的原理（逆向 `/system/vendor/bin/coocaa_guard`）

`coocaa_guard` 是厂商的 root 守护进程，由 `init` 以 **root + 完整 capability** 启动：

```
$ cat /proc/1500/status
Uid:  0  0  0  0
CapEff: 0000003fffffffff
```

它会创建一个 Unix socket：

```
/data/ccos/            # 0700 system:system
/data/ccos/guard.sock  # 属主 1000:1000
```

socket 目录权限是 0700 且属主是 `system`，所以**只有 uid=1000 的进程能进去**。
好在我们的 `su` 带有 `CAP_SETUID/CAP_SETGID`（capability 0xc0），可以
`setgid(1000) + setuid(1000)` 把自己降成 system 再连 socket。

守护进程的命令协议是**明文单行**，从二进制里读出来的命令表：

| 命令 | 行为 |
| --- | --- |
| `shellexec <命令>` | 以 root 执行命令（内部 re-exec 自身：`coocaa_guard shellexec <cmd>`） |
| `start_telnetd` | 启动 `busybox telnetd -p 4149 -l /system/bin/sh`（**root**） |
| `stop_telnetd` | 停止 |
| `accredit_read_input_event` | 放开 `/dev/input` 权限 |
| `recovery_start` | 清理并重启酷开桌面 |
| `get_all_input_devices_info` | 导出 `/data/input_devices` |

连接后发一条命令，守护进程固定回 `ok`（注意：`ok` 只表示"收到了命令"，
不代表执行成功），随后关闭连接。

### 用法

```bash
# 1) 编译客户端（ARMv7 静态）
./tools/build-guardctl.sh

# 2) 推到电视
./tools/tv-adb.sh push tools/guardctl /data/local/tmp/guardctl
./tools/tv-adb.sh shell 'chmod 755 /data/local/tmp/guardctl'

# 3) 起一个 root telnet（走 su 降权到 system 连 socket）
./tools/tv-adb.sh shell 'su -c "/data/local/tmp/guardctl --raw start_telnetd"'

# 4) 连进去
telnet 192.168.0.9 4149      # uid=0(root)，CapEff 完整
```

设备上已经装好的快捷方式：

```bash
./tools/tv-adb.sh shell 'su -c "/system/xbin/tvroot"'
```

`tvroot` 就是把上面第 3 步固化成一条命令，并打印电视 IP。

### 为什么 `shellexec` 用不了、`start_telnetd` 能用

`shellexec` 的实现是 `execv("coocaa_guard", {"shellexec", cmd, NULL})`：
用的是 `execv`（**不查 PATH**）且路径没有 `/`，所以在非 `/system/vendor/bin`
的工作目录下必然 `ENOENT`，命令根本没跑起来。
`start_telnetd` 用的是 `execvp` + 绝对路径（找不到时回退到 `busybox`），所以正常。

## 2. 通道 C（厂商 boot-shell）坏了怎么修

### 症状

```sh
sh -n /system/bin/hisi_boot_shell.sh
# /system/bin/hisi_boot_shell.sh[11]: syntax error: 'if' unmatched
```

`init.hi3751.rc` 里的服务：

```
service boot-shell /system/bin/hisi_boot_shell.sh
    user root
    group root
    oneshot
    disabled
```

脚本被写成 CRLF 后，`mksh` 解析失败，服务立刻退出，
于是"插 U 盘 = 开机自动 root"这条通道就没了。

### 修复（需要通道 B 或 C 之一）

```sh
# 用 U 盘里的原件覆盖（init 通道里跑，权限最大）
mount -o rw,remount /system
cp /mnt/usb/sda1/hisi_boot_shell.sh.fixed /system/bin/hisi_boot_shell.sh
chown 0:0 /system/bin/hisi_boot_shell.sh
chmod 755 /system/bin/hisi_boot_shell.sh
mount -o ro,remount /system
sh -n /system/bin/hisi_boot_shell.sh    # 期望无输出
```

也可以直接用通道 B：

```sh
./tools/tv-root.py 'sh /data/local/tmp/repair.sh'
```

### U 盘入口脚本自带自愈

`payload/hi_boot_shell.sh`（写在 U 盘根目录、被厂商脚本 source 的那个）
每次运行都会先检查厂商脚本：

* 语法正常 → 什么都不做；
* 语法错误 → 用 `busybox tr -d '\r'` 去掉 CR 原地修复；
* 文件丢失 → 用 U 盘上的 `hisi_boot_shell.sh.orig` 还原。

> 电视的 toybox **没有** `tr/sed/head/tail/awk/od`，写脚本时一律用 `busybox <applet>`。

---

## 3. 血泪教训：不要用 `adb shell cat` 传文件

事故经过：

```sh
adb shell 'cat /system/bin/hisi_boot_shell.sh > /tmp/x.sh'   # ❌ 文本模式
```

`adb shell` 走的是 pty，**LF 会被转换成 CRLF**。于是备份"原文件"的动作，
反过来把目标文件写成了 CRLF，直接把厂商的 root 后门脚本写坏了，
而能修它的通道正好就是那个被写坏的脚本 —— 死锁。

正确做法：

```sh
adb pull /system/bin/hisi_boot_shell.sh ./backup.sh   # ✅ 二进制
adb push ./hisi_boot_shell.sh.fixed /data/local/tmp/  # ✅ 二进制
```

同理：判断文件是否被污染，要用 `busybox md5sum` 比对，不要用文本工具看。

---

## 4. 已验证的恢复流程（2026-10-21 实测）

1. 厂商脚本被写成 CRLF（1106 字节），`sh -n` 报错；
2. 用通道 B（telnet root）把修好的版本（1078 字节）写回 `/system/bin/`；
   `busybox md5sum` 与 `.fixed` 副本一致，`sh -n` 通过；
3. `setprop ctl.start boot-shell` → 厂商脚本找到 U 盘 → source 我们的入口 →
   日志 `/data/local/tmp/boot_task.log` 显示 `uid=0(root)`；
4. 重启后再验证：root 仍在、桌面仍是 `app.orchard.tv`（Aerial）、通道 B 仍可用。

## 5. 不做什么

* **不加开机自启的看门狗**：`/system/etc/init.bigfish.sh` 保持厂商原样
  （`md5 = 891db002bccfb30ea7617f4475358087`），不做开机自动修复。
  脚本坏了就按上面第 2 节手动跑一次修复脚本即可。
* 不改 `init.rc`、不刷机、不动 boot 分区。
