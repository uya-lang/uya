#include <stdio.h>

// 为 test_comprehensive_cast.uya 提供的外部函数实现
int tn(void* node) {
    return 1;  // 简单返回 1
}

int pt(const char* s) {
    printf("%s\n", s);
    return 1;
}

// 为 test_ffi_cast.uya 提供的外部函数实现
int test_ffi_ptr(void* ptr) {
    return 2;  // 简单返回 2
}

int puts(const char* s) {
    printf("%s", s);
    return 1;
}

// 为 test_pointer_cast.uya 提供的外部函数实现
int process_data(void* data) {
    return 3;  // 简单返回 3
}

int print_int(int n) {
    printf("print_int: %d\n", n);
    return n;  // 返回 n 本身，这样测试可以验证返回值
}

// 为 test_simple_cast.uya 提供的外部函数实现
int proc(void* item) {
    return 4;  // 简单返回 4
}

int print(const char* s) {
    printf("%s", s);
    return 1;
}