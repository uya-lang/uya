#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

void gen_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return;
    
    switch (expr->type) {
        case AST_NUMBER:
            fprintf(codegen->output, "%d", expr->data.number.value);
            break;
        case AST_BOOL:
            fprintf(codegen->output, "%s", expr->data.bool_literal.value ? "true" : "false");
            break;
        case AST_STRING: {
            const char *str_const = add_string_constant(codegen, expr->data.string_literal.value);
            if (str_const) {
                fprintf(codegen->output, "%s", str_const);
            } else {
                fputs("\"\"", codegen->output);
            }
            break;
        }
        case AST_BINARY_EXPR: {
            ASTNode *left = expr->data.binary_expr.left;
            ASTNode *right = expr->data.binary_expr.right;
            int op = expr->data.binary_expr.op;
            
            // 检查是否是结构体比较（== 或 !=）
            int is_struct_comparison = 0;
            if ((op == TOKEN_EQUAL || op == TOKEN_NOT_EQUAL) &&
                left && right) {
                // 检查左操作数是否是结构体类型
                if (left->type == AST_IDENTIFIER) {
                    if (is_identifier_struct_type(codegen, left->data.identifier.name)) {
                        is_struct_comparison = 1;
                    }
                } else if (left->type == AST_STRUCT_INIT) {
                    is_struct_comparison = 1;
                }
            }
            
            if (is_struct_comparison) {
                // 使用memcmp比较结构体
                // 需要获取左操作数的类型来确定结构体大小
                const char *struct_name = NULL;
                if (left->type == AST_IDENTIFIER) {
                    // 对于变量，我们需要查找其类型
                    // 这里简化处理，使用sizeof运算符
                    fputs("memcmp(&", codegen->output);
                    gen_expr(codegen, left);
                    fputs(", &", codegen->output);
                    gen_expr(codegen, right);
                    fputs(", sizeof(", codegen->output);
                    gen_expr(codegen, left);
                    fputs("))", codegen->output);
                } else if (left->type == AST_STRUCT_INIT) {
                    // 对于结构体字面量，使用结构体名称
                    struct_name = left->data.struct_init.struct_name;
                    fputs("memcmp(&", codegen->output);
                    gen_expr(codegen, left);
                    fputs(", &", codegen->output);
                    gen_expr(codegen, right);
                    fprintf(codegen->output, ", sizeof(struct %s))", struct_name);
                } else {
                    // 默认情况，使用sizeof左操作数
                    fputs("memcmp(&", codegen->output);
                    gen_expr(codegen, left);
                    fputs(", &", codegen->output);
                    gen_expr(codegen, right);
                    fputs(", sizeof(", codegen->output);
                    gen_expr(codegen, left);
                    fputs("))", codegen->output);
                }
                if (op == TOKEN_EQUAL) {
                    fputs(" == 0", codegen->output);
                } else if (op == TOKEN_NOT_EQUAL) {
                    fputs(" != 0", codegen->output);
                }
            } else {
                // 普通二元表达式
                fputc('(', codegen->output);
                gen_expr(codegen, left);
                // 操作符映射
                if (op == TOKEN_PLUS) {
                    fputs(" + ", codegen->output);
                } else if (op == TOKEN_MINUS) {
                    fputs(" - ", codegen->output);
                } else if (op == TOKEN_ASTERISK) {
                    fputs(" * ", codegen->output);
                } else if (op == TOKEN_SLASH) {
                    fputs(" / ", codegen->output);
                } else if (op == TOKEN_PERCENT) {
                    fputs(" % ", codegen->output);
                } else if (op == TOKEN_EQUAL) {
                    fputs(" == ", codegen->output);
                } else if (op == TOKEN_NOT_EQUAL) {
                    fputs(" != ", codegen->output);
                } else if (op == TOKEN_LESS) {
                    fputs(" < ", codegen->output);
                } else if (op == TOKEN_GREATER) {
                    fputs(" > ", codegen->output);
                } else if (op == TOKEN_LESS_EQUAL) {
                    fputs(" <= ", codegen->output);
                } else if (op == TOKEN_GREATER_EQUAL) {
                    fputs(" >= ", codegen->output);
                } else if (op == TOKEN_LOGICAL_AND) {
                    fputs(" && ", codegen->output);
                } else if (op == TOKEN_LOGICAL_OR) {
                    fputs(" || ", codegen->output);
                } else {
                    fputs(" + ", codegen->output); // 默认为加法
                }
                gen_expr(codegen, right);
                fputc(')', codegen->output);
            }
            break;
        }
        case AST_UNARY_EXPR: {
            int op = expr->data.unary_expr.op;
            ASTNode *operand = expr->data.unary_expr.operand;
            fputc('(', codegen->output);
            if (op == TOKEN_ASTERISK) {
                fputs("*", codegen->output);
            } else if (op == TOKEN_AMPERSAND) {
                fputs("&", codegen->output);
            } else if (op == TOKEN_MINUS) {
                fputs("-", codegen->output);
            } else if (op == TOKEN_EXCLAMATION) {
                fputs("!", codegen->output);
            } else if (op == TOKEN_PLUS) {
                fputs("+", codegen->output);
            } else {
                fputs("+", codegen->output); // 默认
            }
            gen_expr(codegen, operand);
            fputc(')', codegen->output);
            break;
        }
        case AST_MEMBER_ACCESS: {
            ASTNode *object = expr->data.member_access.object;
            const char *field_name = expr->data.member_access.field_name;
            
            if (!object || !field_name) {
                break;
            }
            
            // 检查是否是枚举值访问（EnumName.Variant）
            if (object->type == AST_IDENTIFIER) {
                const char *enum_name = object->data.identifier.name;
                if (enum_name) {
                    // 检查是否是枚举类型名称（不检查变量表，直接检查枚举声明）
                    ASTNode *enum_decl = find_enum_decl_c99(codegen, enum_name);
                    if (enum_decl != NULL) {
                        // 是枚举类型，查找变体值
                        int enum_value = find_enum_variant_value(codegen, enum_decl, field_name);
                        if (enum_value >= 0) {
                            // 找到变体，直接输出枚举值名称（C中枚举值不需要前缀）
                            const char *safe_variant_name = get_safe_c_identifier(codegen, field_name);
                            fprintf(codegen->output, "%s", safe_variant_name);
                            break;
                        }
                    }
                }
            }
            
            // 普通字段访问（结构体字段）
            const char *safe_field_name = get_safe_c_identifier(codegen, field_name);
            
            // 检查对象是否是指针类型（需要自动解引用）
            int is_pointer = 0;
            if (object->type == AST_IDENTIFIER) {
                // 标识符：检查变量类型是否是指针
                is_pointer = is_identifier_pointer_type(codegen, object->data.identifier.name);
            } else if (object->type == AST_MEMBER_ACCESS) {
                // 嵌套成员访问：检查嵌套访问的结果类型是否是指针
                is_pointer = is_member_access_pointer_type(codegen, object);
            } else if (object->type == AST_ARRAY_ACCESS) {
                // 数组访问：检查数组元素类型是否是指针
                // 例如：programs[i] 如果 programs 的类型是 [&ASTNode: 64]，那么 programs[i] 是指针类型
                is_pointer = is_array_access_pointer_type(codegen, object);
            } else if (object->type == AST_UNARY_EXPR) {
                // 一元表达式：检查操作符
                int op = object->data.unary_expr.op;
                if (op == TOKEN_AMPERSAND) {
                    // &expr：取地址表达式的结果是指针，但这里访问的是 expr 的字段
                    // 实际上不应该发生这种情况，因为 &expr.field 在语法上不合法
                    // 但为了安全，我们假设不是指针
                    is_pointer = 0;
                } else if (op == TOKEN_ASTERISK) {
                    // *ptr：解引用表达式的结果是结构体本身，不是指针
                    // 所以应该使用 . 而不是 ->
                    is_pointer = 0;
                }
                // 其他一元操作符（!, -, +）不影响类型判断
            }
            
            gen_expr(codegen, object);
            if (is_pointer) {
                // 指针类型使用 -> 操作符
                fprintf(codegen->output, "->%s", safe_field_name);
            } else {
                // 非指针类型使用 . 操作符
                fprintf(codegen->output, ".%s", safe_field_name);
            }
            break;
        }
        case AST_ARRAY_ACCESS: {
            ASTNode *array = expr->data.array_access.array;
            ASTNode *index = expr->data.array_access.index;
            
            // 检查数组表达式是否是指向数组的指针
            int is_ptr_to_array = 0;
            if (array->type == AST_IDENTIFIER) {
                const char *array_name = array->data.identifier.name;
                if (array_name) {
                    is_ptr_to_array = is_identifier_pointer_to_array_type(codegen, array_name);
                }
            }
            
            if (is_ptr_to_array) {
                // 指向数组的指针需要先解引用：(*ptr)[index]
                fputc('(', codegen->output);
                fputc('*', codegen->output);
                gen_expr(codegen, array);
                fputc(')', codegen->output);
            } else {
                gen_expr(codegen, array);
            }
            
            fputc('[', codegen->output);
            gen_expr(codegen, index);
            fputc(']', codegen->output);
            break;
        }
        case AST_STRUCT_INIT: {
            const char *struct_name = get_safe_c_identifier(codegen, expr->data.struct_init.struct_name);
            int field_count = expr->data.struct_init.field_count;
            const char **field_names = expr->data.struct_init.field_names;
            ASTNode **field_values = expr->data.struct_init.field_values;
            
            // 检查是否有数组字段且初始化值是标识符（另一个数组变量）
            // 在C中，数组不能直接赋值，需要使用memcpy
            int has_array_field_with_identifier = 0;
            ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
            if (struct_decl) {
                for (int i = 0; i < field_count; i++) {
                    const char *field_name = field_names[i];
                    ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_name);
                    if (field_type && field_type->type == AST_TYPE_ARRAY) {
                        ASTNode *field_value = field_values[i];
                        if (field_value && field_value->type == AST_IDENTIFIER) {
                            has_array_field_with_identifier = 1;
                            break;
                        }
                    }
                }
            }
            
            if (has_array_field_with_identifier) {
                // 不能使用复合字面量，需要改用临时变量和memcpy
                // 生成临时变量名
                static int temp_counter = 0;
                char temp_name[32];
                snprintf(temp_name, sizeof(temp_name), "_temp_struct_%d", temp_counter++);
                
                // 先声明临时变量
                fprintf(codegen->output, "((struct %s){", struct_name);
                for (int i = 0; i < field_count; i++) {
                    const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                    ASTNode *field_type = find_struct_field_type(codegen, struct_decl, safe_field_name);
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
                fputc('}', codegen->output);
                
                // 生成memcpy调用
                fputs(", ", codegen->output);
                fprintf(codegen->output, "memcpy(%s.", temp_name);
                
                // 找到第一个数组字段（标识符类型）
                for (int i = 0; i < field_count; i++) {
                    const char *field_name = field_names[i];
                    ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_name);
                    ASTNode *field_value = field_values[i];
                    
                    if (field_type && field_type->type == AST_TYPE_ARRAY && 
                        field_value && field_value->type == AST_IDENTIFIER) {
                        const char *safe_field_name = get_safe_c_identifier(codegen, field_name);
                        fprintf(codegen->output, "%s, ", safe_field_name);
                        gen_expr(codegen, field_value);
                        fprintf(codegen->output, ", sizeof(%s.%s))", temp_name, safe_field_name);
                        break;
                    }
                }
                
                fputc(')', codegen->output);
            } else {
                // 正常情况：使用复合字面量
                fprintf(codegen->output, "(struct %s){", struct_name);
                for (int i = 0; i < field_count; i++) {
                    const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                    fprintf(codegen->output, ".%s = ", safe_field_name);
                    gen_expr(codegen, field_values[i]);
                    if (i < field_count - 1) fputs(", ", codegen->output);
                }
                fputc('}', codegen->output);
            }
            break;
        }
        case AST_ARRAY_LITERAL: {
            ASTNode **elements = expr->data.array_literal.elements;
            int element_count = expr->data.array_literal.element_count;
            fputc('{', codegen->output);
            for (int i = 0; i < element_count; i++) {
                gen_expr(codegen, elements[i]);
                if (i < element_count - 1) fputs(", ", codegen->output);
            }
            fputc('}', codegen->output);
            break;
        }
        case AST_SIZEOF: {
            ASTNode *target = expr->data.sizeof_expr.target;
            int is_type = expr->data.sizeof_expr.is_type;
            fputs("sizeof(", codegen->output);
            if (is_type) {
                // 显式检查是否是结构体类型（即使在 c99_type_to_c 中查找失败）
                if (target->type == AST_TYPE_NAMED) {
                    const char *name = target->data.type_named.name;
                    if (name && !is_c_keyword(name)) {
                        // 检查是否是结构体（检查是否在表中，不管是否已定义）
                        const char *safe_name = get_safe_c_identifier(codegen, name);
                        if (is_struct_in_table(codegen, safe_name)) {
                            fprintf(codegen->output, "struct %s", safe_name);
                        } else {
                            // 如果不在表中，尝试从程序节点中查找结构体声明
                            if (codegen->program_node) {
                                ASTNode **decls = codegen->program_node->data.program.decls;
                                int decl_count = codegen->program_node->data.program.decl_count;
                                int found = 0;
                                for (int i = 0; i < decl_count; i++) {
                                    ASTNode *decl = decls[i];
                                    if (decl && decl->type == AST_STRUCT_DECL) {
                                        const char *struct_name = decl->data.struct_decl.name;
                                        if (struct_name) {
                                            const char *safe_struct_name = get_safe_c_identifier(codegen, struct_name);
                                            if (strcmp(safe_struct_name, safe_name) == 0) {
                                                fprintf(codegen->output, "struct %s", safe_name);
                                                found = 1;
                                                break;
                                            }
                                        }
                                    }
                                }
                                if (!found) {
                                    // 不是结构体，使用默认类型转换
                                    const char *type_c = c99_type_to_c(codegen, target);
                                    fprintf(codegen->output, "%s", type_c);
                                }
                            } else {
                                const char *type_c = c99_type_to_c(codegen, target);
                                fprintf(codegen->output, "%s", type_c);
                            }
                        }
                    } else {
                        const char *type_c = c99_type_to_c(codegen, target);
                        fprintf(codegen->output, "%s", type_c);
                    }
                } else {
                    const char *type_c = c99_type_to_c(codegen, target);
                    // 检查是否是数组指针类型（包含 [数字] *，且 * 在末尾）
                    const char *bracket = strchr(type_c, '[');
                    const char *asterisk = strrchr(type_c, '*');  // 从后往前找最后一个 *
                    if (bracket && asterisk && bracket < asterisk) {
                        // 检查 * 是否在末尾（后面只有空格或结束）
                        const char *after_asterisk = asterisk + 1;
                        while (*after_asterisk == ' ') after_asterisk++;
                        if (*after_asterisk == '\0') {
                            // 数组指针类型：T[N] * -> T(*)[N]
                            // 找到 ']' 的位置
                            const char *close_bracket = strchr(bracket, ']');
                            if (close_bracket) {
                                size_t base_len = bracket - type_c;
                                size_t array_spec_len = close_bracket - bracket + 1;
                                fprintf(codegen->output, "%.*s(*)", (int)base_len, type_c);
                                fprintf(codegen->output, "%.*s", (int)array_spec_len, bracket);
                            } else {
                                fprintf(codegen->output, "%s", type_c);
                            }
                        } else {
                            fprintf(codegen->output, "%s", type_c);
                        }
                    } else {
                        fprintf(codegen->output, "%s", type_c);
                    }
                }
            } else {
                // 即使 is_type = 0，也检查是否是结构体标识符（如 sizeof(Point) 中的 Point）
                if (target->type == AST_IDENTIFIER || target->type == AST_TYPE_NAMED) {
                    const char *name = (target->type == AST_IDENTIFIER)
                        ? target->data.identifier.name
                        : target->data.type_named.name;
                    if (name && !is_c_keyword(name)) {
                        const char *safe_name = get_safe_c_identifier(codegen, name);
                        if (is_struct_in_table(codegen, safe_name)) {
                            fprintf(codegen->output, "struct %s", safe_name);
                        } else {
                            int is_enum = is_enum_in_table(codegen, safe_name);
                            if (!is_enum && find_enum_decl_c99(codegen, safe_name)) {
                                is_enum = 1;
                            }
                            if (is_enum) {
                                fprintf(codegen->output, "enum %s", safe_name);
                            } else {
                                gen_expr(codegen, target);
                            }
                        }
                    } else {
                        gen_expr(codegen, target);
                    }
                } else {
                    gen_expr(codegen, target);
                }
            }
            fputc(')', codegen->output);
            break;
        }
        case AST_LEN: {
            ASTNode *array = expr->data.len_expr.array;
            
            // 检查数组表达式是否是标识符（局部变量或参数）
            if (array->type == AST_IDENTIFIER) {
                const char *var_name = array->data.identifier.name;
                
                // 查找变量类型以确定数组大小
                int found = 0;
                int array_size = -1;
                
                // 检查局部变量
                for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
                    if (strcmp(codegen->local_variables[i].name, var_name) == 0) {
                        const char *type_c = codegen->local_variables[i].type_c;
                        if (type_c) {
                            // 从类型字符串中提取数组大小，格式如 "int32_t[3]"
                            const char *bracket = strchr(type_c, '[');
                            if (bracket) {
                                const char *close_bracket = strchr(bracket + 1, ']');
                                if (close_bracket) {
                                    // 提取数字部分
                                    int len = close_bracket - bracket - 1;
                                    char num_buf[32];
                                    if (len < (int)sizeof(num_buf)) {
                                        memcpy(num_buf, bracket + 1, len);
                                        num_buf[len] = '\0';
                                        array_size = atoi(num_buf);
                                        if (array_size > 0) {
                                            fprintf(codegen->output, "%d", array_size);
                                            found = 1;
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        break;
                    }
                }
                
                // 如果找到数组大小，直接输出
                if (found) {
                    break;
                }
            }
            
            // 备用方案：使用 sizeof 计算（适用于非参数数组）
            // 注意：这只适用于栈分配的数组，不适用于函数参数
            fputs("sizeof(", codegen->output);
            gen_expr(codegen, array);
            fputs(") / sizeof((", codegen->output);
            gen_expr(codegen, array);
            fputs(")[0])", codegen->output);
            break;
        }
        case AST_ALIGNOF: {
            ASTNode *target = expr->data.alignof_expr.target;
            int is_type = expr->data.alignof_expr.is_type;
            
            // 获取类型字符串
            const char *type_c = NULL;
            if (is_type) {
                type_c = c99_type_to_c(codegen, target);
            } else {
                // 即使 is_type = 0，也检查是否是类型标识符（如 alignof(usize) 中的 usize）
                if (target->type == AST_IDENTIFIER) {
                    const char *name = target->data.identifier.name;
                    if (name && !is_c_keyword(name)) {
                        const char *safe_name = get_safe_c_identifier(codegen, name);
                        if (is_struct_in_table(codegen, safe_name)) {
                            // 结构体类型
                            size_t len = strlen(safe_name) + 8;  // "struct " + name + '\0'
                            char *buf = arena_alloc(codegen->arena, len);
                            if (buf) {
                                snprintf(buf, len, "struct %s", safe_name);
                                type_c = buf;
                            }
                        } else {
                            // 对于变量名，需要获取变量的类型
                            // 查找局部变量表
                            for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
                                if (strcmp(codegen->local_variables[i].name, safe_name) == 0) {
                                    type_c = codegen->local_variables[i].type_c;
                                    break;
                                }
                            }
                            
                            // 如果局部变量表中找不到，查找全局变量表
                            if (!type_c) {
                                for (int i = 0; i < codegen->global_variable_count; i++) {
                                    if (strcmp(codegen->global_variables[i].name, safe_name) == 0) {
                                        type_c = codegen->global_variables[i].type_c;
                                        break;
                                    }
                                }
                            }
                            
                            // 如果找不到，可能是类型名（如 alignof(usize)）
                            if (!type_c) {
                                type_c = safe_name;
                            }
                        }
                    }
                }
                
                // 如果仍然没有类型，生成表达式（用于复杂情况）
                if (!type_c) {
                    // 对于复杂表达式，我们需要使用 typeof，但 C99 不支持
                    // 所以这里我们尝试使用变量的类型
                    // 如果失败，将生成错误的代码，但这是 C99 的限制
                    fputs("uya_alignof(", codegen->output);
                    gen_expr(codegen, target);
                    fputc(')', codegen->output);
                    break;
                }
            }
            
            if (!type_c) {
                // 回退：生成表达式
                fputs("uya_alignof(", codegen->output);
                gen_expr(codegen, target);
                fputc(')', codegen->output);
                break;
            }
            
            // 检查类型是否是数组类型（包含 '['）
            const char *bracket = strchr(type_c, '[');
            if (bracket) {
                // 数组类型：提取元素类型（数组的对齐值等于元素类型的对齐值）
                size_t elem_len = bracket - type_c;
                char *elem_type = arena_alloc(codegen->arena, elem_len + 1);
                if (elem_type) {
                    memcpy(elem_type, type_c, elem_len);
                    elem_type[elem_len] = '\0';
                    // 移除可能的 const 限定符（如果存在）
                    if (strncmp(elem_type, "const ", 6) == 0) {
                        fputs("uya_alignof(", codegen->output);
                        fprintf(codegen->output, "%s", elem_type + 6);
                        fputc(')', codegen->output);
                    } else {
                        fputs("uya_alignof(", codegen->output);
                        fprintf(codegen->output, "%s", elem_type);
                        fputc(')', codegen->output);
                    }
                } else {
                    // 分配失败，回退到原始类型（会失败，但至少不会崩溃）
                    fputs("uya_alignof(", codegen->output);
                    fprintf(codegen->output, "%s", type_c);
                    fputc(')', codegen->output);
                }
            } else {
                // 非数组类型：直接使用
                fputs("uya_alignof(", codegen->output);
                fprintf(codegen->output, "%s", type_c);
                fputc(')', codegen->output);
            }
            break;
        }
        case AST_CAST_EXPR: {
            ASTNode *src_expr = expr->data.cast_expr.expr;
            ASTNode *target_type = expr->data.cast_expr.target_type;
            const char *type_c = c99_type_to_c(codegen, target_type);
            fputc('(', codegen->output);
            fprintf(codegen->output, "%s)", type_c);
            gen_expr(codegen, src_expr);
            break;
        }
        case AST_IDENTIFIER: {
            const char *name = expr->data.identifier.name;
            if (name && strcmp(name, "null") == 0) {
                fputs("NULL", codegen->output);
            } else {
                const char *safe_name = get_safe_c_identifier(codegen, name);
                fprintf(codegen->output, "%s", safe_name);
            }
            break;
        }
        case AST_CALL_EXPR: {
            ASTNode *callee = expr->data.call_expr.callee;
            ASTNode **args = expr->data.call_expr.args;
            int arg_count = expr->data.call_expr.arg_count;
            
            // 查找函数声明（用于检查参数类型）
            ASTNode *fn_decl = NULL;
            if (callee && callee->type == AST_IDENTIFIER) {
                const char *func_name = callee->data.identifier.name;
                fn_decl = find_function_decl_c99(codegen, func_name);
            }
            
            // 生成被调用函数名
            if (callee && callee->type == AST_IDENTIFIER) {
                const char *safe_name = get_safe_c_identifier(codegen, callee->data.identifier.name);
                fprintf(codegen->output, "%s(", safe_name);
            } else {
                fputs("unknown(", codegen->output);
            }
            
            // 生成参数
            for (int i = 0; i < arg_count; i++) {
                // 检查参数是否是字符串常量，如果是则添加类型转换以消除 const 警告
                int is_string_arg = (args[i] && args[i]->type == AST_STRING);
                if (is_string_arg) {
                    fputs("(uint8_t *)", codegen->output);
                }
                
                // 检查是否是大结构体参数且函数期望指针
                // 对于 extern 函数，如果参数类型是大结构体（>16字节），则传递地址
                int need_address = 0;
                if (fn_decl && fn_decl->type == AST_FN_DECL) {
                    ASTNode *body = fn_decl->data.fn_decl.body;
                    int is_extern = (body == NULL) ? 1 : 0;
                    
                    if (is_extern && args[i] && i < fn_decl->data.fn_decl.param_count) {
                        ASTNode *param = fn_decl->data.fn_decl.params[i];
                        if (param && param->type == AST_VAR_DECL) {
                            ASTNode *param_type = param->data.var_decl.type;
                            if (param_type && param_type->type == AST_TYPE_NAMED) {
                                int struct_size = calculate_struct_size(codegen, param_type);
                                if (struct_size > 16) {
                                    // 函数期望指针，需要传递地址
                                    need_address = 1;
                                }
                            }
                        }
                    }
                }
                
                if (need_address) {
                    fputc('&', codegen->output);
                }
                gen_expr(codegen, args[i]);
                if (i < arg_count - 1) fputs(", ", codegen->output);
            }
            fputc(')', codegen->output);
            break;
        }
        case AST_ASSIGN: {
            // 赋值表达式（右结合）：dest = src
            // 在表达式中使用时，需要生成 (dest = src) 的形式
            ASTNode *dest = expr->data.assign.dest;
            ASTNode *src = expr->data.assign.src;
            
            fputc('(', codegen->output);
            gen_expr(codegen, dest);
            fputs(" = ", codegen->output);
            gen_expr(codegen, src);
            fputc(')', codegen->output);
            break;
        }
        default:
            fputs("0", codegen->output);
            break;
    }
}
