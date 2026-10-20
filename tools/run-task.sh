#!/bin/bash
# 把一个任务脚本推到电视，并以 init root（boot-shell 上下文）执行
#
#   ./run-task.sh ../payload/tasks/20_debloat.sh
#
# 前提：电视已插着本项目的 U 盘（payload/hi_boot_shell.sh 位于 U 盘根目录）。
# 流程：推送任务 -> 推送 U 盘入口 -> setprop ctl.start boot-shell -> 打印日志

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${DIR}/.." && pwd)"
ADB=("${DIR}/tv-adb.sh")

if [[ $# -lt 1 ]]; then
    echo "用法: $0 <task.sh> [更多任务...]" >&2
    exit 1
fi

for task in "$@"; do
    if [[ ! -f "$task" ]]; then
        echo "找不到任务文件: $task" >&2
        exit 1
    fi
done

# 1. 推送任务（最后一个任务覆盖 pending_task.sh，其余作为 backup 保留）
LAST="${!#}"
for task in "$@"; do
    echo ">> 推送任务 $(basename "$task")"
    "${ADB[@]}" push "$task" /data/local/tmp/pending_task.sh >/dev/null || {
        echo "推送失败" >&2; exit 1; }
    "${ADB[@]}" shell 'chmod 755 /data/local/tmp/pending_task.sh' >/dev/null
done

# 2. 推送 U 盘入口脚本
#    注意：电视的 toybox 没有 cut/awk，这里把 df 原始输出拿到 Mac 上再解析
DF_OUT=$("${ADB[@]}" shell 'df 2>/dev/null' 2>/dev/null | tr -d '\r')
USB_MOUNT=$(printf '%s\n' "$DF_OUT" | grep 'mnt/usb' | awk 'NR==1{print $1}')
if [[ -z "$USB_MOUNT" ]]; then
    echo "电视上没有检测到 mnt/usb 挂载点，请确认 U 盘已插入" >&2
    printf '%s\n' "$DF_OUT" >&2
    exit 1
fi
echo ">> U 盘挂载点: $USB_MOUNT"
"${ADB[@]}" push "$ROOT/payload/hi_boot_shell.sh" "${USB_MOUNT}/hi_boot_shell.sh" >/dev/null || {
    echo "推送 U 盘入口失败" >&2; exit 1; }

# 3. 触发
echo ">> 触发 boot-shell"
"${ADB[@]}" shell 'setprop ctl.start boot-shell' >/dev/null

# 4. 等待并打印日志
sleep 8
"${ADB[@]}" shell 'cat /data/local/tmp/boot_task.log' | tr -d '\r'
