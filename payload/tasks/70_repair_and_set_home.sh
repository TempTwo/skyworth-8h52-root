#!/system/bin/sh
# 任务: 修复厂商 boot-shell 脚本（CRLF/丢失） + 装好固化件 + 指定默认桌面
#
# 需要 root（本任务请通过 boot-shell 或 guardctl 通道执行）：
#   ./tools/run-task.sh ./payload/tasks/70_repair_and_set_home.sh
#
# 说明: 电视的 toybox 没有 tr/sed/head/awk，一律用 busybox 的 applet。

LOG=/data/local/tmp/repair_task.log
exec >>"$LOG" 2>&1

echo "=== repair + set home $(date) ==="
id

VENDOR=/system/bin/hisi_boot_shell.sh
FIXED=/system/etc/hisi_boot_shell.sh.fixed
ORIG=/system/etc/hisi_boot_shell.sh.orig
USB_DIR=${BOOT_SHELL_FILE%/*}
[ "$USB_DIR" = "$BOOT_SHELL_FILE" ] && USB_DIR=$IS_U_USING

# ---- 1) 修复厂商脚本 ----
if [ ! -f "$VENDOR" ]; then
    echo "--- 厂商脚本丢失 ---"
    SRC=""
    [ -f "$FIXED" ] && SRC=$FIXED
    [ -z "$SRC" ] && [ -f "$USB_DIR/hisi_boot_shell.sh.fixed" ] && SRC=$USB_DIR/hisi_boot_shell.sh.fixed
    [ -z "$SRC" ] && [ -f "$USB_DIR/hisi_boot_shell.sh.orig" ] && SRC=$USB_DIR/hisi_boot_shell.sh.orig
    if [ -n "$SRC" ]; then
        mount -o rw,remount /system
        cp "$SRC" "$VENDOR"
        chown 0:0 "$VENDOR"
        chmod 755 "$VENDOR"
        mount -o ro,remount /system
        echo "已从 $SRC 还原"
    else
        echo "找不到可用的原件！"
    fi
elif ! sh -n "$VENDOR" 2>/dev/null; then
    echo "--- 厂商脚本语法异常，去 CR 修复 ---"
    T=/data/local/tmp/hbs.fixed
    busybox tr -d '\r' < "$VENDOR" > "$T"
    if [ -s "$T" ] && sh -n "$T" 2>/dev/null; then
        cp "$VENDOR" /data/local/tmp/hisi_boot_shell.sh.broken.bak
        mount -o rw,remount /system
        cat "$T" > "$VENDOR"
        chown 0:0 "$VENDOR"
        chmod 755 "$VENDOR"
        mount -o ro,remount /system
        echo "已修复"
    else
        echo "去 CR 修复失败，尝试用 .fixed 覆盖"
        if [ -f "$FIXED" ]; then
            mount -o rw,remount /system
            cp "$FIXED" "$VENDOR"
            chown 0:0 "$VENDOR"
            chmod 755 "$VENDOR"
            mount -o ro,remount /system
            echo "已用 .fixed 覆盖"
        fi
    fi
    rm -f "$T"
else
    echo "厂商脚本语法正常"
fi
sh -n "$VENDOR" 2>&1 && echo "校验: 语法 OK" || echo "校验: 仍然损坏"

# ---- 2) 装好固化件（guardctl / tvroot）----
if [ -f /data/local/tmp/guardctl ]; then
    mount -o rw,remount /system
    cp /data/local/tmp/guardctl /system/xbin/guardctl
    chown 0:0 /system/xbin/guardctl
    chmod 755 /system/xbin/guardctl
    mount -o ro,remount /system
    echo "guardctl 已安装到 /system/xbin/"
fi

# ---- 3) 默认桌面 ----
CFG=/system/pcfg/8H52_G3/config/general_config.xml
NEW=/data/local/tmp/general_config_new.xml
if [ -f "$NEW" ]; then
    mount -o rw,remount /system
    cp "$CFG" /data/local/tmp/general_config.xml.bak.repair 2>/dev/null
    cp "$NEW" "$CFG"
    chown 0:0 "$CFG"
    chmod 644 "$CFG"
    mount -o ro,remount /system
    grep DEFAULT_HOMEPAGE "$CFG"
fi

setprop persist.service.homepage.pkg com.gathin.tvhome
setprop persist.service.homepage.cls com.gathin.tvhome.MainActivity
setprop persist.service.starthomepage 1

echo "=== repair task done ==="
