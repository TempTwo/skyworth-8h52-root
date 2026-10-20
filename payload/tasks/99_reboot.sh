#!/system/bin/sh
# 任务: 一次性重启（带标志位，避免重启循环）
#
# 首次执行会创建 /data/local/tmp/reboot_once_done 并重启；
# 之后 U 盘插着开机时该任务会跳过，不会形成重启循环。

FLAG=/data/local/tmp/reboot_once_done

echo "=== reboot task ==="
id

if [ ! -f "$FLAG" ]; then
    touch "$FLAG"
    sync
    echo "rebooting now"
    reboot
    echo "reboot returned rc=$?"
else
    echo "reboot_once_done exists; skip"
fi
echo "=== reboot task done ==="
