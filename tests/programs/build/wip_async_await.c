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
static const char str0[] = "@await 语法解析测试\n";

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

int32_t async_get();
int32_t test_await();
int32_t uya_main(void);


int32_t async_get() {
    int32_t _uya_ret = 42;
    return _uya_ret;
}

int32_t test_await() {
    const int32_t result = async_get();
    int32_t _uya_ret = result;
    return _uya_ret;
}

int32_t uya_main(void) {
printf("%s", (const char *)str0);
int32_t _uya_ret = 0;
return _uya_ret;
}
