#!/bin/bash
# 一键部署：改桌面配置 -> 精简 -> 阻断紧急升级 -> 校验
#
#   ./deploy.sh --homepage app.orchard.tv/app.orchard.tv.MainActivity
#   ./deploy.sh                     # 使用默认桌面（AS Launcher）
#
# 前提：电视已插 U 盘，且 /system/xbin/su 已安装（首次请先跑 00_install_root.sh）

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${DIR}/.." && pwd)"
ADB=("${DIR}/tv-adb.sh")
HOMEPAGE="${HOMEPAGE:-app.orchard.tv/app.orchard.tv.MainActivity}"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --homepage) HOMEPAGE="$2"; shift 2 ;;
        -h|--help) sed -n '2,8p' "$0"; exit 0 ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
done

PKG="${HOMEPAGE%%/*}"
CLS="${HOMEPAGE#*/}"
echo "目标桌面: $HOMEPAGE"

echo ">> 1/5 生成配置"
"${DIR}/patch-config.py" --pull --out /tmp/tv_general_config_new.xml \
    --set "DEFAULT_HOMEPAGE=${HOMEPAGE}" || exit 1

echo ">> 2/5 推送配置与桌面目标"
"${ADB[@]}" push /tmp/tv_general_config_new.xml /data/local/tmp/general_config_new.xml >/dev/null || exit 1
"${ADB[@]}" shell 'chmod 644 /data/local/tmp/general_config_new.xml' >/dev/null
printf '%s\n' "$HOMEPAGE" > /tmp/tv_homepage_target.txt
"${ADB[@]}" push /tmp/tv_homepage_target.txt /data/local/tmp/homepage_target.txt >/dev/null || exit 1
"${ADB[@]}" shell 'chmod 644 /data/local/tmp/homepage_target.txt' >/dev/null

echo ">> 3/5 执行 10_set_homepage.sh"
"${DIR}/run-task.sh" "$ROOT/payload/tasks/10_set_homepage.sh" || exit 1

echo ">> 4/5 执行 20_debloat.sh + 30_block_upgrade.sh"
"${DIR}/run-task.sh" "$ROOT/payload/tasks/30_block_upgrade.sh" || exit 1
"${DIR}/run-task.sh" "$ROOT/payload/tasks/20_debloat.sh" || exit 1

echo ">> 5/5 校验"
"${ADB[@]}" shell "getprop persist.service.homepage.pkg; getprop persist.service.homepage.cls; pm list packages -d"

cat <<EOF

完成。重启电视验收：
    "${ADB[@]}" reboot
    "${ADB[@]}" shell 'dumpsys activity activities | grep mResumedActivity'
EOF
