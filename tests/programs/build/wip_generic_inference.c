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

int32_t max_i32(int32_t a, int32_t b);
double max_f64(double a, double b);
int32_t uya_main(void);

int32_t max_i32(int32_t a, int32_t b) {
    if ((a > b)) {
        int32_t _uya_ret = a;
        return _uya_ret;
    } else {
        int32_t _uya_ret = b;
        return _uya_ret;
    }
}

double max_f64(double a, double b) {
    if ((a > b)) {
        double _uya_ret = a;
        return _uya_ret;
    } else {
        double _uya_ret = b;
        return _uya_ret;
    }
}

int32_t uya_main(void) {
const int32_t result1 = max_i32(10, 20);
if ((result1 != 20)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const double result2 = max_f64(3.1400000000000001, 2.71);
if ((result2 != 3.1400000000000001)) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
const int32_t result3 = max_i32(100, 200);
if ((result3 != 200)) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
