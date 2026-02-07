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


struct TypeInfo;

// 内置 TypeInfo 结构体（由 @mc_type 使用）
struct TypeInfo {
    int8_t * name;
    int32_t size;
    int32_t align;
    int32_t kind;
    bool is_integer;
    bool is_float;
    bool is_bool;
    bool is_pointer;
    bool is_array;
    bool is_void;
};

int32_t uya_main(void);

int32_t uya_main(void) {
const int32_t sum = (10 + 20);
if ((sum != 30)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t sq = (5 * 5);
if ((sq != 25)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const int32_t c = 42;
if ((c != 42)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
const int32_t _unused = 0;
const int32_t nested = ((2 * 2) + (3 * 3));
if ((nested != 13)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
