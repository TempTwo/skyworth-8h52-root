/* guardctl —— 通过 coocaa_guard 的 Unix socket 下发命令
 *
 * 背景：
 *   /system/vendor/bin/coocaa_guard 以 root 运行，监听一个 Unix socket。
 *   V017/V020 上它用的是 **abstract namespace**（名字以 '@' 开头，
 *   在 /proc/net/unix 里显示为 "@coocaa_guard_ctrl_cmd"），不是文件路径。
 *   早先的版本监听的是文件 /data/ccos/guard.sock。
 *   两种都支持：优先 abstract，失败再退回文件。
 *
 *   socket 目录/属主限制 uid=1000(system) 才能连，
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

/* abstract namespace 名字（不带前导 '@'，connect 时内核会补） */
#define ABS_SOCK_NAME "coocaa_guard_ctrl_cmd"
/* 旧版本的文件路径 */
#define FILE_SOCK_PATH "/data/ccos/guard.sock"

static int connect_abstract(const char *name) {
    struct sockaddr_un addr;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    /* Linux abstract socket: sun_path[0] = '\0'，名字从 sun_path+1 开始 */
    addr.sun_path[0] = '\0';
    strncpy(addr.sun_path + 1, name, sizeof(addr.sun_path) - 2);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) == 0) return fd;
    close(fd);
    return -1;
}

static int connect_file(const char *path) {
    struct sockaddr_un addr;
    int fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd < 0) return -1;
    memset(&addr, 0, sizeof(addr));
    addr.sun_family = AF_UNIX;
    strncpy(addr.sun_path, path, sizeof(addr.sun_path) - 1);
    if (connect(fd, (struct sockaddr *)&addr, sizeof(addr)) == 0) return fd;
    close(fd);
    return -1;
}

int main(int argc, char **argv) {
    if (argc < 2) {
        fprintf(stderr, "用法: %s <命令>   |   %s --raw <原文>\n", argv[0], argv[0]);
        return 2;
    }

    /* 降权到 system(1000)，才能连上 socket */
    if (setgid(1000) != 0) fprintf(stderr, "setgid: %s\n", strerror(errno));
    if (setuid(1000) != 0) fprintf(stderr, "setuid: %s\n", strerror(errno));

    int fd = connect_abstract(ABS_SOCK_NAME);
    if (fd < 0) {
        fd = connect_file(FILE_SOCK_PATH);
        if (fd < 0) {
            fprintf(stderr, "connect %s (abstract) 和 %s (file) 都失败: %s\n",
                    ABS_SOCK_NAME, FILE_SOCK_PATH, strerror(errno));
            return 1;
        }
    }

    char msg[4096];
    msg[0] = '\0';
    if (strcmp(argv[1], "--raw") == 0 && argc >= 3) {
        strncpy(msg, argv[2], sizeof(msg) - 1);
    } else {
        const char *cmd = argv[1];
        char tmp[4096];
        strncpy(tmp, cmd, sizeof(tmp) - 1);
        if (strncmp(tmp, "shellexec ", 10) != 0) {
            snprintf(msg, sizeof(msg), "shellexec %s", tmp);
        } else {
            strncpy(msg, tmp, sizeof(msg) - 1);
        }
        for (int i = 2; i < argc; i++) {
            strncat(msg, " ", sizeof(msg) - strlen(msg) - 1);
            strncat(msg, argv[i], sizeof(msg) - strlen(msg) - 1);
        }
    }
    /* 补一个换行，方便 shell 执行（--raw 原样发送，不加） */
    if (strcmp(argv[1], "--raw") != 0 && msg[0] && msg[strlen(msg) - 1] != '\n')
        strncat(msg, "\n", sizeof(msg) - strlen(msg) - 1);

    if (write(fd, msg, strlen(msg)) < 0) {
        perror("write");
        close(fd);
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
