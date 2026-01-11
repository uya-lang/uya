#include "codegen.h"
#include <string.h>

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
    char *name_copy = (char *)arena_alloc(arena, name_len + 1);
    if (!name_copy) {
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
    
    return 0;
}

// 获取基础类型的LLVM类型
// 参数：codegen - 代码生成器指针
//       type_kind - 类型种类（TypeKind枚举：TYPE_I32, TYPE_BOOL, TYPE_VOID）
// 返回：LLVM类型引用，失败返回NULL
// 注意：此函数仅支持基础类型，结构体类型需要使用其他函数
LLVMTypeRef codegen_get_base_type(CodeGenerator *codegen, TypeKind type_kind) {
    if (!codegen || !codegen->context) {
        return NULL;
    }
    
    switch (type_kind) {
        case TYPE_I32:
            // i32 类型映射到 LLVM Int32 类型（全局类型，不依赖context）
            return LLVMInt32Type();
            
        case TYPE_BOOL:
            // bool 类型映射到 LLVM Int1 类型（1位整数，更精确，全局类型）
            return LLVMInt1Type();
            
        case TYPE_VOID:
            // void 类型映射到 LLVM Void 类型（全局类型）
            return LLVMVoidType();
            
        case TYPE_STRUCT:
            // 结构体类型不能使用此函数，应使用其他函数
            return NULL;
            
        default:
            return NULL;
    }
}

// 从AST生成代码
// 参数：codegen - 代码生成器指针
//       ast - AST 根节点（程序节点）
//       output_file - 输出文件路径
// 返回：成功返回0，失败返回非0
int codegen_generate(CodeGenerator *codegen, ASTNode *ast, const char *output_file) {
    if (!codegen || !ast || !output_file) {
        return -1;
    }
    
    // TODO: 实现代码生成逻辑
    // 1. 为每个结构体定义创建 LLVM 结构体类型
    // 2. 为每个函数创建 LLVM 函数声明/定义
    // 3. 生成函数体：遍历 AST，生成对应的 LLVM IR 指令
    // 4. 运行优化器（可选）
    // 5. 生成目标代码：使用 LLVMTargetMachineEmitToFile()
    // 6. 清理资源
    
    return -1;  // 暂时返回失败，待实现
}

