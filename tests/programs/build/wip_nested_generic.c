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
struct Box;
struct Pair;


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

struct Box_i32 {
    int32_t value;
};

struct Pair_i32_i32 {
    int32_t first;
    int32_t second;
};

struct Box_Pair_i32_i32 {
    struct Pair_i32_i32 value;
};


int32_t uya_main(void);

int32_t uya_main(void) {
const struct Box_i32 b1 = (struct Box_i32){.value = 42};
if ((b1.value != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const struct Box_Pair_i32_i32 b2 = (struct Box_Pair_i32_i32){.value = (struct Pair_i32_i32){.first = 10, .second = 20}};
if ((b2.value.first != 10)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
if ((b2.value.second != 20)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
