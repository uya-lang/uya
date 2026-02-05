#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

/* 递归收集所有测试语句（使用固定大小数组，最多 1000 个测试） */
#define MAX_TESTS 1000
static void collect_tests_from_node(C99CodeGenerator *codegen, ASTNode *node, ASTNode **tests, int *test_count) {
    if (!codegen || !node || !tests || !test_count) return;
    if (*test_count >= MAX_TESTS) return;  // 防止溢出
    
    if (node->type == AST_TEST_STMT) {
        // 添加到测试列表
        tests[*test_count] = node;
        (*test_count)++;
    }
    
    // 递归处理子节点
    if (node->type == AST_BLOCK && node->data.block.stmts) {
        for (int i = 0; i < node->data.block.stmt_count; i++) {
            collect_tests_from_node(codegen, node->data.block.stmts[i], tests, test_count);
        }
    } else if (node->type == AST_IF_STMT) {
        collect_tests_from_node(codegen, node->data.if_stmt.then_branch, tests, test_count);
        if (node->data.if_stmt.else_branch) {
            collect_tests_from_node(codegen, node->data.if_stmt.else_branch, tests, test_count);
        }
    } else if (node->type == AST_WHILE_STMT) {
        collect_tests_from_node(codegen, node->data.while_stmt.body, tests, test_count);
    } else if (node->type == AST_FOR_STMT) {
        collect_tests_from_node(codegen, node->data.for_stmt.body, tests, test_count);
    } else if (node->type == AST_FN_DECL && node->data.fn_decl.body) {
        collect_tests_from_node(codegen, node->data.fn_decl.body, tests, test_count);
    }
}

/* 从测试描述字符串生成安全的函数名（使用哈希避免中文问题） */
static const char *get_test_function_name(C99CodeGenerator *codegen, const char *description) {
    if (!description) return NULL;
    
    // 使用简单的哈希函数生成唯一标识符
    unsigned int hash = 0;
    const char *p = description;
    while (*p) {
        hash = hash * 31 + (unsigned char)*p;
        p++;
    }
    
    // 生成函数名：uya_test_<hash>
    char *buf = arena_alloc(codegen->arena, 64);
    if (!buf) return NULL;
    snprintf(buf, 64, "uya_test_%u", hash);
    
    return get_safe_c_identifier(codegen, buf);
}

/* 生成测试函数 */
static void gen_test_function(C99CodeGenerator *codegen, ASTNode *test_stmt) {
    if (!test_stmt || test_stmt->type != AST_TEST_STMT) return;
    
    const char *description = test_stmt->data.test_stmt.description;
    const char *func_name = get_test_function_name(codegen, description);
    ASTNode *body = test_stmt->data.test_stmt.body;
    
    if (!func_name || !body) return;
    
    // 创建 void 类型节点（用于设置 current_function_return_type）
    ASTNode *void_type = ast_new_node(AST_TYPE_NAMED, test_stmt->line, test_stmt->column, codegen->arena, test_stmt->filename);
    if (void_type) {
        void_type->data.type_named.name = "void";
    }
    
    // 保存之前的返回类型
    ASTNode *saved_return_type = codegen->current_function_return_type;
    
    // 设置当前函数的返回类型为 void
    codegen->current_function_return_type = void_type;
    
    // 生成函数定义
    emit_line_directive(codegen, test_stmt->line, test_stmt->filename);
    fprintf(codegen->output, "static void %s(void) {\n", func_name);
    
    // 生成函数体
    gen_stmt(codegen, body);
    
    // 恢复之前的返回类型
    codegen->current_function_return_type = saved_return_type;
    
    fprintf(codegen->output, "}\n");
}

/* 生成测试运行器函数 */
static void gen_test_runner(C99CodeGenerator *codegen, ASTNode **tests, int test_count) {
    if (!tests || test_count <= 0) return;
    
    fprintf(codegen->output, "static void uya_run_tests(void) {\n");
    
    for (int i = 0; i < test_count; i++) {
        ASTNode *test = tests[i];
        if (!test || test->type != AST_TEST_STMT) continue;
        
        const char *func_name = get_test_function_name(codegen, test->data.test_stmt.description);
        if (func_name) {
            fprintf(codegen->output, "    %s();\n", func_name);
        }
    }
    
    fprintf(codegen->output, "}\n");
}

