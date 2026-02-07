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

int32_t uya_main(void) {
const int32_t result = ({ const int32_t x = 42;
x; });
if ((result != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
