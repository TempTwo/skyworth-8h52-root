#!/system/bin/sh
# U 盘入口：由厂商 /system/bin/hisi_boot_shell.sh 以 root 身份 source。
#
# 作用：
#   1) 若 /system/xbin/su 不存在，则安装 U 盘里的 su（setuid root）
#   2) 若 /data/local/tmp/pending_task.sh 存在，则以 init root 执行它
#
# 本脚本不含任何联网行为，可长期留在 U 盘上作为恢复通道。

LOG=/data/local/tmp/boot_task.log
exec >>"$LOG" 2>&1

echo "=== usb root entry ==="
id

USB_DIR=${BOOT_SHELL_FILE%/*}
if [ -z "$USB_DIR" ]; then
    USB_DIR=/mnt/usb
fi
echo "USB_DIR=$USB_DIR"

# ---- 1. 确保 su 就位 ----
if [ ! -x /system/xbin/su ] && [ -f "$USB_DIR/su" ]; then
    echo "--- installing su ---"
    mount -o rw,remount /system
    if [ -f /system/xbin/su ]; then
        cp /system/xbin/su /data/local/tmp/su.orig
    fi
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

# ---- 2. 执行待办任务 ----
if [ -f /data/local/tmp/pending_task.sh ]; then
    echo "--- running pending task ---"
    sh /data/local/tmp/pending_task.sh
else
    echo "no pending task"
fi

echo "=== usb root entry done ==="
