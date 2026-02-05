#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

// 查找结构体对应的方法块
ASTNode *find_method_block_for_struct_c99(C99CodeGenerator *codegen, const char *struct_name) {
    if (!codegen || !struct_name || !codegen->program_node) return NULL;
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_METHOD_BLOCK) continue;
        if (decl->data.method_block.struct_name &&
            strcmp(decl->data.method_block.struct_name, struct_name) == 0) {
            return decl;
        }
    }
    return NULL;
}

// 查找联合体对应的方法块
ASTNode *find_method_block_for_union_c99(C99CodeGenerator *codegen, const char *union_name) {
    if (!codegen || !union_name || !codegen->program_node) return NULL;
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_METHOD_BLOCK) continue;
        if (decl->data.method_block.union_name &&
            strcmp(decl->data.method_block.union_name, union_name) == 0) {
            return decl;
        }
    }
    return NULL;
}

// 在方法块中按名称查找方法
ASTNode *find_method_in_block(ASTNode *method_block, const char *method_name) {
    if (!method_block || method_block->type != AST_METHOD_BLOCK || !method_name) return NULL;
    for (int i = 0; i < method_block->data.method_block.method_count; i++) {
        ASTNode *m = method_block->data.method_block.methods[i];
        if (m && m->type == AST_FN_DECL && m->data.fn_decl.name &&
            strcmp(m->data.fn_decl.name, method_name) == 0) {
            return m;
        }
    }
    return NULL;
}

// 查找结构体方法（同时检查外部方法块和内部定义的方法）
ASTNode *find_method_in_struct_c99(C99CodeGenerator *codegen, const char *struct_name, const char *method_name) {
    if (!codegen || !struct_name || !method_name) return NULL;
    // 1. 先检查外部方法块
    ASTNode *method_block = find_method_block_for_struct_c99(codegen, struct_name);
    if (method_block) {
        ASTNode *m = find_method_in_block(method_block, method_name);
        if (m) return m;
    }
    // 2. 再检查结构体内部定义的方法
    ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
    if (struct_decl && struct_decl->data.struct_decl.methods) {
        for (int i = 0; i < struct_decl->data.struct_decl.method_count; i++) {
            ASTNode *m = struct_decl->data.struct_decl.methods[i];
            if (m && m->type == AST_FN_DECL && m->data.fn_decl.name &&
                strcmp(m->data.fn_decl.name, method_name) == 0) {
                return m;
            }
        }
    }
    return NULL;
}

// 查找联合体方法（同时检查外部方法块和内部定义的方法）
ASTNode *find_method_in_union_c99(C99CodeGenerator *codegen, const char *union_name, const char *method_name) {
    if (!codegen || !union_name || !method_name) return NULL;
    ASTNode *method_block = find_method_block_for_union_c99(codegen, union_name);
    if (method_block) {
        ASTNode *m = find_method_in_block(method_block, method_name);
        if (m) return m;
    }
    ASTNode *union_decl = find_union_decl_c99(codegen, union_name);
    if (union_decl && union_decl->data.union_decl.methods) {
        for (int i = 0; i < union_decl->data.union_decl.method_count; i++) {
            ASTNode *m = union_decl->data.union_decl.methods[i];
            if (m && m->type == AST_FN_DECL && m->data.fn_decl.name &&
                strcmp(m->data.fn_decl.name, method_name) == 0) {
                return m;
            }
        }
    }
    return NULL;
}

int type_has_drop_c99(C99CodeGenerator *codegen, const char *struct_name) {
    return find_method_in_struct_c99(codegen, struct_name, "drop") != NULL;
}

