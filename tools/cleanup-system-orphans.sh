#!/system/bin/sh
# 清理 /system 上【未安装】的占位 APK（packages.xml 里没有的），
# 以及 /skyworth 里对应已卸载功能的遗留数据。
#
# 这些 APK 在系统里占着空间，但 PackageManager 根本不认识它们（未安装），
# 删掉不影响任何运行中的东西；系统升级(OTA)或刷机可恢复。
#
# 需要 root（/system 要 remount rw）。
#
# ============================================================================
# ⚠️ 事故警告（2026-10-22）：这个脚本曾经把电视刷成砖！
#
# 原因：pm list packages -f 的输出格式是
#       package:<路径>=<包名>
#   旧代码只剥掉了 "package:" 前缀，没剥掉 "=包名" 后缀，
#   于是每行都变成 "路径=包名"，和裸路径做 grep -qx 永远匹配不上，
#   结果把 54 个 APK 全当"未安装"删掉了 —— 其中 25 个是已安装的系统 APK，
#   电视开机卡在 logo，recovery 里也没有网络，只能靠整包刷回。
#
# 现在改成用 PackageManager 自己的清单（/data/system/packages.xml）作为真值来源，
# 并且默认 DRY-RUN —— 只报告不删除。要真删必须显式加 --apply。
#
# 另外两个硬性纪律：
#   1) 绝不删除共用 android.uid.system (uid 1000) 的包 —— 删一个会让整组签名失效，
#      com.tianci.system 和 Aerial 会一起起不来。uid 1000 的包只能 disable。
#   2) 删除前必须先备份 /system，并把 packages.xml + 全部 APK 的 md5 导出。
# ============================================================================
LOG=/data/local/tmp/cleanup3.log
BB=/system/bin/busybox
MANIFEST=/data/local/tmp/removed-system-apks.txt
PKGXML=/data/system/packages.xml
BACKUP=/data/local/tmp/system_backup

APPLY=0
[ "$1" = "--apply" ] && APPLY=1

{
echo "=== 清理 /system 占位 APK $(date) ==="
if [ $APPLY -eq 0 ]; then
    echo "*** DRY-RUN 模式（只报告，不删除）。加 --apply 才会真的删。 ***"
fi

# ---- 0) 先备份 ----
echo "--- 备份 ---"
$BB mkdir -p "$BACKUP" 2>/dev/null
$BB cp "$PKGXML" "$BACKUP/packages.xml" 2>/dev/null && echo "已备份 packages.xml"
$BB find /system/app /system/vendor/app /system/priv-app -name "*.apk" 2>/dev/null | $BB sort > "$BACKUP/system_apks.txt"
$BB md5sum $(cat "$BACKUP/system_apks.txt") > "$BACKUP/system_apks.md5" 2>/dev/null
echo "已记录 $($BB wc -l < "$BACKUP/system_apks.txt") 个系统 APK 的 md5"
$BB tar -cf "$BACKUP/apps.tar" -C / system/app system/vendor/app system/priv-app 2>/dev/null && echo "已打包系统 APK -> $BACKUP/apps.tar"

# ---- 1) 真值来源：PackageManager 的 packages.xml ----
# packages.xml 里 <package name="..."> 下有 <codePath>...</codePath>，
# 只有出现在这里的才算"已安装"。这比解析 pm 输出可靠得多。
echo "--- 从 packages.xml 提取已安装包的 codePath ---"
$BB grep -o '<codePath>[^<]*</codePath>' "$PKGXML" 2>/dev/null \
  | $BB sed 's|<codePath>||; s|</codePath>||' \
  | $BB sort -u > /data/local/tmp/.installed_paths
echo "已安装包数: $($BB wc -l < /data/local/tmp/.installed_paths)"

# ---- 2) 扫描 /system 下的 APK，逐个判断 ----
before=$($BB du -sk /system/app /system/priv-app /system/vendor/app 2>/dev/null | $BB awk '{s+=$1} END{print s}')
echo "清理前 /system 相关目录: ${before}KB"
: > $MANIFEST

for apks in /system/app/*/*.apk /system/priv-app/*/*.apk /system/vendor/app/*/*.apk; do
    [ -f "$apks" ] || continue

    # 已安装 → 保留
    if $BB grep -qx "$apks" /data/local/tmp/.installed_paths; then
        continue
    fi

    # ★ 硬性纪律：uid 1000 (android.uid.system) 共享组的包不删 APK ★
    # 创维的酷开包几乎全部共用这个 shared uid，删一个会让整组签名校验失效，
    # 结果 com.tianci.system / Aerial 一起起不来 —— 电视直接变砖。
    pkgname=$($BB grep -B30 "\"$apks\"" "$PKGXML" 2>/dev/null | $BB grep -o 'package name="[^"]*"' | $BB tail -1 | $BB sed 's/package name="//; s/"//')
    if [ -n "$pkgname" ]; then
        shareduid=$($BB grep -A40 "\"$pkgname\"" "$PKGXML" 2>/dev/null | $BB grep -m1 -o 'sharedUserId="[^"]*"' | $BB sed 's/sharedUserId="//; s/"//')
        if [ "$shareduid" = "1000" ]; then
            echo "跳过(uid1000共享组, 只能禁用不能删APK): $apks  [$pkgname]"
            continue
        fi
    fi

    size=$($BB du -k "$apks" 2>/dev/null | $BB cut -f1)
    echo "删除 $apks (${size}KB) [$pkgname]" >> $MANIFEST
    if [ $APPLY -eq 1 ]; then
        $BB rm -f "$apks" 2>/dev/null
        [ -f "$apks" ] && echo "  删除失败: $apks" || echo "  已删除: $apks"
    else
        echo "  [DRY-RUN] 将删除: $apks"
    fi
done

echo "共 $([ $APPLY -eq 1 ] && $BB wc -l < $MANIFEST || echo 0) 个 APK 被删除，明细见 $MANIFEST"

# ---- 3) 清掉空目录 ----
for d in /system/app/* /system/priv-app/* /system/vendor/app/*; do
    [ -d "$d" ] || continue
    $BB ls -A "$d" 2>/dev/null | $BB grep -q . || $BB rmdir "$d" 2>/dev/null
done

after=$($BB du -sk /system/app /system/priv-app /system/vendor/app 2>/dev/null | $BB awk '{s+=$1} END{print s}')
echo "清理后: ${after}KB"
echo "释放: $((before-after))KB"

# ---- 4) /skyworth 里已卸载功能的遗留数据 ----
# 注意：/skyworth 是独立分区，删这里不影响 /system，也不会牵连签名。
echo "=== 清理 /skyworth 遗留数据 ==="
sb=$($BB du -sk /skyworth 2>/dev/null | $BB cut -f1)
echo "清理前 /skyworth: ${sb}KB"
for d in /skyworth/ChinaNetTV /skyworth/Wuliquankai /skyworth/karaoketv /skyworth/karaoketv_api /skyworth/CIBNJvjingcai; do
    [ -d "$d" ] || continue
    echo "删除 $d"
    [ $APPLY -eq 1 ] && $BB rm -rf "$d" 2>/dev/null
done
sa=$($BB du -sk /skyworth 2>/dev/null | $BB cut -f1)
echo "清理后 /skyworth: ${sa}KB（释放 $((sb-sa))KB）"

# ---- 5) 其它零碎 ----
[ $APPLY -eq 1 ] && { $BB rm -rf /data/log/* 2>/dev/null; $BB rm -f /data/tombstones/* 2>/dev/null; }
echo "=== 完成 ==="
df /system /data /skyworth 2>/dev/null
} > $LOG 2>&1

cat $LOG
