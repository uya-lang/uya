#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

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
        case AST_CAST_EXPR:
            collect_slice_types_from_node(codegen, node->data.cast_expr.expr);
            if (node->data.cast_expr.target_type) collect_slice_types_from_node(codegen, node->data.cast_expr.target_type);
            break;
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
        collect_slice_types_from_node(codegen, decls[i]);
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
        if (decl->type == AST_UNION_DECL) {
            gen_union_definition(codegen, decl);
            fputs("\n", codegen->output);
        }
    }
    // 第六步 d：生成所有结构体定义（在切片结构体之后，因为结构体可能含切片字段）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        if (decl->type == AST_STRUCT_DECL) {
            gen_struct_definition(codegen, decl);
            fputs("\n", codegen->output);
        }
    }

    // 第七步：生成所有函数的前向声明（解决相互递归调用）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        if (decl->type == AST_FN_DECL) {
            gen_function_prototype(codegen, decl);
        } else if (decl->type == AST_METHOD_BLOCK) {
            const char *struct_name = decl->data.method_block.struct_name;
            for (int j = 0; j < decl->data.method_block.method_count; j++) {
                ASTNode *m = decl->data.method_block.methods[j];
                if (m && m->type == AST_FN_DECL) {
                    gen_method_prototype(codegen, m, struct_name);
                }
            }
        } else if (decl->type == AST_STRUCT_DECL) {
            // 生成结构体内部定义的方法的前向声明
            const char *struct_name = decl->data.struct_decl.name;
            for (int j = 0; j < decl->data.struct_decl.method_count; j++) {
                ASTNode *m = decl->data.struct_decl.methods[j];
                if (m && m->type == AST_FN_DECL) {
                    gen_method_prototype(codegen, m, struct_name);
                }
            }
        }
    }
    // 第七步 b：生成 vtable 常量（依赖方法前向声明）
    emit_vtable_constants(codegen);
    fputs("\n", codegen->output);

    // 第八步：生成所有声明（全局变量、函数定义）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        
        switch (decl->type) {
            case AST_UNION_DECL:
                break;
            case AST_STRUCT_DECL: {
                // 生成结构体内部定义的方法
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
            case AST_FN_DECL:
                // 只生成有函数体的定义（外部函数由前向声明处理）
                gen_function(codegen, decl);
                fputs("\n", codegen->output);
                break;
            case AST_METHOD_BLOCK: {
                const char *struct_name = decl->data.method_block.struct_name;
                for (int j = 0; j < decl->data.method_block.method_count; j++) {
                    ASTNode *m = decl->data.method_block.methods[j];
                    if (m && m->type == AST_FN_DECL && m->data.fn_decl.body) {
                        gen_method_function(codegen, m, struct_name);
                        fputs("\n", codegen->output);
                    }
                }
                break;
            }
            case AST_ERROR_DECL:
                break;
            // 忽略其他声明类型（暂时）
            default:
                break;
        }
    }
    
    // main() !i32：不在此处生成 main()，由测试时的 bridge.c 提供 main() 并调用 uya_main()
    
    return 0;
}