/* guardctl —— 通过 coocaa_guard 的 Unix socket 下发命令
 *
 * 背景：
 *   /system/vendor/bin/coocaa_guard 以 root 运行，监听 /data/ccos/guard.sock。
 *   该目录权限 0700、属主 1000:1000(system)，所以只有 uid=1000 的进程能进去。
 *   我们的 su 以 root 身份运行但只有 CAP_SETUID/CAP_SETGID(0xc0)，
 *   正好可以 setgid(1000)+setuid(1000) 变成 system，再连接 socket。
 *
 * 守护进程协议是明文单行：
 *   shellexec <命令>      以 root 执行命令
 *   start_telnetd         启动 busybox telnetd -p 4149 -l /system/bin/sh
 *   stop_telnetd          停止
 *
 * 用法：
 *   guardctl "id"                 发送 shellexec id
 *   guardctl --raw "start_telnetd" 原样发送
 */
#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>

#define SOCK_PATH "/data/ccos/guard.sock"

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "用法: %s <命令>   |   %s --raw <原文>\n", argv[0], argv[0]);
        return 2;
    }

    /* 降权到 system(1000)，才能穿过 /data/ccos (0700 system:system) */
    if (setgid(1000) != 0) fprintf(stderr, "setgid: %s\n", strerror(errno));
    if (setuid(1000) != 0) fprintf(stderr, "setuid: %s\n", strerror(errno));

    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) { perror("socket"); return 1; }

    struct sockaddr_un addr;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, SOCK_PATH, sizeof(addr.sun_path) - 1);

    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        perror("connect " SOCK_PATH);
        return 1;
    }

    char msg[4096];
    if (strcmp(argv[1], "--raw") == 0 && argc >= 3) {
        strncpy(msg, argv[2], sizeof(msg) - 1);
    } else {
        const char *cmd = argv[1];
        for (int i = 2; i < argc; i++) {
            strncat(msg, " ", sizeof(msg) - strlen(msg) - 1);
            strncat(msg, argv[i], sizeof(msg) - strlen(msg) - 1);
        }
        if (strncmp(cmd, "shellexec ", 10) != 0) {
            char tmp[4096];
            strncpy(tmp, cmd, sizeof(tmp) - 1);
            strncpy(cmd = tmp, tmp, sizeof(tmp) - 1);
            snprintf(msg, sizeof(msg), "shellexec %s", tmp);
        } else {
            strncpy(msg, cmd, sizeof(msg) - 1);
        }
    }
    /* 补一个换行，方便 shell 执行（--raw 原样发送，不加） */
    if (strcmp(argv[1], "--raw") != 0 && msg[0] && msg[strlen(msg) - 1] != '\n')
        strncat(msg, "\n", sizeof(msg) - strlen(msg) - 1);

    if (write(fd, msg, strlen(msg)) < 0) {
        perror("write");
        return 1;
    }
    shutdown(fd, SHUT_WR);

    char buf[4096];
    int n;
    while ((n = read(fd, buf, sizeof(buf))) > 0) {
        if (write(1, buf, n) < 0) break;
    }
    close(fd);
    return 0;
}
