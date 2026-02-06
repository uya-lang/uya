#include "internal.h"
#include "checker.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

/* 已知 C 变参函数对应的 va_list 版本（用于 ... 转发） */
static const char *get_vprintf_style_name(const char *c_name) {
    if (!c_name) return NULL;
    if (strcmp(c_name, "printf") == 0) return "vprintf";
    if (strcmp(c_name, "sprintf") == 0) return "vsprintf";
    if (strcmp(c_name, "fprintf") == 0) return "vfprintf";
    if (strcmp(c_name, "snprintf") == 0) return "vsnprintf";
    return NULL;
}

/* 检查是否是标准库函数（需要 const char * 而不是 uint8_t *） */
static int is_stdlib_function_for_string_arg(const char *func_name) {
    if (!func_name) return 0;
    /* I/O 函数 */
    if (strcmp(func_name, "printf") == 0 ||
        strcmp(func_name, "sprintf") == 0 ||
        strcmp(func_name, "fprintf") == 0 ||
        strcmp(func_name, "snprintf") == 0 ||
        strcmp(func_name, "fputs") == 0) {
        return 1;
    }
    /* 字符串处理函数 */
    if (strcmp(func_name, "strcmp") == 0 ||
        strcmp(func_name, "strncmp") == 0 ||
        strcmp(func_name, "strlen") == 0 ||
        strcmp(func_name, "strchr") == 0 ||
        strcmp(func_name, "strrchr") == 0 ||
        strcmp(func_name, "strstr") == 0) {
        return 1;
    }
    return 0;
}

/* 根据 C 类型字符串返回无符号类型（用于包装运算），无匹配则返回 "unsigned" */
static const char *unsigned_type_for_wrapping(const char *type_c) {
    if (!type_c) return "unsigned";
    if (strstr(type_c, "int8")) return "uint8_t";
    if (strstr(type_c, "int16")) return "uint16_t";
    if (strstr(type_c, "int32")) return "uint32_t";
    if (strstr(type_c, "int64")) return "uint64_t";
    return "unsigned";
}

/* 根据 C 类型字符串生成整数极值字面量（用于饱和运算），无匹配则用 i32 极值 */
static void gen_saturate_limit(C99CodeGenerator *codegen, const char *type_c, int is_max) {
    if (!type_c) {
        fprintf(codegen->output, "%s", is_max ? "2147483647" : "(-2147483647-1)");
        return;
    }
    if (strstr(type_c, "int8")) {
        fprintf(codegen->output, "%s", is_max ? "127" : "(-128)");
        return;
    }
    if (strstr(type_c, "int16")) {
        fprintf(codegen->output, "%s", is_max ? "32767" : "(-32768)");
        return;
    }
    if (strstr(type_c, "int32")) {
        fprintf(codegen->output, "%s", is_max ? "2147483647" : "(-2147483647-1)");
        return;
    }
    if (strstr(type_c, "int64")) {
        fprintf(codegen->output, "%s", is_max ? "9223372036854775807LL" : "(-9223372036854775807LL-1LL)");
        return;
    }
    fprintf(codegen->output, "%s", is_max ? "2147483647" : "(-2147483647-1)");
}

/* 根据整数类型与 max/min 生成 C 极值字面量（resolved_kind 为 TypeKind） */
static void gen_int_limit_literal(C99CodeGenerator *codegen, int is_max, int resolved_kind) {
    if (resolved_kind == 0) {
        fputs("0", codegen->output);
        return;
    }
    switch ((TypeKind)resolved_kind) {
        case TYPE_I8:
            fprintf(codegen->output, "%s", is_max ? "127" : "(-128)");
            break;
        case TYPE_I16:
            fprintf(codegen->output, "%s", is_max ? "32767" : "(-32768)");
            break;
        case TYPE_I32:
            fprintf(codegen->output, "%s", is_max ? "2147483647" : "(-2147483647-1)");
            break;
        case TYPE_I64:
            fprintf(codegen->output, "%s", is_max ? "9223372036854775807LL" : "(-9223372036854775807LL-1LL)");
            break;
        case TYPE_U8:
        case TYPE_BYTE:
            fprintf(codegen->output, "%s", is_max ? "255" : "0");
            break;
        case TYPE_U16:
            fprintf(codegen->output, "%s", is_max ? "65535" : "0");
            break;
        case TYPE_U32:
            fprintf(codegen->output, "%s", is_max ? "4294967295U" : "0");
            break;
        case TYPE_USIZE:
            fprintf(codegen->output, "%s", is_max ? "((size_t)-1)" : "0");
            break;
        case TYPE_U64:
            fprintf(codegen->output, "%s", is_max ? "18446744073709551615ULL" : "0");
            break;
        default:
            fputs("0", codegen->output);
            break;
    }
}

void c99_emit_string_interp_fill(C99CodeGenerator *codegen, ASTNode *expr, const char *buf_name) {
    if (!codegen || !expr || expr->type != AST_STRING_INTERP || !buf_name) return;
    int n = expr->data.string_interp.segment_count;
    if (n <= 0 || expr->data.string_interp.computed_size <= 0) return;
    
    int fill_id = codegen->interp_fill_counter++;
    c99_emit_indent(codegen);
    fprintf(codegen->output, "int _off_%d = 0;\n", fill_id);
    for (int i = 0; i < n; i++) {
        ASTStringInterpSegment *seg = &expr->data.string_interp.segments[i];
        if (seg->is_text) {
            size_t len = seg->text ? strlen(seg->text) : 0;
            const char *cn = add_string_constant(codegen, seg->text ? seg->text : "");
            if (cn) {
                c99_emit_indent(codegen);
                fprintf(codegen->output, "memcpy(%s + _off_%d, %s, %zu);\n", buf_name, fill_id, cn, len);
                c99_emit_indent(codegen);
                fprintf(codegen->output, "_off_%d += %zu;\n", fill_id, len);
            }
            continue;
        }
        {
            char fmt_buf[64];
            if (seg->format_spec && seg->format_spec[0]) {
                snprintf(fmt_buf, sizeof(fmt_buf), "%%%s", seg->format_spec);
            } else {
                strcpy(fmt_buf, "%d");
            }
            const char *fmt_const = add_string_constant(codegen, fmt_buf);
            if (!fmt_const) continue;
            c99_emit_indent(codegen);
            fprintf(codegen->output, "_off_%d += sprintf(%s + _off_%d, %s, ", fill_id, buf_name, fill_id, fmt_const);
            gen_expr(codegen, seg->expr);
            fputs(");\n", codegen->output);
        }
    }
    c99_emit_indent(codegen);
    fprintf(codegen->output, "%s[_off_%d] = '\\0';\n", buf_name, fill_id);
}

