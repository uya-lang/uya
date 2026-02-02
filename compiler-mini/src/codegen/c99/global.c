#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

void gen_global_init_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return;
    
    switch (expr->type) {
        case AST_STRUCT_INIT: {
            // 对于全局作用域，生成标准初始化器列表，不使用复合字面量
            int field_count = expr->data.struct_init.field_count;
            const char **field_names = expr->data.struct_init.field_names;
            ASTNode **field_values = expr->data.struct_init.field_values;
            fputc('{', codegen->output);
            for (int i = 0; i < field_count; i++) {
                const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                fprintf(codegen->output, ".%s = ", safe_field_name);
                gen_global_init_expr(codegen, field_values[i]);
                if (i < field_count - 1) fputs(", ", codegen->output);
            }
            fputc('}', codegen->output);
            break;
        }
        case AST_ARRAY_LITERAL: {
            ASTNode **elements = expr->data.array_literal.elements;
            int element_count = expr->data.array_literal.element_count;
            ASTNode *repeat_count_expr = expr->data.array_literal.repeat_count_expr;
            fputc('{', codegen->output);
            if (repeat_count_expr != NULL && element_count >= 1) {
                int n = eval_const_expr(codegen, repeat_count_expr);
                if (n <= 0) n = 1;
                for (int i = 0; i < n; i++) {
                    gen_global_init_expr(codegen, elements[0]);
                    if (i < n - 1) fputs(", ", codegen->output);
                }
            } else {
                for (int i = 0; i < element_count; i++) {
                    gen_global_init_expr(codegen, elements[i]);
                    if (i < element_count - 1) fputs(", ", codegen->output);
                }
            }
            fputc('}', codegen->output);
            break;
        }
        default:
            // 对于其他表达式类型（数字、布尔值、字符串等），使用标准生成方式
            gen_expr(codegen, expr);
            break;
    }
}

// 生成全局变量定义
void gen_global_var(C99CodeGenerator *codegen, ASTNode *var_decl) {
    if (!var_decl || var_decl->type != AST_VAR_DECL) return;
    
    const char *var_name = get_safe_c_identifier(codegen, var_decl->data.var_decl.name);
    ASTNode *var_type = var_decl->data.var_decl.type;
    ASTNode *init_expr = var_decl->data.var_decl.init;
    int is_const = var_decl->data.var_decl.is_const;
    
    if (!var_name || !var_type) return;
    
    const char *type_c = NULL;
    
    // 检查是否为数组类型
    if (var_type->type == AST_TYPE_ARRAY) {
        // 对于数组类型（包括多维数组），使用 c99_type_to_c 处理整个类型
        // 它会正确处理多维数组，例如 [[byte: PATH_MAX]: MAX_INPUT_FILES] -> uint8_t[64][4096]
        const char *full_type_c = c99_type_to_c(codegen, var_type);
        
        // 解析类型字符串，分离基类型和数组维度
        // 例如："uint8_t[64][4096]" -> 基类型="uint8_t", 维度="[64][4096]"
        const char *first_bracket = strchr(full_type_c, '[');
        if (first_bracket) {
            // 找到第一个 '['，分割基类型和维度
            size_t base_len = first_bracket - full_type_c;
            char *base_type = arena_alloc(codegen->arena, base_len + 1);
            if (base_type) {
                memcpy(base_type, full_type_c, base_len);
                base_type[base_len] = '\0';
                
                // 维度部分是从 '[' 开始到结尾
                const char *dimensions = full_type_c + base_len;
                
                // 生成数组声明：const base_type var_name dimensions
                if (is_const) {
                    fprintf(codegen->output, "const %s %s%s", base_type, var_name, dimensions);
                } else {
                    fprintf(codegen->output, "%s %s%s", base_type, var_name, dimensions);
                }
                type_c = base_type;  // 保存基类型用于后续使用
            } else {
                // 分配失败，回退到简单处理
                type_c = full_type_c;
                if (is_const) {
                    fprintf(codegen->output, "const %s %s", type_c, var_name);
                } else {
                    fprintf(codegen->output, "%s %s", type_c, var_name);
                }
            }
        } else {
            // 没有找到 '['，可能是错误情况，回退到简单处理
            type_c = full_type_c;
            if (is_const) {
                fprintf(codegen->output, "const %s %s", type_c, var_name);
            } else {
                fprintf(codegen->output, "%s %s", type_c, var_name);
            }
        }
    } else {
        type_c = c99_type_to_c(codegen, var_type);
        if (is_const) {
            fprintf(codegen->output, "const %s %s", type_c, var_name);
        } else {
            fprintf(codegen->output, "%s %s", type_c, var_name);
        }
    }
    
    // 初始化表达式（使用全局作用域兼容的生成方式）
    if (init_expr) {
        fputs(" = ", codegen->output);
        gen_global_init_expr(codegen, init_expr);
    }
    
    fputs(";\n", codegen->output);
    
    // 添加到全局变量表（可选，用于后续引用）
    if (codegen->global_variable_count < C99_MAX_GLOBAL_VARS) {
        codegen->global_variables[codegen->global_variable_count].name = var_name;
        codegen->global_variables[codegen->global_variable_count].type_c = type_c;
        codegen->global_variables[codegen->global_variable_count].is_const = is_const;
        codegen->global_variable_count++;
    }
}
