#!/system/bin/sh
# U 盘入口（刷完固件后自动恢复用）
#
# 由 init 的 boot-shell 服务（user root）在 dev.bootcomplete=1 时 source 本文件。
# 刷完原厂固件后开机 → 本脚本自动：
#   1) 配好静态 IP（否则 adb 连不回来）—— 创维的静态 IP 原本由"软设置"App 配置，App 没了就丢
#   2) 安装 /system/xbin/su（setuid root）
#   3) 安装 Aerial 桌面（U盘上的 aerial.apk）并把厂商配置里的 DEFAULT_HOMEPAGE 指过去
#   4) 修厂商 boot-shell 脚本（CRLF/丢失自愈）
#   5) 清理指向已删 APK 的悬空包记录，避免开不了机
#   6) 执行 /data/local/tmp/pending_task.sh
#
# 电视的 toybox 没有 tr/sed/head/cut/awk/base64，一律用 busybox 的 applet。

LOG=/data/local/tmp/boot_task.log
BB=/system/bin/busybox
exec >>"$LOG" 2>&1

echo "=== usb root entry $(date) ==="
id

VENDOR=/system/bin/hisi_boot_shell.sh
USB_DIR=${BOOT_SHELL_FILE%/*}
if [ -z "$USB_DIR" ] || [ "$USB_DIR" = "$BOOT_SHELL_FILE" ]; then
    USB_DIR=$IS_U_USING
fi
[ -z "$USB_DIR" ] && USB_DIR=/mnt/usb/sda1
echo "USB_DIR=$USB_DIR"

TV_IP=${TV_IP:-192.168.0.9}
TV_GW=${TV_GW:-192.168.0.1}
CFG=/system/pcfg/8H52_G3/config/general_config.xml

# ---- 1) 静态 IP ----
echo "--- 配置静态 IP $TV_IP ---"
$BB ip addr show dev eth0 2>/dev/null | $BB grep -q "inet $TV_IP" || \
    $BB ip addr add $TV_IP/24 dev eth0 2>/dev/null && echo "已加 $TV_IP/24"
$BB ip route show 2>/dev/null | $BB grep -q "default" || \
    $BB ip route add default via $TV_GW dev eth0 2>/dev/null && echo "已加默认路由 $TV_GW"
$BB ip addr show dev eth0 2>/dev/null

# ---- 2) 自愈厂商脚本 ----
if [ ! -f "$VENDOR" ]; then
    echo "--- 厂商脚本丢失，尝试还原 ---"
    for src in "$USB_DIR/hisi_boot_shell.sh.fixed" "$USB_DIR/hisi_boot_shell.sh.orig" "/system/etc/hisi_boot_shell.sh.fixed"; do
        [ -f "$src" ] || continue
        mount -o rw,remount /system
        cp "$src" "$VENDOR"; chown 0:0 "$VENDOR"; chmod 755 "$VENDOR"
        mount -o ro,remount /system
        echo "已从 $src 还原"; break
    done
elif ! sh -n "$VENDOR" 2>/dev/null; then
    echo "--- 厂商脚本语法异常，去 CR 修复 ---"
    T=/data/local/tmp/hbs.fixed
    $BB tr -d '\r' < "$VENDOR" > "$T"
    if [ -s "$T" ] && sh -n "$T" 2>/dev/null; then
        cp "$VENDOR" /data/local/tmp/hisi_boot_shell.sh.broken.bak
        mount -o rw,remount /system
        cat "$T" > "$VENDOR"; chown 0:0 "$VENDOR"; chmod 755 "$VENDOR"
        mount -o ro,remount /system
        echo "已修复"
    else
        rm -f "$T"
        echo "去 CR 失败，尝试用 .fixed 覆盖"
        if [ -f "$USB_DIR/hisi_boot_shell.sh.fixed" ]; then
            mount -o rw,remount /system
            cp "$USB_DIR/hisi_boot_shell.sh.fixed" "$VENDOR"; chown 0:0 "$VENDOR"; chmod 755 "$VENDOR"
            mount -o ro,remount /system
        fi
    fi
else
    echo "厂商脚本语法正常"
fi

# ---- 3) 清悬空包记录 ----
echo "--- 清理悬空包记录 ---"
pm list packages -f 2>/dev/null | $BB sed 's/^package://' > /data/local/tmp/.pl
while IFS= read -r line; do
    path=${line%%=*}; pkg=${line#*=}
    [ -f "$path" ] && continue
    echo "悬空: $pkg"
    pm uninstall "$pkg" 2>/dev/null || \
        $BB sed -i "/name=\"$pkg\"/,/<\/package>/d" /data/system/packages.xml 2>/dev/null
done < /data/local/tmp/.pl

# ---- 4) 装 su ----
if [ ! -x /system/xbin/su ] && [ -f "$USB_DIR/su" ]; then
    echo "--- 安装 su ---"
    mount -o rw,remount /system
    cp "$USB_DIR/su" /system/xbin/su; chown 0:0 /system/xbin/su; chmod 6755 /system/xbin/su
    mount -o ro,remount /system
fi

# ---- 5) 装 Aerial 桌面 + 改厂商配置指向 ----
if [ -f "$USB_DIR/aerial.apk" ]; then
    echo "--- 安装 Aerial 桌面 ---"
    pm install -r "$USB_DIR/aerial.apk" 2>&1 | $BB tail -2
fi
if [ -f "$CFG" ]; then
    mount -o rw,remount /system
    if $BB grep -q "DEFAULT_HOMEPAGE" "$CFG"; then
        $BB sed -i 's|<config name="DEFAULT_HOMEPAGE" value="[^"]*"/>|<config name="DEFAULT_HOMEPAGE" value="app.orchard.tv/app.orchard.tv.MainActivity"/>|' "$CFG"
        chown 0:0 "$CFG"; chmod 644 "$CFG"
        echo "已把 DEFAULT_HOMEPAGE 指向 Aerial"
        $BB grep DEFAULT_HOMEPAGE "$CFG"
    fi
    mount -o ro,remount /system
fi
setprop persist.service.homepage.pkg app.orchard.tv
setprop persist.service.homepage.cls app.orchard.tv.MainActivity
setprop persist.service.starthomepage 1

# ---- 6) 待办任务 ----
if [ -f /data/local/tmp/pending_task.sh ]; then
    echo "--- running pending task ---"
    sh /data/local/tmp/pending_task.sh
fi

echo "=== usb root entry done ==="
