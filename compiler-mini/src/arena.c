#include "arena.h"
#include <stdint.h>
#include <stddef.h>

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
        return NULL;
    }
    
    // 对齐当前的 offset，确保返回的地址是 8 字节对齐的
    size_t aligned_offset = align_size(arena->offset, ARENA_ALIGNMENT);
    
    // 对齐请求的大小
    size_t aligned_size = align_size(size, ARENA_ALIGNMENT);
    
    // 检查是否有足够空间
    if (aligned_offset + aligned_size > arena->size) {
        return NULL;  // 空间不足
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

