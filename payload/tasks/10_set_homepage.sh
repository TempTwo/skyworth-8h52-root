#!/system/bin/sh
# 任务: 应用桌面 / 广告配置
#
# 需要先把打好补丁的 general_config_new.xml 推到 /data/local/tmp/general_config_new.xml，
# 并把目标桌面写进 /data/local/tmp/homepage_target.txt（格式: 包名/Activity 全名）。

CFG=/data/local/tmp/general_config_new.xml
SYS_CFG=/system/pcfg/8H52_G3/config/general_config.xml
CCOS_CFG=/data/ccos/general_config.xml
TARGET_FILE=/data/local/tmp/homepage_target.txt

echo "=== set homepage ==="
id

TARGET=$(cat "$TARGET_FILE" 2>/dev/null)
if [ -z "$TARGET" ]; then
    TARGET="app.orchard.tv/app.orchard.tv.MainActivity"
    echo "no target file, using default: $TARGET"
else
    echo "target: $TARGET"
fi
PKG=${TARGET%%/*}
CLS=${TARGET#*/}

mount -o rw,remount /system
echo "remount_rc=$?"

if [ -f "$CFG" ]; then
    echo "--- system config ---"
    cp "$SYS_CFG" "$SYS_CFG.bak4" 2>/dev/null
    cp "$CFG" "$SYS_CFG"
    chown 0:0 "$SYS_CFG"
    chmod 644 "$SYS_CFG"
    grep -E 'BOOT_AD|DEFAULT_HOMEPAGE|Need_CooCaa_Auto_Jump_Home|SUPPORT_SCREENSAVER' "$SYS_CFG"

    if [ -d /data/ccos ]; then
        echo "--- ccos config ---"
        cp "$CCOS_CFG" "$CCOS_CFG.bak4" 2>/dev/null
        cp "$CFG" "$CCOS_CFG"
        chown 1000:1000 "$CCOS_CFG"
        chmod 644 "$CCOS_CFG"
    fi
else
    echo "ERROR: $CFG not found (先跑 tools/patch-config.py 生成并推送)"
fi

echo "--- props ---"
setprop persist.service.homepage.pkg "$PKG"
setprop persist.service.homepage.cls "$CLS"
setprop persist.service.starthomepage 1
getprop persist.service.homepage.pkg
getprop persist.service.homepage.cls
getprop persist.service.starthomepage

mount -o ro,remount /system
echo "remount_ro_rc=$?"
echo "=== set homepage done ==="
