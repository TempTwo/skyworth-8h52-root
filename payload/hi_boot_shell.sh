#!/system/bin/sh
# U 盘入口：由厂商 /system/bin/hisi_boot_shell.sh 以 root 身份 source 执行。
#
# 三件事：
#   1) 自愈：厂商脚本若被写成 CRLF（mksh 解析失败 → init 起不来这个服务），
#      这里用 root 把它改回 LF；厂商脚本若整个丢失，则用 U 盘上的原件还原。
#   2) 确保 /system/xbin/su 存在且是 setuid root
#   3) 执行待办任务 /data/local/tmp/pending_task.sh
#
# 注意：电视上没有 tr/sed/head/tail（toybox 精简版），一律用 busybox 的 applet。
#
# 本脚本不含任何联网行为，可长期留在 U 盘上作为恢复通道。

LOG=/data/local/tmp/boot_task.log
exec >>"$LOG" 2>&1

echo "=== usb root entry $(date) ==="
id

VENDOR=/system/bin/hisi_boot_shell.sh
# 本脚本是被厂商脚本 source 进来的，同一 shell 里能拿到 BOOT_SHELL_FILE / IS_U_USING
USB_DIR=${BOOT_SHELL_FILE%/*}
if [ -z "$USB_DIR" ] || [ "$USB_DIR" = "$BOOT_SHELL_FILE" ]; then
    USB_DIR=$IS_U_USING
fi
PRISTINE="$USB_DIR/hisi_boot_shell.sh.orig"
echo "USB_DIR=$USB_DIR"

# ---- 0) 自愈：修复厂商脚本 ----
if [ ! -f "$VENDOR" ]; then
    echo "--- 厂商脚本丢失，尝试从 U 盘原件还原 ---"
    if [ -f "$PRISTINE" ]; then
        mount -o rw,remount /system
        cp "$PRISTINE" "$VENDOR"
        chown 0:0 "$VENDOR"
        chmod 755 "$VENDOR"
        mount -o ro,remount /system
        echo "已从 U 盘原件还原 $VENDOR"
    fi
elif ! sh -n "$VENDOR" 2>/dev/null; then
    echo "--- 厂商脚本语法异常（多半是 CRLF），执行去 CR 修复 ---"
    FIX=/data/local/tmp/hbs.fixed
    busybox tr -d '\r' < "$VENDOR" > "$FIX"
    if [ -s "$FIX" ] && sh -n "$FIX" 2>/dev/null; then
        cp "$VENDOR" /data/local/tmp/hisi_boot_shell.sh.broken.bak
        mount -o rw,remount /system
        cat "$FIX" > "$VENDOR"
        chown 0:0 "$VENDOR"
        chmod 755 "$VENDOR"
        mount -o ro,remount /system
        echo "已修复 $VENDOR"
    elif [ -f "$PRISTINE" ]; then
        echo "--- 去 CR 修复失败，改用 U 盘原件还原 ---"
        mount -o rw,remount /system
        cp "$PRISTINE" "$VENDOR"
        chown 0:0 "$VENDOR"
        chmod 755 "$VENDOR"
        mount -o ro,remount /system
        echo "已从 U 盘原件还原 $VENDOR"
    else
        echo "自动修复失败，请手工处理"
    fi
    rm -f "$FIX"
else
    echo "厂商脚本语法正常"
fi

# ---- 1) 确保 su 就位 ----
if [ ! -x /system/xbin/su ] && [ -f "$USB_DIR/su" ]; then
    echo "--- installing su ---"
    mount -o rw,remount /system
    cp "$USB_DIR/su" /system/xbin/su
    chown 0:0 /system/xbin/su
    chmod 6755 /system/xbin/su
    ls -l /system/xbin/su
    mount -o ro,remount /system
fi

if [ -x /system/xbin/su ]; then
    /system/xbin/su -c 'id' > /data/local/tmp/su_test.txt 2>&1
    echo "su check: $(cat /data/local/tmp/su_test.txt 2>/dev/null)"
fi

# ---- 2) 执行待办任务 ----
if [ -f /data/local/tmp/pending_task.sh ]; then
    echo "--- running pending task ---"
    sh /data/local/tmp/pending_task.sh
else
    echo "no pending task"
fi

echo "=== usb root entry done ==="
