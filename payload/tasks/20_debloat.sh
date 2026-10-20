#!/system/bin/sh
# 任务: 精简（只做可逆的 disable-user）
#
# 全部用 pm disable-user，可用 pm enable <pkg> 逐个恢复。

echo "=== debloat ==="
id

echo "--- freeze coocaa apps ---"
for p in com.tianci.movieplatform com.tianci.appstore com.coocaa.skycast.tool com.coocaa.theme_package_ccos_nine com.coocaa.tvmanager com.tianci.user com.skyworth.angel.voice; do
    if pm list packages | grep -q "package:$p"; then
        pm disable-user --user 0 "$p"
        echo "frozen $p"
    else
        echo "not installed: $p"
    fi
done

echo "--- freeze useless framework apps ---"
for p in com.android.location.fused com.android.htmlviewer com.android.backupconfirm com.android.sharedstoragebackup; do
    if pm list packages | grep -q "package:$p"; then
        pm disable-user --user 0 "$p"
        echo "frozen $p"
    else
        echo "not installed: $p"
    fi
done

echo "--- remove 3rd-party leftovers (optional) ---"
for p in com.xu.homeguard me.efesser.flauncher com.leanbitlab.ltvL; do
    if pm list packages | grep -q "package:$p"; then
        pm uninstall "$p"
        echo "uninstalled $p"
    else
        echo "not installed: $p"
    fi
done

echo "--- disabled list ---"
pm list packages -d
echo "=== debloat done ==="
