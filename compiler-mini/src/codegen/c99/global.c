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
            fputc('{', codegen->output);
            for (int i = 0; i < element_count; i++) {
                gen_global_init_expr(codegen, elements[i]);
                if (i < element_count - 1) fputs(", ", codegen->output);
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
    int array_size = -1;
    
    // 检查是否为数组类型
    if (var_type->type == AST_TYPE_ARRAY) {
        ASTNode *element_type = var_type->data.type_array.element_type;
        ASTNode *size_expr = var_type->data.type_array.size_expr;
        type_c = c99_type_to_c(codegen, element_type);
        
        // 评估数组大小
        if (size_expr) {
            array_size = eval_const_expr(codegen, size_expr);
            if (array_size <= 0) {
                array_size = 1;  // 占位符
            }
        } else {
            array_size = 1;  // 占位符
        }
        
        // 生成数组声明：const elem_type var_name[size]
        if (is_const) {
            fprintf(codegen->output, "const %s %s[%d]", type_c, var_name, array_size);
        } else {
            fprintf(codegen->output, "%s %s[%d]", type_c, var_name, array_size);
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
    if (codegen->global_variable_count < 128) {
        codegen->global_variables[codegen->global_variable_count].name = var_name;
        codegen->global_variables[codegen->global_variable_count].type_c = type_c;
        codegen->global_variables[codegen->global_variable_count].is_const = is_const;
        codegen->global_variable_count++;
    }
}
