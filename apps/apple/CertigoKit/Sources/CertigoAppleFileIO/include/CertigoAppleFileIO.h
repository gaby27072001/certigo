#ifndef CERTIGO_APPLE_FILE_IO_H
#define CERTIGO_APPLE_FILE_IO_H

#include <stddef.h>

int certigo_file_path(int descriptor, char *buffer, size_t capacity);
int certigo_file_protection(int descriptor);
int certigo_set_file_protection(int descriptor, int protection);

#endif