// 获取方法的 C 函数名（uya_StructName_methodname）
const char *get_method_c_name(C99CodeGenerator *codegen, const char *struct_name, const char *method_name) {
    if (!struct_name || !method_name) return NULL;
    const char *safe_s = get_safe_c_identifier(codegen, struct_name);
    const char *safe_m = get_safe_c_identifier(codegen, method_name);
    if (!safe_s || !safe_m) return NULL;
    size_t len = 5 + strlen(safe_s) + 1 + strlen(safe_m) + 1;  // "uya_" + S + "_" + M + NUL
    char *buf = arena_alloc(codegen->arena, len);
    if (!buf) return NULL;
    snprintf(buf, len, "uya_%s_%s", safe_s, safe_m);
    return buf;
}

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
    
    // 检查是否是指向数组的指针类型（格式：T (*)[N]）
    // 这种类型在 c99_type_to_c 中会生成 "T (*)[N]" 格式
    const char *ptr_bracket = strstr(type_c, "(*)");
    if (ptr_bracket) {
        // 是指向数组的指针，格式应该是 "T (*param_name)[N]"
        // 找到 [N] 部分
        const char *array_bracket = strchr(ptr_bracket, '[');
        if (array_bracket) {
            // 提取 T (*) 之前的部分
            size_t base_len = ptr_bracket - type_c;
            // 提取 [N] 部分
            const char *dims = array_bracket;
            fprintf(output, "%.*s (*%s)%s", (int)base_len, type_c, param_name, dims);
            return;
        }
    }
    
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
    // 内存操作函数
    if (strcmp(func_name, "memcpy") == 0 ||
        strcmp(func_name, "memset") == 0 ||
        strcmp(func_name, "memcmp") == 0 ||
        strcmp(func_name, "memmove") == 0) {
        return 1;
    }
    // 文件 I/O 函数
    if (strcmp(func_name, "fopen") == 0 ||
        strcmp(func_name, "fread") == 0 ||
        strcmp(func_name, "fwrite") == 0 ||
        strcmp(func_name, "fclose") == 0 ||
        strcmp(func_name, "fgetc") == 0 ||
        strcmp(func_name, "fputc") == 0 ||
        strcmp(func_name, "fgets") == 0 ||
        strcmp(func_name, "fputs") == 0 ||
        strcmp(func_name, "fflush") == 0) {
        return 1;
    }
    return 0;
}

