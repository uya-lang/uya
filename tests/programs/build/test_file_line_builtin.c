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


// 字符串常量
static const char str0[] = "File: %s\n";
static const char str1[] = "test_file_line_builtin.uya";
static const char str2[] = "错误: @file 未返回正确的文件名\n";
static const char str3[] = "Line 1: %d\n";
static const char str4[] = "Line 2: %d\n";
static const char str5[] = "错误: @line 未递增（line1=%d, line2=%d）\n";
static const char str6[] = "Sum (@line + 10): %d\n";
static const char str7[] = "错误: 同一行的 @line 应该返回相同值（line3=%d, line4=%d）\n";
static const char str8[] = "Direct @line in printf: %d\n";
static const char str9[] = "错误: @file 在不同位置应该返回相同文件名\n";
static const char str10[] = "所有测试通过\n";

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
uint8_t * const file = "tests/programs/test_file_line_builtin.uya";
printf((uint8_t *)str0, file);
uint8_t * const found = strstr(file, (uint8_t *)str1);
if ((found == NULL)) {
    printf("%s", (uint8_t *)str2);
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t line1 = 20;
printf((uint8_t *)str3, line1);
const int32_t line2 = 23;
printf((uint8_t *)str4, line2);
if ((line2 <= line1)) {
    printf((uint8_t *)str5, line1, line2);
    int32_t _uya_ret = 1;
    return _uya_ret;
}
const int32_t sum = (33 + 10);
printf((uint8_t *)str6, sum);
const int32_t line3 = 37;
const int32_t line4 = 37;
if ((line3 != line4)) {
    printf((uint8_t *)str7, line3, line4);
    int32_t _uya_ret = 1;
    return _uya_ret;
}
printf((uint8_t *)str8, 44);
uint8_t * const file2 = "tests/programs/test_file_line_builtin.uya";
if ((strcmp(file, file2) != 0)) {
    printf("%s", (uint8_t *)str9);
    int32_t _uya_ret = 1;
    return _uya_ret;
}
printf("%s", (uint8_t *)str10);
int32_t _uya_ret = 0;
return _uya_ret;
}
