# 阶段2：实现 Arena 分配器 ✅

## 2.1 Arena 分配器接口

- [x] 创建 `src/arena.h`
  - [x] 定义 Arena 结构体（包含静态缓冲区、当前指针、大小等字段）
  - [x] 声明 `arena_alloc(size)` - 分配内存
  - [x] 声明 `arena_reset()` - 重置分配器
  - [x] 声明 `arena_init()` - 初始化 Arena
  - [x] 添加中文注释说明

## 2.2 Arena 分配器实现

- [x] 创建 `src/arena.c`
  - [x] 实现 `arena_init()` - 初始化 Arena 分配器
  - [x] 实现 `arena_alloc(size)` - 从缓冲区分配内存（bump pointer，支持 8 字节对齐）
  - [x] 实现 `arena_reset()` - 重置指针到开始位置
  - [x] 实现内存对齐（8 字节对齐）
  - [x] 添加中文注释说明
  - [x] 验证代码可以编译

## 2.3 Arena 分配器测试

- [x] 创建测试文件 `tests/test_arena.c`
- [x] 测试基本分配功能
- [x] 测试重置功能
- [x] 测试内存对齐（8 字节对齐）
- [x] 测试分配失败情况（空间不足）
- [x] 所有测试通过

