// Hosted native print helper runtime object.
//
// This object is linked by hosted native profiles when PortableMIR contains
// print/println helper calls. The __uya_* symbols are the canonical runtime
// surface; the uya_write* names bridge the current MIR helper IDs.

#include <limits.h>
#include <stddef.h>
#include <stdint.h>
#include <unistd.h>

static int __uya_write_clamped(int fd, const char *buf, int len) {
    ssize_t written;
    if (len <= 0) {
        return 0;
    }
    if (buf == NULL) {
        return -1;
    }
    written = write(fd, buf, (size_t)len);
    if (written < 0) {
        return -1;
    }
    if (written > INT_MAX) {
        return INT_MAX;
    }
    return (int)written;
}

int __uya_print_str(int fd, const char *ptr, int len) {
    return __uya_write_clamped(fd, ptr, len);
}

int __uya_write_newline(int fd) {
    return __uya_write_clamped(fd, "\n", 1);
}

int __uya_print_i32(int fd, int value) {
    char out[16];
    char digits[16];
    int len = 0;
    int digit_count = 0;
    long long temp = value;
    int i;

    if (temp == 0) {
        return __uya_write_clamped(fd, "0", 1);
    }
    if (temp < 0) {
        out[len++] = '-';
        temp = -temp;
    }
    while (temp > 0 && digit_count < (int)sizeof(digits)) {
        digits[digit_count++] = (char)('0' + (temp % 10));
        temp = temp / 10;
    }
    i = digit_count - 1;
    while (i >= 0 && len < (int)sizeof(out)) {
        out[len++] = digits[i];
        i = i - 1;
    }
    return __uya_write_clamped(fd, out, len);
}

int uya_write(int fd, const char *ptr, unsigned long len) {
    if (len > (unsigned long)INT_MAX) {
        return -1;
    }
    return __uya_write_clamped(fd, ptr, (int)len);
}

int uya_write_str(int fd, const char *ptr, int len) {
    return __uya_print_str(fd, ptr, len);
}

int uya_write_newline(int fd) {
    return __uya_write_newline(fd);
}
