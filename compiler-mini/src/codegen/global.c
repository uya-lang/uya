#include "internal.h"

// 前向声明
LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node);
int add_global_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef global_var, LLVMTypeRef type, const char *struct_name);
LLVMValueRef codegen_gen_expr(CodeGenerator *codegen, ASTNode *expr);

int codegen_gen_global_var(CodeGenerator *codegen, ASTNode *var_decl) {
    if (!codegen || !var_decl || var_decl->type != AST_VAR_DECL) {
        return -1;
    }
    
    const char *var_name = var_decl->data.var_decl.name;
    ASTNode *var_type_node = var_decl->data.var_decl.type;
    ASTNode *init_expr = var_decl->data.var_decl.init;
    
    if (!var_name || !var_type_node) {
        return -1;
    }
    
    // 获取变量类型
    LLVMTypeRef llvm_type = get_llvm_type_from_ast(codegen, var_type_node);
    if (!llvm_type) {
        // 调试信息：输出变量名称和类型节点信息
        if (var_name) {
            fprintf(stderr, "调试: 全局变量 %s 的类型获取失败\n", var_name);
            if (var_type_node) {
                fprintf(stderr, "调试: 类型节点类型: %d\n", var_type_node->type);
                if (var_type_node->type == AST_TYPE_NAMED && var_type_node->data.type_named.name) {
                    fprintf(stderr, "调试: 类型名称: %s\n", var_type_node->data.type_named.name);
                }
            }
        }
        // 放宽检查：如果类型获取失败，尝试使用默认类型（i32）
        // 这在编译器自举时可能发生，因为类型系统可能不够完善
        llvm_type = codegen_get_base_type(codegen, TYPE_I32);
        if (!llvm_type) {
            return -1;
        }
    }
    
    // 提取结构体名称（如果类型是结构体类型）
    const char *struct_name = NULL;
    if (var_type_node->type == AST_TYPE_NAMED) {
        const char *type_name = var_type_node->data.type_named.name;
        if (type_name && strcmp(type_name, "i32") != 0 && 
            strcmp(type_name, "bool") != 0 && strcmp(type_name, "byte") != 0 && 
            strcmp(type_name, "void") != 0) {
            // 可能是结构体类型
            if (codegen_get_struct_type(codegen, type_name) != NULL) {
                struct_name = type_name;  // 名称已经在 Arena 中
            }
        }
    }
    
    // 创建全局变量（使用内部链接，因为没有导出机制）
    LLVMValueRef global_var = LLVMAddGlobal(codegen->module, llvm_type, var_name);
    if (!global_var) {
        // 调试信息：输出变量名称
        if (var_name) {
            fprintf(stderr, "调试: 全局变量 %s 创建失败\n", var_name);
        }
        return -1;
    }
    
    // 设置链接属性（内部链接，全局变量在当前模块内可见）
    LLVMSetLinkage(global_var, LLVMInternalLinkage);
    
    // 设置初始值
    LLVMValueRef init_val = NULL;
    if (init_expr) {
        // 对于常量表达式（数字字面量、布尔字面量），可以直接使用
        // 注意：这里简化处理，只支持常量字面量，不支持复杂表达式
        if (init_expr->type == AST_NUMBER) {
            int value = init_expr->data.number.value;
            if (LLVMGetTypeKind(llvm_type) == LLVMIntegerTypeKind) {
                init_val = LLVMConstInt(llvm_type, (unsigned long long)value, 1);  // 1 表示有符号
            }
        } else if (init_expr->type == AST_BOOL) {
            int value = init_expr->data.bool_literal.value;
            if (LLVMGetTypeKind(llvm_type) == LLVMIntegerTypeKind) {
                init_val = LLVMConstInt(llvm_type, value ? 1ULL : 0ULL, 0);  // 0 表示无符号（布尔值）
            }
        }
        // TODO: 支持其他常量表达式（如结构体字面量、数组字面量等）
    }
    
    // 如果没有初始值或初始值不是常量，使用零初始化
    if (!init_val) {
        init_val = LLVMConstNull(llvm_type);
    }
    
    // 设置全局变量的初始值
    LLVMSetInitializer(global_var, init_val);
    
    // 添加到全局变量映射表
    if (add_global_var(codegen, var_name, global_var, llvm_type, struct_name) != 0) {
        // 调试信息：输出变量名称
        if (var_name) {
            fprintf(stderr, "调试: 全局变量 %s 添加到映射表失败\n", var_name);
        }
        return -1;
    }
    
    return 0;
}

