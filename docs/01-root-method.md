# Root 方案详解

## 1. 目标机环境

| 项 | 值 |
| --- | --- |
| 型号 | 创维 8H52_G3 |
| SoC | Hi3751V551 |
| Android | 5.1.1 (API 22) |
| ABI | armeabi-v7a（`ro.product.cpu.abilist` 里只有 32 位） |
| 分辨率 | 1920x1080 |
| 内核 | 3.18.16_s5 |
| 安全补丁 | 2017-06-01 |
| `ro.debuggable` | 1 |
| `ro.secure` | 1 |
| SELinux | Disabled |

关键有利条件：**SELinux 关闭 + setuid 生效**，因此一个自编译的 setuid-root 静态二进制就能拿到 uid 0。

## 2. 厂商留下的 root 后门

`/system/bin/hisi_boot_shell.sh` 是厂商出厂就带在系统里的调试脚本，由 init 管理：

```
service boot-shell /system/bin/hisi_boot_shell.sh
    class core
    user root
    oneshot
    disabled

on property:dev.bootcomplete=1
    start boot-shell
```

它的逻辑（简化）：

```sh
IS_U_USING=`df | grep mnt/usb | busybox cut -f 1 -d " "`   # 找到 U 盘挂载点
BOOT_SHELL_FILE=$IS_U_USING"/hi_boot_shell.sh"
...
. "$BOOT_SHELL_FILE"                                        # 以 root 身份 source U 盘脚本
```

也就是说：**U 盘根目录放一个 `hi_boot_shell.sh`，就会在开机（`dev.bootcomplete=1`）时以 root 身份执行**。

触发方式有两种：

1. 插着 U 盘开机 → init 自动跑 `boot-shell`；
2. 已经开机 → 任意 shell 用户执行 `setprop ctl.start boot-shell`（`ctl.*` 属性普通 shell 可写，电视实测可用）。

## 3. 我们的 payload

U 盘（FAT32）根目录：

```
su                 # ARMv7 静态二进制，setuid-root
hi_boot_shell.sh   # 入口：装 su + 执行待办任务
```

`hi_boot_shell.sh` 做三件事：

1. `mount -o rw,remount /system`；
2. 把 `su` 复制到 `/system/xbin/su`，`chown 0:0` + `chmod 6755`；
3. 如果 `/data/local/tmp/pending_task.sh` 存在，就执行它。

`su.c` 全文只有十几行：

```c
int main(int argc, char **argv) {
    setgid(0);
    setuid(0);
    if (argc >= 3 && strcmp(argv[1], "-c") == 0)
        execl("/system/bin/sh", "sh", "-c", argv[2], NULL);
    else if (argc > 1)
        execvp(argv[1], &argv[1]);
    else
        execl("/system/bin/sh", "sh", NULL);
    return 1;
}
```

用 musl 静态编译（`zig cc -target arm-linux-musleabihf -static`），约 8 KB，零动态依赖，
在 Android 5.1 的 ARMv7 上直接可跑。

## 4. 能力边界：为什么还需要 boot-shell

`su` 虽然是 uid 0，但**从 ADB 启动时继承 adbd 的 capability bounding set**：

```
$ adb shell cat /proc/self/status | grep Cap
CapEff: 0000000000000000
CapBnd: 00000000000000c0      # 只有 CAP_SETGID(6) / CAP_SETUID(7)
```

bounding set 只能减不能加，所以 setuid 出来的进程拿不到 `CAP_DAC_OVERRIDE` / `CAP_SYS_ADMIN`。实测：

| 操作 | `su -c` | boot-shell（init root） |
| --- | --- | --- |
| `mount -o rw,remount /system` | ❌ Permission denied | ✅ |
| `cat /data/ccos/general_config.xml` | ❌ Permission denied | ✅ |
| `pm disable-user --user 0 <pkg>` | ✅ | ✅ |
| `setprop persist.*` | ✅ | ✅ |
| 删 `/data/data/<pkg>` | ❌ | ✅ |

所以本工具链分两条通道：

* **通道 A（日常）**：`adb shell /system/xbin/su -c "..."`，uid 0，操作应用/属性足够；
* **通道 B（系统级）**：`tools/run-task.sh` → 推送任务 → `setprop ctl.start boot-shell` → init 上下文执行，拿到完整 root。

## 5. 过程中踩到的坑

1. **`adb root` 不可用**：`ro.secure=1`，adbd 重启后仍是 `shell` 用户，走了上面的后门路线。
2. **ADB 直连失败**：macOS 直连 `192.168.0.9:5555` 报 `No route to host`，但普通 TCP 可达，
   因此用 `tools/tv-adb-proxy.py` 做 `127.0.0.1:15555 -> 192.168.0.9:5555` 转发。
3. **电视 toybox 很残缺**：没有 `head` / `tail` / `sed` / `strings` / `sqlite3`，
   所有日志解析、配置改写、数据库处理都在 Mac 上做，再 push 回电视。
4. **U 盘挂载点不是 `/mnt/usb`**：实际是 `/mnt/usb/sda1`（`df` 输出的挂载点），
   所以脚本里用 `USB_DIR=${BOOT_SHELL_FILE%/*}` 动态取目录，不能写死。
5. **酷开桌面会"复活"**：`com.coocaa.skycast.tool` 内置 `EmergencyUpgradeEngine`，
   会从 `apk-sky-fs.coocaa.ottcn.com` 下载新版 `com.tianci.movieplatform` 并安装。
   必须禁用它 + hosts 屏蔽该域名，否则桌面每隔一段时间就被拉回来。
6. **Desktop 卸载会回退到系统版**：`com.tianci.movieplatform` 在 `/data/app` 有更新版，
   `/system/vendor/ccos/app/SkyMovie` 还有系统版。`pm uninstall` 会回退，
   所以改用 `pm disable-user`（冻结），可随时 `pm enable` 恢复。

## 6. 关键命令速查

```sh
# 触发一次 root 任务
adb shell 'setprop ctl.start boot-shell'
adb shell 'cat /data/local/tmp/boot_task.log'

# 验证 root
adb shell '/system/xbin/su -c id'

# 冻结 / 恢复某个包
adb shell 'pm disable-user --user 0 com.tianci.movieplatform'
adb shell 'pm enable com.tianci.movieplatform'

# 强制某个 Activity 启动
adb shell 'am start -n com.oversea.aslauncher/.ui.main.MainActivity'

# 截图（用于自动化验收）
adb exec-out screencap -p > /tmp/screen.png
```
