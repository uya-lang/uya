// C99 代码由 Uya Mini 编译器生成
// 使用 -std=c99 编译
//
#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdarg.h>
#include <stdio.h>

// C99 兼容的 alignof 实现
#define uya_alignof(type) offsetof(struct { char c; type t; }, t)

static inline void *__uya_memcpy(void *dest, const void *src, size_t n) {
    char *d = (char *)dest; const char *s = (const char *)src;
    for (size_t i = 0; i < n; i++) d[i] = s[i]; return dest;
}
static inline int __uya_memcmp(const void *s1, const void *s2, size_t n) {
    const unsigned char *a = (const unsigned char *)s1, *b = (const unsigned char *)s2;
    for (size_t i = 0; i < n; i++) { if (a[i] != b[i]) return a[i] - b[i]; } return 0;
}

// 错误联合类型（用于 !i64 等）
struct err_union_int64_t { uint32_t error_id; int64_t value; };


struct TypeInfo;
struct Point;
struct Rect;
struct Node;

enum Color {
    Red = 1,
    Green = 2,
    Blue = 3
};

enum Status {
    Pending,
    Processing,
    Completed
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

struct Point {
    int32_t x;
    int32_t y;
};

struct Rect {
    struct Point top_left;
    struct Point bottom_right;
    enum Color color;
    enum Status status;
};

struct Node {
    int32_t value;
    enum Color color;
    struct Node * children[4];
    struct Point point;
};

// 系统调用辅助函数（Linux x86-64）
#ifdef __x86_64__
static inline long uya_syscall0(long nr) {
    register long rax __asm__("rax") = nr;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall1(long nr, long a1) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall2(long nr, long a1, long a2) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall3(long nr, long a1, long a2, long a3) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall4(long nr, long a1, long a2, long a3, long a4) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    register long r10 __asm__("r10") = a4;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall5(long nr, long a1, long a2, long a3, long a4, long a5) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8) : "rcx", "r11", "memory");
    return rax;
}

static inline long uya_syscall6(long nr, long a1, long a2, long a3, long a4, long a5, long a6) {
    register long rax __asm__("rax") = nr;
    register long rdi __asm__("rdi") = a1;
    register long rsi __asm__("rsi") = a2;
    register long rdx __asm__("rdx") = a3;
    register long r10 __asm__("r10") = a4;
    register long r8 __asm__("r8") = a5;
    register long r9 __asm__("r9") = a6;
    __asm__ volatile("syscall" : "=r"(rax) : "r"(rax), "r"(rdi), "r"(rsi), "r"(rdx), "r"(r10), "r"(r8), "r"(r9) : "rcx", "r11", "memory");
    return rax;
}
#else
#error "@syscall currently only supports Linux x86-64"
#endif

int32_t test_enum_struct();
int32_t test_enum_array();
int32_t test_struct_array();
int32_t test_enum_struct_array();
int32_t test_pointer_struct_enum();
int32_t test_multidim_struct_array();
int32_t test_enum_struct_comparison();
struct Rect test_mixed_function_params(struct Point p, enum Color c, enum Status s);
int32_t test_mixed_function();
int32_t test_mixed_sizeof_alignof();
int32_t test_mixed_type_conversion();
int32_t test_complex_combination();
int32_t uya_main(void);

