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
struct Vec;


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

struct Vec_i32 {
    int32_t * data;
    size_t len;
};

struct Vec_f32 {
    float * data;
    size_t len;
};

size_t get_len_i32(struct Vec_i32 v);
size_t get_len_f32(struct Vec_f32 v);
struct Vec_f32 create_vec_f32(size_t len);
int32_t uya_main(void);

size_t get_len_i32(struct Vec_i32 v) {
    size_t _uya_ret = v.len;
    return _uya_ret;
}

size_t get_len_f32(struct Vec_f32 v) {
    size_t _uya_ret = v.len;
    return _uya_ret;
}

struct Vec_f32 create_vec_f32(size_t len) {
    struct Vec_f32 _uya_ret = (struct Vec_f32){.data = NULL, .len = len};
    return _uya_ret;
}

int32_t uya_main(void) {
const struct Vec_i32 v1 = (struct Vec_i32){.data = NULL, .len = 10};
const size_t len1 = get_len_i32(v1);
if ((len1 != 10)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const struct Vec_f32 v2 = create_vec_f32(20);
if ((v2.len != 20)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const size_t len2 = get_len_f32(v2);
if ((len2 != 20)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
