// C99 代码由 Uya Mini 编译器生成
// 使用 -std=c99 编译
//
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>

// C99 兼容的 alignof 实现
#define uya_alignof(type) offsetof(struct { char c; type t; }, t)


int32_t add(int32_t a, int32_t b);
int32_t main();

int32_t add(int32_t a, int32_t b) {
    return (a + b);
}

int32_t main() {
    const int32_t x = 10;
    const int32_t y = 20;
    const int32_t result = add(x, y);
    return result;
}

