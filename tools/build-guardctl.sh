#!/bin/bash
# 编译 ARMv7 静态 guardctl —— 通过 coocaa_guard 的 Unix socket 下发 root 命令
#
#   ./build-guardctl.sh
#
# 用法（推到电视后）：
#   su -c "/data/local/tmp/guardctl --raw start_telnetd"   # 起 root telnetd(4149)
#   su -c "/data/local/tmp/guardctl 'id'"                   # 直接执行一条命令

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="$DIR/guardctl.c"
OUT="$DIR/guardctl"

if command -v zig >/dev/null 2>&1; then
    echo ">> 使用 zig: $(zig version)"
    zig cc -target arm-linux-musleabihf -static -Os -s -o "$OUT" "$SRC"
elif command -v clang >/dev/null 2>&1; then
    SYSROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
    SYSROOT="${SYSROOT:-$HOME/Library/Android/sdk/ndk-bundle}"
    if [[ ! -d "$SYSROOT" ]]; then
        echo "找不到 NDK，请安装 zig 或设置 ANDROID_NDK_HOME" >&2
        exit 1
    fi
    clang --target=armv7a-linux-androideabi21 -O2 -fPIE -pie -static \
        -isysroot "$SYSROOT" -o "$OUT" "$SRC"
else
    echo "找不到 zig 或 clang" >&2
    exit 1
fi

file "$OUT"
echo "生成: $OUT"