// 生成函数原型（前向声明）
void gen_function_prototype(C99CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL) return;
    
    // 跳过泛型函数的前向声明（泛型函数不能直接调用，只能通过实例化调用）
    if (fn_decl->data.fn_decl.type_param_count > 0) return;
    
    const char *func_name = get_safe_c_identifier(codegen, fn_decl->data.fn_decl.name);
    ASTNode *return_type = fn_decl->data.fn_decl.return_type;
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    int is_varargs = fn_decl->data.fn_decl.is_varargs;
    ASTNode *body = fn_decl->data.fn_decl.body;
    
    // 检查是否为 copy_type 函数（需要 const 限定符）
    const char *orig_name = fn_decl->data.fn_decl.name;
    int is_copy_type = (orig_name && strcmp(orig_name, "copy_type") == 0) ? 1 : 0;
    
    // 特殊处理：main 函数需要重命名为 uya_main（符合 Uya 规范：main 函数无参数）
    int is_main = (orig_name && strcmp(orig_name, "main") == 0) ? 1 : 0;
    if (is_main) {
        // main 函数生成 uya_main 的前向声明
        const char *return_c = convert_array_return_type(codegen, return_type);
        fprintf(codegen->output, "%s uya_main(void);\n", return_c);
        return;
    }
    
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
        
        // 特殊处理 copy_type 函数：将第一个参数类型改为 const struct Type *
        if (is_copy_type && i == 0) {
            param_type_c = "const struct Type *";
        }
        
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
        } else if (param_type->type == AST_TYPE_SLICE) {
            // Slice 类型参数：通过指针传递（slice 是引用类型）
            fprintf(codegen->output, "%s *%s", param_type_c, param_name);
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
    
    // 跳过泛型函数的定义（泛型函数不能直接调用，只能通过实例化调用）
    if (fn_decl->data.fn_decl.type_param_count > 0) return;
    
    const char *func_name = get_safe_c_identifier(codegen, fn_decl->data.fn_decl.name);
    ASTNode *return_type = fn_decl->data.fn_decl.return_type;
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    int is_varargs = fn_decl->data.fn_decl.is_varargs;
    ASTNode *body = fn_decl->data.fn_decl.body;
    
    // 如果没有函数体（外部函数），则不生成定义
    if (!body) return;
    
    // 检查是否为 copy_type 函数（需要 const 限定符）
    const char *orig_name = fn_decl->data.fn_decl.name;
    int is_copy_type = (orig_name && strcmp(orig_name, "copy_type") == 0) ? 1 : 0;
    
    // 生成 #line 指令，指向函数定义的位置
    emit_line_directive(codegen, fn_decl->line, fn_decl->filename);
    
    // 特殊处理：main 函数需要重命名为 uya_main（符合 Uya 规范：main 函数无参数）
    int is_main = (orig_name && strcmp(orig_name, "main") == 0) ? 1 : 0;
    
    // 返回类型（如果是数组类型，转换为指针类型）
    const char *return_c = convert_array_return_type(codegen, return_type);
    
    if (is_main) {
        // main 函数重命名为 uya_main（符合 Uya 规范：main 函数无参数）
        fprintf(codegen->output, "%s uya_main(void)", return_c);
    } else {
        fprintf(codegen->output, "%s %s(", return_c, func_name);
        
        // 参数列表
        for (int i = 0; i < param_count; i++) {
            ASTNode *param = params[i];
            if (!param || param->type != AST_VAR_DECL) continue;
            
            const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
            ASTNode *param_type = param->data.var_decl.type;
            const char *param_type_c = c99_type_to_c(codegen, param_type);
            
            // 特殊处理 copy_type 函数：将第一个参数类型改为 const struct Type *
            if (is_copy_type && i == 0) {
                param_type_c = "const struct Type *";
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
            } else if (param_type->type == AST_TYPE_SLICE) {
                // Slice 类型参数：通过指针传递（slice 是引用类型）
                fprintf(codegen->output, "%s *%s", param_type_c, param_name);
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
    }
    
    // 添加函数体开始
    if (is_main) {
        fputs(" {\n", codegen->output);
    } else {
        fputs(") {\n", codegen->output);
    }
    codegen->indent_level++;
    
    // 保存当前函数的返回类型（用于生成返回语句）
    codegen->current_function_return_type = return_type;
    
    // 保存当前函数声明（用于 @params 与 ... 转发）；不在入口生成 va_start/元组，仅按需在表达式/语句处生成
    ASTNode *saved_current_function_decl = codegen->current_function_decl;
    codegen->current_function_decl = fn_decl;
    
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
            if (param_name && codegen->local_variable_count < C99_MAX_LOCAL_VARS) {
                codegen->local_variables[codegen->local_variable_count].name = param->data.var_decl.name;  // 使用原始名称
                codegen->local_variables[codegen->local_variable_count].type_c = array_type_c;
                codegen->local_variable_count++;
            }
        } else {
            // 非数组参数：正常添加到局部变量表
            const char *param_type_c = c99_type_to_c(codegen, param_type);
            // 对于 slice 类型参数，需要添加 * 后缀（因为 slice 参数通过指针传递）
            if (param_type->type == AST_TYPE_SLICE) {
                // 为 slice 类型添加指针后缀
                size_t len = strlen(param_type_c) + 3;  // 类型 + " *" + null
                char *ptr_type = arena_alloc(codegen->arena, len);
                if (ptr_type) {
                    snprintf(ptr_type, len, "%s *", param_type_c);
                    param_type_c = ptr_type;
                }
            }
            if (param_name && param_type_c && codegen->local_variable_count < C99_MAX_LOCAL_VARS) {
                codegen->local_variables[codegen->local_variable_count].name = param->data.var_decl.name;
                codegen->local_variables[codegen->local_variable_count].type_c = param_type_c;
                codegen->local_variable_count++;
            }
        }
    }
    
    // 生成函数体
    gen_stmt(codegen, body);
    
    // 清除当前函数的返回类型与声明
    codegen->current_function_return_type = NULL;
    codegen->current_function_decl = saved_current_function_decl;
    
    // 恢复函数开始时的局部变量表状态
    // 这样下一个函数可以从干净的状态开始
    codegen->local_variable_count = saved_local_variable_count;
    codegen->current_depth = saved_current_depth;
    
    codegen->indent_level--;
    c99_emit(codegen, "}\n");
}

