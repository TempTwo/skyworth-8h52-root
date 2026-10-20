#!/system/bin/sh
# 任务: 阻断酷开"紧急升级"回灌
#
# com.coocaa.skycast.tool 内置 EmergencyUpgradeEngine，会从
# apk-sky-fs.coocaa.ottcn.com 下载新版 com.tianci.movieplatform 并安装，
# 导致被冻结的酷开桌面复活。这里三重保险：
#   1) 冻结 skycast.tool
#   2) 删除已下载的升级包
#   3) hosts 屏蔽该域名

echo "=== block emergency upgrade ==="
id

echo "--- freeze skycast tool ---"
pm disable-user --user 0 com.coocaa.skycast.tool
am force-stop com.coocaa.skycast.tool

echo "--- remove downloaded upgrade apk ---"
rm -rf /data/data/com.coocaa.skycast.tool/cache/emergency_download
rm -rf /data/data/com.coocaa.skycast.tool/cache/emergency_update
echo "cleaned"

echo "--- block host ---"
mount -o rw,remount /system
if ! grep -q 'apk-sky-fs.coocaa.ottcn.com' /system/etc/hosts 2>/dev/null; then
    echo "" >> /system/etc/hosts
    echo "127.0.0.1 apk-sky-fs.coocaa.ottcn.com" >> /system/etc/hosts
    echo "hosts rule added"
else
    echo "hosts rule already present"
fi
chmod 644 /system/etc/hosts
cat /system/etc/hosts
mount -o ro,remount /system

echo "--- keep launcher frozen ---"
pm disable-user --user 0 com.tianci.movieplatform
pm disable --user 0 com.tianci.movieplatform/com.ccos.cooui.hdmirecall.runtime.RecallBootReceiver

echo "=== block emergency upgrade done ==="
