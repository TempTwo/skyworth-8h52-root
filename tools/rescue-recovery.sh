#!/system/bin/sh
# 在电视 recovery 的 adb shell（root）里跑
# 作用：把 /system 分区整块 dump 出来，Mac 侧用 ext4 取证把被误删的 APK 捞回来
BB=/system/bin/busybox
[ -x "$BB" ] || BB=/system/bin/busybox
LOG=/data/local/tmp/rescue.log
exec >"$LOG" 2>&1
echo "=== rescue $(date) ==="
id
mount /data 2>/dev/null
mount 2>/dev/null | $BB grep -E "/data|/system"
DEV=/dev/block/platform/hi_mci.1/by-name/system
[ -b "$DEV" ] || DEV=$(ls /dev/block/platform/*/by-name/ 2>/dev/null | $BB grep -i system | $BB head -1)
if [ -b "$DEV" ]; then
    echo "dumping $DEV ..."
    df /data | $BB tail -1
    dd if=$DEV of=/data/local/tmp/sys.img bs=4M 2>&1 | $BB tail -3
    ls -l /data/local/tmp/sys.img
    echo "DUMP_DONE"
else
    echo "找不到 system 分区设备"
    ls -l /dev/block/platform/*/by-name/ 2>/dev/null | $BB head -20
fi
echo "=== rescue done ==="
