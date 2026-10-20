#include <unistd.h>
#include <string.h>

int main(int argc, char **argv) {
    setgid(0);
    setuid(0);

    if (argc >= 3 && strcmp(argv[1], "-c") == 0) {
        execl("/system/bin/sh", "sh", "-c", argv[2], (char *)0);
    } else if (argc > 1) {
        execvp(argv[1], &argv[1]);
    } else {
        execl("/system/bin/sh", "sh", (char *)0);
    }
    return 1;
}
