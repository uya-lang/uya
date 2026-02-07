#include "arena.h"
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>

// 内存对齐边界（字节）
#define ARENA_ALIGNMENT 8

// 对齐到指定边界
// 参数：size - 要对齐的大小，align - 对齐边界
// 返回：对齐后的大小
static size_t align_size(size_t size, size_t align) {
    return (size + align - 1) & ~(align - 1);
}

// 初始化 Arena 分配器
void arena_init(Arena *arena, void *buffer, size_t size) {
    if (arena == NULL || buffer == NULL) {
        return;
    }
    
    arena->buffer = (uint8_t *)buffer;
    arena->size = size;
    arena->offset = 0;
}

// 从 Arena 分配内存
void *arena_alloc(Arena *arena, size_t size) {
    if (arena == NULL || arena->buffer == NULL) {
        fprintf(stderr, "错误: Arena 分配失败（Arena 或 buffer 未初始化）\n");
        exit(1);
    }
    
    // 对齐当前的 offset，确保返回的地址是 8 字节对齐的
    size_t aligned_offset = align_size(arena->offset, ARENA_ALIGNMENT);
    
    // 对齐请求的大小
    size_t aligned_size = align_size(size, ARENA_ALIGNMENT);
    
    // 检查是否有足够空间；不足则报错退出
    if (aligned_offset + aligned_size > arena->size) {
        size_t need = aligned_size;
        size_t remaining = (arena->size > aligned_offset) ? (arena->size - aligned_offset) : 0;
        fprintf(stderr, "错误: Arena 分配失败（内存不足，需要 %zu 字节，剩余 %zu 字节）\n", need, remaining);
        fprintf(stderr, "提示: 请增加 ARENA_BUFFER_SIZE 后重新编译编译器\n");
        exit(1);
    }
    
    // 计算返回的地址（buffer + 对齐后的 offset）
    void *result = (void *)(arena->buffer + aligned_offset);
    
    // 更新 offset（移动到对齐后的位置 + 分配的大小）
    arena->offset = aligned_offset + aligned_size;
    
    return result;
}

// 重置 Arena 分配器
void arena_reset(Arena *arena) {
    if (arena == NULL) {
        return;
    }
    
    arena->offset = 0;
}

