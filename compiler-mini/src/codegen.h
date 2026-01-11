#ifndef CODEGEN_H
#define CODEGEN_H

#include "ast.h"
#include "arena.h"
#include "checker.h"
#include <llvm-c/Core.h>
#include <llvm-c/Target.h>
#include <llvm-c/TargetMachine.h>

// 代码生成器结构体
// 使用 LLVM C API 生成 LLVM IR 并编译为二进制代码
typedef struct CodeGenerator {
    Arena *arena;                   // Arena 分配器（用于编译器自身内存分配）
    LLVMContextRef context;         // LLVM 上下文
    LLVMModuleRef module;           // LLVM 模块
    LLVMBuilderRef builder;         // IR 构建器（用于生成指令）
    const char *module_name;        // 模块名称（存储在 Arena 中）
    
    // 结构体类型映射表（固定大小数组，存储结构体名称到LLVM类型的映射）
    // 使用固定大小数组和线性查找（简单实现）
    struct StructTypeMap {
        const char *name;           // 结构体名称（存储在 Arena 中）
        LLVMTypeRef llvm_type;      // LLVM 结构体类型
    } struct_types[64];             // 固定大小（最多支持64个结构体类型）
    int struct_type_count;          // 当前结构体类型数量
    
    // 当前函数的变量表（固定大小数组，存储变量名到LLVM值的映射）
    // 用于代码生成时查找局部变量（使用 alloca 分配的栈变量）
    struct VarMap {
        const char *name;           // 变量名称（存储在 Arena 中）
        LLVMValueRef value;         // LLVM 值（alloca 指令返回的指针）
        LLVMTypeRef type;           // 变量类型（用于 LLVMBuildLoad2）
    } var_map[256];                 // 固定大小（最多支持256个局部变量）
    int var_map_count;              // 当前变量数量
    
    // 函数映射表（固定大小数组，存储函数名到LLVM函数值的映射）
    // 用于代码生成时查找函数引用
    struct FuncMap {
        const char *name;           // 函数名称（存储在 Arena 中）
        LLVMValueRef func;          // LLVM 函数值
    } func_map[64];                 // 固定大小（最多支持64个函数）
    int func_map_count;             // 当前函数数量
} CodeGenerator;

// 创建代码生成器
// 参数：codegen - CodeGenerator 结构体指针（由调用者分配）
//       arena - Arena 分配器指针
//       module_name - 模块名称（字符串存储在 Arena 中）
// 返回：成功返回0，失败返回非0
int codegen_new(CodeGenerator *codegen, Arena *arena, const char *module_name);

// 从AST生成代码
// 参数：codegen - 代码生成器指针
//       ast - AST 根节点（程序节点）
//       output_file - 输出文件路径
// 返回：成功返回0，失败返回非0
int codegen_generate(CodeGenerator *codegen, ASTNode *ast, const char *output_file);

// 获取基础类型的LLVM类型
// 参数：codegen - 代码生成器指针
//       type_kind - 类型种类（TypeKind枚举：TYPE_I32, TYPE_BOOL, TYPE_VOID）
// 返回：LLVM类型引用，失败返回NULL
// 注意：此函数仅支持基础类型，结构体类型需要使用其他函数
LLVMTypeRef codegen_get_base_type(CodeGenerator *codegen, TypeKind type_kind);

// 注册结构体类型（从AST结构体声明创建LLVM结构体类型并注册）
// 参数：codegen - 代码生成器指针
//       struct_decl - AST结构体声明节点
// 返回：成功返回0，失败返回非0
// 注意：如果结构体类型已注册，会返回成功（不重复注册）
int codegen_register_struct_type(CodeGenerator *codegen, ASTNode *struct_decl);

// 获取结构体类型的LLVM类型
// 参数：codegen - 代码生成器指针
//       struct_name - 结构体名称
// 返回：LLVM类型引用，未找到返回NULL
LLVMTypeRef codegen_get_struct_type(CodeGenerator *codegen, const char *struct_name);

// 生成表达式代码（从表达式AST节点生成LLVM值）
// 参数：codegen - 代码生成器指针
//       expr - 表达式AST节点
// 返回：LLVM值引用（LLVMValueRef），失败返回NULL
// 注意：此函数需要在函数上下文中调用（builder需要在函数的基本块中）
//       标识符和函数调用使用变量表和函数表查找
LLVMValueRef codegen_gen_expr(CodeGenerator *codegen, ASTNode *expr);

// 生成语句代码（从语句AST节点生成LLVM IR指令）
// 参数：codegen - 代码生成器指针
//       stmt - 语句AST节点
// 返回：成功返回0，失败返回非0
// 注意：此函数需要在函数上下文中调用（builder需要在函数的基本块中）
int codegen_gen_stmt(CodeGenerator *codegen, ASTNode *stmt);

// 生成函数代码（从函数声明AST节点生成LLVM函数）
// 参数：codegen - 代码生成器指针
//       fn_decl - 函数声明AST节点
// 返回：成功返回0，失败返回非0
int codegen_gen_function(CodeGenerator *codegen, ASTNode *fn_decl);

#endif // CODEGEN_H