void gen_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return;
    
    switch (expr->type) {
        case AST_NUMBER:
            fprintf(codegen->output, "%d", expr->data.number.value);
            break;
        case AST_FLOAT: {
            double val = expr->data.float_literal.value;
            fprintf(codegen->output, "%.17g", val);
            break;
        }
        case AST_BOOL:
            fprintf(codegen->output, "%s", expr->data.bool_literal.value ? "true" : "false");
            break;
        case AST_INT_LIMIT:
            gen_int_limit_literal(codegen, expr->data.int_limit.is_max, expr->data.int_limit.resolved_kind);
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
        case AST_STRING_INTERP: {
            if (codegen->string_interp_buf) {
                fputs(codegen->string_interp_buf, codegen->output);
            } else {
                fputs("((char*)0)", codegen->output);
            }
            break;
        }
        case AST_BINARY_EXPR: {
            ASTNode *left = expr->data.binary_expr.left;
            ASTNode *right = expr->data.binary_expr.right;
            int op = expr->data.binary_expr.op;
            
            // 错误类型比较：err == error.X 或 error.X == err -> .error_id 比较
            if ((op == TOKEN_EQUAL || op == TOKEN_NOT_EQUAL) && left && right) {
                if (left->type == AST_IDENTIFIER && right->type == AST_ERROR_VALUE) {
                    unsigned id = right->data.error_value.name ? get_or_add_error_id(codegen, right->data.error_value.name) : 0;
                    if (id == 0) id = 1;
                    const char *safe = get_safe_c_identifier(codegen, left->data.identifier.name);
                    if (op == TOKEN_NOT_EQUAL)
                        fprintf(codegen->output, "(%s.error_id != %uU)", safe, id);
                    else
                        fprintf(codegen->output, "(%s.error_id == %uU)", safe, id);
                    break;
                }
                if (left->type == AST_ERROR_VALUE && right->type == AST_IDENTIFIER) {
                    unsigned id = left->data.error_value.name ? get_or_add_error_id(codegen, left->data.error_value.name) : 0;
                    if (id == 0) id = 1;
                    const char *safe = get_safe_c_identifier(codegen, right->data.identifier.name);
                    if (op == TOKEN_NOT_EQUAL)
                        fprintf(codegen->output, "(%uU != %s.error_id)", id, safe);
                    else
                        fprintf(codegen->output, "(%uU == %s.error_id)", id, safe);
                    break;
                }
            }
            
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
                // 按字段比较，避免 padding 未初始化导致 memcmp 结果错误
                ASTNode *struct_decl = NULL;
                if (left->type == AST_IDENTIFIER) {
                    const char *type_c = get_identifier_type_c(codegen, left->data.identifier.name);
                    struct_decl = type_c ? find_struct_decl_from_type_c(codegen, type_c) : NULL;
                } else if (left->type == AST_STRUCT_INIT) {
                    struct_decl = find_struct_decl_c99(codegen, left->data.struct_init.struct_name);
                }
                if (struct_decl && struct_decl->type == AST_STRUCT_DECL) {
                    int field_count = struct_decl->data.struct_decl.field_count;
                    ASTNode **fields = struct_decl->data.struct_decl.fields;
                    if (field_count == 0) {
                        /* 空结构体：视为相等，直接输出 1(==) 或 0(!=)，不再包括号 */
                        if (op == TOKEN_EQUAL) {
                            fputs("(1)", codegen->output);
                        } else {
                            fputs("(0)", codegen->output);
                        }
                    } else {
                    if (op == TOKEN_NOT_EQUAL) {
                        fputs("(!(", codegen->output);
                    } else {
                        fputc('(', codegen->output);
                    }
                        for (int i = 0; i < field_count; i++) {
                            ASTNode *field = fields[i];
                            if (!field || field->type != AST_VAR_DECL) continue;
                            const char *field_name = field->data.var_decl.name;
                            ASTNode *field_type = field->data.var_decl.type;
                            const char *safe_field = get_safe_c_identifier(codegen, field_name);
                            if (!safe_field) continue;
                            /* 嵌套结构体或数组字段在 C 中不能直接用 ==，用 memcmp */
                            int field_needs_memcmp = 0;
                            if (field_type) {
                                if (field_type->type == AST_TYPE_NAMED) {
                                    const char *type_name = field_type->data.type_named.name;
                                    if (type_name && find_struct_decl_c99(codegen, type_name)) {
                                        field_needs_memcmp = 1;
                                    }
                                } else if (field_type->type == AST_TYPE_ARRAY) {
                                    field_needs_memcmp = 1;
                                }
                            }
                            if (field_needs_memcmp) {
                                fputs("(memcmp(&(", codegen->output);
                                gen_expr(codegen, left);
                                fputs(").", codegen->output);
                                fputs(safe_field, codegen->output);
                                fputs(", &(", codegen->output);
                                gen_expr(codegen, right);
                                fputs(").", codegen->output);
                                fputs(safe_field, codegen->output);
                                fputs(", sizeof((", codegen->output);
                                gen_expr(codegen, left);
                                fputs(").", codegen->output);
                                fputs(safe_field, codegen->output);
                                fputs(")) == 0)", codegen->output);
                            } else {
                                fputs("((", codegen->output);
                                gen_expr(codegen, left);
                                fputs(").", codegen->output);
                                fputs(safe_field, codegen->output);
                                fputs(" == (", codegen->output);
                                gen_expr(codegen, right);
                                fputs(").", codegen->output);
                                fputs(safe_field, codegen->output);
                                fputs(")", codegen->output);
                            }
                            if (i < field_count - 1) fputs(" && ", codegen->output);
                        }
                    fputc(')', codegen->output);
                    if (op == TOKEN_NOT_EQUAL) {
                        fputc(')', codegen->output);
                    }
                    }
                } else {
                    /* 回退：无法按字段比较时用 memcmp，整体加括号 */
                    const char *struct_name = NULL;
                    fputc('(', codegen->output);
                    if (left->type == AST_IDENTIFIER) {
                        fputs("memcmp(&", codegen->output);
                        gen_expr(codegen, left);
                        fputs(", &", codegen->output);
                        gen_expr(codegen, right);
                        fputs(", sizeof(", codegen->output);
                        gen_expr(codegen, left);
                        fputs("))", codegen->output);
                    } else if (left->type == AST_STRUCT_INIT) {
                        struct_name = get_safe_c_identifier(codegen, left->data.struct_init.struct_name);
                        fputs("memcmp(&", codegen->output);
                        gen_expr(codegen, left);
                        fputs(", &", codegen->output);
                        gen_expr(codegen, right);
                        fprintf(codegen->output, ", sizeof(struct %s))", struct_name ? struct_name : "void");
                    } else {
                        fputs("memcmp(&", codegen->output);
                        gen_expr(codegen, left);
                        fputs(", &", codegen->output);
                        gen_expr(codegen, right);
                        fputs(", sizeof(", codegen->output);
                        gen_expr(codegen, left);
                        fputs("))", codegen->output);
                    }
                    if (op == TOKEN_EQUAL) {
                        fputs(" == 0)", codegen->output);
                    } else if (op == TOKEN_NOT_EQUAL) {
                        fputs(" != 0)", codegen->output);
                    } else {
                        fputc(')', codegen->output);
                    }
                }
            } else if (op == TOKEN_PLUS_PIPE || op == TOKEN_MINUS_PIPE || op == TOKEN_ASTERISK_PIPE ||
                       op == TOKEN_PLUS_PERCENT || op == TOKEN_MINUS_PERCENT || op == TOKEN_ASTERISK_PERCENT) {
                /* 饱和运算 +| -| *| 或包装运算 +% -% *%（规范 uya.md §10、§16） */
                const char *type_c = get_c_type_of_expr(codegen, left);
                if (!type_c) type_c = "int32_t";
                if (op == TOKEN_PLUS_PIPE || op == TOKEN_MINUS_PIPE || op == TOKEN_ASTERISK_PIPE) {
                    /* 饱和：GCC/Clang 语句表达式 + __builtin_*_overflow，溢出时返回 MAX/MIN；_s 须非 const 以便 &_s 可写 */
                    const char *base_type = type_c;
                    if (base_type && strncmp(base_type, "const ", 6) == 0) base_type = base_type + 6;
                    if (!base_type) base_type = "int32_t";
                    fputs("({ ", codegen->output);
                    fprintf(codegen->output, "%s _l = (", base_type);
                    gen_expr(codegen, left);
                    fputs("); ", codegen->output);
                    fprintf(codegen->output, "%s _r = (", base_type);
                    gen_expr(codegen, right);
                    fputs("); ", codegen->output);
                    fprintf(codegen->output, "%s _s; ", base_type);
                    if (op == TOKEN_PLUS_PIPE) {
                        fputs("__builtin_add_overflow(_l, _r, &_s) ? (_l>=0 && _r>=0 ? ", codegen->output);
                    } else if (op == TOKEN_MINUS_PIPE) {
                        fputs("__builtin_sub_overflow(_l, _r, &_s) ? (_l>=0 && _r<0 ? ", codegen->output);
                    } else {
                        /* 乘法饱和：用 if-else 避免嵌套三元运算符的 C 解析歧义 */
                        fprintf(codegen->output, "%s _res; ", base_type);
                        fputs("if (__builtin_mul_overflow(_l, _r, &_s)) _res = ((_l>=0 && _r>=0) || (_l<0 && _r<0)) ? ", codegen->output);
                    }
                    gen_saturate_limit(codegen, type_c, 1);
                    fputs(" : ", codegen->output);
                    gen_saturate_limit(codegen, type_c, 0);
                    if (op == TOKEN_ASTERISK_PIPE)
                        fputs("; else _res = _s; _res; })", codegen->output);
                    else
                        fputs(") : _s; })", codegen->output);
                } else {
                    /* 包装：(T)((UT)(a) op (UT)(b)) */
                    const char *ut = unsigned_type_for_wrapping(type_c);
                    fprintf(codegen->output, "((%s)((%s)(", type_c, ut);
                    gen_expr(codegen, left);
                    if (op == TOKEN_PLUS_PERCENT) fputs(") + (", codegen->output);
                    else if (op == TOKEN_MINUS_PERCENT) fputs(") - (", codegen->output);
                    else fputs(") * (", codegen->output);
                    fprintf(codegen->output, "%s)(", ut);
                    gen_expr(codegen, right);
                    fputs(")))", codegen->output);
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
                } else if (op == TOKEN_AMPERSAND) {
                    fputs(" & ", codegen->output);
                } else if (op == TOKEN_PIPE) {
                    fputs(" | ", codegen->output);
                } else if (op == TOKEN_CARET) {
                    fputs(" ^ ", codegen->output);
                } else if (op == TOKEN_LSHIFT) {
                    fputs(" << ", codegen->output);
                } else if (op == TOKEN_RSHIFT) {
                    fputs(" >> ", codegen->output);
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
            } else if (op == TOKEN_TILDE) {
                fputs("~", codegen->output);
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
            
            // 普通字段访问（结构体字段）或元组下标（.0, .1 -> .f0, .f1）
            const char *safe_field_name;
            if (field_name && field_name[0] >= '0' && field_name[0] <= '9') {
                /* 元组下标 .0, .1, ... -> C 成员名 f0, f1, ... */
                int idx = atoi(field_name);
                size_t len = 16;
                char *buf = (char *)arena_alloc(codegen->arena, len);
                if (buf) {
                    snprintf(buf, len, "f%d", idx);
                    safe_field_name = buf;
                } else {
                    safe_field_name = "f0";
                }
            } else {
                safe_field_name = get_safe_c_identifier(codegen, field_name);
            }
            
            // 检查对象是否是指针类型（需要自动解引用）
            int is_pointer = 0;
            if (object->type == AST_IDENTIFIER) {
                // 标识符：检查变量类型是否是指针
                // 注意：需要使用 get_safe_c_identifier 转换名称，因为变量表中存储的是转换后的名称
                const char *var_name = object->data.identifier.name;
                if (var_name) {
                    const char *safe_name = get_safe_c_identifier(codegen, var_name);
                    is_pointer = is_identifier_pointer_type(codegen, safe_name);
                }
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
            
            if (codegen->emitting_assign_lhs && object->type == AST_IDENTIFIER && object->data.identifier.name &&
                strcmp(object->data.identifier.name, "self") == 0 && codegen->current_method_struct_name) {
                const char *safe_struct = get_safe_c_identifier(codegen, codegen->current_method_struct_name);
                if (safe_struct) fprintf(codegen->output, "((struct %s *)self)", safe_struct);
                else gen_expr(codegen, object);
            } else {
                gen_expr(codegen, object);
            }
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
            if (array->type == AST_SLICE_EXPR) {
                fputc('(', codegen->output);
                gen_expr(codegen, array);
                fputs(").ptr[", codegen->output);
                gen_expr(codegen, index);
                fputc(']', codegen->output);
                break;
            }
            if (array->type == AST_MEMBER_ACCESS) {
                const char *type_c = get_c_type_of_expr(codegen, array);
                if (type_c && strstr(type_c, "uya_slice_")) {
                    fputc('(', codegen->output);
                    gen_expr(codegen, array);
                    fputs(").ptr[", codegen->output);
                    gen_expr(codegen, index);
                    fputc(']', codegen->output);
                    break;
                }
            }
            if (array->type == AST_IDENTIFIER) {
                const char *type_c = get_identifier_type_c(codegen, array->data.identifier.name);
                if (type_c && strstr(type_c, "uya_slice_")) {
                    // 检查标识符是否是指针类型
                    const char *safe_name = get_safe_c_identifier(codegen, array->data.identifier.name);
                    int is_pointer = is_identifier_pointer_type(codegen, safe_name);
                    if (is_pointer) {
                        // 指针类型使用 -> 操作符
                        gen_expr(codegen, array);
                        fputs("->ptr[", codegen->output);
                    } else {
                        // 非指针类型使用 . 操作符
                        fputc('(', codegen->output);
                        gen_expr(codegen, array);
                        fputs(").ptr[", codegen->output);
                    }
                    gen_expr(codegen, index);
                    fputc(']', codegen->output);
                    break;
                }
            }
            // 注意：对于指向数组的指针（如 uint8_t (*)[4096]），
            // 在 C 中可以直接使用 file_paths_buffer[i]，不需要 (*file_paths_buffer)[i]
            // 因为 file_paths_buffer[i] 会自动解引用
            gen_expr(codegen, array);
            fputc('[', codegen->output);
            gen_expr(codegen, index);
            fputc(']', codegen->output);
            break;
        }
        case AST_SLICE_EXPR: {
            ASTNode *base = expr->data.slice_expr.base;
            ASTNode *start_expr = expr->data.slice_expr.start_expr;
            ASTNode *len_expr = expr->data.slice_expr.len_expr;
            const char *slice_type_c = get_c_type_of_expr(codegen, expr);
            if (!slice_type_c) slice_type_c = "struct uya_slice_int32_t";
            fputc('(', codegen->output);
            fprintf(codegen->output, "%s){ .ptr = ", slice_type_c);
            if (base->type == AST_SLICE_EXPR) {
                fputc('(', codegen->output);
                gen_expr(codegen, base);
                fputs(").ptr + ", codegen->output);
            } else if (base->type == AST_IDENTIFIER) {
                const char *type_c = get_identifier_type_c(codegen, base->data.identifier.name);
                if (type_c && strstr(type_c, "uya_slice_")) {
                    fputc('(', codegen->output);
                    gen_expr(codegen, base);
                    fputs(").ptr + ", codegen->output);
                } else {
                    gen_expr(codegen, base);
                    fputs(" + ", codegen->output);
                }
            } else {
                gen_expr(codegen, base);
                fputs(" + ", codegen->output);
            }
            gen_expr(codegen, start_expr);
            fputs(", .len = ", codegen->output);
            gen_expr(codegen, len_expr);
            fputc('}', codegen->output);
            break;
        }
        case AST_STRUCT_INIT: {
            const char *orig_name = expr->data.struct_init.struct_name;
            const char *struct_name;
            
            // 检查是否是泛型结构体初始化
            if (expr->data.struct_init.type_arg_count > 0 && 
                expr->data.struct_init.type_args != NULL) {
                // 使用单态化结构体名称
                struct_name = get_mono_struct_name(codegen, orig_name,
                    expr->data.struct_init.type_args,
                    expr->data.struct_init.type_arg_count);
            } else {
                struct_name = get_safe_c_identifier(codegen, orig_name);
            }
            
            int field_count = expr->data.struct_init.field_count;
            const char **field_names = expr->data.struct_init.field_names;
            ASTNode **field_values = expr->data.struct_init.field_values;
            fprintf(codegen->output, "(struct %s){", struct_name);
            for (int i = 0; i < field_count; i++) {
                const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                fprintf(codegen->output, ".%s = ", safe_field_name);
                gen_expr(codegen, field_values[i]);
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
                /* [value: N] 形式：重复 value 共 N 次 */
                int n = eval_const_expr(codegen, repeat_count_expr);
                if (n <= 0) n = 1;
                for (int i = 0; i < n; i++) {
                    gen_expr(codegen, elements[0]);
                    if (i < n - 1) fputs(", ", codegen->output);
                }
            } else if (element_count > 0) {
                for (int i = 0; i < element_count; i++) {
                    gen_expr(codegen, elements[i]);
                    if (i < element_count - 1) fputs(", ", codegen->output);
                }
            } else {
                /* 空数组字面量：生成 {0} 避免 ISO C 警告 */
                fputs("0", codegen->output);
            }
            fputc('}', codegen->output);
            break;
        }
        case AST_PARAMS: {
            /* 仅在此处生成：未使用 @params 的函数不会生成任何元组/va 代码（零开销） */
            /* @params -> 当前函数参数的元组复合字面量 (struct { T0 f0; ... }){ .f0 = p0, ... } */
            ASTNode *fn = codegen->current_function_decl;
            if (!fn || fn->type != AST_FN_DECL || fn->data.fn_decl.param_count <= 0 ||
                !fn->data.fn_decl.params) {
                fputs("(struct { int32_t f0; }){ .f0 = 0 }", codegen->output);
                break;
            }
            ASTNode **params = fn->data.fn_decl.params;
            int n = fn->data.fn_decl.param_count;
            size_t total_len = 128;
            for (int i = 0; i < n; i++) {
                if (params[i] && params[i]->type == AST_VAR_DECL && params[i]->data.var_decl.type)
                    total_len += 64;
            }
            char *type_buf = (char *)arena_alloc(codegen->arena, total_len);
            if (!type_buf) {
                fputs("(struct { int32_t f0; }){ .f0 = 0 }", codegen->output);
                break;
            }
            size_t off = 0;
            off += (size_t)snprintf(type_buf + off, total_len - off, "struct { ");
            for (int i = 0; i < n; i++) {
                const char *et = "int32_t";
                if (params[i] && params[i]->type == AST_VAR_DECL && params[i]->data.var_decl.type)
                    et = c99_type_to_c(codegen, params[i]->data.var_decl.type);
                off += (size_t)snprintf(type_buf + off, total_len - off, "%s f%d; ", et, i);
            }
            snprintf(type_buf + off, total_len - off, "}");
            fprintf(codegen->output, "(%s){", type_buf);
            for (int i = 0; i < n; i++) {
                fprintf(codegen->output, ".f%d = ", i);
                if (params[i] && params[i]->type == AST_VAR_DECL && params[i]->data.var_decl.name) {
                    const char *pname = get_safe_c_identifier(codegen, params[i]->data.var_decl.name);
                    fprintf(codegen->output, "%s", pname);
                } else {
                    fputs("0", codegen->output);
                }
                if (i < n - 1) fputs(", ", codegen->output);
            }
            fputc('}', codegen->output);
            break;
        }
        case AST_TUPLE_LITERAL: {
            /* 元组字面量 (e0, e1, ...) -> (struct { T0 f0; T1 f1; }) { .f0 = e0, .f1 = e1 } */
            ASTNode **elements = expr->data.tuple_literal.elements;
            int n = expr->data.tuple_literal.element_count;
            if (n <= 0 || !elements) {
                fputs("(struct { int32_t f0; }){ .f0 = 0 }", codegen->output);
                break;
            }
            size_t total_len = 64;
            for (int i = 0; i < n; i++) {
                const char *et = get_c_type_of_expr(codegen, elements[i]);
                total_len += (et ? strlen(et) : 4) + 24;
            }
            char *type_buf = (char *)arena_alloc(codegen->arena, total_len);
            if (!type_buf) {
                fputs("(struct { int32_t f0; }){ .f0 = 0 }", codegen->output);
                break;
            }
            size_t off = 0;
            off += (size_t)snprintf(type_buf + off, total_len - off, "struct { ");
            for (int i = 0; i < n; i++) {
                const char *et = get_c_type_of_expr(codegen, elements[i]);
                if (!et) et = "int32_t";
                off += (size_t)snprintf(type_buf + off, total_len - off, "%s f%d; ", et, i);
            }
            snprintf(type_buf + off, total_len - off, "}");
            fprintf(codegen->output, "(%s){", type_buf);
            for (int i = 0; i < n; i++) {
                fprintf(codegen->output, ".f%d = ", i);
                gen_expr(codegen, elements[i]);
                if (i < n - 1) fputs(", ", codegen->output);
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
            if (array->type == AST_SLICE_EXPR) {
                fputc('(', codegen->output);
                gen_expr(codegen, array);
                fputs(").len", codegen->output);
                break;
            }
            if (array->type == AST_MEMBER_ACCESS) {
                const char *type_c = get_c_type_of_expr(codegen, array);
                if (type_c && strstr(type_c, "uya_slice_")) {
                    gen_expr(codegen, array);
                    fputs(".len", codegen->output);
                    break;
                }
            }
            if (array->type == AST_IDENTIFIER) {
                const char *var_name = array->data.identifier.name;
                const char *type_c = get_identifier_type_c(codegen, var_name);
                if (type_c && strstr(type_c, "uya_slice_")) {
                    gen_expr(codegen, array);
                    fputs(".len", codegen->output);
                    break;
                }
            }
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
                type_c = "void";
            }
            
            /* void 类型不能用于 uya_alignof 宏（struct { char c; void t; } 非法），直接输出 1 */
            if (strcmp(type_c, "void") == 0) {
                fputs("1", codegen->output);
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
        case AST_FILE: {
            // @file：输出当前源文件名的字符串字面量
            const char *filename = expr->filename ? expr->filename : "<unknown>";
            // 转义文件名中的反斜杠和引号
            fputc('"', codegen->output);
            for (const char *p = filename; *p; p++) {
                if (*p == '\\') {
                    fputs("\\\\", codegen->output);
                } else if (*p == '"') {
                    fputs("\\\"", codegen->output);
                } else {
                    fputc(*p, codegen->output);
                }
            }
            fputc('"', codegen->output);
            break;
        }
        case AST_LINE: {
            // @line：输出当前行号
            fprintf(codegen->output, "%d", expr->line);
            break;
        }
        case AST_CAST_EXPR: {
            ASTNode *src_expr = expr->data.cast_expr.expr;
            ASTNode *target_type = expr->data.cast_expr.target_type;
            int is_force_cast = expr->data.cast_expr.is_force_cast;
            const char *type_c = c99_type_to_c(codegen, target_type);
            if (is_force_cast) {
                /* as! 强转：返回 !T，包装为 { .error_id = 0, .value = (T)(expr) } */
                ASTNode tmp = {0};
                tmp.type = AST_TYPE_ERROR_UNION;
                tmp.data.type_error_union.payload_type = target_type;
                const char *union_c = c99_type_to_c(codegen, &tmp);
                int is_void = (target_type->type == AST_TYPE_NAMED && target_type->data.type_named.name &&
                    strcmp(target_type->data.type_named.name, "void") == 0);
                fprintf(codegen->output, "({ %s _uya_asbang = { .error_id = 0", union_c);
                if (!is_void) {
                    fprintf(codegen->output, ", .value = (%s)(", type_c);
                    gen_expr(codegen, src_expr);
                    fputs(") }; _uya_asbang; })", codegen->output);
                } else {
                    fputs(" }; ", codegen->output);
                    gen_expr(codegen, src_expr);
                    fputs("; _uya_asbang; })", codegen->output);
                }
                break;
            }
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
                const char *type_c = get_identifier_type_c(codegen, name);
                // 如果是原子类型，生成原子 load
                if (type_c && strstr(type_c, "_Atomic") != NULL) {
                    fprintf(codegen->output, "__atomic_load_n(&%s, __ATOMIC_SEQ_CST)", safe_name);
                } else {
                    fprintf(codegen->output, "%s", safe_name);
                }
            }
            break;
        }
        case AST_ERROR_VALUE: {
            unsigned id = expr->data.error_value.name ? get_or_add_error_id(codegen, expr->data.error_value.name) : 0;
            if (id == 0) id = 1;
            fprintf(codegen->output, "%uU", id);
            break;
        }
        case AST_TRY_EXPR: {
            ASTNode *operand = expr->data.try_expr.operand;
            ASTNode *ret_type = codegen->current_function_return_type;
            if (!operand) {
                fputs("0", codegen->output);
                break;
            }
            /* 操作数类型（如 !f32），可能与函数返回类型（如 !i32）不同 */
            const char *operand_union_c = get_c_type_of_expr(codegen, operand);
            int operand_is_err_union = (operand_union_c && strstr(operand_union_c, "err_union_") != NULL);
            if (!operand_is_err_union || !ret_type || ret_type->type != AST_TYPE_ERROR_UNION) {
                /* 回退：操作数非 !T 或不在 !T 函数内 */
                if (ret_type && ret_type->type == AST_TYPE_ERROR_UNION) {
                    const char *union_c = c99_type_to_c(codegen, ret_type);
                    fprintf(codegen->output, "({ %s _uya_try_tmp = ", union_c);
                    gen_expr(codegen, operand);
                    fprintf(codegen->output, "; if (_uya_try_tmp.error_id != 0) return _uya_try_tmp; _uya_try_tmp.value; })");
                } else {
                    fputs("0", codegen->output);
                }
                break;
            }
            const char *ret_union_c = c99_type_to_c(codegen, ret_type);
            fprintf(codegen->output, "({ %s _uya_try_tmp = ", operand_union_c);
            gen_expr(codegen, operand);
            /* 错误传播时需转换为函数返回类型 */
            fprintf(codegen->output, "; if (_uya_try_tmp.error_id != 0) return (%s){ .error_id = _uya_try_tmp.error_id, .value = 0 }; _uya_try_tmp.value; })", ret_union_c);
            break;
        }
        case AST_AWAIT_EXPR: {
            // @await 表达式 - 暂时直接生成操作数的代码
            // 完整实现需要 CPS 变换和状态机生成
            // 当前阶段：仅生成操作数表达式（同步调用）
            ASTNode *operand = expr->data.await_expr.operand;
            if (operand) {
                gen_expr(codegen, operand);
            } else {
                fputs("0", codegen->output);
            }
            break;
        }
        case AST_CATCH_EXPR: {
            ASTNode *operand = expr->data.catch_expr.operand;
            ASTNode *block = expr->data.catch_expr.catch_block;
            const char *err_name = expr->data.catch_expr.err_name;
            ASTNode *ret_type = codegen->current_function_return_type;
            if (!operand || !block) {
                fputs("0", codegen->output);
                break;
            }
            /* 操作数类型（如 !f32）可能与函数返回类型（如 !i32）不同 */
            const char *operand_union_c = get_c_type_of_expr(codegen, operand);
            int operand_is_err_union = (operand_union_c && strstr(operand_union_c, "err_union_") != NULL);
            const char *union_c;
            const char *payload_c;
            if (operand_is_err_union) {
                /* 使用操作数的 !T 类型及 payload 类型 */
                union_c = operand_union_c;
                /* 从操作数推断 payload：as! T 的 payload 为 T */
                if (operand->type == AST_CAST_EXPR && operand->data.cast_expr.is_force_cast &&
                    operand->data.cast_expr.target_type) {
                    payload_c = c99_type_to_c(codegen, operand->data.cast_expr.target_type);
                } else if (ret_type && ret_type->type == AST_TYPE_ERROR_UNION &&
                    ret_type->data.type_error_union.payload_type) {
                    payload_c = c99_type_to_c(codegen, ret_type->data.type_error_union.payload_type);
                } else {
                    /* 从错误联合类型名称推断 payload 类型 */
                    if (operand_union_c && strcmp(operand_union_c, "struct err_union_void") == 0) {
                        payload_c = "void";
                    } else {
                        payload_c = "int32_t";
                    }
                }
            } else if (ret_type && ret_type->type == AST_TYPE_ERROR_UNION) {
                union_c = c99_type_to_c(codegen, ret_type);
                ASTNode *payload_node = ret_type->data.type_error_union.payload_type;
                payload_c = payload_node ? c99_type_to_c(codegen, payload_node) : "void";
            } else {
                fputs("0", codegen->output);
                break;
            }
            int n = block->data.block.stmt_count;
            ASTNode *last_stmt = (n > 0) ? block->data.block.stmts[n - 1] : NULL;
            int is_void_payload = (payload_c && strcmp(payload_c, "void") == 0);
            if (is_void_payload) {
                // !void 类型：不需要声明结果变量
                fprintf(codegen->output, "({ %s _uya_catch_tmp = ", union_c);
            } else {
                fprintf(codegen->output, "({ %s _uya_catch_result; %s _uya_catch_tmp = ", payload_c, union_c);
            }
            gen_expr(codegen, operand);
            fputs("; if (_uya_catch_tmp.error_id != 0) {\n", codegen->output);
            codegen->indent_level++;
            if (err_name) {
                const char *safe = get_safe_c_identifier(codegen, err_name);
                c99_emit_indent(codegen);
                fprintf(codegen->output, "%s %s = _uya_catch_tmp;\n", union_c, safe);
            }
            for (int i = 0; i < n; i++) {
                ASTNode *s = block->data.block.stmts[i];
                if (!s) continue;
                if (i == n - 1 && last_stmt && last_stmt->type != AST_RETURN_STMT && !is_void_payload) {
                    c99_emit_indent(codegen);
                    fputs("_uya_catch_result = (", codegen->output);
                    gen_expr(codegen, last_stmt);
                    fputs(");\n", codegen->output);
                } else {
                    gen_stmt(codegen, s);
                }
            }
            codegen->indent_level--;
            c99_emit_indent(codegen);
            if (is_void_payload) {
                fputs("} else { /* void payload */ } 0; })", codegen->output);
            } else {
                fputs("} else _uya_catch_result = _uya_catch_tmp.value; _uya_catch_result; })", codegen->output);
            }
            break;
        }
        case AST_CALL_EXPR: {
            ASTNode *callee = expr->data.call_expr.callee;
            ASTNode **args = expr->data.call_expr.args;
            int arg_count = expr->data.call_expr.arg_count;
            int has_ellipsis = expr->data.call_expr.has_ellipsis_forward;
            const char *callee_name = (callee && callee->type == AST_IDENTIFIER) ? callee->data.identifier.name : NULL;

            /* 插值仅作 printf/fprintf 格式参数时：脱糖为单次 printf(fmt, ...)，无中间缓冲 */
            if (callee_name && args && !has_ellipsis) {
                if (strcmp(callee_name, "printf") == 0 && arg_count == 1 && args[0] && args[0]->type == AST_STRING_INTERP) {
                    ASTNode *interp = args[0];
                    const char *safe = get_safe_c_identifier(codegen, "printf");
                    fprintf(codegen->output, "%s(", safe);
                    emit_printf_fmt_inline(codegen, interp);
                    int n = interp->data.string_interp.segment_count;
                    for (int i = 0; i < n; i++) {
                        ASTStringInterpSegment *seg = &interp->data.string_interp.segments[i];
                        if (!seg->is_text && seg->expr) {
                            fputs(", ", codegen->output);
                            gen_expr(codegen, seg->expr);
                        }
                    }
                    fputc(')', codegen->output);
                    break;
                } else if (strcmp(callee_name, "fprintf") == 0 && arg_count == 2 && args[1] && args[1]->type == AST_STRING_INTERP) {
                    ASTNode *interp = args[1];
                    const char *safe = get_safe_c_identifier(codegen, "fprintf");
                    fprintf(codegen->output, "%s(", safe);
                    gen_expr(codegen, args[0]);
                    fputs(", ", codegen->output);
                    emit_printf_fmt_inline(codegen, interp);
                    int n = interp->data.string_interp.segment_count;
                    for (int i = 0; i < n; i++) {
                        ASTStringInterpSegment *seg = &interp->data.string_interp.segments[i];
                        if (!seg->is_text && seg->expr) {
                            fputs(", ", codegen->output);
                            gen_expr(codegen, seg->expr);
                        }
                    }
                    fputc(')', codegen->output);
                    break;
                }
            }

            /* 实参中的字符串插值：先为每个 AST_STRING_INTERP 生成临时缓冲区 */
            for (int i = 0; i < arg_count && i < C99_MAX_CALL_ARGS; i++) {
                codegen->interp_arg_temp_names[i] = NULL;
            }
            for (int i = 0; i < arg_count && i < C99_MAX_CALL_ARGS; i++) {
                if (!args[i] || args[i]->type != AST_STRING_INTERP) continue;
                int size = args[i]->data.string_interp.computed_size;
                if (size <= 0) continue;
                char name_buf[64];
                snprintf(name_buf, sizeof(name_buf), "__uya_interp_%d", codegen->interp_temp_counter++);
                const char *temp_name = arena_strdup(codegen->arena, name_buf);
                if (!temp_name) continue;
                codegen->interp_arg_temp_names[i] = temp_name;
                c99_emit_indent(codegen);
                fprintf(codegen->output, "char %s[%d];\n", temp_name, size);
                c99_emit_string_interp_fill(codegen, args[i], temp_name);
            }
            
            /* 联合体变体构造：UnionName.variant(expr) -> 普通 union: (struct uya_tagged_U){ ._tag, .u = (union U){ .v } }；extern union: (union U){ .v = expr } */
            if (callee && callee->type == AST_MEMBER_ACCESS) {
                ASTNode *obj = callee->data.member_access.object;
                const char *method_name = callee->data.member_access.field_name;
                if (obj && obj->type == AST_IDENTIFIER && obj->data.identifier.name && arg_count == 1 && args && args[0]) {
                    ASTNode *union_decl = find_union_decl_c99(codegen, obj->data.identifier.name);
                    if (union_decl) {
                        int idx = find_union_variant_index(union_decl, method_name);
                        if (idx >= 0) {
                            const char *uname = get_safe_c_identifier(codegen, union_decl->data.union_decl.name);
                            const char *vname = get_safe_c_identifier(codegen, method_name);
                            if (uname && vname) {
                                if (union_decl->data.union_decl.is_extern) {
                                    fprintf(codegen->output, "((union %s){ .%s = (", uname, vname);
                                    gen_expr(codegen, args[0]);
                                    fputs(") })", codegen->output);
                                } else {
                                    fprintf(codegen->output, "((struct uya_tagged_%s){ ._tag = %d, .u = (union %s){ .%s = (", uname, idx, uname, vname);
                                    gen_expr(codegen, args[0]);
                                    fputs(") } })", codegen->output);
                                }
                                break;
                            }
                        }
                    }
                }
                const char *obj_type_c = get_c_type_of_expr(codegen, obj);
                if (obj_type_c && strstr(obj_type_c, "uya_interface_") != NULL) {
                    const char *p = strstr(obj_type_c, "uya_interface_");
                    if (p) {
                        p += 14;  /* skip "uya_interface_" to get interface name */
                        const char *safe_method = get_safe_c_identifier(codegen, method_name);
                        fprintf(codegen->output, "((struct uya_vtable_%s *)(", p);
                        gen_expr(codegen, obj);
                        fprintf(codegen->output, ").vtable)->%s((", safe_method);
                        gen_expr(codegen, obj);
                        fputs(").data", codegen->output);
                        for (int i = 0; i < arg_count; i++) {
                            fputs(", ", codegen->output);
                            if (codegen->interp_arg_temp_names[i]) {
                                fputs("(uint8_t *)", codegen->output);
                                fputs(codegen->interp_arg_temp_names[i], codegen->output);
                            } else {
                                if (args[i] && args[i]->type == AST_STRING) {
                                    // 检查是否是标准库函数，如果是则使用 (const char *) 而不是 (uint8_t *)
                                    int is_stdlib = is_stdlib_function_for_string_arg(callee_name);
                                    fputs(is_stdlib ? "(const char *)" : "(uint8_t *)", codegen->output);
                                }
                                gen_expr(codegen, args[i]);
                            }
                        }
                        fputc(')', codegen->output);
                        break;
                    }
                }
                /* 联合体/结构体方法调用：obj.method(args) -> uya_UnionName_method(&obj, args...) 或 uya_StructName_method(&obj, args...) */
                if (obj_type_c && strstr(obj_type_c, "uya_interface_") == NULL) {
                    const char *base = obj_type_c;
                    if (strncmp(base, "const ", 6) == 0) base += 6;
                    if (strncmp(base, "struct ", 7) != 0) base = NULL;
                    if (base) {
                    const char *start = base + 7;
                    const char *end = strchr(start, ' ');
                    if (!end) end = start + strlen(start);
                    const char *asterisk = strchr(start, '*');
                    if (asterisk && asterisk < end) end = asterisk;
                    while (end > start && (end[-1] == ' ' || end[-1] == '\t')) end--;
                    if (end > start) {
                        char type_name_buf[128];
                        size_t slen = (size_t)(end - start);
                        if (slen < sizeof(type_name_buf)) {
                            memcpy(type_name_buf, start, slen);
                            type_name_buf[slen] = '\0';
                            /* 联合体类型为 struct uya_tagged_UnionName，先尝试联合体方法 */
                            ASTNode *union_decl = find_union_decl_by_tagged_c99(codegen, type_name_buf);
                            if (union_decl) {
                                ASTNode *method_fn = find_method_in_union_c99(codegen, union_decl->data.union_decl.name, method_name);
                                if (method_fn) {
                                    const char *cname = get_method_c_name(codegen, union_decl->data.union_decl.name, method_name);
                                    if (cname) {
                                        int is_ptr = (strchr(obj_type_c, '*') != NULL);
                                        fprintf(codegen->output, "%s(%s(", cname, is_ptr ? "" : "&");
                                        gen_expr(codegen, obj);
                                        fputs(")", codegen->output);
                                        for (int i = 0; i < arg_count; i++) {
                                            fputs(", ", codegen->output);
                                            if (codegen->interp_arg_temp_names[i]) {
                                                fputs("(uint8_t *)", codegen->output);
                                                fputs(codegen->interp_arg_temp_names[i], codegen->output);
                                            } else {
                                                if (args[i] && args[i]->type == AST_STRING) fputs("(uint8_t *)", codegen->output);
                                                gen_expr(codegen, args[i]);
                                            }
                                        }
                                        fputc(')', codegen->output);
                                        break;
                                    }
                                }
                            } else {
                                /* 结构体方法 */
                                ASTNode *method_fn = find_method_in_struct_c99(codegen, type_name_buf, method_name);
                                if (method_fn) {
                                    const char *cname = get_method_c_name(codegen, type_name_buf, method_name);
                                    if (cname) {
                                        int is_ptr = (strchr(obj_type_c, '*') != NULL);
                                        fprintf(codegen->output, "%s(%s(", cname, is_ptr ? "" : "&");
                                        gen_expr(codegen, obj);
                                        fputs(")", codegen->output);
                                        for (int i = 0; i < arg_count; i++) {
                                            fputs(", ", codegen->output);
                                            if (codegen->interp_arg_temp_names[i]) {
                                                fputs("(uint8_t *)", codegen->output);
                                                fputs(codegen->interp_arg_temp_names[i], codegen->output);
                                            } else {
                                                if (args[i] && args[i]->type == AST_STRING) fputs("(uint8_t *)", codegen->output);
                                                gen_expr(codegen, args[i]);
                                            }
                                        }
                                        fputc(')', codegen->output);
                                        break;
                                    }
                                }
                            }
                        }
                    }
                    }
                }
            }
            
            // 查找函数声明（用于检查参数类型）
            ASTNode *fn_decl = NULL;
            if (callee && callee->type == AST_IDENTIFIER) {
                callee_name = callee->data.identifier.name;
                fn_decl = find_function_decl_c99(codegen, callee_name);
            }
            
            /* 仅在此处生成：无 ... 转发的调用不生成 va_list（零开销转发） */
            if (has_ellipsis && codegen->current_function_decl &&
                codegen->current_function_decl->type == AST_FN_DECL &&
                codegen->current_function_decl->data.fn_decl.is_varargs &&
                codegen->current_function_decl->data.fn_decl.param_count > 0 &&
                callee_name) {
                const char *vname = get_vprintf_style_name(callee_name);
                const char *last_param = codegen->current_function_decl->data.fn_decl.params[
                    codegen->current_function_decl->data.fn_decl.param_count - 1]->data.var_decl.name;
                if (vname && last_param) {
                    const char *last_safe = get_safe_c_identifier(codegen, last_param);
                    /* GCC statement expression: ({ ...; expr }) 的值是最后的 expr */
                    fprintf(codegen->output, "((void)0, ({\n");
                    codegen->indent_level++;
                    c99_emit(codegen, "va_list uya_va;\n");
                    c99_emit(codegen, "va_start(uya_va, %s);\n", last_safe);
                    fprintf(codegen->output, "%*sint32_t _uya_ret = %s(", codegen->indent_level * 4, "", vname);
                    for (int i = 0; i < arg_count; i++) {
                        if (i > 0) fputs(", ", codegen->output);
                        if (args[i] && args[i]->type == AST_STRING) {
                            // 检查是否是标准库函数，如果是则使用 (const char *) 而不是 (uint8_t *)
                            int is_stdlib = is_stdlib_function_for_string_arg(callee_name);
                            fputs(is_stdlib ? "(const char *)" : "(uint8_t *)", codegen->output);
                        }
                        gen_expr(codegen, args[i]);
                    }
                    fputs(", uya_va);\n", codegen->output);
                    c99_emit(codegen, "va_end(uya_va);\n");
                    c99_emit(codegen, "_uya_ret;\n");  /* 语句表达式的值 */
                    codegen->indent_level--;
                    c99_emit(codegen, "}))");
                    break;
                }
            }
            
            // 生成被调用函数名
            int printf_one_fmt = (callee_name && strcmp(callee_name, "printf") == 0 && arg_count == 1);
            if (callee && callee->type == AST_IDENTIFIER) {
                const char *func_name = callee->data.identifier.name;
                const char *output_name = func_name;
                
                // 检查是否是泛型函数调用（有类型实参）
                ASTNode **call_type_args = expr->data.call_expr.type_args;
                int call_type_arg_count = expr->data.call_expr.type_arg_count;
                if (call_type_args && call_type_arg_count > 0) {
                    // 泛型函数调用：生成单态化函数名
                    output_name = get_mono_function_name(codegen, func_name, call_type_args, call_type_arg_count);
                }
                
                const char *safe_name = get_safe_c_identifier(codegen, output_name);
                fprintf(codegen->output, "%s(", safe_name);
                if (printf_one_fmt) {
                    fputs("\"%s\", ", codegen->output);  /* 单参数 printf 用字面量格式避免 -Wformat-security */
                }
            } else {
                fputs("unknown(", codegen->output);
            }
            
            // 生成参数
            for (int i = 0; i < arg_count; i++) {
                if (i > 0) fputs(", ", codegen->output);
                if (codegen->interp_arg_temp_names[i]) {
                    // 检查是否是标准库函数，如果是则使用 (const char *) 而不是 (uint8_t *)
                    int is_stdlib = is_stdlib_function_for_string_arg(callee_name);
                    fputs(is_stdlib ? "(const char *)" : "(uint8_t *)", codegen->output);
                    fputs(codegen->interp_arg_temp_names[i], codegen->output);
                    continue;
                }
                // 检查参数是否是字符串常量或 *byte 类型，如果是则添加类型转换以消除 const 警告
                int is_string_arg = (args[i] && args[i]->type == AST_STRING);
                // 检查参数是否是 *byte 类型的标识符或字符串常量
                int is_byte_ptr_arg = 0;
                if (args[i] && args[i]->type == AST_IDENTIFIER) {
                    const char *arg_name = args[i]->data.identifier.name;
                    const char *arg_type_c = get_identifier_type_c(codegen, arg_name);
                    if (arg_type_c && strcmp(arg_type_c, "uint8_t *") == 0) {
                        is_byte_ptr_arg = 1;
                    } else if (!arg_type_c) {
                        // 检查是否是字符串常量（字符串常量名称通常以 "str" 开头）
                        if (arg_name && strncmp(arg_name, "str", 3) == 0) {
                            // 检查是否是字符串常量表中的名称
                            for (int j = 0; j < codegen->string_constant_count; j++) {
                                if (codegen->string_constants[j].name &&
                                    strcmp(codegen->string_constants[j].name, arg_name) == 0) {
                                    is_byte_ptr_arg = 1;
                                    break;
                                }
                            }
                        }
                    }
                }
                if (is_string_arg || is_byte_ptr_arg) {
                    // 检查是否是标准库函数，如果是则使用 (const char *) 而不是 (uint8_t *)
                    int is_stdlib = is_stdlib_function_for_string_arg(callee_name);
                    fputs(is_stdlib ? "(const char *)" : "(uint8_t *)", codegen->output);
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
                /* 装箱：当形参是接口类型且实参是实现了该接口的结构体时，生成 vtable+data */
                if (fn_decl && fn_decl->type == AST_FN_DECL && i < fn_decl->data.fn_decl.param_count) {
                    ASTNode *param = fn_decl->data.fn_decl.params[i];
                    if (param && param->type == AST_VAR_DECL && param->data.var_decl.type &&
                        param->data.var_decl.type->type == AST_TYPE_NAMED) {
                        const char *param_type_name = param->data.var_decl.type->data.type_named.name;
                        ASTNode *iface = find_interface_decl_c99(codegen, param_type_name);
                        if (iface && args[i]) {
                            const char *struct_name_for_check = NULL;
                            if (args[i]->type == AST_IDENTIFIER) {
                                const char *arg_type_c = get_identifier_type_c(codegen, args[i]->data.identifier.name);
                                if (arg_type_c) {
                                    /* 去掉可选的 "const " 前缀 */
                                    if (strncmp(arg_type_c, "const ", 6) == 0) arg_type_c += 6;
                                }
                                if (arg_type_c && strncmp(arg_type_c, "struct ", 7) == 0 &&
                                    !strstr(arg_type_c, "uya_interface_")) {
                                    const char *p = arg_type_c + 7;
                                    const char *end = strchr(p, ' ');
                                    if (!end) end = p + strlen(p);
                                    size_t slen = (size_t)(end - p);
                                    if (slen < 64) {
                                        char snbuf[64];
                                        memcpy(snbuf, p, slen);
                                        snbuf[slen] = '\0';
                                        if (struct_implements_interface_c99(codegen, snbuf, param_type_name)) {
                                            struct_name_for_check = snbuf;
                                        }
                                    }
                                }
                            } else if (args[i]->type == AST_STRUCT_INIT) {
                                const char *st_name = args[i]->data.struct_init.struct_name;
                                if (st_name && struct_implements_interface_c99(codegen, st_name, param_type_name)) {
                                    struct_name_for_check = st_name;
                                }
                            }
                            if (struct_name_for_check) {
                                    const char *safe_iface = get_safe_c_identifier(codegen, param_type_name);
                                    const char *safe_struct = get_safe_c_identifier(codegen, struct_name_for_check);
                                    fprintf(codegen->output, "(struct uya_interface_%s){ .vtable = (void*)&uya_vtable_%s_%s, .data = (void*)&(",
                                            safe_iface, safe_iface, safe_struct);
                                    gen_expr(codegen, args[i]);
                                    fputs(") }", codegen->output);
                                    continue;
                            }
                        }
                    }
                }
                gen_expr(codegen, args[i]);
            }
            fputc(')', codegen->output);
            break;
        }
        case AST_ASSIGN: {
            // 赋值表达式（右结合）：dest = src；dest 为 _ 时仅求值右侧
            ASTNode *dest = expr->data.assign.dest;
            ASTNode *src = expr->data.assign.src;
            
            fputc('(', codegen->output);
            if (dest->type == AST_UNDERSCORE) {
                gen_expr(codegen, src);
            } else {
                gen_expr(codegen, dest);
                fputs(" = ", codegen->output);
                gen_expr(codegen, src);
            }
            fputc(')', codegen->output);
            break;
        }
        case AST_MATCH_EXPR: {
            /* match expr { pat => result, ... } 作为表达式：GCC 语句表达式 */
            ASTNode *match_expr = expr->data.match_expr.expr;
            const char *m_type = get_c_type_of_expr(codegen, match_expr);
            if (!m_type) m_type = "int32_t";
            const char *res_type = "int32_t";
            if (expr->data.match_expr.arm_count > 0) {
                const char *t = get_c_type_of_expr(codegen, expr->data.match_expr.arms[0].result_expr);
                if (t) res_type = t;
            }
            fputs("({ ", codegen->output);
            fprintf(codegen->output, "%s _uya_m = ", m_type);
            gen_expr(codegen, match_expr);
            fputs("; ", codegen->output);
            fprintf(codegen->output, "%s _uya_r; ", res_type);
            int first = 1;
            for (int i = 0; i < expr->data.match_expr.arm_count; i++) {
                ASTMatchArm *arm = &expr->data.match_expr.arms[i];
                const char *prefix = first ? "" : "else ";
                first = 0;
                if (arm->kind == MATCH_PAT_LITERAL && arm->data.literal.expr) {
                    if (arm->data.literal.expr->type == AST_NUMBER) {
                        fprintf(codegen->output, "%sif (_uya_m == %d) _uya_r = ", prefix, arm->data.literal.expr->data.number.value);
                    } else if (arm->data.literal.expr->type == AST_BOOL) {
                        fprintf(codegen->output, "%sif (_uya_m == %s) _uya_r = ", prefix, arm->data.literal.expr->data.bool_literal.value ? "1" : "0");
                    }
                    gen_expr(codegen, arm->result_expr);
                    fputs("; ", codegen->output);
                } else if (arm->kind == MATCH_PAT_ENUM) {
                    ASTNode *enum_decl = find_enum_decl_c99(codegen, arm->data.enum_pat.enum_name);
                    int ev = enum_decl ? find_enum_variant_value(codegen, enum_decl, arm->data.enum_pat.variant_name) : -1;
                    if (ev >= 0) {
                        fprintf(codegen->output, "%sif (_uya_m == %d) _uya_r = ", prefix, ev);
                    } else {
                        fprintf(codegen->output, "%sif (0) _uya_r = ", prefix);  /* 占位 */
                    }
                    gen_expr(codegen, arm->result_expr);
                    fputs("; ", codegen->output);
                } else if (arm->kind == MATCH_PAT_BIND) {
                    const char *v = get_safe_c_identifier(codegen, arm->data.bind.var_name);
                    if (v) fprintf(codegen->output, "%s{ %s %s = _uya_m; _uya_r = ", prefix, m_type, v);
                    gen_expr(codegen, arm->result_expr);
                    if (v) fputs("; } ", codegen->output);
                    else fputs("; ", codegen->output);
                } else if (arm->kind == MATCH_PAT_WILDCARD || arm->kind == MATCH_PAT_ELSE) {
                    fprintf(codegen->output, "%s{ _uya_r = ", prefix);
                    gen_expr(codegen, arm->result_expr);
                    fputs("; } ", codegen->output);
                } else if (arm->kind == MATCH_PAT_ERROR) {
                    unsigned id = arm->data.error_pat.error_name ? get_or_add_error_id(codegen, arm->data.error_pat.error_name) : 0;
                    if (id == 0) id = 1;
                    fprintf(codegen->output, "%sif (_uya_m.error_id == %uU) _uya_r = ", prefix, id);
                    gen_expr(codegen, arm->result_expr);
                    fputs("; ", codegen->output);
                } else if (arm->kind == MATCH_PAT_UNION && arm->data.union_pat.variant_name) {
                    ASTNode *union_decl = find_union_decl_by_variant_c99(codegen, arm->data.union_pat.variant_name);
                    if (union_decl) {
                        int idx = find_union_variant_index(union_decl, arm->data.union_pat.variant_name);
                        const char *uname = get_safe_c_identifier(codegen, union_decl->data.union_decl.name);
                        const char *vname = get_safe_c_identifier(codegen, arm->data.union_pat.variant_name);
                        if (idx >= 0 && uname && vname) {
                            ASTNode *vnode = union_decl->data.union_decl.variants[idx];
                            const char *vtype = (vnode && vnode->type == AST_VAR_DECL && vnode->data.var_decl.type) ? c99_type_to_c(codegen, vnode->data.var_decl.type) : "int";
                            const char *bind = (arm->data.union_pat.var_name && strcmp(arm->data.union_pat.var_name, "_") != 0) ? get_safe_c_identifier(codegen, arm->data.union_pat.var_name) : NULL;
                            if (bind) {
                                fprintf(codegen->output, "%sif (_uya_m._tag == %d) { %s %s = _uya_m.u.%s; _uya_r = ", prefix, idx, vtype, bind, vname);
                            } else {
                                fprintf(codegen->output, "%sif (_uya_m._tag == %d) _uya_r = ", prefix, idx);
                            }
                            gen_expr(codegen, arm->result_expr);
                            fputs(bind ? "; } " : "; ", codegen->output);
                        }
                    }
                }
            }
            fputs("_uya_r; })", codegen->output);
            break;
        }
        case AST_BLOCK: {
            // 块表达式：使用 GCC 语句表达式扩展 ({ stmts; last_expr; })
            // 最后一条语句如果是表达式，作为整个块的值
            ASTNode **block_stmts = expr->data.block.stmts;
            int block_count = expr->data.block.stmt_count;
            
            fputs("({ ", codegen->output);
            
            // 找到最后一个非声明的表达式作为返回值
            int last_expr_idx = -1;
            for (int i = block_count - 1; i >= 0; i--) {
                ASTNode *bs = block_stmts[i];
                if (bs == NULL) continue;
                if (bs->type == AST_VAR_DECL) continue;
                if (bs->type == AST_IF_STMT || bs->type == AST_WHILE_STMT ||
                    bs->type == AST_FOR_STMT || bs->type == AST_RETURN_STMT ||
                    bs->type == AST_BREAK_STMT || bs->type == AST_CONTINUE_STMT ||
                    bs->type == AST_BLOCK || bs->type == AST_ASSIGN ||
                    bs->type == AST_DEFER_STMT || bs->type == AST_ERRDEFER_STMT) continue;
                last_expr_idx = i;
                break;
            }
            
            // 输出所有语句（除了最后一个表达式，它会作为返回值）
            for (int i = 0; i < block_count; i++) {
                ASTNode *bs = block_stmts[i];
                if (bs == NULL) continue;
                if (i == last_expr_idx) {
                    // 最后一个表达式：直接输出，不加分号
                    gen_expr(codegen, bs);
                    fputs("; ", codegen->output);
                } else {
                    // 其他语句：正常输出
                    gen_stmt(codegen, bs);
                }
            }
            
            fputs("})", codegen->output);
            break;
        }
        default:
            fputs("0", codegen->output);
            break;
    }
}