/* 递归收集 AST 中使用的切片类型，以便 step 6b 输出对应 struct */
static void collect_slice_types_from_node(C99CodeGenerator *codegen, ASTNode *node) {
    if (!codegen || !node) return;
    if (node->type == AST_VAR_DECL && node->data.var_decl.type) {
        if (node->data.var_decl.type->type == AST_TYPE_SLICE) {
            (void)c99_type_to_c(codegen, node->data.var_decl.type);
        }
        collect_slice_types_from_node(codegen, node->data.var_decl.type);
        if (node->data.var_decl.init)
            collect_slice_types_from_node(codegen, node->data.var_decl.init);
        return;
    }
    if (node->type == AST_FN_DECL) {
        if (node->data.fn_decl.return_type) {
            if (node->data.fn_decl.return_type->type == AST_TYPE_SLICE)
                (void)c99_type_to_c(codegen, node->data.fn_decl.return_type);
            collect_slice_types_from_node(codegen, node->data.fn_decl.return_type);
        }
        for (int j = 0; j < node->data.fn_decl.param_count && node->data.fn_decl.params; j++) {
            ASTNode *p = node->data.fn_decl.params[j];
            if (p) collect_slice_types_from_node(codegen, p);
        }
        if (node->data.fn_decl.body) collect_slice_types_from_node(codegen, node->data.fn_decl.body);
        return;
    }
    if (node->type == AST_BLOCK && node->data.block.stmts) {
        for (int i = 0; i < node->data.block.stmt_count; i++) {
            collect_slice_types_from_node(codegen, node->data.block.stmts[i]);
        }
        return;
    }
    if (node->type == AST_IF_STMT) {
        collect_slice_types_from_node(codegen, node->data.if_stmt.condition);
        collect_slice_types_from_node(codegen, node->data.if_stmt.then_branch);
        if (node->data.if_stmt.else_branch) collect_slice_types_from_node(codegen, node->data.if_stmt.else_branch);
        return;
    }
    if (node->type == AST_WHILE_STMT) {
        collect_slice_types_from_node(codegen, node->data.while_stmt.condition);
        collect_slice_types_from_node(codegen, node->data.while_stmt.body);
        return;
    }
    if (node->type == AST_FOR_STMT) {
        if (node->data.for_stmt.is_range) {
            collect_slice_types_from_node(codegen, node->data.for_stmt.range_start);
            if (node->data.for_stmt.range_end)
                collect_slice_types_from_node(codegen, node->data.for_stmt.range_end);
        } else {
            collect_slice_types_from_node(codegen, node->data.for_stmt.array);
        }
        collect_slice_types_from_node(codegen, node->data.for_stmt.body);
        return;
    }
    if (node->type == AST_MATCH_EXPR) {
        collect_slice_types_from_node(codegen, node->data.match_expr.expr);
        for (int i = 0; i < node->data.match_expr.arm_count; i++)
            collect_slice_types_from_node(codegen, node->data.match_expr.arms[i].result_expr);
        return;
    }
    if (node->type == AST_RETURN_STMT && node->data.return_stmt.expr) {
        collect_slice_types_from_node(codegen, node->data.return_stmt.expr);
        return;
    }
    /* AST_EXPR_STMT 在 union 中无数据，跳过 */
    if (node->type == AST_ASSIGN) {
        collect_slice_types_from_node(codegen, node->data.assign.dest);
        collect_slice_types_from_node(codegen, node->data.assign.src);
        return;
    }
    if (node->type == AST_SLICE_EXPR) {
        collect_slice_types_from_node(codegen, node->data.slice_expr.base);
        collect_slice_types_from_node(codegen, node->data.slice_expr.start_expr);
        collect_slice_types_from_node(codegen, node->data.slice_expr.len_expr);
        return;
    }
    if (node->type == AST_STRUCT_DECL && node->data.struct_decl.fields) {
        for (int i = 0; i < node->data.struct_decl.field_count; i++) {
            ASTNode *field = node->data.struct_decl.fields[i];
            if (field && field->type == AST_VAR_DECL && field->data.var_decl.type) {
                if (field->data.var_decl.type->type == AST_TYPE_SLICE) {
                    (void)c99_type_to_c(codegen, field->data.var_decl.type);
                }
                collect_slice_types_from_node(codegen, field->data.var_decl.type);
            }
        }
        return;
    }
    /* 其他表达式节点：递归子节点 */
    switch (node->type) {
        case AST_BINARY_EXPR:
            collect_slice_types_from_node(codegen, node->data.binary_expr.left);
            collect_slice_types_from_node(codegen, node->data.binary_expr.right);
            break;
        case AST_UNARY_EXPR:
            collect_slice_types_from_node(codegen, node->data.unary_expr.operand);
            break;
        case AST_TRY_EXPR:
            collect_slice_types_from_node(codegen, node->data.try_expr.operand);
            break;
        case AST_MEMBER_ACCESS:
            collect_slice_types_from_node(codegen, node->data.member_access.object);
            break;
        case AST_ARRAY_ACCESS:
            collect_slice_types_from_node(codegen, node->data.array_access.array);
            collect_slice_types_from_node(codegen, node->data.array_access.index);
            break;
        case AST_CALL_EXPR: {
            collect_slice_types_from_node(codegen, node->data.call_expr.callee);
            for (int i = 0; i < node->data.call_expr.arg_count && node->data.call_expr.args; i++) {
                collect_slice_types_from_node(codegen, node->data.call_expr.args[i]);
            }
            break;
        }
        case AST_CAST_EXPR: {
            collect_slice_types_from_node(codegen, node->data.cast_expr.expr);
            if (node->data.cast_expr.target_type) {
                collect_slice_types_from_node(codegen, node->data.cast_expr.target_type);
                /* as! 强转需要 !T 结构体，预先定义以免在表达式内联生成 */
                if (node->data.cast_expr.is_force_cast) {
                    ASTNode tmp = {0};
                    tmp.type = AST_TYPE_ERROR_UNION;
                    tmp.data.type_error_union.payload_type = node->data.cast_expr.target_type;
                    (void)c99_type_to_c(codegen, &tmp);
                }
            }
            break;
        }
        case AST_LEN:
            collect_slice_types_from_node(codegen, node->data.len_expr.array);
            break;
        case AST_SIZEOF:
            if (node->data.sizeof_expr.target) {
                if (node->data.sizeof_expr.is_type && node->data.sizeof_expr.target->type == AST_TYPE_SLICE) {
                    (void)c99_type_to_c(codegen, node->data.sizeof_expr.target);
                }
                collect_slice_types_from_node(codegen, node->data.sizeof_expr.target);
            }
            break;
        default:
            break;
    }
}

