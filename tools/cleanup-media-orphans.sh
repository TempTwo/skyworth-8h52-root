#!/system/bin/sh
# 清理 /data/media/0（Android 模拟存储）里已卸载 App 留下的孤儿目录
# 只用 busybox 的工具（这台电视的 toybox 没有 basename/sed/cut）
LOG=/data/local/tmp/cleanup2.log
BB=/system/bin/busybox
KEEP="Android com.coocaa.os.ccosservice com.coocaa.os.softsettings com.tianci.system com.tianci.localmedia com.tianci.de com.tianci.tv com.hisilicon.android.hiRMService com.hisilicon.blackscreen com.hisilicon.quicksuspend com.loostone.tuning com.skyworth.android.skyRMService com.skyworth.iSwitchDtvService com.skyworth.setting com.skyworth.tianciime skyworth.dtvLoader org.jellyfin.androidtv app.orchard.tv"

{
echo "=== 清理 /data/media/0 孤儿目录 $(date) ==="
before=$($BB du -sk /data/media/0 2>/dev/null | $BB cut -f1)
echo "清理前: ${before}KB"

for d in /data/media/0/*; do
    [ -e "$d" ] || continue
    name=$($BB basename "$d")
    keep=0
    for k in $KEEP; do
        [ "$name" = "$k" ] && keep=1
    done
    # Download 目录：只清内容，保留目录本身
    if [ "$name" = "Download" ]; then
        $BB rm -rf "$d"/* 2>/dev/null
        echo "清空 Download 目录内容"
        continue
    fi
    if [ $keep = 1 ]; then
        echo "保留 $name"
        continue
    fi
    s=$($BB du -sk "$d" 2>/dev/null | $BB cut -f1)
    if $BB rm -rf "$d" 2>/dev/null; then
        echo "删除 $name (${s}KB)"
    else
        echo "跳过 $name (删不掉)"
    fi
done

after=$($BB du -sk /data/media/0 2>/dev/null | $BB cut -f1)
echo "清理后: ${after}KB"
echo "本次释放: $((before-after))KB"
} > $LOG 2>&1
