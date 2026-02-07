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
struct Incomplete;

struct uya_interface_IReader { void *vtable; void *data; };
struct uya_vtable_IReader {
    int32_t (*read)(void *self);
};
struct uya_interface_IWriter { void *vtable; void *data; };
struct uya_vtable_IWriter {
    void (*write)(void *self, int32_t);
};
struct uya_interface_IReadWriter { void *vtable; void *data; };
struct uya_vtable_IReadWriter {
    int32_t (*read)(void *self);
    void (*write)(void *self, int32_t);
};

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

struct Incomplete {
    int32_t data;
};

int32_t uya_Incomplete_read(const struct Incomplete * self);
int32_t uya_main(void);
static const struct uya_vtable_IReadWriter uya_vtable_IReadWriter_Incomplete = { (int32_t (*)(void *self))&uya_Incomplete_read };

int32_t uya_Incomplete_read(const struct Incomplete * self) {
    int32_t _uya_ret = self->data;
    return _uya_ret;
}

int32_t uya_main(void) {
int32_t _uya_ret = 0;
return _uya_ret;
}
