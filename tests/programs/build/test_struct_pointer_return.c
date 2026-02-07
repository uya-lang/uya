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
struct Node;
struct Inner;
struct Outer;



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

struct Node {
    int32_t value;
    struct Node * next;
};

struct Inner {
    int32_t data;
};

struct Outer {
    struct Inner inner;
    int32_t count;
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

struct Point * get_global_point();
struct Node * get_global_node();
struct Point * get_point_pointer(struct Point * p);
struct Node * get_node_pointer(struct Node * n);
struct Outer * get_outer_pointer(struct Outer * o);
struct Inner * get_inner_pointer_from_outer(struct Outer * o);
int32_t * get_point_x_pointer(struct Point * p);
int32_t * get_point_y_pointer(struct Point * p);
struct Point * get_point_from_node(struct Node * n);
int32_t * get_array_first_element();
uint8_t * get_byte_array_first_element();
struct Point * get_struct_array_first_element();
int32_t * get_array_element_by_index(int32_t index);
struct Point * get_struct_array_element_by_index(int32_t index);
struct Outer * get_nested_struct_array_first_element();
struct Node * get_node_array_first_element();
struct Point * get_struct_array_element_and_modify();
int32_t get_x(struct Point * p);
int32_t get_point_x_from_ptr(struct Point * p);
int32_t get_value_from_ptr(int32_t * p);
int32_t uya_main(void);

struct Point global_point = {.x = 0, .y = 0};

struct Node global_node = {.value = 0, .next = NULL};

int32_t global_array[5] = {10, 20, 30, 40, 50};

uint8_t global_byte_array[10] = {1, 2, 3, 4, 5, 6, 7, 8, 9, 10};

struct Point global_point_array[3] = {{.x = 100, .y = 200}, {.x = 300, .y = 400}, {.x = 500, .y = 600}};

struct Point global_point_array2[5] = {{.x = 1, .y = 2}, {.x = 3, .y = 4}, {.x = 5, .y = 6}, {.x = 7, .y = 8}, {.x = 9, .y = 10}};

struct Outer global_outer_array[3] = {{.inner = {.data = 100}, .count = 1}, {.inner = {.data = 200}, .count = 2}, {.inner = {.data = 300}, .count = 3}};

struct Node global_node_array[3] = {{.value = 10, .next = NULL}, {.value = 20, .next = NULL}, {.value = 30, .next = NULL}};

struct Point global_point_array3[3] = {{.x = 100, .y = 200}, {.x = 300, .y = 400}, {.x = 500, .y = 600}};

struct Point * get_global_point() {
    struct Point * _uya_ret = (&global_point);
    return _uya_ret;
}

struct Node * get_global_node() {
    struct Node * _uya_ret = (&global_node);
    return _uya_ret;
}

struct Point * get_point_pointer(struct Point * p) {
    struct Point * _uya_ret = p;
    return _uya_ret;
}

struct Node * get_node_pointer(struct Node * n) {
    struct Node * _uya_ret = n;
    return _uya_ret;
}

struct Outer * get_outer_pointer(struct Outer * o) {
    struct Outer * _uya_ret = o;
    return _uya_ret;
}

struct Inner * get_inner_pointer_from_outer(struct Outer * o) {
    struct Inner * _uya_ret = (&o->inner);
    return _uya_ret;
}

int32_t * get_point_x_pointer(struct Point * p) {
    int32_t * _uya_ret = (&p->x);
    return _uya_ret;
}

int32_t * get_point_y_pointer(struct Point * p) {
    int32_t * _uya_ret = (&p->y);
    return _uya_ret;
}

struct Point * get_point_from_node(struct Node * n) {
    global_point.x = n->value;
    global_point.y = (n->value * 2);
    struct Point * _uya_ret = (&global_point);
    return _uya_ret;
}

int32_t * get_array_first_element() {
    int32_t * _uya_ret = (&global_array[0]);
    return _uya_ret;
}

uint8_t * get_byte_array_first_element() {
    uint8_t * _uya_ret = (&global_byte_array[0]);
    return _uya_ret;
}

struct Point * get_struct_array_first_element() {
    struct Point * _uya_ret = (&global_point_array[0]);
    return _uya_ret;
}

int32_t * get_array_element_by_index(int32_t index) {
    int32_t * _uya_ret = (&global_array[index]);
    return _uya_ret;
}

struct Point * get_struct_array_element_by_index(int32_t index) {
    struct Point * _uya_ret = (&global_point_array2[index]);
    return _uya_ret;
}

struct Outer * get_nested_struct_array_first_element() {
    struct Outer * _uya_ret = (&global_outer_array[0]);
    return _uya_ret;
}

struct Node * get_node_array_first_element() {
    struct Node * _uya_ret = (&global_node_array[0]);
    return _uya_ret;
}

struct Point * get_struct_array_element_and_modify() {
    global_point_array3[0].x = 111;
    global_point_array3[0].y = 222;
    struct Point * _uya_ret = (&global_point_array3[0]);
    return _uya_ret;
}

int32_t get_x(struct Point * p) {
    int32_t _uya_ret = p->x;
    return _uya_ret;
}

int32_t get_point_x_from_ptr(struct Point * p) {
    int32_t _uya_ret = p->x;
    return _uya_ret;
}

int32_t get_value_from_ptr(int32_t * p) {
    int32_t _uya_ret = (*p);
    return _uya_ret;
}

int32_t uya_main(void) {
global_point.x = 100;
global_point.y = 200;
struct Point * ptr1 = get_global_point();
if ((ptr1 == NULL)) {
    int32_t _uya_ret = 1;
    return _uya_ret;
}
if (((ptr1->x != 100) || (ptr1->y != 200))) {
    int32_t _uya_ret = 2;
    return _uya_ret;
}
ptr1->x = 300;
ptr1->y = 400;
if (((global_point.x != 300) || (global_point.y != 400))) {
    int32_t _uya_ret = 3;
    return _uya_ret;
}
struct Point local_point = (struct Point){.x = 10, .y = 20};
struct Point * ptr2 = get_point_pointer((&local_point));
if (((ptr2->x != 10) || (ptr2->y != 20))) {
    int32_t _uya_ret = 4;
    return _uya_ret;
}
ptr2->x = 50;
ptr2->y = 60;
if (((local_point.x != 50) || (local_point.y != 60))) {
    int32_t _uya_ret = 5;
    return _uya_ret;
}
struct Node local_node = (struct Node){.value = 99, .next = NULL};
struct Node * node_ptr = get_node_pointer((&local_node));
if ((node_ptr->value != 99)) {
    int32_t _uya_ret = 6;
    return _uya_ret;
}
node_ptr->value = 77;
if ((local_node.value != 77)) {
    int32_t _uya_ret = 7;
    return _uya_ret;
}
struct Outer outer = (struct Outer){.inner = (struct Inner){.data = 500}, .count = 10};
struct Outer * outer_ptr = get_outer_pointer((&outer));
if (((outer_ptr->inner.data != 500) || (outer_ptr->count != 10))) {
    int32_t _uya_ret = 8;
    return _uya_ret;
}
outer_ptr->inner.data = 600;
outer_ptr->count = 20;
if (((outer.inner.data != 600) || (outer.count != 20))) {
    int32_t _uya_ret = 9;
    return _uya_ret;
}
struct Inner * inner_ptr = get_inner_pointer_from_outer((&outer));
if ((inner_ptr->data != 600)) {
    int32_t _uya_ret = 10;
    return _uya_ret;
}
inner_ptr->data = 700;
if ((outer.inner.data != 700)) {
    int32_t _uya_ret = 11;
    return _uya_ret;
}
struct Point point = (struct Point){.x = 1000, .y = 2000};
int32_t * x_ptr = get_point_x_pointer((&point));
int32_t * y_ptr = get_point_y_pointer((&point));
if ((((*x_ptr) != 1000) || ((*y_ptr) != 2000))) {
    int32_t _uya_ret = 12;
    return _uya_ret;
}
(*x_ptr) = 3000;
(*y_ptr) = 4000;
if (((point.x != 3000) || (point.y != 4000))) {
    int32_t _uya_ret = 13;
    return _uya_ret;
}
global_node.value = 42;
global_node.next = NULL;
struct Node node = (struct Node){.value = 123, .next = NULL};
struct Point * point_ptr = get_point_from_node((&node));
if (((point_ptr->x != 123) || (point_ptr->y != 246))) {
    int32_t _uya_ret = 14;
    return _uya_ret;
}
global_point.x = 300;
global_point.y = 400;
struct Point * ptr3 = get_global_point();
struct Point * ptr4 = get_global_point();
if ((ptr3 != ptr4)) {
    int32_t _uya_ret = 15;
    return _uya_ret;
}
struct Point point1 = (struct Point){.x = 1, .y = 2};
struct Point point2 = (struct Point){.x = 1, .y = 2};
struct Point * ptr5 = get_point_pointer((&point1));
struct Point * ptr6 = get_point_pointer((&point2));
if ((ptr5 == ptr6)) {
    int32_t _uya_ret = 16;
    return _uya_ret;
}
struct Node * null_node = NULL;
struct Node * node_ptr2 = get_node_pointer(null_node);
if ((node_ptr2 != NULL)) {
    int32_t _uya_ret = 17;
    return _uya_ret;
}
struct Point point3 = (struct Point){.x = 999, .y = 888};
struct Point * ptr7 = get_point_pointer((&point3));
struct Point point_copy = (*ptr7);
if (((point_copy.x != 999) || (point_copy.y != 888))) {
    int32_t _uya_ret = 18;
    return _uya_ret;
}
struct Point point4 = (struct Point){.x = 100, .y = 200};
struct Point * ptr8 = get_point_pointer((&point4));
int32_t sum = (ptr8->x + ptr8->y);
if ((sum != 300)) {
    int32_t _uya_ret = 19;
    return _uya_ret;
}
struct Point point5 = (struct Point){.x = 555, .y = 666};
struct Point * ptr9 = get_point_pointer((&point5));
int32_t x_val = get_x(ptr9);
if ((x_val != 555)) {
    int32_t _uya_ret = 20;
    return _uya_ret;
}
struct Point point6 = (struct Point){.x = 777, .y = 888};
struct Point * ptr10 = get_point_pointer((&point6));
struct Point * ptr11 = ptr10;
if (((ptr11->x != 777) || (ptr11->y != 888))) {
    int32_t _uya_ret = 21;
    return _uya_ret;
}
ptr11->x = 999;
if ((point6.x != 999)) {
    int32_t _uya_ret = 22;
    return _uya_ret;
}
int32_t * arr_ptr = get_array_first_element();
if ((arr_ptr == NULL)) {
    int32_t _uya_ret = 23;
    return _uya_ret;
}
int32_t first_val = (*arr_ptr);
if ((first_val != 10)) {
    int32_t _uya_ret = 24;
    return _uya_ret;
}
(*arr_ptr) = 999;
int32_t first_val2 = (*arr_ptr);
if ((first_val2 != 999)) {
    int32_t _uya_ret = 25;
    return _uya_ret;
}
uint8_t * byte_ptr = get_byte_array_first_element();
if ((byte_ptr == NULL)) {
    int32_t _uya_ret = 26;
    return _uya_ret;
}
uint8_t first_byte = (*byte_ptr);
if ((first_byte != 1)) {
    int32_t _uya_ret = 27;
    return _uya_ret;
}
(*byte_ptr) = 100;
uint8_t first_byte2 = (*byte_ptr);
if ((first_byte2 != 100)) {
    int32_t _uya_ret = 28;
    return _uya_ret;
}
struct Point * point_arr_ptr = get_struct_array_first_element();
if ((point_arr_ptr == NULL)) {
    int32_t _uya_ret = 29;
    return _uya_ret;
}
if (((point_arr_ptr->x != 100) || (point_arr_ptr->y != 200))) {
    int32_t _uya_ret = 30;
    return _uya_ret;
}
point_arr_ptr->x = 777;
point_arr_ptr->y = 888;
if (((point_arr_ptr->x != 777) || (point_arr_ptr->y != 888))) {
    int32_t _uya_ret = 31;
    return _uya_ret;
}
struct Point * point_arr_ptr2 = get_struct_array_element_by_index(2);
if ((point_arr_ptr2 == NULL)) {
    int32_t _uya_ret = 42;
    return _uya_ret;
}
if (((point_arr_ptr2->x != 5) || (point_arr_ptr2->y != 6))) {
    int32_t _uya_ret = 43;
    return _uya_ret;
}
point_arr_ptr2->x = 555;
point_arr_ptr2->y = 666;
if (((point_arr_ptr2->x != 555) || (point_arr_ptr2->y != 666))) {
    int32_t _uya_ret = 44;
    return _uya_ret;
}
struct Outer * outer_arr_ptr = get_nested_struct_array_first_element();
if ((outer_arr_ptr == NULL)) {
    int32_t _uya_ret = 45;
    return _uya_ret;
}
if (((outer_arr_ptr->inner.data != 100) || (outer_arr_ptr->count != 1))) {
    int32_t _uya_ret = 46;
    return _uya_ret;
}
outer_arr_ptr->inner.data = 999;
outer_arr_ptr->count = 888;
if (((outer_arr_ptr->inner.data != 999) || (outer_arr_ptr->count != 888))) {
    int32_t _uya_ret = 47;
    return _uya_ret;
}
struct Node * node_arr_ptr = get_node_array_first_element();
if ((node_arr_ptr == NULL)) {
    int32_t _uya_ret = 48;
    return _uya_ret;
}
if ((node_arr_ptr->value != 10)) {
    int32_t _uya_ret = 49;
    return _uya_ret;
}
node_arr_ptr->value = 999;
if ((node_arr_ptr->value != 999)) {
    int32_t _uya_ret = 50;
    return _uya_ret;
}
struct Point * point_arr_ptr3 = get_struct_array_element_and_modify();
if ((point_arr_ptr3 == NULL)) {
    int32_t _uya_ret = 51;
    return _uya_ret;
}
if (((point_arr_ptr3->x != 111) || (point_arr_ptr3->y != 222))) {
    int32_t _uya_ret = 52;
    return _uya_ret;
}
point_arr_ptr3->x = 333;
point_arr_ptr3->y = 444;
if (((point_arr_ptr3->x != 333) || (point_arr_ptr3->y != 444))) {
    int32_t _uya_ret = 53;
    return _uya_ret;
}
struct Point * point_arr_ptr4 = get_struct_array_first_element();
int32_t sum3 = (point_arr_ptr4->x + point_arr_ptr4->y);
if ((sum3 != 1665)) {
    int32_t _uya_ret = 54;
    return _uya_ret;
}
struct Point * point_arr_ptr5 = get_struct_array_element_by_index(1);
int32_t x_val2 = get_point_x_from_ptr(point_arr_ptr5);
if ((x_val2 != 3)) {
    int32_t _uya_ret = 55;
    return _uya_ret;
}
struct Point * point_arr_ptr6 = get_struct_array_first_element();
struct Point * point_arr_ptr7 = point_arr_ptr6;
if (((point_arr_ptr7->x != 777) || (point_arr_ptr7->y != 888))) {
    int32_t _uya_ret = 56;
    return _uya_ret;
}
point_arr_ptr7->x = 1111;
point_arr_ptr7->y = 2222;
if (((point_arr_ptr6->x != 1111) || (point_arr_ptr6->y != 2222))) {
    int32_t _uya_ret = 57;
    return _uya_ret;
}
struct Point * point_arr_ptr8 = get_struct_array_element_by_index(0);
struct Point point_copy2 = (*point_arr_ptr8);
if (((point_copy2.x != 1) || (point_copy2.y != 2))) {
    int32_t _uya_ret = 58;
    return _uya_ret;
}
struct Outer * outer_arr_ptr2 = get_nested_struct_array_first_element();
int32_t inner_data = outer_arr_ptr2->inner.data;
if ((inner_data != 999)) {
    int32_t _uya_ret = 59;
    return _uya_ret;
}
struct Inner * inner_ptr2 = (&outer_arr_ptr2->inner);
if ((inner_ptr2->data != 999)) {
    int32_t _uya_ret = 60;
    return _uya_ret;
}
struct Point * point_arr_ptr9 = get_struct_array_first_element();
struct Point * point_arr_ptr10 = get_struct_array_first_element();
if (((point_arr_ptr9 == NULL) || (point_arr_ptr10 == NULL))) {
    int32_t _uya_ret = 61;
    return _uya_ret;
}
int32_t * elem_ptr = get_array_element_by_index(2);
if ((elem_ptr == NULL)) {
    int32_t _uya_ret = 32;
    return _uya_ret;
}
int32_t elem_val = (*elem_ptr);
if ((elem_val != 30)) {
    int32_t _uya_ret = 33;
    return _uya_ret;
}
(*elem_ptr) = 333;
int32_t elem_val2 = (*elem_ptr);
if ((elem_val2 != 333)) {
    int32_t _uya_ret = 34;
    return _uya_ret;
}
int32_t * arr_ptr2 = get_array_first_element();
int32_t sum2 = ((*arr_ptr2) + 100);
if ((sum2 != 1099)) {
    int32_t _uya_ret = 35;
    return _uya_ret;
}
int32_t * arr_ptr3 = get_array_first_element();
int32_t val = get_value_from_ptr(arr_ptr3);
if ((val != 999)) {
    int32_t _uya_ret = 36;
    return _uya_ret;
}
int32_t * arr_ptr4 = get_array_first_element();
int32_t * arr_ptr5 = arr_ptr4;
if (((*arr_ptr5) != 999)) {
    int32_t _uya_ret = 37;
    return _uya_ret;
}
(*arr_ptr5) = 1111;
if (((*arr_ptr4) != 1111)) {
    int32_t _uya_ret = 38;
    return _uya_ret;
}
int32_t * arr_ptr6 = get_array_first_element();
if ((arr_ptr6 == NULL)) {
    int32_t _uya_ret = 39;
    return _uya_ret;
}
if ((arr_ptr6 != NULL)) {
} else {
    int32_t _uya_ret = 40;
    return _uya_ret;
}
int32_t * arr_ptr7 = get_array_first_element();
int32_t * arr_ptr8 = get_array_first_element();
if (((arr_ptr7 == NULL) || (arr_ptr8 == NULL))) {
    int32_t _uya_ret = 41;
    return _uya_ret;
}
int32_t _uya_ret = 0;
return _uya_ret;
}
