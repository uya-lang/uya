// C99 代码由 Uya Mini 编译器生成
// 使用 -std=c99 编译
//
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdarg.h>
#include <string.h>
#include <stdio.h>

// C99 兼容的 alignof 实现
#define uya_alignof(type) offsetof(struct { char c; type t; }, t)


struct PublicStruct;
struct PrivateStruct;


struct PublicStruct {
    int32_t x;
    int32_t y;
};

struct PrivateStruct {
    int32_t x;
};

int32_t public_func();
int32_t private_func();

int32_t public_func() {
    int32_t _uya_ret = 42;
    return _uya_ret;
}

int32_t private_func() {
    int32_t _uya_ret = 0;
    return _uya_ret;
}

