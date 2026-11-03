#!/system/bin/sh
# 把 packages.xml 里指向"文件已不存在"的包记录清掉（pm uninstall 会同时更新 packages.xml）。
# 目的：让系统下次重启不会因为找不到 APK 而报错/卡住。
# 这些包其实已经"等于卸载"，这里只是把状态同步干净；之后把 APK 放回 /system，
# 系统开机扫描会自动把它们装回去。
LOG=/data/local/tmp/dangle.log
BB=/system/bin/busybox

{
echo "=== 清理悬空包记录 $(date) ==="
pm list packages -f 2>/dev/null | $BB sed 's/^package://' > /data/local/tmp/.pl
ok=0; bad=0
while IFS= read -r line; do
    path=${line%%=*}
    pkg=${line#*=}
    [ -f "$path" ] && continue
    echo "悬空: $pkg ($path)"
    out=$(pm uninstall "$pkg" 2>&1)
    case "$out" in
        Success) echo "  已清除 $pkg"; ok=$((ok+1)) ;;
        *) echo "  清除失败 $pkg: $out"; bad=$((bad+1)) ;;
    esac
done < /data/local/tmp/.pl
echo "=== 成功 $ok 个，失败 $bad 个 ==="
echo "--- 剩余包 ---"
pm list packages 2>/dev/null | $BB wc -l
} > $LOG 2>&1
