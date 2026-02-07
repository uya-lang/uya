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
struct Result;


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

struct Result_i32 {
    int32_t value;
    bool ok;
};

struct Result_bool {
    bool value;
    bool ok;
};

struct Result_i32 ok_i32(int32_t value);
struct Result_bool ok_bool(bool value);
struct Result_i32 err_i32(int32_t default_value);
int32_t uya_main(void);

struct Result_i32 ok_i32(int32_t value) {
    struct Result_i32 _uya_ret = (struct Result_i32){.value = value, .ok = true};
    return _uya_ret;
}

struct Result_bool ok_bool(bool value) {
    struct Result_bool _uya_ret = (struct Result_bool){.value = value, .ok = true};
    return _uya_ret;
}

struct Result_i32 err_i32(int32_t default_value) {
    struct Result_i32 _uya_ret = (struct Result_i32){.value = default_value, .ok = false};
    return _uya_ret;
}

int32_t uya_main(void) {
const struct Result_i32 r1 = ok_i32(42);
if ((r1.value != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
if ((r1.ok != true)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const struct Result_i32 r2 = err_i32(0);
if ((r2.value != 0)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
if ((r2.ok != false)) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
const struct Result_bool r3 = ok_bool(true);
if ((r3.value != true)) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