// 生成方法函数的前向声明（uya_StructName_methodname）
void gen_method_prototype(C99CodeGenerator *codegen, ASTNode *fn_decl, const char *struct_name) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL || !struct_name) return;
    const char *method_name = fn_decl->data.fn_decl.name;
    const char *c_name = get_method_c_name(codegen, struct_name, method_name);
    if (!c_name) return;
    const char *return_c = convert_array_return_type(codegen, fn_decl->data.fn_decl.return_type);
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    fprintf(codegen->output, "%s %s(", return_c, c_name);
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        const char *param_type_c = c99_type_to_c_with_self_opt(codegen, param->data.var_decl.type, struct_name, (i == 0));
        format_param_type(codegen, param_type_c, param_name, codegen->output);
        if (i < param_count - 1) fputs(", ", codegen->output);
    }
    fputs(");\n", codegen->output);
}

// 生成方法函数定义（uya_StructName_methodname）
void gen_method_function(C99CodeGenerator *codegen, ASTNode *fn_decl, const char *struct_name) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL || !struct_name || !fn_decl->data.fn_decl.body) return;
    const char *method_name = fn_decl->data.fn_decl.name;
    const char *c_name = get_method_c_name(codegen, struct_name, method_name);
    if (!c_name) return;
    const char *return_c = convert_array_return_type(codegen, fn_decl->data.fn_decl.return_type);
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    emit_line_directive(codegen, fn_decl->line, fn_decl->filename);
    fprintf(codegen->output, "%s %s(", return_c, c_name);
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        const char *param_type_c = c99_type_to_c_with_self_opt(codegen, param->data.var_decl.type, struct_name, (i == 0));
        format_param_type(codegen, param_type_c, param_name, codegen->output);
        if (i < param_count - 1) fputs(", ", codegen->output);
    }
    fputs(") {\n", codegen->output);
    codegen->indent_level++;
    codegen->current_function_return_type = fn_decl->data.fn_decl.return_type;
    ASTNode *saved_current_function_decl = codegen->current_function_decl;
    codegen->current_function_decl = fn_decl;
    const char *saved_method_struct = codegen->current_method_struct_name;
    codegen->current_method_struct_name = struct_name;
    int saved_local_count = codegen->local_variable_count;
    int saved_depth = codegen->current_depth;
    codegen->local_variable_count = 0;
    codegen->current_depth = 0;
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        const char *param_type_c = c99_type_to_c_with_self_opt(codegen, param->data.var_decl.type, struct_name, (i == 0));
        if (param_name && param_type_c && codegen->local_variable_count < C99_MAX_LOCAL_VARS) {
            codegen->local_variables[codegen->local_variable_count].name = param->data.var_decl.name;
            codegen->local_variables[codegen->local_variable_count].type_c = param_type_c;
            codegen->local_variable_count++;
        }
    }
    if (method_name && strcmp(method_name, "drop") == 0) {
        ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
        const char *self_safe = get_safe_c_identifier(codegen, "self");
        if (struct_decl && struct_decl->data.struct_decl.fields && self_safe) {
            int fc = struct_decl->data.struct_decl.field_count;
            for (int i = fc - 1; i >= 0; i--) {
                ASTNode *field = struct_decl->data.struct_decl.fields[i];
                if (!field || field->type != AST_VAR_DECL || !field->data.var_decl.name) continue;
                ASTNode *ft = field->data.var_decl.type;
                if (!ft || ft->type != AST_TYPE_NAMED || !ft->data.type_named.name) continue;
                const char *field_type_name = ft->data.type_named.name;
                if (!type_has_drop_c99(codegen, field_type_name)) continue;
                const char *drop_c = get_method_c_name(codegen, field_type_name, "drop");
                const char *field_safe = get_safe_c_identifier(codegen, field->data.var_decl.name);
                if (drop_c && field_safe) {
                    fprintf(codegen->output, "    /* drop field */ %s(%s.%s);\n", drop_c, self_safe, field_safe);
                }
            }
        }
    }
    gen_stmt(codegen, fn_decl->data.fn_decl.body);
    
    // 检查函数体是否以 return 结尾
    int has_return = 0;
    if (fn_decl->data.fn_decl.body && fn_decl->data.fn_decl.body->type == AST_BLOCK) {
        ASTNode **stmts = fn_decl->data.fn_decl.body->data.block.stmts;
        int stmt_count = fn_decl->data.fn_decl.body->data.block.stmt_count;
        for (int i = stmt_count - 1; i >= 0; i--) {
            if (stmts[i] && stmts[i]->type != AST_DEFER_STMT && stmts[i]->type != AST_ERRDEFER_STMT) {
                has_return = (stmts[i]->type == AST_RETURN_STMT);
                break;
            }
        }
    }
    
    // 如果返回类型是 !void 且函数体没有显式返回，添加默认返回语句
    if (!has_return && fn_decl->data.fn_decl.return_type && 
        fn_decl->data.fn_decl.return_type->type == AST_TYPE_ERROR_UNION) {
        ASTNode *payload_node = fn_decl->data.fn_decl.return_type->data.type_error_union.payload_type;
        int is_void_payload = (!payload_node || (payload_node->type == AST_TYPE_NAMED &&
            payload_node->data.type_named.name && strcmp(payload_node->data.type_named.name, "void") == 0));
        if (is_void_payload) {
            // !void 类型：返回成功的错误联合
            c99_emit_indent(codegen);
            c99_emit(codegen, "return (%s){ .error_id = 0 };\n", return_c);
        }
    }
    
    codegen->current_function_return_type = NULL;
    codegen->current_function_decl = saved_current_function_decl;
    codegen->current_method_struct_name = saved_method_struct;
    codegen->local_variable_count = saved_local_count;
    codegen->current_depth = saved_depth;
    codegen->indent_level--;
    c99_emit(codegen, "}\n");
}

