#!/system/bin/sh
# 任务: 把已冻结的冗余包真正卸载，并清理 /data 残留释放空间
#
# 策略：
#   * 系统包（含 /system 与 /system/vendor 的原版）：pm uninstall --user 0
#       —— 对当前用户彻底移除，图标消失、无法运行；原 APK 仍在系统分区，
#          需要时 `pm install-existing <pkg>` 即可恢复。
#   * 纯第三方包（只有 /data/app 一份）：pm uninstall，彻底删除。
#   * 最后删掉 /data/app、/data/data 里的残留目录，回收 /data 空间。

echo "=== uninstall bloat ==="
id

SYS_LIST="com.android.htmlviewer com.android.backupconfirm com.android.sharedstoragebackup com.android.location.fused com.coocaa.theme_package_ccos_nine com.tianci.movieplatform com.tianci.appstore com.coocaa.tvmanager com.skyworth.angel.voice com.tianci.user"
THIRD_LIST="com.coocaa.skycast.tool"

echo "--- system packages: uninstall for user 0 ---"
for p in $SYS_LIST; do
    if pm list packages | grep -q "package:$p"; then
        pm uninstall --user 0 "$p"
        echo "uninstalled(user0) $p"
    else
        echo "not installed: $p"
    fi
done

echo "--- third party: full uninstall ---"
for p in $THIRD_LIST; do
    if pm list packages | grep -q "package:$p"; then
        pm uninstall "$p"
        echo "uninstalled $p"
    else
        echo "not installed: $p"
    fi
done

echo "--- clean leftovers ---"
for p in $SYS_LIST $THIRD_LIST; do
    rm -rf "/data/data/$p"
    rm -rf "/data/app/$p"-*
    rm -rf "/data/app_backup/$p"
done
echo "cleaned"

echo "--- still installed? (should be empty) ---"
pm list packages 2>/dev/null | grep -E "movieplatform|appstore|tvmanager|angel.voice|tianci.user|skycast|theme_package|htmlviewer|backupconfirm|sharedstoragebackup|location.fused"

echo "--- uninstalled-but-known list ---"
pm list packages -u 2>/dev/null | grep -E "movieplatform|appstore|tvmanager|angel.voice|tianci.user|skycast"

echo "--- free space ---"
df /data
echo "=== uninstall bloat done ==="
