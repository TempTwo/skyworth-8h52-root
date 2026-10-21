#!/usr/bin/env python3
"""tv-root.py —— 通过 coocaa_guard 启动的 telnetd(4149) 在电视上执行 root 命令

用法:
    tv-root.py "id"                  执行一条命令并打印输出
    tv-root.py -f script.sh          发送一个本地脚本文件的内容（多行）
    tv-root.py -f - "start_telnetd"  发送原文（不加换行的原样模式）

前提: 电视上已有 root 通道
    adb shell 'su -c "/system/xbin/guardctl --raw start_telnetd"'
"""
import socket
import sys
import time

HOST = "192.168.0.9"
PORT = 4149


def recv_all(sock, quiet=0.6, total=6.0):
    """读取直到安静一段时间"""
    buf = b""
    end = time.time() + total
    last = time.time()
    while time.time() < end:
        try:
            sock.settimeout(0.4)
            data = sock.recv(65536)
            if not data:
                break
            buf += data
            last = time.time()
        except socket.timeout:
            if time.time() - last > quiet:
                break
    return buf


def run(payload: bytes, quiet=0.8, total=8.0, show_banner=True):
    s = socket.create_connection((HOST, PORT), timeout=10)
    s.settimeout(1.0)
    banner = recv_all(s, quiet=quiet, total=2.0)
    if show_banner and banner:
        # 去掉 telnet 协商字符
        clean = bytes(b for b in banner if b >= 32 or b in (10, 13))
        sys.stdout.write(clean.decode("utf-8", "replace"))
        sys.stdout.flush()
    s.sendall(payload)
    out = recv_all(s, quiet=quiet, total=total)
    s.close()
    clean = bytes(b for b in out if b >= 32 or b in (10, 13))
    text = clean.decode("utf-8", "replace")
    sys.stdout.write(text)
    sys.stdout.flush()
    return text


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    if args[0] == "-f":
        if args[1] == "-":
            data = sys.stdin.buffer.read()
        else:
            with open(args[1], "rb") as f:
                data = f.read()
        if not data.endswith(b"\n"):
            data += b"\n"
        run(data)
    else:
        cmd = " ".join(args)
        run(cmd.encode() + b"\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