/* 替换类型节点中的类型参数为具体类型（递归） */
ASTNode *replace_type_params_in_type(C99CodeGenerator *codegen, ASTNode *type_node, TypeParam *type_params, int type_param_count, ASTNode **type_args) {
    if (!type_node) return NULL;
    
    // 如果是命名类型，检查是否是类型参数
    if (type_node->type == AST_TYPE_NAMED) {
        const char *name = type_node->data.type_named.name;
        if (name) {
            // 检查是否是类型参数
            for (int i = 0; i < type_param_count; i++) {
                if (type_params[i].name && strcmp(type_params[i].name, name) == 0) {
                    // 找到匹配的类型参数，返回对应的具体类型
                    if (i < type_param_count && type_args[i]) {
                        return type_args[i];
                    }
                }
            }
        }
        // 如果是泛型类型（如 Vec<i32>），需要递归处理类型参数
        if (type_node->data.type_named.type_arg_count > 0) {
            ASTNode *new_type = ast_new_node(AST_TYPE_NAMED, type_node->line, type_node->column, codegen->arena, type_node->filename);
            if (new_type) {
                new_type->data.type_named.name = type_node->data.type_named.name;
                new_type->data.type_named.type_arg_count = type_node->data.type_named.type_arg_count;
                new_type->data.type_named.type_args = arena_alloc(codegen->arena, sizeof(ASTNode *) * new_type->data.type_named.type_arg_count);
                if (new_type->data.type_named.type_args) {
                    for (int i = 0; i < new_type->data.type_named.type_arg_count; i++) {
                        new_type->data.type_named.type_args[i] = replace_type_params_in_type(codegen, type_node->data.type_named.type_args[i], type_params, type_param_count, type_args);
                    }
                }
                return new_type;
            }
        }
    }
    
    // 对于指针类型，递归处理指向的类型
    if (type_node->type == AST_TYPE_POINTER) {
        ASTNode *pointed_type = type_node->data.type_pointer.pointed_type;
        if (pointed_type) {
            ASTNode *new_pointed_type = replace_type_params_in_type(codegen, pointed_type, type_params, type_param_count, type_args);
            if (new_pointed_type != pointed_type) {
                // 创建新的指针类型节点
                ASTNode *new_type = ast_new_node(AST_TYPE_POINTER, type_node->line, type_node->column, codegen->arena, type_node->filename);
                if (new_type) {
                    new_type->data.type_pointer.pointed_type = new_pointed_type;
                    new_type->data.type_pointer.is_ffi_pointer = type_node->data.type_pointer.is_ffi_pointer;
                    return new_type;
                }
            }
        }
        return type_node;
    }
    
    // 对于数组类型，递归处理元素类型
    if (type_node->type == AST_TYPE_ARRAY) {
        ASTNode *element_type = type_node->data.type_array.element_type;
        if (element_type) {
            ASTNode *new_element_type = replace_type_params_in_type(codegen, element_type, type_params, type_param_count, type_args);
            if (new_element_type != element_type) {
                // 创建新的数组类型节点
                ASTNode *new_type = ast_new_node(AST_TYPE_ARRAY, type_node->line, type_node->column, codegen->arena, type_node->filename);
                if (new_type) {
                    new_type->data.type_array.element_type = new_element_type;
                    new_type->data.type_array.size_expr = type_node->data.type_array.size_expr;  // 大小表达式不变
                    return new_type;
                }
            }
        }
        return type_node;
    }
    
    // 对于其他类型节点，保持原样
    return type_node;
}

