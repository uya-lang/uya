// bridge.c - 提供运行时桥接函数（测试版本）
// 这个文件提供了 Uya 程序需要的运行时函数，包括：
// 1. 命令行参数访问函数（get_argc, get_argv）
// 2. 标准错误流访问函数（get_stderr）
// 3. 指针运算辅助函数（ptr_diff）

#include <stdio.h>
#include <stdint.h>
#include <stddef.h>

// 全局变量：保存命令行参数
static int saved_argc = 0;
static char **saved_argv = NULL;

// 初始化函数：由生成的 main 函数调用，保存命令行参数
void bridge_init(int argc, char **argv) {
    saved_argc = argc;
    saved_argv = argv;
}

// 获取命令行参数数量
int32_t get_argc(void) {
    return (int32_t)saved_argc;
}

// 获取第 index 个命令行参数
uint8_t *get_argv(int32_t index) {
    if (index < 0 || index >= saved_argc || saved_argv == NULL) {
        return NULL;
    }
    return (uint8_t *)saved_argv[index];
}

// 获取标准错误流指针
void *get_stderr(void) {
    return (void *)stderr;
}

// 计算两个指针之间的字节偏移量（ptr1 - ptr2）
// 用于替代 Uya Mini 中不支持的指针到整数直接转换
int32_t ptr_diff(uint8_t *ptr1, uint8_t *ptr2) {
    if (ptr1 == NULL || ptr2 == NULL) {
        return 0;
    }
    return (int32_t)(ptr1 - ptr2);
}

