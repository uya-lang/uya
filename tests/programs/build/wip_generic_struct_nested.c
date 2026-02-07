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
struct DoubleBox;


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
    int32_t data;
};

struct DoubleBox_i32 {
    struct Box_i32 inner;
    int32_t extra;
};

int32_t uya_main(void);

int32_t uya_main(void) {
const struct Box_i32 b1 = (struct Box_i32){.data = 42};
if ((b1.data != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const struct Box_i32 inner_box = (struct Box_i32){.data = 100};
const struct DoubleBox_i32 db = (struct DoubleBox_i32){.inner = inner_box, .extra = 999};
const int32_t inner_data = db.inner.data;
if ((inner_data != 100)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
if ((db.extra != 999)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
