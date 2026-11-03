#!/bin/sh
# root-run.sh —— 以完整 root 身份在电视上执行脚本
#
# 状态（2026-10-23 实测）：走 guard/tvroot 的"不插 U 盘完整 root"在
# V020.006.110 固件上已失效（guard socket 改名 + skybusybox 缺失），
# 请改用 ./tools/run-task.sh（U 盘 boot-shell 通道）。本脚本留档。
#
# 用法:
#   ./tools/root-run.sh <本地脚本路径>     # 推送并执行，结果打印到 stdout
#   ./tools/root-run.sh -c "<命令>"         # 直接跑一条命令
#
# 原理:
#   厂商 init 里有 service boot-shell /system/bin/hisi_boot_shell.sh
#     user root / group root / oneshot / disabled
#   它以 root(完整 capability, CapEff=0x3fffffffff) 运行，并 source U 盘里的
#   hi_boot_shell.sh；而 hi_boot_shell.sh 的最后一步执行 /data/local/tmp/pending_task.sh。
#   所以：把命令写进 pending_task.sh → 触发 boot-shell → 以完整 root 执行。
#
# 关键细节（踩过的坑）:
#   * boot-shell 是 oneshot 服务，触发前必须先 ctl.stop 让状态回到 stopped，
#     否则 init 会忽略 ctl.start（看起来像"没执行"）。
#   * 电视的 shell 是 toybox 精简版，**没有 printf/tr/sed/head/cut/awk**，
#     必须用 `busybox <applet>`。pending_task 必须在电视端用
#     `busybox printf` 生成——Mac 端 heredoc 生成的文件经 adb push 后
#     换行/转义会被破坏。
#   * 传输二进制文件必须用 adb push/pull，`adb shell cat` 会把 LF 转成 CRLF。

set -e

DIR="$(cd "$(dirname "$0")" && pwd)"
ADB="$DIR/tv-adb.sh"
BB=/system/bin/busybox
OUT=/data/local/tmp/root_out.txt
PEND=/data/local/tmp/pending_task.sh
CMD=/data/local/tmp/root_cmd.sh

if [ "$1" = "-c" ]; then
    LOCAL=/tmp/root_cmd_local.sh
    cat > "$LOCAL" <<EOF
#!/system/bin/sh
$2
EOF
elif [ "$1" = "-f" ]; then
    LOCAL="$2"
else
    LOCAL="$1"
fi

if [ ! -f "$LOCAL" ]; then
    echo "找不到脚本: $LOCAL" >&2
    exit 1
fi

# 1) 推命令脚本（adb push 是二进制安全的）
"$ADB" push "$LOCAL" "$CMD" >/dev/null

# 2) 在电视端用 busybox printf 组装 pending_task
"$ADB" shell "$BB chmod 777 $CMD" >/dev/null 2>&1 || true
"$ADB" shell "$BB rm -f $OUT" >/dev/null 2>&1 || true
"$ADB" shell "$BB printf '#!/system/bin/sh\nexec > $OUT 2>&1\nsh $CMD\necho \"__ROOT_DONE__\"\n' > $PEND" >/dev/null
"$ADB" shell "$BB chmod 777 $PEND" >/dev/null 2>&1 || true

# 3) 重置 oneshot 状态并触发
"$ADB" shell "setprop ctl.stop boot-shell" >/dev/null 2>&1 || true
sleep 2
"$ADB" shell "setprop ctl.start boot-shell" >/dev/null 2>&1 || true

# 4) 等结果
i=0
while [ $i -lt 60 ]; do
    sleep 1
    if "$ADB" shell "$BB grep -q __ROOT_DONE__ $OUT" >/dev/null 2>&1; then
        echo "=== 结果 ==="
        "$ADB" shell "$BB cat $OUT" 2>/dev/null
        exit 0
    fi
    i=$((i + 1))
done

echo "!! 超时。检查 $OUT" >&2
"$ADB" shell "$BB cat $OUT" 2>/dev/null
exit 1
