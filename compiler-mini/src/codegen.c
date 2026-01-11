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

// 辅助函数：从AST类型节点获取LLVM类型（仅支持基础类型和已注册的结构体类型）
// 参数：codegen - 代码生成器指针
//       type_node - AST类型节点（AST_TYPE_NAMED）
// 返回：LLVM类型引用，失败返回NULL
static LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node) {
    if (!codegen || !type_node || type_node->type != AST_TYPE_NAMED) {
        return NULL;
    }
    
    const char *type_name = type_node->data.type_named.name;
    if (!type_name) {
        return NULL;
    }
    
    // 基础类型
    if (strcmp(type_name, "i32") == 0) {
        return codegen_get_base_type(codegen, TYPE_I32);
    } else if (strcmp(type_name, "bool") == 0) {
        return codegen_get_base_type(codegen, TYPE_BOOL);
    } else if (strcmp(type_name, "void") == 0) {
        return codegen_get_base_type(codegen, TYPE_VOID);
    }
    
    // 结构体类型（必须在注册表中查找）
    return codegen_get_struct_type(codegen, type_name);
}

// 获取结构体类型的LLVM类型
// 参数：codegen - 代码生成器指针
//       struct_name - 结构体名称
// 返回：LLVM类型引用，未找到返回NULL
LLVMTypeRef codegen_get_struct_type(CodeGenerator *codegen, const char *struct_name) {
    if (!codegen || !struct_name) {
        return NULL;
    }
    
    // 在结构体类型映射表中线性查找
    for (int i = 0; i < codegen->struct_type_count; i++) {
        if (codegen->struct_types[i].name != NULL && 
            strcmp(codegen->struct_types[i].name, struct_name) == 0) {
            return codegen->struct_types[i].llvm_type;
        }
    }
    
    return NULL;  // 未找到
}

// 注册结构体类型（从AST结构体声明创建LLVM结构体类型并注册）
// 参数：codegen - 代码生成器指针
//       struct_decl - AST结构体声明节点
// 返回：成功返回0，失败返回非0
// 注意：如果结构体类型已注册，会返回成功（不重复注册）
int codegen_register_struct_type(CodeGenerator *codegen, ASTNode *struct_decl) {
    if (!codegen || !struct_decl || struct_decl->type != AST_STRUCT_DECL) {
        return -1;
    }
    
    const char *struct_name = struct_decl->data.struct_decl.name;
    if (!struct_name) {
        return -1;
    }
    
    // 检查是否已经注册
    if (codegen_get_struct_type(codegen, struct_name) != NULL) {
        return 0;  // 已注册，返回成功
    }
    
    // 检查映射表是否已满
    if (codegen->struct_type_count >= 64) {
        return -1;  // 映射表已满
    }
    
    int field_count = struct_decl->data.struct_decl.field_count;
    if (field_count < 0) {
        return -1;
    }
    
    // 准备字段类型数组
    LLVMTypeRef *field_types = NULL;
    if (field_count > 0) {
        // 使用固定大小数组（栈分配，无堆分配）
        // 注意：最多支持16个字段（如果超过需要调整）
        if (field_count > 16) {
            return -1;  // 字段数过多
        }
        LLVMTypeRef field_types_array[16];
        field_types = field_types_array;
        
        // 遍历字段，获取每个字段的LLVM类型
        for (int i = 0; i < field_count; i++) {
            ASTNode *field = struct_decl->data.struct_decl.fields[i];
            if (!field || field->type != AST_VAR_DECL) {
                return -1;
            }
            
            ASTNode *field_type_node = field->data.var_decl.type;
            LLVMTypeRef field_llvm_type = get_llvm_type_from_ast(codegen, field_type_node);
            if (!field_llvm_type) {
                return -1;  // 字段类型无效或未找到（结构体类型需要先注册）
            }
            
            field_types[i] = field_llvm_type;
        }
    }
    
    // 创建LLVM结构体类型
    LLVMTypeRef struct_type;
    if (field_count == 0) {
        // 空结构体
        struct_type = LLVMStructTypeInContext(codegen->context, NULL, 0, 0);
    } else {
        // 非空结构体（packed=0，使用默认对齐）
        struct_type = LLVMStructTypeInContext(codegen->context, field_types, field_count, 0);
    }
    
    if (!struct_type) {
        return -1;
    }
    
    // 注册到映射表
    // 复制结构体名称到Arena（如果需要，但通常名称已经在Arena中）
    int idx = codegen->struct_type_count;
    codegen->struct_types[idx].name = struct_name;  // 名称已经在Arena中
    codegen->struct_types[idx].llvm_type = struct_type;
    codegen->struct_type_count++;
    
    return 0;
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