int32_t test_enum_struct() {
    struct Rect rect = (struct Rect){.top_left = (struct Point){.x = 0, .y = 0}, .bottom_right = (struct Point){.x = 10, .y = 10}, .color = Red, .status = Pending};
    if (((rect.color != Red) || (rect.status != Pending))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (((rect.top_left.x != 0) || (rect.top_left.y != 0))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_enum_array() {
const enum Color colors[3] = {Red, Green, Blue};
    if ((((colors[0] != Red) || (colors[1] != Green)) || (colors[2] != Blue))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    int32_t count = 0;
    {
        // for loop - array traversal
        size_t _len = sizeof(colors) / sizeof(colors[0]);
        for (size_t _i = 0; _i < _len; _i++) {
            const enum Color color = colors[_i];
            if ((((color == Red) || (color == Green)) || (color == Blue))) {
                count = (count + 1);
            }
        }
    }
    if ((count != 3)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_struct_array() {
const struct Point points[3] = {(struct Point){.x = 0, .y = 0}, (struct Point){.x = 10, .y = 10}, (struct Point){.x = 20, .y = 20}};
    if (((points[0].x != 0) || (points[0].y != 0))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (((points[1].x != 10) || (points[1].y != 10))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
struct Point points2[3] = {0};
    points2[0] = points[0];
    points2[1] = points[1];
    points2[2] = points[2];
    if (((points2[0].x != 0) || (points2[2].x != 20))) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_enum_struct_array() {
const struct Rect rects[2] = {(struct Rect){.top_left = (struct Point){.x = 0, .y = 0}, .bottom_right = (struct Point){.x = 10, .y = 10}, .color = Red, .status = Pending}, (struct Rect){.top_left = (struct Point){.x = 20, .y = 20}, .bottom_right = (struct Point){.x = 30, .y = 30}, .color = Blue, .status = Completed}};
    if (((rects[0].color != Red) || (rects[0].status != Pending))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (((rects[1].color != Blue) || (rects[1].status != Completed))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if (((rects[0].top_left.x != 0) || (rects[1].bottom_right.x != 30))) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_pointer_struct_enum() {
    struct Rect rect = (struct Rect){.top_left = (struct Point){.x = 0, .y = 0}, .bottom_right = (struct Point){.x = 10, .y = 10}, .color = Red, .status = Pending};
    struct Rect * const rect_ptr = (&rect);
    if (((rect_ptr->color != Red) || (rect_ptr->status != Pending))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    rect_ptr->color = Blue;
    rect_ptr->status = Completed;
    if (((rect.color != Blue) || (rect.status != Completed))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if (((rect_ptr->top_left.x != 0) || (rect_ptr->bottom_right.x != 10))) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_multidim_struct_array() {
const struct Point grid[2][2] = {{(struct Point){.x = 0, .y = 0}, (struct Point){.x = 1, .y = 1}}, {(struct Point){.x = 2, .y = 2}, (struct Point){.x = 3, .y = 3}}};
    if (((grid[0][0].x != 0) || (grid[0][0].y != 0))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (((grid[1][1].x != 3) || (grid[1][1].y != 3))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_enum_struct_comparison() {
    struct Rect rect1 = (struct Rect){.top_left = (struct Point){.x = 0, .y = 0}, .bottom_right = (struct Point){.x = 10, .y = 10}, .color = Red, .status = Pending};
    struct Rect rect2 = (struct Rect){.top_left = (struct Point){.x = 0, .y = 0}, .bottom_right = (struct Point){.x = 10, .y = 10}, .color = Red, .status = Pending};
    struct Rect rect3 = (struct Rect){.top_left = (struct Point){.x = 0, .y = 0}, .bottom_right = (struct Point){.x = 10, .y = 10}, .color = Blue, .status = Pending};
    if ((!((__uya_memcmp(&(rect1).top_left, &(rect2).top_left, sizeof((rect1).top_left)) == 0) && (__uya_memcmp(&(rect1).bottom_right, &(rect2).bottom_right, sizeof((rect1).bottom_right)) == 0) && ((rect1).color == (rect2).color) && ((rect1).status == (rect2).status)))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (((__uya_memcmp(&(rect1).top_left, &(rect3).top_left, sizeof((rect1).top_left)) == 0) && (__uya_memcmp(&(rect1).bottom_right, &(rect3).bottom_right, sizeof((rect1).bottom_right)) == 0) && ((rect1).color == (rect3).color) && ((rect1).status == (rect3).status))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if (((rect1.color != Red) || (rect1.color == Blue))) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

struct Rect test_mixed_function_params(struct Point p, enum Color c, enum Status s) {
    struct Rect _uya_ret = (struct Rect){.top_left = p, .bottom_right = (struct Point){.x = (p.x + 10), .y = (p.y + 10)}, .color = c, .status = s};
    return _uya_ret;
}

int32_t test_mixed_function() {
    struct Point p = (struct Point){.x = 5, .y = 5};
    struct Rect rect = test_mixed_function_params(p, Green, Processing);
    if (((rect.top_left.x != 5) || (rect.top_left.y != 5))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (((rect.bottom_right.x != 15) || (rect.bottom_right.y != 15))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if (((rect.color != Green) || (rect.status != Processing))) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_mixed_sizeof_alignof() {
    const int32_t point_size = sizeof(struct Point);
    const int32_t color_size = sizeof(enum Color);
    const int32_t rect_size = sizeof(struct Rect);
    if ((point_size != 8)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if ((color_size != 4)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    if ((rect_size < 24)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    const int32_t point_align = uya_alignof(struct Point);
    const int32_t rect_align = uya_alignof(struct Rect);
    if ((point_align != 4)) {
        int32_t _uya_ret = 4;
        return _uya_ret;
    }
    if ((rect_align != 4)) {
        int32_t _uya_ret = 5;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_mixed_type_conversion() {
    const int32_t color_val = (int32_t)Red;
    if ((color_val != 1)) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    const int32_t status_val = (int32_t)Pending;
    if ((status_val != 0)) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    const int32_t color_as_i32 = (int32_t)Green;
    if ((color_as_i32 != 2)) {
        int32_t _uya_ret = 3;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t test_complex_combination() {
const struct Rect rects[3] = {(struct Rect){.top_left = (struct Point){.x = 0, .y = 0}, .bottom_right = (struct Point){.x = 10, .y = 10}, .color = Red, .status = Pending}, (struct Rect){.top_left = (struct Point){.x = 10, .y = 10}, .bottom_right = (struct Point){.x = 20, .y = 20}, .color = Green, .status = Processing}, (struct Rect){.top_left = (struct Point){.x = 20, .y = 20}, .bottom_right = (struct Point){.x = 30, .y = 30}, .color = Blue, .status = Completed}};
    int32_t red_count = 0;
    int32_t green_count = 0;
    int32_t blue_count = 0;
    {
        // for loop - array traversal
        size_t _len = sizeof(rects) / sizeof(rects[0]);
        for (size_t _i = 0; _i < _len; _i++) {
            const struct Rect rect = rects[_i];
            if ((rect.color == Red)) {
                red_count = (red_count + 1);
            } else {
                if ((rect.color == Green)) {
                    green_count = (green_count + 1);
                } else {
                    if ((rect.color == Blue)) {
                        blue_count = (blue_count + 1);
                    }
                }
            }
        }
    }
    if ((((red_count != 1) || (green_count != 1)) || (blue_count != 1))) {
        int32_t _uya_ret = 1;
        return _uya_ret;
    }
    if (((rects[0].top_left.x != 0) || (rects[2].bottom_right.x != 30))) {
        int32_t _uya_ret = 2;
        return _uya_ret;
    }
    int32_t _uya_ret = 0;
    return _uya_ret;
}

int32_t uya_main(void) {
const int32_t result1 = test_enum_struct();
if ((result1 != 0)) {
    int32_t _uya_ret = result1;
    return _uya_ret;
}
const int32_t result2 = test_enum_array();
if ((result2 != 0)) {
    int32_t _uya_ret = (10 + result2);
    return _uya_ret;
}
const int32_t result3 = test_struct_array();
if ((result3 != 0)) {
    int32_t _uya_ret = (20 + result3);
    return _uya_ret;
}
const int32_t result4 = test_enum_struct_array();
if ((result4 != 0)) {
    int32_t _uya_ret = (30 + result4);
    return _uya_ret;
}
const int32_t result5 = test_pointer_struct_enum();
if ((result5 != 0)) {
    int32_t _uya_ret = (40 + result5);
    return _uya_ret;
}
const int32_t result6 = test_multidim_struct_array();
if ((result6 != 0)) {
    int32_t _uya_ret = (50 + result6);
    return _uya_ret;
}
const int32_t result7 = test_enum_struct_comparison();
if ((result7 != 0)) {
    int32_t _uya_ret = (60 + result7);
    return _uya_ret;
}
const int32_t result8 = test_mixed_function();
if ((result8 != 0)) {
    int32_t _uya_ret = (70 + result8);
    return _uya_ret;
}
const int32_t result9 = test_mixed_sizeof_alignof();
if ((result9 != 0)) {
    int32_t _uya_ret = (80 + result9);
    return _uya_ret;
}
const int32_t result10 = test_mixed_type_conversion();
if ((result10 != 0)) {
    int32_t _uya_ret = (90 + result10);
    return _uya_ret;
}
const int32_t result11 = test_complex_combination();
if ((result11 != 0)) {
    int32_t _uya_ret = (100 + result11);
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
