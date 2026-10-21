#!/bin/bash
# 一键制作"启动 U 盘"：格式化 FAT32/MBR 并写入 root payload
#
#   ./make-usb.sh                     # 自动识别外置可移动磁盘
#   ./make-usb.sh --disk /dev/disk5    # 指定磁盘
#   ./make-usb.sh --no-format          # 只更新文件，不格式化
#
# ⚠️ 会清空目标 U 盘。脚本会拒绝操作非"外置可移动"的磁盘。

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${DIR}/.." && pwd)"
LABEL="${TVROOT_LABEL:-TVROOT}"
DISK=""
DO_FORMAT=1

while [[ $# -gt 0 ]]; do
    case "$1" in
        --disk) DISK="$2"; shift 2 ;;
        --no-format) DO_FORMAT=0; shift ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) echo "未知参数: $1" >&2; exit 1 ;;
    esac
done

find_disk() {
    # 找出所有"外置 + 可移动"的物理磁盘
    local d
    for d in $(diskutil list | grep -E '^/dev/disk[0-9]+ \(' | sed 's/ (.*//'); do
        local info
        info="$(diskutil info "$d" 2>/dev/null || true)"
        if grep -q 'Device Location:.*External' <<<"$info" \
           && grep -q 'Removable Media:.*Removable' <<<"$info"; then
            echo "$d"
        fi
    done
}

if [[ -z "$DISK" ]]; then
    CANDIDATES=()
    while IFS= read -r d; do
        [[ -n "$d" ]] && CANDIDATES+=("$d")
    done < <(find_disk)
    if [[ ${#CANDIDATES[@]} -eq 0 ]]; then
        echo "未找到外置可移动磁盘，请用 --disk 指定" >&2
        exit 1
    fi
    if [[ ${#CANDIDATES[@]} -gt 1 ]]; then
        echo "找到多个外置磁盘，请用 --disk 指定：" >&2
        printf '  %s\n' "${CANDIDATES[@]}" >&2
        exit 1
    fi
    DISK="${CANDIDATES[0]}"
fi

# 安全检查
INFO="$(diskutil info "$DISK")"
if ! grep -q 'Device Location:.*External' <<<"$INFO"; then
    echo "拒绝操作：$DISK 不是外置磁盘" >&2
    exit 1
fi
if [[ "$DISK" == "/dev/disk0" || "$DISK" == "/dev/disk1" ]]; then
    echo "拒绝操作：$DISK 可能是系统盘" >&2
    exit 1
fi

echo "目标磁盘: $DISK"
diskutil info "$DISK" | grep -E 'Device / Media Name|Disk Size|Removable Media|Device Location' || true

if [[ "$DO_FORMAT" -eq 1 ]]; then
    echo ">> 格式化为 FAT32/MBR (卷标 $LABEL)"
    diskutil eraseDisk "MS-DOS FAT32" "$LABEL" MBR "$DISK"
else
    echo ">> 跳过格式化"
    if ! diskutil mount "$DISK" >/dev/null 2>&1; then
        diskutil mount "$DISK"
    fi
fi

VOL="/Volumes/${LABEL}"
if [[ ! -d "$VOL" ]]; then
    VOL="$(diskutil info "$DISK" | awk -F': *' '/Mount Point/{print $2; exit}')"
fi
if [[ -z "$VOL" || ! -d "$VOL" ]]; then
    echo "找不到挂载点" >&2
    exit 1
fi
echo "挂载点: $VOL"

echo ">> 写入 payload"
cp "$ROOT/payload/su" "$VOL/su"
cp "$ROOT/payload/hi_boot_shell.sh" "$VOL/hi_boot_shell.sh"
cp "$ROOT/payload/hisi_boot_shell.sh.fixed" "$VOL/hisi_boot_shell.sh.fixed"
cp "$ROOT/payload/hisi_boot_shell.sh.orig" "$VOL/hisi_boot_shell.sh.orig"
[ -f "$ROOT/tools/guardctl" ] && cp "$ROOT/tools/guardctl" "$VOL/guardctl"
mkdir -p "$VOL/payload/tasks"
cp -R "$ROOT/payload/tasks/." "$VOL/payload/tasks/"

cat > "$VOL/README.txt" <<EOF
创维 8H52_G3 启动 U 盘 (TVROOT)
================================
su                   : setuid root 二进制 (由 hi_boot_shell.sh 安装到 /system/xbin/su)
hi_boot_shell.sh     : 厂商 /system/bin/hisi_boot_shell.sh 会以 root source 本文件
                       每次运行会先检查厂商脚本，坏了自动去 CR 修复
hisi_boot_shell.sh.fixed : 修好的厂商脚本（拷回 /system/bin 即可修复）
hisi_boot_shell.sh.orig  : 厂商原版留底（纯 LF）
guardctl             : 备用，通过 coocaa_guard 的 socket 下发 root 命令
payload/tasks/       : 以 init root 执行的脚本 (通过 /data/local/tmp/pending_task.sh 调用)

用法:
  1) 插入电视 USB 口
  2) adb shell 'setprop ctl.start boot-shell'
  3) adb shell 'cat /data/local/tmp/boot_task.log'

注意: 传文件务必用 adb push，adb shell cat 会把 LF 变成 CRLF 把脚本写坏。
EOF

# 清理 macOS 元数据 & 保证脚本是 LF
rm -rf "$VOL/.Spotlight-V100" "$VOL/.fseventsd" "$VOL/.Trashes" 2>/dev/null || true
for f in "$VOL/hi_boot_shell.sh" "$VOL"/payload/tasks/*.sh; do
    if grep -q $'\r' "$f" 2>/dev/null; then
        echo "修正 CRLF: $f"
        tr -d '\r' < "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
done

echo ">> 内容:"
ls -la "$VOL"
file "$VOL/su"

echo ">> 弹出"
sync
diskutil eject "$DISK" || true
echo "完成。把 U 盘插到电视上，然后执行：adb shell 'setprop ctl.start boot-shell'"
