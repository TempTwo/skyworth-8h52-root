#!/system/bin/sh
# 清数据开机后的恢复脚本（用 root 跑；adb shell su -c "sh /data/local/tmp/restore.sh"）
BB=/system/bin/busybox
LOG=/data/local/tmp/restore.log
exec >>"$LOG" 2>&1

echo "=== restore $(date) ==="
echo "--- 网络 ---"
$BB ip addr show 2>/dev/null | $BB grep -E "inet |^[0-9]" | $BB head -8
$BB ip route show 2>/dev/null

echo "--- root 通道（/system 里的，没被清数据影响）---"
ls -l /system/xbin/su /system/xbin/guardctl /system/xbin/tvroot 2>&1
if [ -x /system/xbin/su ]; then /system/xbin/su -c id 2>&1; fi

echo "--- 桌面配置（DEFAULT_HOMEPAGE）---"
grep DEFAULT_HOMEPAGE /system/pcfg/8H52_G3/config/general_config.xml 2>&1
grep -E "BOOT_AD|SUPPORT_SCREENSAVER|Need_CooCaa" /system/pcfg/8H52_G3/config/general_config.xml 2>&1

echo "--- 已被清掉的系统 APK（缺失清单）---"
for d in /system/app/HiRMService/HiRMService.apk \
         /system/app/SkyRMService/SkyRMService.apk \
         /system/vendor/ccos/app/SkySystemService/SkySystemService.apk \
         /system/app/webview/webview.apk \
         /system/priv-app/ExternalStorageProvider/ExternalStorageProvider.apk \
         /system/vendor/app/SkyPackageInstaller/SkyPackageInstaller.apk; do
    [ -f "$d" ] && echo "在: $d" || echo "缺: $d"
done

echo "--- 已装包 ---"
pm list packages 2>/dev/null | $BB wc -l
pm list packages 2>/dev/null | $BB grep -E "orchard|walkman|jellyfin|hongguo"

echo "--- 重装 Aerial 桌面（APK 放 /data/local/tmp/aerial.apk）---"
if [ -f /data/local/tmp/aerial.apk ]; then
    pm install -r /data/local/tmp/aerial.apk 2>&1
fi

echo "--- 恢复出厂后的桌面是否可用（起一下）---"
am start -n app.orchard.tv/.MainActivity 2>&1 | $BB head -3

echo "--- 红外输入设备（判断遥控器键码是否标准）---"
cat /proc/bus/input/devices 2>/dev/null | $BB grep -A3 -iE "hi_ir|IR|remote" | $BB head -20

echo "=== restore done ==="
