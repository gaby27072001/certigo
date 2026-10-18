#include "CertigoAppleFileIO.h"
#if defined(__APPLE__)
#include <errno.h>
#include <fcntl.h>
#include <sys/param.h>

int certigo_file_path(int descriptor, char *buffer, size_t capacity) {
    if (buffer == NULL || capacity < MAXPATHLEN) {
        errno = EINVAL;
        return -1;
    }
    return fcntl(descriptor, F_GETPATH, buffer);
}

int certigo_file_protection(int descriptor) {
    return fcntl(descriptor, F_GETPROTECTIONCLASS);
}

int certigo_set_file_protection(int descriptor, int protection) {
    return fcntl(descriptor, F_SETPROTECTIONCLASS, protection);
}
#endif
