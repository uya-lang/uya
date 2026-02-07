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
struct Container;


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

struct Container_i32 {
    int32_t value;
};

struct Container_f64 {
    double value;
};

int32_t uya_Container_i32_get(const struct Container_i32 * self);
void uya_Container_i32_set(const struct Container_i32 * self, int32_t new_value);
double uya_Container_f64_get(const struct Container_f64 * self);
void uya_Container_f64_set(const struct Container_f64 * self, double new_value);
int32_t uya_main(void);

int32_t uya_Container_i32_get(const struct Container_i32 * self) {
    int32_t _uya_ret = self->value;
    return _uya_ret;
}

void uya_Container_i32_set(const struct Container_i32 * self, int32_t new_value) {
}

double uya_Container_f64_get(const struct Container_f64 * self) {
    double _uya_ret = self->value;
    return _uya_ret;
}

void uya_Container_f64_set(const struct Container_f64 * self, double new_value) {
}

int32_t uya_main(void) {
const struct Container_i32 c = (struct Container_i32){.value = 42};
const int32_t v = uya_Container_i32_get(&(c));
if ((v != 42)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const struct Container_f64 cf = (struct Container_f64){.value = 3.1400000000000001};
const double vf = uya_Container_f64_get(&(cf));
int32_t _uya_ret = 0;
return _uya_ret;
}
