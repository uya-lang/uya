#include "internal.h"

// 创建代码生成器
// 参数：codegen - CodeGenerator 结构体指针（由调用者分配）
//       arena - Arena 分配器指针
//       module_name - 模块名称（字符串存储在 Arena 中）
// 返回：成功返回0，失败返回非0
int codegen_new(CodeGenerator *codegen, Arena *arena, const char *module_name) {
    if (!codegen || !arena || !module_name) {
        return -1;
    }
    
    // 初始化结构体
    memset(codegen, 0, sizeof(CodeGenerator));
    
    // 设置 Arena 分配器
    codegen->arena = arena;
    
    // 复制模块名称到 Arena
    size_t name_len = strlen(module_name);
    // 注意：需要检查 Arena 的剩余空间
    extern size_t arena_get_used(Arena *arena);  // 前向声明（如果存在）
    char *name_copy = (char *)arena_alloc(arena, name_len + 1);
    if (!name_copy) {
        // 尝试获取 Arena 使用情况（如果可能）
        return -1;
    }
    memcpy(name_copy, module_name, name_len + 1);
    codegen->module_name = name_copy;
    
    // 创建 LLVM 上下文
    codegen->context = LLVMContextCreate();
    if (!codegen->context) {
        return -1;
    }
    
    // 创建 LLVM 模块
    codegen->module = LLVMModuleCreateWithNameInContext(codegen->module_name, codegen->context);
    if (!codegen->module) {
        LLVMContextDispose(codegen->context);
        return -1;
    }
    
    // 创建 IR 构建器
    codegen->builder = LLVMCreateBuilderInContext(codegen->context);
    if (!codegen->builder) {
        LLVMDisposeModule(codegen->module);
        LLVMContextDispose(codegen->context);
        return -1;
    }
    
    // 初始化结构体类型映射表
    codegen->struct_type_count = 0;
    
    // 初始化变量表和函数表
    codegen->var_map_count = 0;
    codegen->func_map_count = 0;
    codegen->global_var_map_count = 0;
    codegen->basic_block_counter = 0;
    codegen->string_literal_counter = 0;
    codegen->loop_stack_depth = 0;
    codegen->program_node = NULL;
    
    return 0;
}

