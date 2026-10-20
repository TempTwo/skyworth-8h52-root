#!/bin/bash
# 创维电视 ADB 入口
#
#   ./tv-adb.sh                      # 列出设备
#   ./tv-adb.sh shell getprop ro.product.model
#   ./tv-adb.sh reboot
#
# 特性：
#   * 自动拉起本地 TCP 代理（macOS 直连 192.168.0.9:5555 会 No route to host）
#   * 设备离线自动重连重试
#
# 环境变量：TV_IP（默认 192.168.0.9）、TV_ADB_PORT（默认 15555）

set -uo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TV_IP="${TV_IP:-192.168.0.9}"
LOCAL_PORT="${TV_ADB_PORT:-15555}"
DEVICE="127.0.0.1:${LOCAL_PORT}"
RETRY="${TV_ADB_RETRY:-5}"

ensure_proxy() {
    if ! nc -z 127.0.0.1 "${LOCAL_PORT}" >/dev/null 2>&1; then
        echo "[tv-adb] 启动代理 127.0.0.1:${LOCAL_PORT} -> ${TV_IP}:5555"
        TV_IP="${TV_IP}" nohup python3 "${DIR}/tv-adb-proxy.py" >/tmp/tv-adb-proxy.log 2>&1 &
        sleep 1
    fi
}

connect() {
    adb connect "${DEVICE}" >/dev/null 2>&1 || true
}

wait_device() {
    local i
    for ((i = 1; i <= RETRY; i++)); do
        if adb devices | grep -q "${DEVICE}[[:space:]]*device"; then
            return 0
        fi
        connect
        sleep 1
    done
    return 1
}

ensure_proxy

if [[ $# -eq 0 ]]; then
    connect
    adb devices -l
    exit 0
fi

if ! wait_device; then
    echo "[tv-adb] 设备连接失败，尝试重连" >&2
    adb disconnect "${DEVICE}" >/dev/null 2>&1 || true
    connect
    sleep 2
fi

# 二进制输出（如 screencap）不能走变量捕获，否则 NUL 字节会被吞掉
if [[ "${1:-}" == "exec-out" ]]; then
    adb -s "${DEVICE}" "$@"
    exit $?
fi

# 带重试地执行命令
attempt=1
while true; do
    out=$(adb -s "${DEVICE}" "$@" 2>&1)
    rc=$?
    if [[ $rc -eq 0 && "$out" != *"device offline"* && "$out" != *"device not found"* ]]; then
        printf '%s\n' "$out"
        exit 0
    fi
    if ((attempt >= RETRY)); then
        printf '%s\n' "$out" >&2
        exit $rc
    fi
    echo "[tv-adb] 第 ${attempt} 次失败（${out}），重连后重试…" >&2
    adb disconnect "${DEVICE}" >/dev/null 2>&1 || true
    connect
    sleep 2
    attempt=$((attempt + 1))
done
