#!/system/bin/sh
# 任务: 恢复原厂桌面与被冻结的应用（救砖 / 回滚）
#
#   REMOVE_SU=1   顺便删除 /system/xbin/su（彻底去 root）

echo "=== restore stock ==="
id

mount -o rw,remount /system
echo "remount_rc=$?"

echo "--- restore config ---"
if [ -f /data/local/tmp/general_config.xml.bak4 ]; then
    cp /data/local/tmp/general_config.xml.bak4 /system/pcfg/8H52_G3/config/general_config.xml
    echo "restored system config"
elif [ -f /data/local/tmp/general_config.xml.orig ]; then
    cp /data/local/tmp/general_config.xml.orig /system/pcfg/8H52_G3/config/general_config.xml
    echo "restored original config"
else
    echo "no config backup found"
fi
if [ -f /data/local/tmp/general_config.xml.ccos.before ]; then
    cp /data/local/tmp/general_config.xml.ccos.before /data/ccos/general_config.xml
    chown 1000:1000 /data/ccos/general_config.xml
    chmod 644 /data/ccos/general_config.xml
    echo "restored ccos config"
fi

echo "--- remove hosts block ---"
if grep -q 'apk-sky-fs.coocaa.ottcn.com' /system/etc/hosts 2>/dev/null; then
    grep -v 'apk-sky-fs.coocaa.ottcn.com' /system/etc/hosts > /data/local/tmp/hosts.new
    cp /data/local/tmp/hosts.new /system/etc/hosts
    chmod 644 /system/etc/hosts
    echo "hosts block removed"
fi

echo "--- re-enable packages ---"
for p in com.tianci.movieplatform com.tianci.appstore com.coocaa.skycast.tool com.coocaa.theme_package_ccos_nine com.coocaa.tvmanager com.tianci.user com.skyworth.angel.voice com.android.location.fused com.android.htmlviewer com.android.backupconfirm com.android.sharedstoragebackup; do
    pm enable "$p"
done
pm enable com.tianci.movieplatform/com.ccos.cooui.hdmirecall.runtime.RecallBootReceiver 2>/dev/null

echo "--- restore homepage props ---"
setprop persist.service.homepage.pkg com.tianci.movieplatform
setprop persist.service.homepage.cls com.coocaa.homepage.vast.HomePageActivity
setprop persist.service.starthomepage 1
getprop persist.service.homepage.pkg
getprop persist.service.homepage.cls

if [ "$REMOVE_SU" = "1" ]; then
    echo "--- removing su ---"
    rm -f /system/xbin/su
    ls -l /system/xbin/su 2>&1
fi

mount -o ro,remount /system
echo "remount_ro_rc=$?"
echo "=== restore stock done, reboot to apply ==="
