#ifndef CODEGEN_INTERNAL_H
#define CODEGEN_INTERNAL_H

#include "codegen.h"
#include "lexer.h"
#include <string.h>
#include <stdlib.h>
#include <llvm-c/TargetMachine.h>
#include <llvm-c/Target.h>
#include <llvm-c/Analysis.h>
#include <llvm-c/Core.h>
#include <stdio.h>

// 注意：这个头文件包含所有内部函数的声明
// 由于原始代码中这些函数都是 static 的，拆分后需要移除 static 关键字
// 以便在不同模块间共享。这里只声明需要跨模块调用的函数。

// 工具函数（在 utils.c 中定义，需要被其他模块调用）
LLVMTypeRef safe_LLVMTypeOf(LLVMValueRef val);
LLVMTypeRef safe_LLVMGetElementType(LLVMTypeRef type);
void format_error_location(const CodeGenerator *codegen, const ASTNode *node, char *buffer, size_t buffer_size);
const char *get_stmt_type_name(ASTNodeType type);
void report_stmt_error(const CodeGenerator *codegen, const ASTNode *stmt, int stmt_index, const char *context);

// 类型系统（在 types.c 中定义）
LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node);

// 变量管理（在 vars.c 中定义）
LLVMValueRef lookup_var(CodeGenerator *codegen, const char *var_name);
LLVMTypeRef lookup_var_type(CodeGenerator *codegen, const char *var_name);
ASTNode *lookup_var_ast_type(CodeGenerator *codegen, const char *var_name);
const char *lookup_var_struct_name(CodeGenerator *codegen, const char *var_name);
int add_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef value, LLVMTypeRef type, const char *struct_name, ASTNode *ast_type);
int add_global_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef global_var, LLVMTypeRef type, const char *struct_name);
LLVMValueRef build_entry_alloca(CodeGenerator *codegen, LLVMTypeRef type, const char *name);
LLVMValueRef codegen_gen_lvalue_address(CodeGenerator *codegen, ASTNode *expr);

// 函数管理（在 funcs.c 中定义）
LLVMValueRef lookup_func(CodeGenerator *codegen, const char *func_name, LLVMTypeRef *func_type_out);
int add_func(CodeGenerator *codegen, const char *func_name, LLVMValueRef func, LLVMTypeRef func_type);
ASTNode *find_fn_decl(CodeGenerator *codegen, const char *func_name);
ASTNode *find_fn_decl_in_node(ASTNode *node, const char *func_name);
int codegen_declare_function(CodeGenerator *codegen, ASTNode *fn_decl);
void declare_functions_in_node(CodeGenerator *codegen, ASTNode *node);

// 结构体相关（在 structs.c 中定义）
void register_structs_in_node(CodeGenerator *codegen, ASTNode *node);
ASTNode *find_struct_decl(CodeGenerator *codegen, const char *struct_name);
int find_struct_field_index(ASTNode *struct_decl, const char *field_name);
const char *find_struct_name_from_type(CodeGenerator *codegen, LLVMTypeRef struct_type);
ASTNode *find_struct_field_ast_type(CodeGenerator *codegen, ASTNode *struct_decl, const char *field_name);

// 枚举相关（在 enums.c 中定义）
ASTNode *find_enum_decl(CodeGenerator *codegen, const char *enum_name);
int find_enum_variant_index(ASTNode *enum_decl, const char *variant_name);
int get_enum_variant_value(ASTNode *enum_decl, int variant_index);
int find_enum_constant_value(CodeGenerator *codegen, const char *constant_name);

// 表达式生成（在 expr.c 中定义）
LLVMValueRef codegen_gen_struct_comparison(
    CodeGenerator *codegen,
    LLVMValueRef left_val,
    LLVMValueRef right_val,
    ASTNode *struct_decl,
    int is_equal
);

// 语句生成（在 stmt.c 中定义）
int gen_branch_with_terminator(CodeGenerator *codegen, 
                               LLVMBasicBlockRef branch_bb,
                               ASTNode *branch_stmt,
                               LLVMBasicBlockRef target_bb);

// 全局变量生成（在 global.c 中定义）
int codegen_gen_global_var(CodeGenerator *codegen, ASTNode *var_decl);

#endif // CODEGEN_INTERNAL_H

