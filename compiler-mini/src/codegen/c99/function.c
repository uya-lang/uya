#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

// 查找函数声明
ASTNode *find_function_decl_c99(C99CodeGenerator *codegen, const char *func_name) {
    if (!codegen || !func_name || !codegen->program_node) {
        return NULL;
    }
    
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_FN_DECL) {
            continue;
        }
        
        const char *decl_name = decl->data.fn_decl.name;
        if (decl_name && strcmp(decl_name, func_name) == 0) {
            return decl;
        }
    }
    
    return NULL;
}

void format_param_type(C99CodeGenerator *codegen __attribute__((unused)), const char *type_c, const char *param_name, FILE *output) {
    if (!type_c || !param_name) return;
    
    // 检查是否是数组类型（包含 [数字]）
    const char *bracket = strchr(type_c, '[');
    if (bracket) {
        // 提取元素类型（bracket之前的部分）
        size_t len = bracket - type_c;
        fprintf(output, "%.*s %s%s", (int)len, type_c, param_name, bracket);
    } else {
        // 非数组类型
        // 检查是否是指针类型（包含 '*'）
        // 如果是指针类型，格式应该是 "type * name"（* 紧跟在类型后面）
        // c99_type_to_c 已经返回了正确的格式（如 "struct Type *"），所以直接输出即可
        fprintf(output, "%s %s", type_c, param_name);
    }
}

// 检查是否是标准库函数（需要特殊处理参数类型）
int is_stdlib_function(const char *func_name) {
    if (!func_name) return 0;
    // 标准库函数列表：这些函数的字符串参数应该是 const char * 而不是 uint8_t *
    // I/O 函数
    if (strcmp(func_name, "printf") == 0 ||
        strcmp(func_name, "sprintf") == 0 ||
        strcmp(func_name, "fprintf") == 0 ||
        strcmp(func_name, "snprintf") == 0 ||
        strcmp(func_name, "scanf") == 0 ||
        strcmp(func_name, "fscanf") == 0 ||
        strcmp(func_name, "sscanf") == 0 ||
        strcmp(func_name, "puts") == 0 ||
        strcmp(func_name, "fputs") == 0 ||
        strcmp(func_name, "putchar") == 0 ||
        strcmp(func_name, "getchar") == 0 ||
        strcmp(func_name, "gets") == 0 ||
        strcmp(func_name, "fgets") == 0) {
        return 1;
    }
    // 字符串处理函数
    if (strcmp(func_name, "strcmp") == 0 ||
        strcmp(func_name, "strncmp") == 0 ||
        strcmp(func_name, "strlen") == 0 ||
        strcmp(func_name, "strcpy") == 0 ||
        strcmp(func_name, "strncpy") == 0 ||
        strcmp(func_name, "strcat") == 0 ||
        strcmp(func_name, "strncat") == 0 ||
        strcmp(func_name, "strstr") == 0 ||
        strcmp(func_name, "strchr") == 0 ||
        strcmp(func_name, "strrchr") == 0 ||
        strcmp(func_name, "strdup") == 0 ||
        strcmp(func_name, "strndup") == 0) {
        return 1;
    }
    return 0;
}

// 生成函数原型（前向声明）
void gen_function_prototype(C99CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL) return;
    
    const char *func_name = get_safe_c_identifier(codegen, fn_decl->data.fn_decl.name);
    ASTNode *return_type = fn_decl->data.fn_decl.return_type;
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    int is_varargs = fn_decl->data.fn_decl.is_varargs;
    ASTNode *body = fn_decl->data.fn_decl.body;
    
    // 检查是否为extern函数（body为NULL表示extern函数）
    int is_extern = (body == NULL) ? 1 : 0;
    
    // 检查是否是标准库函数
    int is_stdlib = is_stdlib_function(func_name);
    
    // 返回类型（如果是数组类型，转换为指针类型）
    const char *return_c = convert_array_return_type(codegen, return_type);
    
    // 对于标准库函数，不生成 extern 声明（应该包含相应的头文件）
    if (is_extern && is_stdlib) {
        // 标准库函数应该包含相应的头文件（如 <stdio.h>），不生成 extern 声明
        // 这样可以避免与标准库的声明冲突
        return;
    }
    
    // 对于extern函数，添加extern关键字
    if (is_extern) {
        fprintf(codegen->output, "extern %s %s(", return_c, func_name);
    } else {
        fprintf(codegen->output, "%s %s(", return_c, func_name);
    }
    
    // 参数列表
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        // 对于 extern 函数，检查大结构体参数（>16字节），转换为指针类型
        // 根据 x86-64 System V ABI，大于 16 字节的结构体通过指针传递
        if (is_extern && param_type->type == AST_TYPE_NAMED) {
            int struct_size = calculate_struct_size(codegen, param_type);
            if (struct_size > 16) {
                // 大结构体：转换为指针类型
                param_type_c = c99_type_to_c(codegen, param_type);
                fprintf(codegen->output, "%s *%s", param_type_c, param_name);
                if (i < param_count - 1) fputs(", ", codegen->output);
                continue;
            }
        }
        
        // 对于标准库函数，将 uint8_t * 转换为 const char *
        if (is_stdlib && param_type->type == AST_TYPE_POINTER) {
            ASTNode *pointed_type = param_type->data.type_pointer.pointed_type;
            if (pointed_type && pointed_type->type == AST_TYPE_NAMED) {
                const char *pointed_name = pointed_type->data.type_named.name;
                if (pointed_name && strcmp(pointed_name, "byte") == 0) {
                    // 将 uint8_t * 替换为 const char *
                    param_type_c = "const char *";
                }
            }
        }
        
        // 数组参数：在参数名后添加 _param 后缀，函数内部会创建副本
        if (param_type->type == AST_TYPE_ARRAY) {
            // 数组参数格式：T name_param[N]
            const char *bracket = strchr(param_type_c, '[');
            if (bracket) {
                size_t len = bracket - param_type_c;
                fprintf(codegen->output, "%.*s %s_param%s", (int)len, param_type_c, param_name, bracket);
            } else {
                fprintf(codegen->output, "%s %s_param", param_type_c, param_name);
            }
        } else {
            format_param_type(codegen, param_type_c, param_name, codegen->output);
        }
        if (i < param_count - 1) fputs(", ", codegen->output);
    }
    
    // 处理可变参数
    if (is_varargs) {
        if (param_count > 0) fputs(", ", codegen->output);
        fputs("...", codegen->output);
    }
    
    fputs(");\n", codegen->output);
}

