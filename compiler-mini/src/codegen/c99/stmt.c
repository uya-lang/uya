#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

/* 在 return/break/continue 前对当前块已声明的变量逆序调用 drop（规范 §12）。 */
static void emit_current_block_drops(C99CodeGenerator *codegen) {
    if (!codegen || codegen->current_drop_scope < 0) return;
    int d = codegen->current_drop_scope;
    int n = codegen->drop_var_count[d];
    for (int i = n - 1; i >= 0; i--) {
        const char *drop_c = get_method_c_name(codegen, codegen->drop_struct_name[d][i], "drop");
        const char *var_safe = codegen->drop_var_safe[d][i];
        if (!drop_c || !var_safe) continue;
        c99_emit(codegen, "/* drop */ ");
        fprintf(codegen->output, "%s(%s);\n", drop_c, var_safe);
    }
}

/* 在块内变量声明逆序上调用 drop（规范 §12：离开作用域时先 defer 再 drop）。
 * 仅处理 AST_VAR_DECL；变量类型须为命名结构体且该结构体有 drop 方法。
 * 已移动的变量（was_moved）不调用 drop。 */
static void emit_drop_cleanup(C99CodeGenerator *codegen, ASTNode **stmts, int stmt_count) {
    if (!codegen || !stmts || stmt_count <= 0) return;
    for (int i = stmt_count - 1; i >= 0; i--) {
        ASTNode *n = stmts[i];
        if (!n || n->type != AST_VAR_DECL) continue;
        if (n->data.var_decl.was_moved) continue;
        ASTNode *type_node = n->data.var_decl.type;
        if (!type_node || type_node->type != AST_TYPE_NAMED || !type_node->data.type_named.name) continue;
        const char *struct_name = type_node->data.type_named.name;
        if (!type_has_drop_c99(codegen, struct_name)) continue;
        const char *drop_c = get_method_c_name(codegen, struct_name, "drop");
        const char *var_safe = get_safe_c_identifier(codegen, n->data.var_decl.name);
        if (!drop_c || !var_safe) continue;
        c99_emit(codegen, "/* drop */ ");
        fprintf(codegen->output, "%s(%s);\n", drop_c, var_safe);
    }
}

/* 在 return/break/continue/块结束前执行当前层的 defer（及可选的 errdefer）。LIFO 顺序。
 * 规范 §9：return 时先计算返回值，再执行 defer，最后返回；defer 不能修改返回值。 */
static void emit_defer_cleanup(C99CodeGenerator *codegen, int emit_errdefer) {
    if (codegen->defer_stack_depth <= 0) return;
    int d = codegen->defer_stack_depth - 1;
    if (emit_errdefer) {
        for (int i = codegen->errdefer_count[d] - 1; i >= 0; i--) {
            ASTNode *n = codegen->errdefer_stack[d][i];
            if (n && n->type == AST_ERRDEFER_STMT && n->data.errdefer_stmt.body) {
                c99_emit(codegen, "/* errdefer */ ");
                gen_stmt(codegen, n->data.errdefer_stmt.body);
            }
        }
    }
    for (int i = codegen->defer_count[d] - 1; i >= 0; i--) {
        ASTNode *n = codegen->defer_stack[d][i];
        if (n && n->type == AST_DEFER_STMT && n->data.defer_stmt.body) {
            c99_emit(codegen, "/* defer */ ");
            gen_stmt(codegen, n->data.defer_stmt.body);
        }
    }
}

