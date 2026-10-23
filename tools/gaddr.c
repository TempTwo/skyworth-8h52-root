#include <unistd.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <sys/socket.h>
#include <sys/un.h>

#define ABS_NAME "coocaa_guard_ctrl_cmd"

int main(int argc, char **argv) {
    if (argc < 2) { fprintf(stderr, "usage: gaddr <cmd>\n"); return 2; }
    setgid(1000); setuid(1000);
    const char *name = ABS_NAME;
    size_t nl = strlen(name);

    struct sockaddr_un a;
    int lens[6];
    int nn = 0;
    lens[nn++] = (int)(sizeof(sa_family_t) + 1 + nl + 1);   /* 26 */
    lens[nn++] = (int)(sizeof(sa_family_t) + 1 + nl);       /* 25 */
    lens[nn++] = (int)(sizeof(sa_family_t) + 2 + nl);       /* 26 alt */
    lens[nn++] = (int)(sizeof(struct sockaddr_un));         /* 110 */

    int fd = -1, used = -1;
    for (int i = 0; i < nn && fd < 0; i++) {
        memset(&a, 0, sizeof(a));
        a.sun_family = AF_UNIX;
        a.sun_path[0] = '\0';
        memcpy(a.sun_path + 1, name, nl);
        fd = socket(AF_UNIX, SOCK_STREAM, 0);
        if (fd < 0) { perror("socket"); return 1; }
        if (connect(fd, (struct sockaddr *)&a, lens[i]) == 0) { used = lens[i]; break; }
        fprintf(stderr, "len=%d: %s\n", lens[i], strerror(errno));
        close(fd); fd = -1;
    }
    if (fd < 0) { fprintf(stderr, "all failed\n"); return 1; }
    fprintf(stderr, "connected len=%d\n", used);

    char msg[4096];
    if (strcmp(argv[1], "--raw") == 0) {
        if (argc < 3) { fprintf(stderr, "--raw needs command\n"); return 2; }
        msg[0] = '\0';
        for (int i = 2; i < argc; i++) {
            if (i > 2) strncat(msg, " ", sizeof(msg)-1-strlen(msg));
            strncat(msg, argv[i], sizeof(msg)-1-strlen(msg));
        }
    } else {
        snprintf(msg, sizeof(msg), "shellexec %s", argv[1]);
    }
    size_t L = strlen(msg);
    msg[L++] = '\n';
    if (write(fd, msg, L) < 0) perror("write");
    shutdown(fd, SHUT_WR);
    char buf[8192]; int n;
    while ((n = read(fd, buf, sizeof(buf))) > 0) write(1, buf, n);
    return 0;
}
