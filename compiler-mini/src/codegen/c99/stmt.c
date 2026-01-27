#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

void gen_stmt(C99CodeGenerator *codegen, ASTNode *stmt) {
    if (!stmt) return;
    
    switch (stmt->type) {
        case AST_EXPR_STMT:
            // 表达式语句的数据存储在表达式的节点中，直接忽略此节点
            break;
        case AST_ASSIGN: {
            ASTNode *dest = stmt->data.assign.dest;
            ASTNode *src = stmt->data.assign.src;
            
            // 检查左侧是否是数组类型
            int is_array_assign = 0;
            if (dest->type == AST_IDENTIFIER) {
                const char *var_name = dest->data.identifier.name;
                // 检查局部变量
                for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
                    if (strcmp(codegen->local_variables[i].name, var_name) == 0) {
                        const char *type_c = codegen->local_variables[i].type_c;
                        if (type_c && strchr(type_c, '[') != NULL) {
                            is_array_assign = 1;
                        }
                        break;
                    }
                }
                // 检查全局变量
                if (!is_array_assign) {
                    for (int i = 0; i < codegen->global_variable_count; i++) {
                        if (strcmp(codegen->global_variables[i].name, var_name) == 0) {
                            const char *type_c = codegen->global_variables[i].type_c;
                            if (type_c && strchr(type_c, '[') != NULL) {
                                is_array_assign = 1;
                            }
                            break;
                        }
                    }
                }
            }
            
            if (is_array_assign) {
                // 数组赋值：使用 memcpy
                c99_emit(codegen, "memcpy(");
                gen_expr(codegen, dest);
                fputs(", ", codegen->output);
                gen_expr(codegen, src);
                fputs(", sizeof(", codegen->output);
                gen_expr(codegen, dest);
                fputs("));\n", codegen->output);
            } else {
                // 普通赋值
                c99_emit(codegen, "");
                gen_expr(codegen, dest);
                fputs(" = ", codegen->output);
                gen_expr(codegen, src);
                fputs(";\n", codegen->output);
            }
            break;
        }
        case AST_RETURN_STMT: {
            ASTNode *expr = stmt->data.return_stmt.expr;
            
            // 检查函数返回类型是否为数组
            int is_array_return = 0;
            ASTNode *return_type = codegen->current_function_return_type;
            if (return_type && return_type->type == AST_TYPE_ARRAY) {
                is_array_return = 1;
            }
            
            if (is_array_return && expr) {
                // 返回数组类型：需要包装在结构体中
                const char *struct_name = get_array_wrapper_struct_name(codegen, return_type);
                if (struct_name) {
                    // 生成包装结构体定义（如果尚未生成）
                    gen_array_wrapper_struct(codegen, return_type, struct_name);
                    
                    // 生成返回语句：return (struct uya_array_xxx) { .data = { ... } };
                    c99_emit(codegen, "return (struct %s) { .data = ", struct_name);
                    
                    if (expr->type == AST_ARRAY_LITERAL) {
                        // 数组字面量
                        fputc('{', codegen->output);
                        ASTNode **elements = expr->data.array_literal.elements;
                        int element_count = expr->data.array_literal.element_count;
                        for (int i = 0; i < element_count; i++) {
                            if (i > 0) fputs(", ", codegen->output);
                            gen_expr(codegen, elements[i]);
                        }
                        fputc('}', codegen->output);
                    } else {
                        // 其他表达式（如变量）
                        gen_expr(codegen, expr);
                    }
                    
                    fputs(" };\n", codegen->output);
                } else {
                    // 回退到普通返回
                    c99_emit(codegen, "return ");
                    gen_expr(codegen, expr);
                    fputs(";\n", codegen->output);
                }
            } else {
                // 非数组返回类型，正常处理
                // 检查返回类型是否为 void
                int is_void = 0;
                if (return_type && return_type->type == AST_TYPE_NAMED) {
                    const char *type_name = return_type->data.type_named.name;
                    if (type_name && strcmp(type_name, "void") == 0) {
                        is_void = 1;
                    }
                }
                
                if (is_void && !expr) {
                    // void 函数且无返回值：生成 return;
                    c99_emit(codegen, "return;\n");
                } else {
                    // 非 void 函数或 void 函数有返回值（错误情况，但让编译器处理）
                    c99_emit(codegen, "return ");
                    if (expr) {
                        gen_expr(codegen, expr);
                    } else {
                        fputs("0", codegen->output);
                    }
                    fputs(";\n", codegen->output);
                }
            }
            break;
        }
        case AST_BLOCK: {
            ASTNode **stmts = stmt->data.block.stmts;
            int stmt_count = stmt->data.block.stmt_count;
            for (int i = 0; i < stmt_count; i++) {
                gen_stmt(codegen, stmts[i]);
            }
            break;
        }
        case AST_VAR_DECL: {
            const char *var_name = get_safe_c_identifier(codegen, stmt->data.var_decl.name);
            ASTNode *var_type = stmt->data.var_decl.type;
            ASTNode *init_expr = stmt->data.var_decl.init;
            int is_const = stmt->data.var_decl.is_const;
            
            // 计算类型字符串
            const char *type_c = NULL;
            const char *stored_type_c = NULL;  // 用于存储到变量表的完整类型字符串
            if (var_type->type == AST_TYPE_ARRAY) {
                // 使用 c99_type_to_c 来处理数组类型（包括多维数组）
                // 它会返回正确的格式，如 "int32_t[3][2]" 对于 [[i32: 2]: 3]
                type_c = c99_type_to_c(codegen, var_type);
                
                // 保存完整的类型字符串（包括 const 和维度）用于存储到变量表
                if (type_c) {
                    size_t type_len = strlen(type_c);
                    if (is_const) {
                        // 为 "const " 前缀分配空间
                        stored_type_c = arena_alloc(codegen->arena, type_len + 7);
                        if (stored_type_c) {
                            snprintf((char *)stored_type_c, type_len + 7, "const %s", type_c);
                        }
                    } else {
                        stored_type_c = arena_strdup(codegen->arena, type_c);
                    }
                }
                
                // 解析类型字符串，分离基类型和数组维度
                // 例如："int32_t[3][2]" -> 基类型="int32_t", 维度="[3][2]"
                // 或者 "int32_t[3]" -> 基类型="int32_t", 维度="[3]"
                const char *first_bracket = strchr(type_c, '[');
                if (first_bracket) {
                    // 找到第一个 '['，分割基类型和维度
                    size_t base_len = first_bracket - type_c;
                    char *base_type = arena_alloc(codegen->arena, base_len + 1);
                    if (base_type) {
                        memcpy(base_type, type_c, base_len);
                        base_type[base_len] = '\0';
                        
                        // 维度部分是从 '[' 开始到结尾
                        const char *dimensions = type_c + base_len;
                        
                        // 生成数组声明：const base_type var_name dimensions
                        if (is_const) {
                            fprintf(codegen->output, "const %s %s%s", base_type, var_name, dimensions);
                        } else {
                            fprintf(codegen->output, "%s %s%s", base_type, var_name, dimensions);
                        }
                        type_c = NULL; // 已处理，避免后续重复输出
                    }
                }
                
                // 如果上面的解析失败，回退到简单处理
                if (type_c) {
                    if (is_const) {
                        c99_emit(codegen, "const %s %s", type_c, var_name);
                    } else {
                        c99_emit(codegen, "%s %s", type_c, var_name);
                    }
                }
            } else {
                // 非数组类型
                type_c = c99_type_to_c(codegen, var_type);
                if (is_const && var_type->type == AST_TYPE_POINTER) {
                    // 检查是否是指向数组的指针类型（格式：T (*)[N]）
                    const char *open_paren = strstr(type_c, "(*");
                    if (open_paren) {
                        // 找到对应的 ')' 和 '['
                        const char *close_paren = strchr(open_paren, ')');
                        const char *bracket = strchr(open_paren, '[');
                        if (close_paren && bracket && close_paren < bracket) {
                            // 这是指向数组的指针：T (*)[N]
                            // 需要生成：T (* const var_name)[N]
                            size_t prefix_len = open_paren - type_c;
                            size_t suffix_len = strlen(bracket);
                            fprintf(codegen->output, "%.*s(* const %s)%.*s", 
                                    (int)prefix_len, type_c, var_name, (int)suffix_len, bracket);
                        } else {
                            // 普通指针：T * -> T * const var_name
                            c99_emit(codegen, "%s const %s", type_c, var_name);
                        }
                    } else {
                        // 普通指针：T * -> T * const var_name
                        c99_emit(codegen, "%s const %s", type_c, var_name);
                    }
                } else if (is_const) {
                    c99_emit(codegen, "const %s %s", type_c, var_name);
                } else {
                    c99_emit(codegen, "%s %s", type_c, var_name);
                }
            }
            
            if (init_expr) {
                // 检查是否是数组类型且初始化表达式是函数调用（返回数组）
                int is_array_from_function = 0;
                if (var_type->type == AST_TYPE_ARRAY && init_expr->type == AST_CALL_EXPR) {
                    // 需要检查函数返回类型是否为数组
                    // 这里简化处理：假设函数调用返回数组类型
                    is_array_from_function = 1;
                }
                
                // 检查是否是数组类型且初始化表达式是另一个数组（需要memcpy）
                int needs_memcpy = 0;
                if (var_type->type == AST_TYPE_ARRAY && init_expr->type == AST_IDENTIFIER) {
                    needs_memcpy = 1;
                }
                
                // 检查是否是结构体初始化且包含数组字段（初始化值是标识符）
                // 在C中，数组不能直接赋值，需要使用memcpy
                int struct_init_needs_memcpy = 0;
                if (init_expr->type == AST_STRUCT_INIT) {
                    const char *struct_name = get_safe_c_identifier(codegen, init_expr->data.struct_init.struct_name);
                    ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
                    if (struct_decl) {
                        int field_count = init_expr->data.struct_init.field_count;
                        const char **field_names = init_expr->data.struct_init.field_names;
                        ASTNode **field_values = init_expr->data.struct_init.field_values;
                        for (int i = 0; i < field_count; i++) {
                            const char *field_name = field_names[i];
                            ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_name);
                            if (field_type && field_type->type == AST_TYPE_ARRAY) {
                                ASTNode *field_value = field_values[i];
                                if (field_value && field_value->type == AST_IDENTIFIER) {
                                    struct_init_needs_memcpy = 1;
                                    break;
                                }
                            }
                        }
                    }
                }
                
                if (is_array_from_function) {
                    // 从函数调用接收数组：需要从包装结构体中提取
                    // 先完成变量声明（不包含初始化）
                    fputs(";\n", codegen->output);
                    // 然后使用 memcpy 从结构体中提取数组
                    c99_emit(codegen, "memcpy(");
                    c99_emit(codegen, "%s", var_name);
                    fputs(", ", codegen->output);
                    gen_expr(codegen, init_expr);
                    fputs(".data, sizeof(", codegen->output);
                    c99_emit(codegen, "%s", var_name);
                    fputs("));\n", codegen->output);
                } else if (needs_memcpy) {
                    // 数组初始化：使用memcpy
                    fputs(";\n", codegen->output);
                    c99_emit(codegen, "memcpy(");
                    c99_emit(codegen, "%s", var_name);
                    fputs(", ", codegen->output);
                    gen_expr(codegen, init_expr);
                    fputs(", sizeof(", codegen->output);
                    c99_emit(codegen, "%s", var_name);
                    fputs("));\n", codegen->output);
                } else if (struct_init_needs_memcpy) {
                    // 结构体初始化包含数组字段：先声明变量，然后使用复合字面量初始化非数组字段，最后用memcpy复制数组字段
                    fputs(" = ", codegen->output);
                    
                    // 生成复合字面量，但数组字段使用空初始化
                    const char *struct_name = get_safe_c_identifier(codegen, init_expr->data.struct_init.struct_name);
                    ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
                    int field_count = init_expr->data.struct_init.field_count;
                    const char **field_names = init_expr->data.struct_init.field_names;
                    ASTNode **field_values = init_expr->data.struct_init.field_values;
                    
                    fprintf(codegen->output, "(struct %s){", struct_name);
                    for (int i = 0; i < field_count; i++) {
                        const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                        ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_names[i]);
                        ASTNode *field_value = field_values[i];
                        
                        fprintf(codegen->output, ".%s = ", safe_field_name);
                        
                        // 如果是数组字段且初始化值是标识符，使用空初始化（后续用memcpy填充）
                        if (field_type && field_type->type == AST_TYPE_ARRAY && 
                            field_value && field_value->type == AST_IDENTIFIER) {
                            fputs("{}", codegen->output);
                        } else {
                            gen_expr(codegen, field_value);
                        }
                        
                        if (i < field_count - 1) fputs(", ", codegen->output);
                    }
                    fputs("};\n", codegen->output);
                    
                    // 使用memcpy复制数组字段
                    for (int i = 0; i < field_count; i++) {
                        const char *field_name = field_names[i];
                        ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_name);
                        ASTNode *field_value = field_values[i];
                        
                        if (field_type && field_type->type == AST_TYPE_ARRAY && 
                            field_value && field_value->type == AST_IDENTIFIER) {
                            const char *safe_field_name = get_safe_c_identifier(codegen, field_name);
                            c99_emit(codegen, "memcpy(");
                            c99_emit(codegen, "%s.%s, ", var_name, safe_field_name);
                            gen_expr(codegen, field_value);
                            c99_emit(codegen, ", sizeof(%s.%s));\n", var_name, safe_field_name);
                        }
                    }
                } else {
                    // 普通初始化
                    fputs(" = ", codegen->output);
                    gen_expr(codegen, init_expr);
                    fputs(";\n", codegen->output);
                }
            } else {
                fputs(";\n", codegen->output);
            }
            
            // 添加到局部变量表（用于类型检测）
            // 对于数组类型，使用 stored_type_c；对于其他类型，使用 type_c
            const char *type_to_store = (var_type->type == AST_TYPE_ARRAY && stored_type_c) ? stored_type_c : type_c;
            if (var_name && type_to_store && codegen->local_variable_count < 128) {
                codegen->local_variables[codegen->local_variable_count].name = var_name;
                codegen->local_variables[codegen->local_variable_count].type_c = type_to_store;
                codegen->local_variable_count++;
            }
            break;
        }
        case AST_IF_STMT: {
            ASTNode *condition = stmt->data.if_stmt.condition;
            ASTNode *then_branch = stmt->data.if_stmt.then_branch;
            ASTNode *else_branch = stmt->data.if_stmt.else_branch;
            
            c99_emit(codegen, "if (");
            gen_expr(codegen, condition);
            fputs(") {\n", codegen->output);
            codegen->indent_level++;
            gen_stmt(codegen, then_branch);
            codegen->indent_level--;
            c99_emit(codegen, "}");
            if (else_branch) {
                fputs(" else {\n", codegen->output);
                codegen->indent_level++;
                gen_stmt(codegen, else_branch);
                codegen->indent_level--;
                c99_emit(codegen, "}");
            }
            fputs("\n", codegen->output);
            break;
        }
        case AST_WHILE_STMT: {
            ASTNode *condition = stmt->data.while_stmt.condition;
            ASTNode *body = stmt->data.while_stmt.body;
            
            c99_emit(codegen, "while (");
            gen_expr(codegen, condition);
            fputs(") {\n", codegen->output);
            codegen->indent_level++;
            gen_stmt(codegen, body);
            codegen->indent_level--;
            c99_emit(codegen, "}\n");
            break;
        }
        case AST_FOR_STMT: {
            // Uya Mini 的 for 循环是数组遍历：for item in array { ... }
            ASTNode *array = stmt->data.for_stmt.array;
            const char *var_name = get_safe_c_identifier(codegen, stmt->data.for_stmt.var_name);
            int is_ref = stmt->data.for_stmt.is_ref;
            ASTNode *body = stmt->data.for_stmt.body;
            
            // 获取数组元素类型
            const char *elem_type_c = get_array_element_type(codegen, array);
            if (!elem_type_c) {
                // 如果无法推断类型，使用int作为默认类型
                elem_type_c = "int32_t";
            }
            
            // 生成临时变量保存数组和长度
            c99_emit(codegen, "{\n");
            codegen->indent_level++;
            c99_emit(codegen, "// for loop - array traversal\n");
            // 生成数组长度计算
            c99_emit(codegen, "size_t _len = sizeof(");
            gen_expr(codegen, array);
            c99_emit(codegen, ") / sizeof(");
            gen_expr(codegen, array);
            c99_emit(codegen, "[0]);\n");
            c99_emit(codegen, "for (size_t _i = 0; _i < _len; _i++) {\n");
            codegen->indent_level++;
            if (is_ref) {
                // 引用迭代：生成指针类型
                // 检查 elem_type_c 是否包含数组维度（如 "int32_t[2]"）
                const char *bracket = strchr(elem_type_c, '[');
                if (bracket) {
                    // 数组类型：分离基类型和维度
                    size_t base_len = bracket - elem_type_c;
                    c99_emit(codegen, "%.*s *%s = &", (int)base_len, elem_type_c, var_name);
                    gen_expr(codegen, array);
                    c99_emit(codegen, "[_i];\n");
                } else {
                    // 非数组类型：直接使用
                    c99_emit(codegen, "%s *%s = &", elem_type_c, var_name);
                    gen_expr(codegen, array);
                    c99_emit(codegen, "[_i];\n");
                }
            } else {
                // 值迭代：生成值类型
                // 检查 elem_type_c 是否包含数组维度（如 "int32_t[2]"）
                const char *bracket = strchr(elem_type_c, '[');
                if (bracket) {
                    // 数组类型：使用 memcpy 复制数组内容
                    // 转换为 C 数组声明格式 "base_type var_name[dims]"
                    size_t base_len = bracket - elem_type_c;
                    c99_emit(codegen, "%.*s %s%s;\n", (int)base_len, elem_type_c, var_name, bracket);
                    c99_emit(codegen, "memcpy(%s, ", var_name);
                    gen_expr(codegen, array);
                    c99_emit(codegen, "[_i], sizeof(%s));\n", var_name);
                } else {
                    // 非数组类型：直接使用
                    c99_emit(codegen, "%s %s = ", elem_type_c, var_name);
                    gen_expr(codegen, array);
                    c99_emit(codegen, "[_i];\n");
                }
            }
            gen_stmt(codegen, body);
            codegen->indent_level--;
            c99_emit(codegen, "}\n");
            codegen->indent_level--;
            c99_emit(codegen, "}\n");
            break;
        }
        case AST_BREAK_STMT:
            c99_emit(codegen, "break;\n");
            break;
        case AST_CONTINUE_STMT:
            c99_emit(codegen, "continue;\n");
            break;
        default:
            // 检查是否为表达式节点
            if (stmt->type >= AST_BINARY_EXPR && stmt->type <= AST_STRING) {
                c99_emit(codegen, "");
                gen_expr(codegen, stmt);
                fputs(";\n", codegen->output);
            }
            // 忽略其他语句
            break;
    }
}
