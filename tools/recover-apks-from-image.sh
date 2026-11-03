#!/bin/bash
# 从 /system 分区镜像里恢复被我误删的 APK（ext4 未分配 inode 还在）
#
# 用法:
#   ./recover-apks.sh <system.img> <输出目录> [要恢复的 apk 名...]
#
# 原理: ext4 删除文件时只清 inode，文件内容块还在空闲区里。
#       debugfs 的 lsdel 能列出已删除 inode，dump 能把它们捞出来。
set -uo pipefail
IMG="${1:?用法: $0 <system.img> <输出目录>}"
OUT="${2:?用法: $0 <system.img> <输出目录>}"
DEBUGFS=/usr/local/opt/e2fsprogs/sbin/debugfs
[ -x "$DEBUGFS" ] || DEBUGFS=$(command -v debugfs)
[ -x "$DEBUGFS" ] || { echo "找不到 debugfs（brew install e2fsprogs）"; exit 1; }
mkdir -p "$OUT"

LSDEL="$OUT/lsdel.txt"
"$DEBUGFS" -R "lsdel" "$IMG" > "$LSDEL" 2>/dev/null
echo "已删除 inode 记录: $(grep -c '^[0-9]' "$LSDEL") 条"

# 需要的 APK（= 我误删的那些系统 APK），来自 /data/local/tmp/removed-system-apks.txt 的文件名
WANT="BlackScreen Bluetooth CertInstaller HTMLViewer HiRMService InputDevices ProxyHandler QuickSuspend SettingsProvider Shell VpnDialogs ExternalStorageProvider DefaultContainerService SkyCommonFactory SkyPackageInstaller SkyTV Miracast dtvLoader iSwitchDtvService karaoketv_api SkyMarketShowApp SkyLocalMedia SkyPayCenter SkySetting SkySystemService SkyTianciIME SkyUserService SkyPushService SkyMovie SkyAngelVoice CoGuide SkyCast SkyTVManager SkyWallpaper SkyAppStore SkyAppBrowser SoftwareSettings TeamPresent EmergencyWarning RemoteCustomerService QuickPanel SkyADService CooDataServer GoldenFaithTheme SkyRMService FusedLocation MessageBox SharedStorageBackup BackupRestoreConfirmation webview"

got=0
for name in $WANT; do
    line=$(grep -E "^[0-9]+\s+.*\b${name}\.apk" "$LSDEL" | head -1)
    [ -z "$line" ] && continue
    ino=$(echo "$line" | awk '{print $1}')
    if "$DEBUGFS" -R "dump $ino $OUT/$name.apk" "$IMG" >/dev/null 2>&1 && [ -s "$OUT/$name.apk" ]; then
        size=$(stat -f%z "$OUT/$name.apk" 2>/dev/null || stat -c%s "$OUT/$name.apk" 2>/dev/null)
        echo "  恢复 $name.apk (ino=$ino, $size 字节)"
        got=$((got+1))
    else
        echo "  失败 $name.apk (ino=$ino)"
    fi
done
echo "共恢复 $got 个"
ls -la "$OUT"/*.apk 2>/dev/null | head -40