int c99_codegen_generate(C99CodeGenerator *codegen, ASTNode *ast, const char *output_file) {
    if (!codegen || !ast || !output_file) {
        return -1;
    }
    
    // 检查是否是程序节点
    if (ast->type != AST_PROGRAM) {
        return -1;
    }
    
    // 保存程序节点引用
    codegen->program_node = ast;
    
    // 输出文件头
    fputs("// C99 代码由 Uya Mini 编译器生成\n", codegen->output);
    fputs("// 使用 -std=c99 编译\n", codegen->output);
    fputs("//\n", codegen->output);
    fputs("#include <stdint.h>\n", codegen->output);
    fputs("#include <stdbool.h>\n", codegen->output);
    fputs("#include <stddef.h>\n", codegen->output);
    fputs("#include <stdarg.h>\n", codegen->output);  // for va_list (variadic forward)
    fputs("#include <string.h>\n", codegen->output);  // for memcmp
    fputs("#include <stdio.h>\n", codegen->output);  // for standard I/O functions (printf, puts, etc.)
    fputs("\n", codegen->output);
    // C99 兼容的 alignof 宏（使用 offsetof 技巧）
    fputs("// C99 兼容的 alignof 实现\n", codegen->output);
    fputs("#define uya_alignof(type) offsetof(struct { char c; type t; }, t)\n", codegen->output);
    fputs("\n", codegen->output);
    
    // 第一步：收集所有字符串常量（从全局变量初始化和函数体）
    ASTNode **decls = ast->data.program.decls;
    int decl_count = ast->data.program.decl_count;
    
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        // 跳过 use 语句（模块导入，不包含字符串常量）
        if (decl->type == AST_USE_STMT) continue;
        if (decl->type == AST_MACRO_DECL) continue;  /* 宏不生成代码，编译时已展开 */
        collect_string_constants_from_decl(codegen, decl);
    }
    
    // 第二步：输出字符串常量定义（在所有其他代码之前）
    emit_string_constants(codegen);
    fputs("\n", codegen->output);
    
    // 第三步：收集错误名称（error Name; 及后续 error.X 使用）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_ERROR_DECL) continue;
        if (decl->data.error_decl.name) {
            get_or_add_error_id(codegen, decl->data.error_decl.name);
        }
    }
    
    // 第四步：收集所有结构体和枚举定义（添加到表中但不生成代码）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        
        if (decl->type == AST_STRUCT_DECL) {
            const char *struct_name = get_safe_c_identifier(codegen, decl->data.struct_decl.name);
            if (!is_struct_in_table(codegen, struct_name)) {
                add_struct_definition(codegen, struct_name);
            }
        } else if (decl->type == AST_ENUM_DECL) {
            const char *enum_name = get_safe_c_identifier(codegen, decl->data.enum_decl.name);
            if (!is_enum_in_table(codegen, enum_name)) {
                add_enum_definition(codegen, enum_name);
            }
        }
    }
    
    // 第四步：生成所有结构体的前向声明（解决相互依赖）
    // 首先添加内置 TypeInfo 的前向声明（用于 @mc_type）
    fputs("struct TypeInfo;\n", codegen->output);
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (!is_struct_defined(codegen, codegen->struct_definitions[i].name)) {
            fprintf(codegen->output, "struct %s;\n", codegen->struct_definitions[i].name);
        }
    }
    if (codegen->struct_definition_count > 0) {
        fputs("\n", codegen->output);
    }

    // 第五步：生成所有枚举定义（在结构体之前，因为结构体可能使用枚举类型）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        if (decl->type == AST_ENUM_DECL) {
            gen_enum_definition(codegen, decl);
            fputs("\n", codegen->output);
        }
    }
    
    // 第六步 a：收集所有使用的切片类型（含结构体字段中的 &[T]）
    for (int i = 0; i < decl_count; i++) {
        if (decls[i] && decls[i]->type != AST_USE_STMT && decls[i]->type != AST_MACRO_DECL) {
            collect_slice_types_from_node(codegen, decls[i]);
        }
    }
    // 第六步 b：生成切片结构体（&[T] -> struct uya_slice_X），必须在用户结构体之前
    emit_pending_slice_structs(codegen);
    if (codegen->slice_struct_count > 0) {
        fputs("\n", codegen->output);
    }
    // 第六步 b2：生成接口结构体与 vtable 结构体（vtable 常量在函数前向声明之后生成）
    emit_interface_structs_and_vtables(codegen);
    fputs("\n", codegen->output);
    // 第六步 c：生成联合体定义（在结构体之前，因结构体可能含联合体）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        if (decl->type == AST_USE_STMT || decl->type == AST_MACRO_DECL) continue;
        if (decl->type == AST_UNION_DECL) {
            gen_union_definition(codegen, decl);
            fputs("\n", codegen->output);
        }
    }
    // 第六步 d1：自动生成内置 TypeInfo 结构体（如果用户没有定义且代码中使用了 @mc_type）
    // TypeInfo 用于 @mc_type 编译时类型反射，包含类型的元信息
    {
        int user_defined_typeinfo = 0;
        for (int i = 0; i < decl_count; i++) {
            ASTNode *decl = decls[i];
            if (decl && decl->type == AST_STRUCT_DECL && decl->data.struct_decl.name &&
                strcmp(decl->data.struct_decl.name, "TypeInfo") == 0) {
                user_defined_typeinfo = 1;
                break;
            }
        }
        if (!user_defined_typeinfo && !is_struct_defined(codegen, "TypeInfo")) {
            // 生成内置 TypeInfo 结构体
            fputs("// 内置 TypeInfo 结构体（由 @mc_type 使用）\n", codegen->output);
            fputs("struct TypeInfo {\n", codegen->output);
            fputs("    int8_t * name;\n", codegen->output);
            fputs("    int32_t size;\n", codegen->output);
            fputs("    int32_t align;\n", codegen->output);
            fputs("    int32_t kind;\n", codegen->output);
            fputs("    bool is_integer;\n", codegen->output);
            fputs("    bool is_float;\n", codegen->output);
            fputs("    bool is_bool;\n", codegen->output);
            fputs("    bool is_pointer;\n", codegen->output);
            fputs("    bool is_array;\n", codegen->output);
            fputs("    bool is_void;\n", codegen->output);
            fputs("};\n\n", codegen->output);
            mark_struct_defined(codegen, "TypeInfo");
        }
    }
    
    // 第六步 d2：生成所有结构体定义（在切片结构体之后，因为结构体可能含切片字段）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        if (decl->type == AST_USE_STMT || decl->type == AST_MACRO_DECL) continue;
        if (decl->type == AST_STRUCT_DECL) {
            gen_struct_definition(codegen, decl);
            fputs("\n", codegen->output);
        }
    }

    // 第七步：生成所有函数的前向声明（解决相互递归调用）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        if (decl->type == AST_USE_STMT || decl->type == AST_MACRO_DECL) continue;
        if (decl->type == AST_FN_DECL) {
            gen_function_prototype(codegen, decl);
        } else if (decl->type == AST_METHOD_BLOCK) {
            const char *type_name = decl->data.method_block.struct_name ? decl->data.method_block.struct_name : decl->data.method_block.union_name;
            if (type_name) {
                for (int j = 0; j < decl->data.method_block.method_count; j++) {
                    ASTNode *m = decl->data.method_block.methods[j];
                    if (m && m->type == AST_FN_DECL) {
                        gen_method_prototype(codegen, m, type_name);
                    }
                }
            }
        } else if (decl->type == AST_STRUCT_DECL) {
            const char *struct_name = decl->data.struct_decl.name;
            for (int j = 0; j < decl->data.struct_decl.method_count; j++) {
                ASTNode *m = decl->data.struct_decl.methods[j];
                if (m && m->type == AST_FN_DECL) {
                    gen_method_prototype(codegen, m, struct_name);
                }
            }
        } else if (decl->type == AST_UNION_DECL) {
            const char *union_name = decl->data.union_decl.name;
            for (int j = 0; j < decl->data.union_decl.method_count; j++) {
                ASTNode *m = decl->data.union_decl.methods[j];
                if (m && m->type == AST_FN_DECL) {
                    gen_method_prototype(codegen, m, union_name);
                }
            }
        }
    }
    // 第七步 b：生成 vtable 常量（依赖方法前向声明）
    emit_vtable_constants(codegen);
    fputs("\n", codegen->output);

    // 第七步 c：收集所有测试语句
    ASTNode *tests[MAX_TESTS];
    int test_count = 0;
    
    // 从程序顶层声明中收集测试语句
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        if (decl->type == AST_USE_STMT || decl->type == AST_MACRO_DECL) continue;
        
        // 顶层测试语句
        if (decl->type == AST_TEST_STMT) {
            if (test_count < MAX_TESTS) {
                tests[test_count] = decl;
                test_count++;
            }
        }
        
        // 从函数体内收集测试（包括嵌套块中的测试）
        if (decl->type == AST_FN_DECL && decl->data.fn_decl.body) {
            collect_tests_from_node(codegen, decl->data.fn_decl.body, tests, &test_count);
        }
    }
    
    // 生成测试函数前向声明
    if (test_count > 0) {
        for (int i = 0; i < test_count; i++) {
            ASTNode *test = tests[i];
            if (!test || test->type != AST_TEST_STMT) continue;
            const char *func_name = get_test_function_name(codegen, test->data.test_stmt.description);
            if (func_name) {
                fprintf(codegen->output, "static void %s(void);\n", func_name);
            }
        }
        fprintf(codegen->output, "static void uya_run_tests(void);\n");
        fputs("\n", codegen->output);
    }

    // 第八步：生成所有声明（全局变量、函数定义）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        
        // 跳过 use 语句（模块导入，不需要生成代码）
        if (decl->type == AST_USE_STMT) continue;
        if (decl->type == AST_MACRO_DECL) continue;  /* 宏不生成代码，编译时已展开 */
        
        switch (decl->type) {
            case AST_UNION_DECL: {
                const char *union_name = decl->data.union_decl.name;
                for (int j = 0; j < decl->data.union_decl.method_count; j++) {
                    ASTNode *m = decl->data.union_decl.methods[j];
                    if (m && m->type == AST_FN_DECL && m->data.fn_decl.body) {
                        gen_method_function(codegen, m, union_name);
                        fputs("\n", codegen->output);
                    }
                }
                break;
            }
            case AST_STRUCT_DECL: {
                const char *struct_name = decl->data.struct_decl.name;
                for (int j = 0; j < decl->data.struct_decl.method_count; j++) {
                    ASTNode *m = decl->data.struct_decl.methods[j];
                    if (m && m->type == AST_FN_DECL && m->data.fn_decl.body) {
                        gen_method_function(codegen, m, struct_name);
                        fputs("\n", codegen->output);
                    }
                }
                break;
            }
            case AST_ENUM_DECL:
                // 已在前面生成
                break;
            case AST_VAR_DECL:
                gen_global_var(codegen, decl);
                fputs("\n", codegen->output);
                break;
            case AST_FN_DECL: {
                // 特殊处理：main 函数在第九步生成（需要添加测试运行器调用）
                const char *func_name = decl->data.fn_decl.name;
                int is_main = (func_name && strcmp(func_name, "main") == 0) ? 1 : 0;
                if (!is_main) {
                    // 只生成有函数体的定义（外部函数由前向声明处理）
                    gen_function(codegen, decl);
                    fputs("\n", codegen->output);
                }
                break;
            }
            case AST_METHOD_BLOCK: {
                const char *type_name = decl->data.method_block.struct_name ? decl->data.method_block.struct_name : decl->data.method_block.union_name;
                if (type_name) {
                    for (int j = 0; j < decl->data.method_block.method_count; j++) {
                        ASTNode *m = decl->data.method_block.methods[j];
                        if (m && m->type == AST_FN_DECL && m->data.fn_decl.body) {
                            gen_method_function(codegen, m, type_name);
                            fputs("\n", codegen->output);
                        }
                    }
                }
                break;
            }
            case AST_ERROR_DECL:
                break;
            case AST_TEST_STMT:
                // 测试语句在下面统一生成
                break;
            // 忽略其他声明类型（暂时）
            default:
                break;
        }
    }
    
    // 第八步 b：生成所有测试函数和测试运行器
    if (test_count > 0) {
        for (int i = 0; i < test_count; i++) {
            gen_test_function(codegen, tests[i]);
            fputs("\n", codegen->output);
        }
        gen_test_runner(codegen, tests, test_count);
        fputs("\n", codegen->output);
    }
    
    // 第九步：生成 main 函数（uya_main），在开始时调用测试运行器
    // 查找 main 函数并生成
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_FN_DECL) continue;
        const char *func_name = decl->data.fn_decl.name;
        if (func_name && strcmp(func_name, "main") == 0 && decl->data.fn_decl.body) {
            // 生成 main 函数（重命名为 uya_main）
            emit_line_directive(codegen, decl->line, decl->filename);
            const char *return_c = convert_array_return_type(codegen, decl->data.fn_decl.return_type);
            fprintf(codegen->output, "%s uya_main(void) {\n", return_c);
            
            // 保存并设置当前函数的返回类型（用于生成返回语句）
            ASTNode *saved_return_type = codegen->current_function_return_type;
            codegen->current_function_return_type = decl->data.fn_decl.return_type;
            
            // 如果有测试，在函数体开始处调用测试运行器
            if (test_count > 0) {
                fprintf(codegen->output, "    uya_run_tests();\n");
            }
            
            // 生成原始函数体
            ASTNode *body = decl->data.fn_decl.body;
            if (body && body->type == AST_BLOCK) {
                ASTNode **stmts = body->data.block.stmts;
                int stmt_count = body->data.block.stmt_count;
                for (int j = 0; j < stmt_count; j++) {
                    gen_stmt(codegen, stmts[j]);
                }
            }
            
            // 恢复之前的返回类型
            codegen->current_function_return_type = saved_return_type;
            
            fprintf(codegen->output, "}\n");
            break;
        }
    }
    
    // 如果没有 main 函数，则不生成 uya_main（由测试时的 bridge.c 提供 main() 并调用 uya_main()）
    
    return 0;
}