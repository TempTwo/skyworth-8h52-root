#!/system/bin/sh
# 任务: 安装 setuid-root 的 su 并自检
# 通过 boot-shell 以 init root 执行。

echo "=== install root ==="
id

USB_DIR=${BOOT_SHELL_FILE%/*}
if [ -z "$USB_DIR" ]; then
    USB_DIR=/mnt/usb
fi

mount -o rw,remount /system
echo "remount_rc=$?"

if [ -f /system/xbin/su ]; then
    cp /system/xbin/su /data/local/tmp/su.orig
    echo "backed up existing su"
fi

if [ -f "$USB_DIR/su" ]; then
    cp "$USB_DIR/su" /system/xbin/su
    chown 0:0 /system/xbin/su
    chmod 6755 /system/xbin/su
    echo "installed su"
else
    echo "ERROR: su not found at $USB_DIR/su"
fi

ls -l /system/xbin/su
mount -o ro,remount /system

echo "--- self test ---"
/system/xbin/su -c 'id'
echo "=== install root done ==="