/* 生成泛型函数实例化的函数定义（单态化） */
void gen_generic_function_instance(C99CodeGenerator *codegen, ASTNode *generic_fn_decl, ASTNode **type_args, int type_arg_count, const char *instance_name) {
    if (!codegen || !generic_fn_decl || generic_fn_decl->type != AST_FN_DECL || !type_args || !instance_name) return;
    if (!generic_fn_decl->data.fn_decl.body) return;  // 没有函数体，不生成定义
    
    TypeParam *type_params = generic_fn_decl->data.fn_decl.type_params;
    int type_param_count = generic_fn_decl->data.fn_decl.type_param_count;
    
    if (type_param_count != type_arg_count) return;  // 类型参数数量不匹配
    
    // 创建实例化的函数声明（复制原始声明，但替换类型参数）
    ASTNode *instance_decl = ast_new_node(AST_FN_DECL, generic_fn_decl->line, generic_fn_decl->column, codegen->arena, generic_fn_decl->filename);
    if (!instance_decl) return;
    
    // 复制基本信息
    instance_decl->data.fn_decl.name = instance_name;  // 使用实例化名称
    instance_decl->data.fn_decl.type_params = NULL;  // 实例化后不再有类型参数
    instance_decl->data.fn_decl.type_param_count = 0;
    instance_decl->data.fn_decl.is_varargs = generic_fn_decl->data.fn_decl.is_varargs;
    instance_decl->data.fn_decl.is_export = generic_fn_decl->data.fn_decl.is_export;
    
    // 替换返回类型中的类型参数
    instance_decl->data.fn_decl.return_type = replace_type_params_in_type(codegen, generic_fn_decl->data.fn_decl.return_type, type_params, type_param_count, type_args);
    
    // 替换参数类型中的类型参数
    instance_decl->data.fn_decl.param_count = generic_fn_decl->data.fn_decl.param_count;
    instance_decl->data.fn_decl.params = arena_alloc(codegen->arena, sizeof(ASTNode *) * instance_decl->data.fn_decl.param_count);
    if (instance_decl->data.fn_decl.params) {
        for (int i = 0; i < instance_decl->data.fn_decl.param_count; i++) {
            ASTNode *param = generic_fn_decl->data.fn_decl.params[i];
            if (param && param->type == AST_VAR_DECL) {
                ASTNode *new_param = ast_new_node(AST_VAR_DECL, param->line, param->column, codegen->arena, param->filename);
                if (new_param) {
                    new_param->data.var_decl.name = param->data.var_decl.name;
                    new_param->data.var_decl.type = replace_type_params_in_type(codegen, param->data.var_decl.type, type_params, type_param_count, type_args);
                    new_param->data.var_decl.init = NULL;  // 参数没有初始化
                    instance_decl->data.fn_decl.params[i] = new_param;
                } else {
                    instance_decl->data.fn_decl.params[i] = param;  // 失败时使用原始参数
                }
            } else {
                instance_decl->data.fn_decl.params[i] = param;
            }
        }
    }
    
    // 复制函数体（函数体中的类型参数会在生成代码时通过类型替换处理）
    // 注意：这里我们直接使用原始函数体，但在生成代码时需要替换类型参数
    // 为了简化，我们创建一个新的函数体节点，但内容相同
    // 实际上，类型参数的替换应该在生成代码时进行，而不是在 AST 层面
    // 所以这里我们直接使用原始函数体
    instance_decl->data.fn_decl.body = generic_fn_decl->data.fn_decl.body;
    
    // 生成函数定义（使用修改后的声明）
    // 但是，我们需要在生成代码时替换类型参数
    // 为了简化实现，我们直接调用 gen_function，但在生成代码时通过类型替换来处理
    // 这里我们需要一个机制来在生成代码时替换类型参数
    
    // 临时方案：直接生成函数定义，但使用实例化名称
    // 类型参数的替换需要在生成代码时进行，这需要修改 gen_function 和相关的类型生成函数
    // 为了快速实现，我们先生成一个简化版本
    
    // 生成函数签名
    const char *return_c = convert_array_return_type(codegen, instance_decl->data.fn_decl.return_type);
    fprintf(codegen->output, "%s %s(", return_c, instance_name);
    
    // 生成参数列表
    for (int i = 0; i < instance_decl->data.fn_decl.param_count; i++) {
        ASTNode *param = instance_decl->data.fn_decl.params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        format_param_type(codegen, param_type_c, param_name, codegen->output);
        if (i < instance_decl->data.fn_decl.param_count - 1) fputs(", ", codegen->output);
    }
    
    if (instance_decl->data.fn_decl.is_varargs) {
        if (instance_decl->data.fn_decl.param_count > 0) fputs(", ", codegen->output);
        fputs("...", codegen->output);
    }
    
    fputs(") {\n", codegen->output);
    codegen->indent_level++;
    
    // 保存状态
    codegen->current_function_return_type = instance_decl->data.fn_decl.return_type;
    ASTNode *saved_current_function_decl = codegen->current_function_decl;
    codegen->current_function_decl = instance_decl;
    int saved_local_variable_count = codegen->local_variable_count;
    int saved_current_depth = codegen->current_depth;
    codegen->local_variable_count = 0;
    codegen->current_depth = 0;
    
    // 处理参数（与 gen_function 中的逻辑相同）
    for (int i = 0; i < instance_decl->data.fn_decl.param_count; i++) {
        ASTNode *param = instance_decl->data.fn_decl.params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        
        if (param_type->type == AST_TYPE_ARRAY) {
            const char *array_type_c = c99_type_to_c(codegen, param_type);
            const char *bracket = strchr(array_type_c, '[');
            c99_emit(codegen, "// 数组参数按值传递：创建局部副本\n");
            if (bracket) {
                size_t len = bracket - array_type_c;
                fprintf(codegen->output, "    %.*s %s%s;\n", (int)len, array_type_c, param_name, bracket);
            } else {
                c99_emit(codegen, "%s %s;\n", array_type_c, param_name);
            }
            c99_emit(codegen, "    memcpy(%s, %s_param, sizeof(%s));\n", param_name, param_name, param_name);
            
            if (param_name && codegen->local_variable_count < C99_MAX_LOCAL_VARS) {
                codegen->local_variables[codegen->local_variable_count].name = param->data.var_decl.name;
                codegen->local_variables[codegen->local_variable_count].type_c = array_type_c;
                codegen->local_variable_count++;
            }
        } else {
            const char *param_type_c = c99_type_to_c(codegen, param_type);
            if (param_type->type == AST_TYPE_SLICE) {
                size_t len = strlen(param_type_c) + 3;
                char *ptr_type = arena_alloc(codegen->arena, len);
                if (ptr_type) {
                    snprintf(ptr_type, len, "%s *", param_type_c);
                    param_type_c = ptr_type;
                }
            }
            if (param_name && param_type_c && codegen->local_variable_count < C99_MAX_LOCAL_VARS) {
                codegen->local_variables[codegen->local_variable_count].name = param->data.var_decl.name;
                codegen->local_variables[codegen->local_variable_count].type_c = param_type_c;
                codegen->local_variable_count++;
            }
        }
    }
    
    // 生成函数体
    gen_stmt(codegen, instance_decl->data.fn_decl.body);
    
    // 恢复状态
    codegen->current_function_return_type = NULL;
    codegen->current_function_decl = saved_current_function_decl;
    codegen->local_variable_count = saved_local_variable_count;
    codegen->current_depth = saved_current_depth;
    codegen->indent_level--;
    c99_emit(codegen, "}\n");
}
