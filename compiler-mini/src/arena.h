#ifndef ARENA_H
#define ARENA_H

#include <stddef.h>
#include <stdint.h>

// Arena 分配器结构体
// 使用静态缓冲区 + bump pointer 实现无堆分配的内存管理
typedef struct {
    uint8_t *buffer;        // 静态缓冲区指针
    size_t size;            // 缓冲区总大小（字节）
    size_t offset;          // 当前分配位置（bump pointer）
} Arena;

// 初始化 Arena 分配器
// 参数：arena - Arena 结构体指针，buffer - 静态缓冲区，size - 缓冲区大小
// 注意：buffer 必须是一个静态缓冲区（栈上或全局），不能是堆分配的内存
void arena_init(Arena *arena, void *buffer, size_t size);

// 从 Arena 分配内存
// 参数：arena - Arena 分配器指针，size - 要分配的内存大小（字节）
// 返回：分配的内存指针，如果分配失败（空间不足）返回 NULL
// 注意：分配的内存会自动对齐到 8 字节边界
void *arena_alloc(Arena *arena, size_t size);

// 重置 Arena 分配器
// 参数：arena - Arena 分配器指针
// 将 bump pointer 重置到开始位置，释放所有已分配的内存
// 注意：不会清除缓冲区内容，只是重置指针
void arena_reset(Arena *arena);

#endif // ARENA_H

