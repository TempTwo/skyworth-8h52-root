#!/usr/bin/env python3
"""把本机 127.0.0.1:15555 转发到创维电视的 ADB 端口。

macOS 上 adb 直连 192.168.0.9:5555 会报 "No route to host"，
但普通 TCP 连接正常，所以用本地转发绕开这个问题。

环境变量：TV_IP（默认 192.168.0.9）、TV_ADB_PORT（默认 15555）
"""
import os
import socket
import threading

TV = (os.environ.get("TV_IP", "192.168.0.9"), 5555)
LISTEN = ("127.0.0.1", int(os.environ.get("TV_ADB_PORT", "15555")))


def pipe(src, dst):
    try:
        while True:
            data = src.recv(65536)
            if not data:
                break
            dst.sendall(data)
    except OSError:
        pass
    finally:
        for sock in (src, dst):
            try:
                sock.close()
            except OSError:
                pass


def handle(client):
    try:
        upstream = socket.create_connection(TV, timeout=5)
    except OSError:
        client.close()
        return
    threading.Thread(target=pipe, args=(client, upstream), daemon=True).start()
    pipe(upstream, client)


def main():
    server = socket.socket()
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(LISTEN)
    server.listen(8)
    print(f"forwarding {LISTEN[0]}:{LISTEN[1]} -> {TV[0]}:{TV[1]}", flush=True)
    while True:
        client, _ = server.accept()
        threading.Thread(target=handle, args=(client,), daemon=True).start()


if __name__ == "__main__":
    main()
