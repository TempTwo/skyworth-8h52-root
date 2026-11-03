/* 读 /dev/input/event* 的原始键码，用来判断创维遥控器发的是标准 Android keycode
 * 还是需要厂商 hiRMService 做映射。
 *
 * 编译（ARM 静态）:
 *   zig cc -target arm-linux-musleabihf -static -Os -o inkeys inkeys.c
 * 用法:
 *   ./inkeys            # 列出所有 input 设备
 *   ./inkeys <device>   # 持续打印某个设备的事件（Ctrl-C 退出）
 *   ./inkeys --all      # 打印所有设备的事件
 */
#include <fcntl.h>
#include <sys/ioctl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <dirent.h>

struct input_event {
    unsigned int time_sec, time_usec;
    unsigned short type;
    unsigned short code;
    unsigned int value;
};

static void list_devices(void) {
    DIR *dir = opendir("/dev/input");
    if (!dir) { perror("/dev/input"); return; }
    struct dirent *ent;
    while ((ent = readdir(dir))) {
        if (strncmp(ent->d_name, "event", 5) != 0) continue;
        char path[256];
        snprintf(path, sizeof(path), "/dev/input/%s", ent->d_name);
        int fd = open(path, O_RDONLY | O_NONBLOCK);
        if (fd < 0) { printf("%-24s (打不开)\n", path); continue; }
        char name[256] = {0}, id[256] = {0};
        unsigned short ev[8], kv[8], abs[8];
        unsigned int evc = 0, kvc = 0, absc = 0;
        ioctl(fd, 0x80016b45 /* EVIOCGNAME */, name);
        ioctl(fd, 0x80084503 /* EVIOCGID */, id);
        ioctl(fd, 0x80082000 /* EVIOCGNAME(len) */, ev);
        (void)ev; (void)evc;
        printf("%-24s name=%s id=%s\n", path, name, id);
        (void)kv; (void)kvc; (void)abs; (void)absc;
        close(fd);
    }
    closedir(dir);
    /* 顺便打印 input 设备的能力表 */
    printf("\n/proc/bus/input/devices:\n");
    FILE *f = fopen("/proc/bus/input/devices", "r");
    if (!f) { perror("devices"); return; }
    char line[512];
    while (fgets(line, sizeof(line), f)) fputs(line, stdout);
    fclose(f);
}

static void dump(const char *path) {
    int fd = open(path, O_RDONLY);
    if (fd < 0) { perror(path); return; }
    printf("--- %s (Ctrl-C 退出) ---\n", path);
    fflush(stdout);
    struct input_event ev;
    while (read(fd, &ev, sizeof(ev)) == (ssize_t)sizeof(ev)) {
        if (ev.type == 1) {  /* EV_KEY */
            printf("KEY code=%u value=%u\n", ev.code, ev.value);
            fflush(stdout);
        }
    }
    close(fd);
}

int main(int argc, char **argv) {
    if (argc < 2 || strcmp(argv[1], "--all") == 0) {
        if (argc >= 2) {
            DIR *dir = opendir("/dev/input");
            struct dirent *ent;
            if (dir) {
                while ((ent = readdir(dir))) {
                    if (strncmp(ent->d_name, "event", 5) != 0) continue;
                    char path[256];
                    snprintf(path, sizeof(path), "/dev/input/%s", ent->d_name);
                    dump(path);
                }
                closedir(dir);
            }
            return 0;
        }
        list_devices();
        return 0;
    }
    dump(argv[1]);
    return 0;
}