void gen_stmt(C99CodeGenerator *codegen, ASTNode *stmt) {
    if (!stmt) return;
    
    // 生成 #line 指令，指向语句的位置（如果行号有效）
    if (stmt->line > 0) {
        emit_line_directive(codegen, stmt->line, stmt->filename);
    }
    
    switch (stmt->type) {
        case AST_EXPR_STMT:
            // 表达式语句的数据存储在表达式的节点中，直接忽略此节点
            break;
        case AST_ASSIGN: {
            ASTNode *dest = stmt->data.assign.dest;
            ASTNode *src = stmt->data.assign.src;
            
            /* _ = expr：仅求值右侧（显式忽略返回值） */
            if (dest->type == AST_UNDERSCORE) {
                c99_emit(codegen, "(void)(");
                gen_expr(codegen, src);
                fputs(");\n", codegen->output);
                break;
            }
            
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
                // 检查目标是否为原子类型
                int is_atomic_assign = 0;
                const char *dest_type_c = NULL;
                if (dest->type == AST_IDENTIFIER) {
                    dest_type_c = get_identifier_type_c(codegen, dest->data.identifier.name);
                    if (dest_type_c && strstr(dest_type_c, "_Atomic") != NULL) {
                        is_atomic_assign = 1;
                    }
                } else if (dest->type == AST_MEMBER_ACCESS) {
                    dest_type_c = get_c_type_of_expr(codegen, dest);
                    if (dest_type_c && strstr(dest_type_c, "_Atomic") != NULL) {
                        is_atomic_assign = 1;
                    }
                }
                
                if (is_atomic_assign) {
                    // 获取 safe_name
                    const char *safe_name = NULL;
                    if (dest->type == AST_IDENTIFIER) {
                        safe_name = get_safe_c_identifier(codegen, dest->data.identifier.name);
                    }
                    
                    // 检查是否为复合赋值（src 是二元表达式，且左侧是相同的标识符）
                    int is_compound_assign = 0;
                    int compound_op = 0;
                    ASTNode *compound_right = NULL;
                    if (src->type == AST_BINARY_EXPR) {
                        ASTNode *bin_left = src->data.binary_expr.left;
                        int bin_op = src->data.binary_expr.op;
                        compound_right = src->data.binary_expr.right;
                        if (dest->type == AST_IDENTIFIER && bin_left->type == AST_IDENTIFIER &&
                            strcmp(dest->data.identifier.name, bin_left->data.identifier.name) == 0) {
                            // 复合赋值：x = x + y 形式
                            if (bin_op == TOKEN_PLUS || bin_op == TOKEN_MINUS || bin_op == TOKEN_ASTERISK ||
                                bin_op == TOKEN_SLASH || bin_op == TOKEN_PERCENT) {
                                is_compound_assign = 1;
                                compound_op = bin_op;
                            }
                        }
                    }
                    
                    if (is_compound_assign) {
                        // 原子复合赋值：生成原子 fetch_add/fetch_sub 等
                        // 硬件支持的原子操作：+= 和 -=
                        if (compound_op == TOKEN_PLUS) {
                            if (safe_name && *safe_name) {
                                fprintf(codegen->output, "__atomic_fetch_add(&%s, ", safe_name);
                            } else {
                                fputs("__atomic_fetch_add(&", codegen->output);
                                gen_expr(codegen, dest);
                                fputs(", ", codegen->output);
                            }
                            gen_expr(codegen, compound_right);
                            fputs(", __ATOMIC_SEQ_CST);\n", codegen->output);
                        } else if (compound_op == TOKEN_MINUS) {
                            if (safe_name && *safe_name) {
                                fprintf(codegen->output, "__atomic_fetch_sub(&%s, ", safe_name);
                            } else {
                                fputs("__atomic_fetch_sub(&", codegen->output);
                                gen_expr(codegen, dest);
                                fputs(", ", codegen->output);
                            }
                            gen_expr(codegen, compound_right);
                            fputs(", __ATOMIC_SEQ_CST);\n", codegen->output);
                        } else {
                            // *=, /=, %= 需要使用 compare-and-swap 循环（软件实现）
                            // 为了简化，先回退到普通原子 store（后续可以优化）
                            if (safe_name && *safe_name) {
                                fprintf(codegen->output, "__atomic_store_n(&%s, ", safe_name);
                            } else {
                                fputs("__atomic_store_n(&", codegen->output);
                                gen_expr(codegen, dest);
                                fputs(", ", codegen->output);
                            }
                            gen_expr(codegen, src);
                            fputs(", __ATOMIC_SEQ_CST);\n", codegen->output);
                        }
                    } else {
                        // 原子赋值：生成原子 store
                        if (safe_name && *safe_name) {
                            fprintf(codegen->output, "__atomic_store_n(&%s, ", safe_name);
                        } else {
                            fputs("__atomic_store_n(&", codegen->output);
                            gen_expr(codegen, dest);
                            fputs(", ", codegen->output);
                        }
                        gen_expr(codegen, src);
                        fputs(", __ATOMIC_SEQ_CST);\n", codegen->output);
                    }
                } else {
                    // 普通赋值（self.field 作为左端时需 cast，以支持 const self 参数）
                    c99_emit(codegen, "");
                    codegen->emitting_assign_lhs = 1;
                    gen_expr(codegen, dest);
                    codegen->emitting_assign_lhs = 0;
                    fputs(" = ", codegen->output);
                    gen_expr(codegen, src);
                    fputs(";\n", codegen->output);
                }
            }
            break;
        }
        case AST_RETURN_STMT: {
            ASTNode *expr = stmt->data.return_stmt.expr;
            ASTNode *return_type = codegen->current_function_return_type;
            int is_error_return = (expr && expr->type == AST_ERROR_VALUE);
            
            // return error.X 与 return;：先执行 defer，再返回（error 值不依赖变量）
            if ((expr && expr->type == AST_ERROR_VALUE) || (!expr && return_type && return_type->type == AST_TYPE_NAMED &&
                    return_type->data.type_named.name && strcmp(return_type->data.type_named.name, "void") == 0)) {
                emit_current_block_drops(codegen);
                emit_defer_cleanup(codegen, is_error_return);
            }
            
            // return error.X：生成错误联合复合字面量
            if (expr && expr->type == AST_ERROR_VALUE && return_type && return_type->type == AST_TYPE_ERROR_UNION) {
                unsigned id = expr->data.error_value.name ? get_or_add_error_id(codegen, expr->data.error_value.name) : 0;
                if (id == 0) { id = 1; }
                const char *ret_c = c99_type_to_c(codegen, return_type);
                int is_void = (return_type->data.type_error_union.payload_type &&
                    return_type->data.type_error_union.payload_type->type == AST_TYPE_NAMED &&
                    return_type->data.type_error_union.payload_type->data.type_named.name &&
                    strcmp(return_type->data.type_error_union.payload_type->data.type_named.name, "void") == 0);
                if (is_void) {
                    c99_emit(codegen, "return (%s){ .error_id = %uU };\n", ret_c, id);
                } else {
                    c99_emit(codegen, "return (%s){ .error_id = %uU, .value = 0 };\n", ret_c, id);
                }
                break;
            }
            
            // return;（void 函数）
            if (!expr) {
                int is_void = 0;
                if (return_type && return_type->type == AST_TYPE_NAMED) {
                    const char *tn = return_type->data.type_named.name;
                    if (tn && strcmp(tn, "void") == 0) is_void = 1;
                }
                if (is_void) {
                    c99_emit(codegen, "return;\n");
                    break;
                }
            }
            
            // 有返回值的 return expr：规范要求先计算返回值，再执行 defer，最后返回
            // 检查是否为 void 类型（不应该到达这里，但为了安全起见）
            int is_void = 0;
            if (return_type && return_type->type == AST_TYPE_NAMED) {
                const char *tn = return_type->data.type_named.name;
                if (tn && strcmp(tn, "void") == 0) is_void = 1;
            }
            
            // void 类型的 return 已经在上面处理了，这里不应该到达
            if (is_void) {
                emit_current_block_drops(codegen);
                emit_defer_cleanup(codegen, is_error_return);
                c99_emit(codegen, "return;\n");
                break;
            }
            
            int is_array_return = (return_type && return_type->type == AST_TYPE_ARRAY);
            const char *ret_c = convert_array_return_type(codegen, return_type);
            if (!ret_c) ret_c = "int32_t";
            
            // 1. 先将返回值计算到临时变量 _uya_ret
            if (is_array_return && expr) {
                const char *struct_name = get_array_wrapper_struct_name(codegen, return_type);
                if (struct_name) {
                    gen_array_wrapper_struct(codegen, return_type, struct_name);
                    c99_emit(codegen, "%s _uya_ret = (struct %s) { .data = ", ret_c, struct_name);
                    if (expr->type == AST_ARRAY_LITERAL) {
                        fputc('{', codegen->output);
                        ASTNode **elements = expr->data.array_literal.elements;
                        int element_count = expr->data.array_literal.element_count;
                        ASTNode *repeat_count_expr = expr->data.array_literal.repeat_count_expr;
                        if (repeat_count_expr != NULL && element_count >= 1) {
                            int n = eval_const_expr(codegen, repeat_count_expr);
                            if (n <= 0) n = 1;
                            for (int i = 0; i < n; i++) {
                                if (i > 0) fputs(", ", codegen->output);
                                gen_expr(codegen, elements[0]);
                            }
                        } else if (element_count > 0) {
                            for (int i = 0; i < element_count; i++) {
                                if (i > 0) fputs(", ", codegen->output);
                                gen_expr(codegen, elements[i]);
                            }
                        } else {
                            /* 空数组字面量：生成 0 避免 ISO C 警告 */
                            fputs("0", codegen->output);
                        }
                        fputc('}', codegen->output);
                    } else {
                        gen_expr(codegen, expr);
                    }
                    fputs(" };\n", codegen->output);
                } else {
                    c99_emit(codegen, "%s _uya_ret = ", ret_c);
                    gen_expr(codegen, expr);
                    fputs(";\n", codegen->output);
                }
            } else {
                if (return_type && return_type->type == AST_TYPE_ERROR_UNION && expr && expr->type != AST_ERROR_VALUE) {
                    ASTNode *payload_node = return_type->data.type_error_union.payload_type;
                    int payload_void = (!payload_node || (payload_node->type == AST_TYPE_NAMED &&
                        payload_node->data.type_named.name && strcmp(payload_node->data.type_named.name, "void") == 0));
                    if (payload_void) {
                        c99_emit(codegen, "%s _uya_ret = (%s){ .error_id = 0 };\n", ret_c, ret_c);
                    } else {
                        c99_emit(codegen, "%s _uya_ret = (%s){ .error_id = 0, .value = ", ret_c, ret_c);
                        gen_expr(codegen, expr);
                        fputs(" };\n", codegen->output);
                    }
                } else if (!is_void && expr) {
                    // 对于泛型结构体实例化的返回类型，如果表达式是结构体初始化，使用返回类型的 C 类型名称
                    const char *struct_name_for_init = NULL;
                    if (expr->type == AST_STRUCT_INIT && 
                        return_type && return_type->type == AST_TYPE_NAMED && 
                        return_type->data.type_named.type_arg_count > 0) {
                        // 泛型结构体实例化：使用返回类型的 C 类型名称
                        const char *type_c_for_init = c99_type_to_c(codegen, return_type);
                        if (type_c_for_init) {
                            // 移除 "struct " 前缀（如果有）
                            if (strncmp(type_c_for_init, "struct ", 7) == 0) {
                                struct_name_for_init = type_c_for_init + 7;
                            } else {
                                struct_name_for_init = type_c_for_init;
                            }
                        }
                    }
                    
                    c99_emit(codegen, "%s _uya_ret = ", ret_c);
                    if (struct_name_for_init && expr->type == AST_STRUCT_INIT) {
                        // 直接生成结构体初始化代码，使用返回类型的 C 类型名称
                        int field_count = expr->data.struct_init.field_count;
                        const char **field_names = expr->data.struct_init.field_names;
                        ASTNode **field_values = expr->data.struct_init.field_values;
                        
                        fprintf(codegen->output, "(struct %s){", struct_name_for_init);
                        for (int i = 0; i < field_count; i++) {
                            const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                            fprintf(codegen->output, ".%s = ", safe_field_name);
                            gen_expr(codegen, field_values[i]);
                            if (i < field_count - 1) fputs(", ", codegen->output);
                        }
                        fputc('}', codegen->output);
                    } else {
                        gen_expr(codegen, expr);
                    }
                    fputs(";\n", codegen->output);
                } else if (!is_void) {
                    c99_emit(codegen, "%s _uya_ret = 0;\n", ret_c);
                }
            }
            emit_current_block_drops(codegen);
            // 2. 执行 defer（defer 不能修改已计算的返回值）
            emit_defer_cleanup(codegen, is_error_return);
            // 3. 返回临时变量（void 类型直接返回）
            if (is_void) {
                c99_emit(codegen, "return;\n");
            } else {
                c99_emit(codegen, "return _uya_ret;\n");
            }
            break;
        }
        case AST_BLOCK: {
            ASTNode **stmts = stmt->data.block.stmts;
            int stmt_count = stmt->data.block.stmt_count;
            int d = codegen->defer_stack_depth;
            int saved_drop_scope = codegen->current_drop_scope;
            if (d >= C99_MAX_DEFER_STACK) {
                for (int i = 0; i < stmt_count; i++) gen_stmt(codegen, stmts[i]);
                break;
            }
            codegen->current_drop_scope = d;
            codegen->drop_var_count[d] = 0;
            int nd = 0, ne = 0;
            for (int i = 0; i < stmt_count && nd < C99_MAX_DEFERS_PER_BLOCK && ne < C99_MAX_DEFERS_PER_BLOCK; i++) {
                if (stmts[i]->type == AST_DEFER_STMT)
                    codegen->defer_stack[d][nd++] = stmts[i];
                else if (stmts[i]->type == AST_ERRDEFER_STMT)
                    codegen->errdefer_stack[d][ne++] = stmts[i];
            }
            codegen->defer_count[d] = nd;
            codegen->errdefer_count[d] = ne;
            codegen->defer_stack_depth++;
            for (int i = 0; i < stmt_count; i++) {
                if (stmts[i]->type != AST_DEFER_STMT && stmts[i]->type != AST_ERRDEFER_STMT)
                    gen_stmt(codegen, stmts[i]);
            }
            /* 若块以 return/break/continue 结尾，该语句已执行 defer，块尾不再重复（否则会生成 return 后的死代码） */
            int last_is_terminal = 0;
            for (int i = stmt_count - 1; i >= 0; i--) {
                if (stmts[i]->type != AST_DEFER_STMT && stmts[i]->type != AST_ERRDEFER_STMT) {
                    last_is_terminal = (stmts[i]->type == AST_RETURN_STMT ||
                        stmts[i]->type == AST_BREAK_STMT || stmts[i]->type == AST_CONTINUE_STMT);
                    break;
                }
            }
            if (!last_is_terminal)
                emit_defer_cleanup(codegen, 0);
            emit_drop_cleanup(codegen, stmts, stmt_count);
            codegen->defer_stack_depth--;
            codegen->current_drop_scope = saved_drop_scope;
            break;
        }
        case AST_DEFER_STMT:
        case AST_ERRDEFER_STMT:
        case AST_TEST_STMT:
            // 测试语句在 main.c 中统一生成为函数
            break;
        case AST_DESTRUCTURE_DECL: {
            /* const (x, y) = init; -> const T0 x = init.f0; const T1 y = init.f1; */
            ASTNode *init = stmt->data.destructure_decl.init;
            const char **names = stmt->data.destructure_decl.names;
            int name_count = stmt->data.destructure_decl.name_count;
            int is_const = stmt->data.destructure_decl.is_const;
            if (!init || !names || name_count <= 0) break;
            for (int i = 0; i < name_count; i++) {
                if (!names[i] || strcmp(names[i], "_") == 0) continue;
                const char *elem_type_c = "int32_t";
                if (init->type == AST_TUPLE_LITERAL && init->data.tuple_literal.elements &&
                    i < init->data.tuple_literal.element_count) {
                    elem_type_c = get_c_type_of_expr(codegen, init->data.tuple_literal.elements[i]);
                    if (!elem_type_c) elem_type_c = "int32_t";
                }
                const char *safe_name = get_safe_c_identifier(codegen, names[i]);
                if (!safe_name) continue;
                if (is_const) {
                    fprintf(codegen->output, "const %s %s = ", elem_type_c, safe_name);
                } else {
                    fprintf(codegen->output, "%s %s = ", elem_type_c, safe_name);
                }
                gen_expr(codegen, init);
                fprintf(codegen->output, ".f%d;\n", i);
                /* 注册局部变量供后续引用 */
                if (codegen->local_variable_count < C99_MAX_LOCAL_VARS) {
                    const char *type_to_store = elem_type_c;
                    if (is_const && elem_type_c) {
                        size_t len = strlen(elem_type_c) + 8;
                        char *buf = (char *)arena_alloc(codegen->arena, len);
                        if (buf) {
                            snprintf(buf, len, "const %s", elem_type_c);
                            type_to_store = buf;
                        }
                    }
                    codegen->local_variables[codegen->local_variable_count].name = safe_name;
                    codegen->local_variables[codegen->local_variable_count].type_c = type_to_store;
                    codegen->local_variable_count++;
                }
            }
            break;
        }
        case AST_VAR_DECL: {
            const char *var_name = get_safe_c_identifier(codegen, stmt->data.var_decl.name);
            ASTNode *var_type = stmt->data.var_decl.type;
            ASTNode *init_expr = stmt->data.var_decl.init;
            int is_const = stmt->data.var_decl.is_const;
            int is_string_interp_init = (init_expr != NULL && init_expr->type == AST_STRING_INTERP);
            /* 字符串插值初始化需先写入缓冲区，const 数组在 C 中改为非 const 声明 */
            int emit_const = is_const && !is_string_interp_init;
            
            // 计算类型字符串
            const char *type_c = NULL;
            const char *stored_type_c = NULL;  // 用于存储到变量表的完整类型字符串
            const char *stored_type_c_for_pointer = NULL;  // 用于存储指针类型的完整类型字符串（包括 const）
            if (var_type->type == AST_TYPE_ARRAY) {
                // 使用 c99_type_to_c 来处理数组类型（包括多维数组）
                // 它会返回正确的格式，如 "int32_t[3][2]" 对于 [[i32: 2]: 3]
                type_c = c99_type_to_c(codegen, var_type);
                
                // 保存完整的类型字符串（包括 const 和维度）用于存储到变量表
                if (type_c) {
                    size_t type_len = strlen(type_c);
                    if (is_const) {
                        // 为 "const " 前缀分配空间（变量表仍记录为 const）
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
                        
                        // 生成数组声明：const base_type var_name dimensions（字符串插值初始化时不加 const 以便填充）
                        if (emit_const) {
                            fprintf(codegen->output, "const %s %s%s", base_type, var_name, dimensions);
                        } else {
                            fprintf(codegen->output, "%s %s%s", base_type, var_name, dimensions);
                        }
                        type_c = NULL; // 已处理，避免后续重复输出
                    }
                }
                
                // 如果上面的解析失败，回退到简单处理
                if (type_c) {
                    if (emit_const) {
                        c99_emit(codegen, "const %s %s", type_c, var_name);
                    } else {
                        c99_emit(codegen, "%s %s", type_c, var_name);
                    }
                }
            } else {
                // 非数组类型
                type_c = c99_type_to_c(codegen, var_type);
                // 检查是否是 void 类型
                int is_void_type = 0;
                if (var_type->type == AST_TYPE_NAMED) {
                    const char *type_name = var_type->data.type_named.name;
                    if (type_name && strcmp(type_name, "void") == 0) {
                        is_void_type = 1;
                    }
                }
                if (is_void_type) {
                    // void 类型变量：生成 (void)(expr); 而不是 const void result = expr;
                    if (init_expr) {
                        // 检查是否是 catch 表达式且包含 break/continue
                        int is_catch_with_break = 0;
                        if (init_expr->type == AST_CATCH_EXPR) {
                            ASTNode *catch_block = init_expr->data.catch_expr.catch_block;
                            if (catch_block && catch_block->type == AST_BLOCK) {
                                for (int i = 0; i < catch_block->data.block.stmt_count; i++) {
                                    ASTNode *s = catch_block->data.block.stmts[i];
                                    if (s && (s->type == AST_BREAK_STMT || s->type == AST_CONTINUE_STMT)) {
                                        is_catch_with_break = 1;
                                        break;
                                    }
                                }
                            }
                        }
                        if (is_catch_with_break) {
                            // catch 表达式包含 break/continue，需要生成语句而不是表达式
                            // 直接生成 if-else 语句
                            ASTNode *operand = init_expr->data.catch_expr.operand;
                            ASTNode *block = init_expr->data.catch_expr.catch_block;
                            const char *err_name = init_expr->data.catch_expr.err_name;
                            if (operand && block) {
                                const char *operand_union_c = get_c_type_of_expr(codegen, operand);
                                int operand_is_err_union = (operand_union_c && strstr(operand_union_c, "err_union_") != NULL);
                                if (operand_is_err_union) {
                                    const char *union_c = operand_union_c;
                                    c99_emit_indent(codegen);
                                    fprintf(codegen->output, "%s _uya_catch_tmp = ", union_c);
                                    gen_expr(codegen, operand);
                                    fputs("; if (_uya_catch_tmp.error_id != 0) {\n", codegen->output);
                                    codegen->indent_level++;
                                    if (err_name) {
                                        const char *safe = get_safe_c_identifier(codegen, err_name);
                                        c99_emit_indent(codegen);
                                        fprintf(codegen->output, "%s %s = _uya_catch_tmp;\n", union_c, safe);
                                    }
                                    for (int i = 0; i < block->data.block.stmt_count; i++) {
                                        ASTNode *s = block->data.block.stmts[i];
                                        if (!s) continue;
                                        gen_stmt(codegen, s);
                                    }
                                    codegen->indent_level--;
                                    c99_emit_indent(codegen);
                                    fputs("}\n", codegen->output);
                                    return;  // void 类型变量不需要存储到变量表
                                }
                            }
                        }
                        // 普通情况：生成 (void)(expr);
                        c99_emit_indent(codegen);
                        fputs("(void)(", codegen->output);
                        gen_expr(codegen, init_expr);
                        fputs(");\n", codegen->output);
                    }
                    return;  // void 类型变量不需要存储到变量表
                }
                // 为存储到变量表准备完整的类型字符串（包括 const 修饰符）
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
                            // 存储类型字符串：T (* const)[N]（用于变量表）
                            size_t total_len = prefix_len + suffix_len + 10; // "(* const)" + null
                            stored_type_c_for_pointer = arena_alloc(codegen->arena, total_len);
                            if (stored_type_c_for_pointer) {
                                snprintf((char *)stored_type_c_for_pointer, total_len, "%.*s(* const)%.*s",
                                        (int)prefix_len, type_c, (int)suffix_len, bracket);
                            }
                        } else {
                            // 普通指针：T * -> T * const var_name
                            c99_emit(codegen, "%s const %s", type_c, var_name);
                            // 存储类型字符串：T * const（用于变量表）
                            size_t len = strlen(type_c) + 7; // " const" + null
                            stored_type_c_for_pointer = arena_alloc(codegen->arena, len);
                            if (stored_type_c_for_pointer) {
                                snprintf((char *)stored_type_c_for_pointer, len, "%s const", type_c);
                            }
                        }
                    } else {
                        // 普通指针：T * -> T * const var_name
                        c99_emit(codegen, "%s const %s", type_c, var_name);
                        // 存储类型字符串：T * const（用于变量表）
                        size_t len = strlen(type_c) + 7; // " const" + null
                        stored_type_c_for_pointer = arena_alloc(codegen->arena, len);
                        if (stored_type_c_for_pointer) {
                            snprintf((char *)stored_type_c_for_pointer, len, "%s const", type_c);
                        }
                    }
                } else if (is_const) {
                    c99_emit(codegen, "const %s %s", type_c, var_name);
                    // 存储类型字符串：const T（用于变量表）
                    size_t len = strlen(type_c) + 7; // "const " + null
                    stored_type_c_for_pointer = arena_alloc(codegen->arena, len);
                    if (stored_type_c_for_pointer) {
                        snprintf((char *)stored_type_c_for_pointer, len, "const %s", type_c);
                    }
                } else {
                    c99_emit(codegen, "%s %s", type_c, var_name);
                }
            }
            
            // *关键修改*：在生成初始化表达式之前，先将变量添加到局部变量表
            // 这样如果初始化表达式或后续表达式使用了这个变量，就能正确识别其类型
            const char *type_to_store = NULL;
            if (var_type->type == AST_TYPE_ARRAY && stored_type_c) {
                type_to_store = stored_type_c;
            } else if (stored_type_c_for_pointer) {
                type_to_store = stored_type_c_for_pointer;
            } else if (var_type->type == AST_TYPE_POINTER && is_const && type_c) {
                // 如果 stored_type_c_for_pointer 为 NULL（arena_alloc 失败），但类型是指针且是 const，
                // 手动构造类型字符串：T * const
                size_t len = strlen(type_c) + 7; // " const" + null
                char *manual_type = arena_alloc(codegen->arena, len);
                if (manual_type) {
                    snprintf(manual_type, len, "%s const", type_c);
                    type_to_store = manual_type;
                } else {
                    // 如果还是失败，使用 type_c（至少包含 *，应该能被识别为指针）
                    type_to_store = type_c;
                }
            } else if (var_type->type == AST_TYPE_POINTER && type_c) {
                // 非 const 指针：直接使用 type_c（应该包含 *）
                type_to_store = type_c;
            } else {
                type_to_store = type_c;
            }
            if (var_name && type_to_store && codegen->local_variable_count < C99_MAX_LOCAL_VARS) {
                codegen->local_variables[codegen->local_variable_count].name = var_name;
                codegen->local_variables[codegen->local_variable_count].type_c = type_to_store;
                codegen->local_variable_count++;
            }
            
            if (init_expr) {
                // @params 作为初始化器：用大括号列表 { .f0 = p0, .f1 = p1 } 避免 C99 匿名 struct 类型不兼容
                int is_params_init = (init_expr->type == AST_PARAMS &&
                    codegen->current_function_decl && codegen->current_function_decl->type == AST_FN_DECL &&
                    codegen->current_function_decl->data.fn_decl.param_count > 0);
                if (is_params_init) {
                    ASTNode **params = codegen->current_function_decl->data.fn_decl.params;
                    int n = codegen->current_function_decl->data.fn_decl.param_count;
                    fputs(" = {", codegen->output);
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
                    fputs("};\n", codegen->output);
                }
                // 检查是否是空结构体初始化（field_count == 0）
                // 如果是，改为手动初始化，避免 gcc 生成错误的 memset 调用
                int is_empty_struct_init = 0;
                ASTNode *struct_decl_for_empty_init = NULL;
                if (!is_params_init && init_expr->type == AST_STRUCT_INIT) {
                    int field_count = init_expr->data.struct_init.field_count;
                    if (field_count == 0) {
                        // 空结构体初始化：从初始化表达式中获取结构体名称
                        const char *struct_name = get_safe_c_identifier(codegen, init_expr->data.struct_init.struct_name);
                        if (struct_name) {
                            struct_decl_for_empty_init = find_struct_decl_c99(codegen, struct_name);
                            if (struct_decl_for_empty_init) {
                                is_empty_struct_init = 1;
                            }
                        }
                    }
                }
                
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
                
                // 字符串插值初始化：先声明变量，再填充
                int is_string_interp_init = (init_expr->type == AST_STRING_INTERP);
                
                // 检查是否是结构体初始化且包含数组字段（初始化值是标识符）
                // 在C中，数组不能直接赋值，需要使用memcpy
                int struct_init_needs_memcpy = 0;
                if (init_expr->type == AST_STRUCT_INIT && !is_empty_struct_init) {
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
                
                if (is_empty_struct_init) {
                    // 空结构体初始化：C 中空结构体有占位字段 _empty，需零初始化
                    // 先完成变量声明（不包含初始化）
                    fputs(";\n", codegen->output);
                    
                    // 获取结构体定义中的所有字段（AST 中空结构体 field_count 为 0）
                    ASTNode *struct_decl = struct_decl_for_empty_init;
                    int field_count = struct_decl->data.struct_decl.field_count;
                    ASTNode **fields = struct_decl->data.struct_decl.fields;
                    
                    if (field_count > 0) {
                        // 手动初始化每个字段（非空结构体但初始化列表为空的情况）
                        for (int i = 0; i < field_count; i++) {
                            ASTNode *field = fields[i];
                            if (!field || field->type != AST_VAR_DECL) {
                                continue;
                            }
                            
                            const char *field_name = get_safe_c_identifier(codegen, field->data.var_decl.name);
                            ASTNode *field_type = field->data.var_decl.type;
                            
                            if (!field_name || !field_type) {
                                continue;
                            }
                            
                            // 根据字段类型生成初始化代码
                            if (field_type->type == AST_TYPE_POINTER) {
                                // 指针类型：初始化为 NULL
                                c99_emit(codegen, "%s.%s = NULL;\n", var_name, field_name);
                            } else if (field_type->type == AST_TYPE_ARRAY) {
                                // 数组类型：使用 memset 清零
                                c99_emit(codegen, "memset(%s.%s, 0, sizeof(%s.%s));\n", 
                                        var_name, field_name, var_name, field_name);
                            } else {
                                // 其他类型（整数、浮点数等）：初始化为 0
                                c99_emit(codegen, "%s.%s = 0;\n", var_name, field_name);
                            }
                        }
                    } else {
                        // 空结构体（AST 无字段）：C 端有 char _empty 占位，整体零初始化（cast 避免 const 警告）
                        c99_emit(codegen, "memset((void *)&%s, 0, sizeof(%s));\n", var_name, var_name);
                    }
                } else if (is_array_from_function) {
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
                } else if (is_string_interp_init) {
                    fputs(";\n", codegen->output);
                    c99_emit_string_interp_fill(codegen, init_expr, var_name);
                } else if (needs_memcpy) {
                    // 数组初始化：使用memcpy
                    fputs(";\n", codegen->output);
                    c99_emit_indent(codegen);
                    fprintf(codegen->output, "memcpy(%s, ", var_name);
                    gen_expr(codegen, init_expr);
                    fprintf(codegen->output, ", sizeof(%s));\n", var_name);
                } else if (struct_init_needs_memcpy) {
                    // 结构体初始化包含数组字段：先声明变量，然后使用复合字面量初始化非数组字段，最后用memcpy复制数组字段
                    fputs(" = ", codegen->output);
                    
                    // 生成复合字面量，但数组字段使用空初始化
                    // 对于泛型结构体实例化，使用变量类型的 C 类型名称
                    const char *struct_name_for_init = NULL;
                    if (var_type && var_type->type == AST_TYPE_NAMED && 
                        var_type->data.type_named.type_arg_count > 0) {
                        // 泛型结构体实例化：使用变量类型的 C 类型名称
                        const char *type_c_for_init = c99_type_to_c(codegen, var_type);
                        if (type_c_for_init) {
                            // 移除 "struct " 前缀（如果有）
                            if (strncmp(type_c_for_init, "struct ", 7) == 0) {
                                struct_name_for_init = type_c_for_init + 7;
                            } else {
                                struct_name_for_init = type_c_for_init;
                            }
                        }
                    }
                    if (!struct_name_for_init) {
                        struct_name_for_init = get_safe_c_identifier(codegen, init_expr->data.struct_init.struct_name);
                    }
                    
                    ASTNode *struct_decl = find_struct_decl_c99(codegen, init_expr->data.struct_init.struct_name);
                    int field_count = init_expr->data.struct_init.field_count;
                    const char **field_names = init_expr->data.struct_init.field_names;
                    ASTNode **field_values = init_expr->data.struct_init.field_values;
                    
                    fprintf(codegen->output, "(struct %s){", struct_name_for_init);
                    for (int i = 0; i < field_count; i++) {
                        const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                        ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_names[i]);
                        ASTNode *field_value = field_values[i];
                        
                        fprintf(codegen->output, ".%s = ", safe_field_name);
                        
                        // 如果是数组字段且初始化值是标识符，使用空初始化（后续用memcpy填充）
                        if (field_type && field_type->type == AST_TYPE_ARRAY && 
                            field_value && field_value->type == AST_IDENTIFIER) {
                            fputs("{0}", codegen->output);  /* 使用 {0} 避免 ISO C 警告 */
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
                } else if (var_type->type == AST_TYPE_TUPLE && init_expr->type == AST_TUPLE_LITERAL) {
                    /* 元组变量用元组字面量初始化：用 { .f0 = e0, .f1 = e1 } 避免 C 匿名结构体类型不兼容 */
                    int n = init_expr->data.tuple_literal.element_count;
                    ASTNode **elements = init_expr->data.tuple_literal.elements;
                    if (n > 0 && elements) {
                        fputs(" = { ", codegen->output);
                        for (int i = 0; i < n; i++) {
                            fprintf(codegen->output, ".f%d = ", i);
                            gen_expr(codegen, elements[i]);
                            if (i < n - 1) fputs(", ", codegen->output);
                        }
                        fputs(" };\n", codegen->output);
                    } else {
                        fputs(" = ", codegen->output);
                        gen_expr(codegen, init_expr);
                        fputs(";\n", codegen->output);
                    }
                } else if (!is_params_init) {
                    // 普通初始化（@params 已在上方单独处理）
                    fputs(" = ", codegen->output);
                    
                    // 对于泛型结构体实例化的结构体初始化，使用变量类型的 C 类型名称
                    if (init_expr->type == AST_STRUCT_INIT && 
                        var_type && var_type->type == AST_TYPE_NAMED && 
                        var_type->data.type_named.type_arg_count > 0) {
                        // 泛型结构体实例化：直接生成结构体初始化代码，使用变量类型的 C 类型名称
                        const char *type_c_for_init = c99_type_to_c(codegen, var_type);
                        const char *struct_name_for_init = NULL;
                        if (type_c_for_init) {
                            // 移除 "struct " 前缀（如果有）
                            if (strncmp(type_c_for_init, "struct ", 7) == 0) {
                                struct_name_for_init = type_c_for_init + 7;
                            } else {
                                struct_name_for_init = type_c_for_init;
                            }
                        }
                        if (struct_name_for_init) {
                            int field_count = init_expr->data.struct_init.field_count;
                            const char **field_names = init_expr->data.struct_init.field_names;
                            ASTNode **field_values = init_expr->data.struct_init.field_values;
                            
                            fprintf(codegen->output, "(struct %s){", struct_name_for_init);
                            for (int i = 0; i < field_count; i++) {
                                const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                                fprintf(codegen->output, ".%s = ", safe_field_name);
                                gen_expr(codegen, field_values[i]);
                                if (i < field_count - 1) fputs(", ", codegen->output);
                            }
                            fputc('}', codegen->output);
                        } else {
                            // 回退到普通处理
                            gen_expr(codegen, init_expr);
                        }
                    } else {
                        gen_expr(codegen, init_expr);
                    }
                    fputs(";\n", codegen->output);
                }
            } else {
                fputs(";\n", codegen->output);
            }
            if (codegen->current_drop_scope >= 0 && var_type && var_type->type == AST_TYPE_NAMED &&
                var_type->data.type_named.name && type_has_drop_c99(codegen, var_type->data.type_named.name) &&
                !stmt->data.var_decl.was_moved) {
                int dd = codegen->current_drop_scope;
                if (codegen->drop_var_count[dd] < C99_MAX_DROP_VARS_PER_BLOCK) {
                    codegen->drop_var_safe[dd][codegen->drop_var_count[dd]] = var_name;
                    codegen->drop_struct_name[dd][codegen->drop_var_count[dd]] = var_type->data.type_named.name;
                    codegen->drop_var_count[dd]++;
                }
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
            ASTNode *body = stmt->data.for_stmt.body;
            if (stmt->data.for_stmt.is_range) {
                // 整数范围：for start..end |v| { } 或 for start..end { }
                ASTNode *start_expr = stmt->data.for_stmt.range_start;
                ASTNode *end_expr = stmt->data.for_stmt.range_end;
                const char *range_type_c = get_c_type_of_expr(codegen, start_expr);
                if (!range_type_c) range_type_c = "int32_t";
                c99_emit(codegen, "{\n");
                codegen->indent_level++;
                c99_emit(codegen, "// for range\n");
                if (end_expr != NULL) {
                    if (stmt->data.for_stmt.var_name != NULL) {
                        const char *var_name = get_safe_c_identifier(codegen, stmt->data.for_stmt.var_name);
                        c99_emit(codegen, "%s %s = ", range_type_c, var_name);
                        gen_expr(codegen, start_expr);
                        c99_emit(codegen, ";\n");
                        c99_emit(codegen, "%s _uya_end = ", range_type_c);
                        gen_expr(codegen, end_expr);
                        c99_emit(codegen, ";\n");
                        c99_emit(codegen, "for (; %s < _uya_end; %s++) {\n", var_name, var_name);
                    } else {
                        c99_emit(codegen, "%s _uya_s = ", range_type_c);
                        gen_expr(codegen, start_expr);
                        c99_emit(codegen, ";\n");
                        c99_emit(codegen, "%s _uya_e = ", range_type_c);
                        gen_expr(codegen, end_expr);
                        c99_emit(codegen, ";\n");
                        c99_emit(codegen, "for (%s _uya_i = _uya_s; _uya_i < _uya_e; _uya_i++) {\n", range_type_c);
                    }
                } else {
                    /* start.. 无限范围：v = start; while(1) { body }，由 break/return 终止 */
                    const char *vname = get_safe_c_identifier(codegen, stmt->data.for_stmt.var_name);
                    c99_emit(codegen, "%s %s = ", range_type_c, vname);
                    gen_expr(codegen, start_expr);
                    c99_emit(codegen, ";\n");
                    c99_emit(codegen, "while (1) {\n");
                }
                codegen->indent_level++;
                gen_stmt(codegen, body);
                codegen->indent_level--;
                c99_emit(codegen, "}\n");
                codegen->indent_level--;
                c99_emit(codegen, "}\n");
                break;
            }
            // 数组遍历或接口迭代形式：for expr | ID | { ... }
            ASTNode *array = stmt->data.for_stmt.array;
            const char *var_name = get_safe_c_identifier(codegen, stmt->data.for_stmt.var_name);
            int is_ref = stmt->data.for_stmt.is_ref;
            
            // 首先尝试作为数组类型处理
            const char *elem_type_c = get_array_element_type(codegen, array);
            
            // 如果不是数组类型，尝试作为接口迭代器处理
            if (!elem_type_c) {
                // 检查是否是结构体类型，且实现了迭代器接口（有 next 和 value 方法）
                const char *expr_type_c = get_c_type_of_expr(codegen, array);
                if (expr_type_c && strstr(expr_type_c, "struct ") == expr_type_c) {
                    // 提取结构体名称（去除 "struct " 前缀）
                    const char *struct_name = expr_type_c + 7;  // 跳过 "struct "
                    // 去除可能的指针后缀
                    char struct_name_buf[256];
                    strncpy(struct_name_buf, struct_name, sizeof(struct_name_buf) - 1);
                    struct_name_buf[sizeof(struct_name_buf) - 1] = '\0';
                    char *ptr = strchr(struct_name_buf, ' ');
                    if (ptr) *ptr = '\0';
                    
                    ASTNode *next_method = find_method_in_struct_c99(codegen, struct_name_buf, "next");
                    ASTNode *value_method = find_method_in_struct_c99(codegen, struct_name_buf, "value");
                    
                    if (next_method != NULL && value_method != NULL) {
                        // 接口迭代形式：生成 while 循环，调用 next() 和 value()
                        const char *iter_type_c = expr_type_c;
                        const char *value_return_type_c = c99_type_to_c(codegen, value_method->data.fn_decl.return_type);
                        if (!value_return_type_c) value_return_type_c = "int32_t";
                        
                        c99_emit(codegen, "{\n");
                        codegen->indent_level++;
                        c99_emit(codegen, "// for loop - iterator interface\n");
                        
                        // 创建迭代器变量
                        c99_emit(codegen, "%s _uya_iter = ", iter_type_c);
                        gen_expr(codegen, array);
                        c99_emit(codegen, ";\n");
                        
                        // while 循环
                        c99_emit(codegen, "while (1) {\n");
                        codegen->indent_level++;
                        
                        // 调用 next() 方法（返回 !void）
                        const char *next_cname = get_method_c_name(codegen, struct_name_buf, "next");
                        if (next_cname) {
                            c99_emit(codegen, "struct err_union_void _uya_next_result = %s(&_uya_iter);\n", next_cname);
                            c99_emit(codegen, "if (_uya_next_result.error_id != 0) {\n");
                            codegen->indent_level++;
                            c99_emit(codegen, "break;  // error.IterEnd\n");
                            codegen->indent_level--;
                            c99_emit(codegen, "}\n");
                        }
                        
                        // 调用 value() 方法获取当前值
                        const char *value_cname = get_method_c_name(codegen, struct_name_buf, "value");
                        if (value_cname && var_name) {
                            c99_emit(codegen, "%s %s = %s(&_uya_iter);\n", value_return_type_c, var_name, value_cname);
                        }
                        
                        // 循环体
                        gen_stmt(codegen, body);
                        
                        codegen->indent_level--;
                        c99_emit(codegen, "}\n");
                        codegen->indent_level--;
                        c99_emit(codegen, "}\n");
                        break;
                    }
                }
                
                // 既不是数组类型，也不是实现了迭代器接口的结构体，使用默认类型
                elem_type_c = "int32_t";
            }
            
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
        case AST_MATCH_EXPR: {
            /* match expr { pat => result, ... } 作为语句 */
            ASTNode *match_expr = stmt->data.match_expr.expr;
            const char *m_type = get_c_type_of_expr(codegen, match_expr);
            if (!m_type) m_type = "int32_t";
            c99_emit(codegen, "{\n");
            codegen->indent_level++;
            c99_emit(codegen, "%s _uya_m = ", m_type);
            gen_expr(codegen, match_expr);
            fputs(";\n", codegen->output);
            int first = 1;
            for (int i = 0; i < stmt->data.match_expr.arm_count; i++) {
                ASTMatchArm *arm = &stmt->data.match_expr.arms[i];
                const char *prefix = first ? "" : "else ";
                first = 0;
                if (arm->kind == MATCH_PAT_LITERAL && arm->data.literal.expr) {
                    if (arm->data.literal.expr->type == AST_NUMBER) {
                        c99_emit(codegen, "%sif (_uya_m == %d) ", prefix, arm->data.literal.expr->data.number.value);
                    } else if (arm->data.literal.expr->type == AST_BOOL) {
                        c99_emit(codegen, "%sif (_uya_m == %s) ", prefix, arm->data.literal.expr->data.bool_literal.value ? "1" : "0");
                    }
                    if (arm->result_expr->type == AST_BLOCK) {
                        fputs("{\n", codegen->output);
                        codegen->indent_level++;
                        gen_stmt(codegen, arm->result_expr);
                        codegen->indent_level--;
                        c99_emit(codegen, "}\n");
                    } else {
                        gen_expr(codegen, arm->result_expr);
                        fputs(";\n", codegen->output);
                    }
                } else if (arm->kind == MATCH_PAT_ENUM) {
                    ASTNode *enum_decl = find_enum_decl_c99(codegen, arm->data.enum_pat.enum_name);
                    int ev = enum_decl ? find_enum_variant_value(codegen, enum_decl, arm->data.enum_pat.variant_name) : -1;
                    if (ev >= 0) c99_emit(codegen, "%sif (_uya_m == %d) ", prefix, ev);
                    else c99_emit(codegen, "%sif (0) ", prefix);
                    if (arm->result_expr->type == AST_BLOCK) {
                        fputs("{\n", codegen->output);
                        codegen->indent_level++;
                        gen_stmt(codegen, arm->result_expr);
                        codegen->indent_level--;
                        c99_emit(codegen, "}\n");
                    } else {
                        gen_expr(codegen, arm->result_expr);
                        fputs(";\n", codegen->output);
                    }
                } else if (arm->kind == MATCH_PAT_BIND) {
                    const char *v = get_safe_c_identifier(codegen, arm->data.bind.var_name);
                    if (v) c99_emit(codegen, "%s{ %s %s = _uya_m;\n", prefix, m_type, v);
                    else c99_emit(codegen, "%s{\n", prefix);
                    codegen->indent_level++;
                    if (arm->result_expr->type == AST_BLOCK)
                        gen_stmt(codegen, arm->result_expr);
                    else {
                        gen_expr(codegen, arm->result_expr);
                        fputs(";\n", codegen->output);
                    }
                    codegen->indent_level--;
                    c99_emit(codegen, "}\n");
                } else if (arm->kind == MATCH_PAT_WILDCARD || arm->kind == MATCH_PAT_ELSE) {
                    c99_emit(codegen, "%s{\n", prefix);
                    codegen->indent_level++;
                    if (arm->result_expr->type == AST_BLOCK)
                        gen_stmt(codegen, arm->result_expr);
                    else {
                        gen_expr(codegen, arm->result_expr);
                        fputs(";\n", codegen->output);
                    }
                    codegen->indent_level--;
                    c99_emit(codegen, "}\n");
                } else if (arm->kind == MATCH_PAT_ERROR) {
                    unsigned id = arm->data.error_pat.error_name ? get_or_add_error_id(codegen, arm->data.error_pat.error_name) : 0;
                    if (id == 0) id = 1;
                    c99_emit(codegen, "%sif (_uya_m.error_id == %uU) ", prefix, id);
                    if (arm->result_expr->type == AST_BLOCK) {
                        fputs("{\n", codegen->output);
                        codegen->indent_level++;
                        gen_stmt(codegen, arm->result_expr);
                        codegen->indent_level--;
                        c99_emit(codegen, "}\n");
                    } else {
                        gen_expr(codegen, arm->result_expr);
                        fputs(";\n", codegen->output);
                    }
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
                                c99_emit(codegen, "%sif (_uya_m._tag == %d) {\n", prefix, idx);
                                codegen->indent_level++;
                                c99_emit(codegen, "%s %s = _uya_m.u.%s;\n", vtype, bind, vname);
                            } else {
                                c99_emit(codegen, "%sif (_uya_m._tag == %d) ", prefix, idx);
                            }
                            if (arm->result_expr->type == AST_BLOCK) {
                                if (!bind) { fputs("{\n", codegen->output); codegen->indent_level++; }
                                gen_stmt(codegen, arm->result_expr);
                                if (!bind) codegen->indent_level--;
                                c99_emit(codegen, "}\n");
                            } else {
                                gen_expr(codegen, arm->result_expr);
                                fputs(";\n", codegen->output);
                                if (bind) { codegen->indent_level--; c99_emit(codegen, "}\n"); }
                            }
                        }
                    }
                }
            }
            codegen->indent_level--;
            c99_emit(codegen, "}\n");
            break;
        }
        case AST_BREAK_STMT:
            emit_current_block_drops(codegen);
            emit_defer_cleanup(codegen, 0);
            c99_emit(codegen, "break;\n");
            break;
        case AST_CONTINUE_STMT:
            emit_current_block_drops(codegen);
            emit_defer_cleanup(codegen, 0);
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
