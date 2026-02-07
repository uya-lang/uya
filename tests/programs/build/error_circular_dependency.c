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



int32_t uya_main(void);
int32_t func_a();
int32_t helper_b();

int32_t uya_main(void) {
    const int32_t a = func_a();
    const int32_t b = helper_b();
    int32_t _uya_ret = (a + b);
    return _uya_ret;
}

int32_t func_a() {
    int32_t _uya_ret = (helper_b() + 1);
    return _uya_ret;
}

int32_t helper_b() {
    int32_t _uya_ret = (func_a() + 1);
    return _uya_ret;
}