// 生成函数定义
void gen_function(C99CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL) return;
    
    const char *func_name = get_safe_c_identifier(codegen, fn_decl->data.fn_decl.name);
    ASTNode *return_type = fn_decl->data.fn_decl.return_type;
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    int is_varargs = fn_decl->data.fn_decl.is_varargs;
    ASTNode *body = fn_decl->data.fn_decl.body;
    
    // 如果没有函数体（外部函数），则不生成定义
    if (!body) return;
    
    // 返回类型（如果是数组类型，转换为指针类型）
    const char *return_c = convert_array_return_type(codegen, return_type);
    fprintf(codegen->output, "%s %s(", return_c, func_name);
    
    // 参数列表
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        // 数组参数：在参数名后添加 _param 后缀，函数内部会创建副本
        if (param_type->type == AST_TYPE_ARRAY) {
            // 数组参数格式：T name_param[N]
            const char *bracket = strchr(param_type_c, '[');
            if (bracket) {
                size_t len = bracket - param_type_c;
                fprintf(codegen->output, "%.*s %s_param%s", (int)len, param_type_c, param_name, bracket);
            } else {
                fprintf(codegen->output, "%s %s_param", param_type_c, param_name);
            }
        } else {
            format_param_type(codegen, param_type_c, param_name, codegen->output);
        }
        if (i < param_count - 1) fputs(", ", codegen->output);
    }
    
    // 处理可变参数
    if (is_varargs) {
        if (param_count > 0) fputs(", ", codegen->output);
        fputs("...", codegen->output);
    }
    
    fputs(") {\n", codegen->output);
    codegen->indent_level++;
    
    // 保存当前函数的返回类型（用于生成返回语句）
    codegen->current_function_return_type = return_type;
    
    // 保存函数开始时的局部变量表状态（用于函数结束时恢复）
    // 每个函数有自己独立的局部变量表，函数结束后恢复之前的状态
    int saved_local_variable_count = codegen->local_variable_count;
    int saved_current_depth = codegen->current_depth;
    
    // 重置当前函数的局部变量表（从 0 开始）
    // 这样每个函数都有自己独立的局部变量表，避免大文件时表被填满
    // 参数和局部变量都从索引 0 开始添加
    codegen->local_variable_count = 0;
    codegen->current_depth = 0;
    
    // 处理数组参数：为数组参数创建局部副本（实现按值传递）
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        
        if (param_type->type == AST_TYPE_ARRAY) {
            // 数组参数：创建局部数组副本
            const char *array_type_c = c99_type_to_c(codegen, param_type);
            // 解析数组类型格式：int32_t[3] -> int32_t arr[3]
            const char *bracket = strchr(array_type_c, '[');
            c99_emit(codegen, "// 数组参数按值传递：创建局部副本\n");
            if (bracket) {
                size_t len = bracket - array_type_c;
                fprintf(codegen->output, "    %.*s %s%s;\n", (int)len, array_type_c, param_name, bracket);
            } else {
                c99_emit(codegen, "%s %s;\n", array_type_c, param_name);
            }
            c99_emit(codegen, "    memcpy(%s, %s_param, sizeof(%s));\n", param_name, param_name, param_name);
            
            // 将参数名注册为局部数组（而不是参数）
            if (param_name && codegen->local_variable_count < 128) {
                codegen->local_variables[codegen->local_variable_count].name = param->data.var_decl.name;  // 使用原始名称
                codegen->local_variables[codegen->local_variable_count].type_c = array_type_c;
                codegen->local_variable_count++;
            }
        } else {
            // 非数组参数：正常添加到局部变量表
            const char *param_type_c = c99_type_to_c(codegen, param_type);
            if (param_name && param_type_c && codegen->local_variable_count < 128) {
                codegen->local_variables[codegen->local_variable_count].name = param->data.var_decl.name;
                codegen->local_variables[codegen->local_variable_count].type_c = param_type_c;
                codegen->local_variable_count++;
            }
        }
    }
    
    // 生成函数体
    gen_stmt(codegen, body);
    
    // 清除当前函数的返回类型
    codegen->current_function_return_type = NULL;
    
    // 恢复函数开始时的局部变量表状态
    // 这样下一个函数可以从干净的状态开始
    codegen->local_variable_count = saved_local_variable_count;
    codegen->current_depth = saved_current_depth;
    
    codegen->indent_level--;
    c99_emit(codegen, "}\n");
}
