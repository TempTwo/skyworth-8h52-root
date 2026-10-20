#!/bin/bash
# 编译 ARMv7 静态 setuid-root 二进制 su
#
#   ./build-su.sh
#
# 优先使用 zig（自带 musl 静态工具链），其次 clang + Android NDK 的 sysroot。

set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${DIR}/.." && pwd)"
SRC="$ROOT/payload/su.c"
OUT="$ROOT/payload/su"

if command -v zig >/dev/null 2>&1; then
    echo ">> 使用 zig: $(zig version)"
    zig cc -target arm-linux-musleabihf -static -Os -s -o "$OUT" "$SRC"
elif command -v clang >/dev/null 2>&1; then
    echo ">> 使用 clang（需要 NDK sysroot）"
    SYSROOT="${ANDROID_NDK_HOME:-${ANDROID_NDK_ROOT:-}}"
    SYSROOT="${SYSROOT:-$HOME/Library/Android/sdk/ndk-bundle}"
    if [[ ! -d "$SYSROOT" ]]; then
        echo "找不到 NDK，请安装 zig 或设置 ANDROID_NDK_HOME" >&2
        exit 1
    fi
    clang --target=armv7a-linux-androideabi21 \
        -O2 -fPIE -pie -static -isysroot "$SYSROOT" \
        -o "$OUT" "$SRC"
else
    echo "找不到 zig 或 clang" >&2
    exit 1
fi

file "$OUT"
echo "生成: $OUT"
