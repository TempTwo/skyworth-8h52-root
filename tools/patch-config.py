#!/usr/bin/env python3
"""批量修改创维电视的 general_config.xml。

用法:
    ./patch-config.py --pull                      # 从电视拉取当前配置并打印
    ./patch-config.py --pull --out new.xml        # 拉取 + 打补丁
    ./patch-config.py --in orig.xml --out new.xml # 本地打补丁

补丁项（可用 --set 追加）:
    BOOT_AD=false
    SUPPORT_SCREENSAVER=false
    Need_CooCaa_Auto_Jump_Home=false
    DEFAULT_HOMEPAGE=<pkg>/<activity>

示例:
    ./patch-config.py --pull --out /tmp/new.xml \\
        --set DEFAULT_HOMEPAGE=app.orchard.tv/app.orchard.tv.MainActivity
"""
import argparse
import re
import subprocess
import sys

TV_CONFIG = "/system/pcfg/8H52_G3/config/general_config.xml"
ADB = ["adb", "-s", "127.0.0.1:15555"]

DEFAULTS = {
    "BOOT_AD": "false",
    "SUPPORT_SCREENSAVER": "false",
    "Need_CooCaa_Auto_Jump_Home": "false",
}


def adb(*args, capture=True):
    cmd = ADB + list(args)
    if capture:
        return subprocess.run(cmd, capture_output=True, text=True, check=False).stdout
    subprocess.run(cmd, check=False)
    return ""


def patch(text, settings):
    for key, value in settings.items():
        pattern = r'(<config\s+name="%s"\s+value=")[^"]*(")' % re.escape(key)
        text, n = re.subn(pattern, lambda m: m.group(1) + value + m.group(2), text)
        if n == 0:
            print(f"警告: 配置项 {key} 未找到", file=sys.stderr)
    return text


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--pull", action="store_true", help="从电视拉取配置")
    ap.add_argument("--in", dest="infile", help="本地输入文件")
    ap.add_argument("--out", dest="outfile", help="输出文件（默认打印到 stdout）")
    ap.add_argument("--set", action="append", default=[], metavar="KEY=VALUE",
                    help="额外的配置项，可重复")
    args = ap.parse_args()

    settings = dict(DEFAULTS)
    for item in args.set:
        if "=" not in item:
            print(f"--set 需要 KEY=VALUE 形式: {item}", file=sys.stderr)
            sys.exit(1)
        k, v = item.split("=", 1)
        settings[k] = v

    if args.pull:
        data = adb("exec-out", "cat", TV_CONFIG)
        if not data.strip().startswith("<?xml"):
            print("拉取失败：请确认 ADB 已连接（tools/tv-adb.sh）", file=sys.stderr)
            sys.exit(1)
        text = data
    elif args.infile:
        with open(args.infile, encoding="utf-8") as fh:
            text = fh.read()
    else:
        ap.error("需要 --pull 或 --in")

    text = patch(text, settings)
    if args.outfile:
        with open(args.outfile, "w", encoding="utf-8") as fh:
            fh.write(text)
        print(f"已写入 {args.outfile}", file=sys.stderr)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
