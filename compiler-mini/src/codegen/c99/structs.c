#include "internal.h"
#include <string.h>

// 检查结构体是否已添加到表中
int is_struct_in_table(C99CodeGenerator *codegen, const char *struct_name) {
    if (!struct_name) return 0;
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (codegen->struct_definitions[i].name && 
            strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            return 1;
        }
    }
    return 0;
}

// 检查结构体是否已定义
int is_struct_defined(C99CodeGenerator *codegen, const char *struct_name) {
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            return codegen->struct_definitions[i].defined;
        }
    }
    return 0;
}

// 标记结构体已定义
void mark_struct_defined(C99CodeGenerator *codegen, const char *struct_name) {
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            codegen->struct_definitions[i].defined = 1;
            return;
        }
    }
    
    // 如果不在表中，添加
    if (codegen->struct_definition_count < C99_MAX_STRUCT_DEFINITIONS) {
        codegen->struct_definitions[codegen->struct_definition_count].name = struct_name;
        codegen->struct_definitions[codegen->struct_definition_count].defined = 1;
        codegen->struct_definition_count++;
    }
}

// 添加结构体定义
void add_struct_definition(C99CodeGenerator *codegen, const char *struct_name) {
    if (is_struct_defined(codegen, struct_name)) {
        return;
    }
    
    if (codegen->struct_definition_count < C99_MAX_STRUCT_DEFINITIONS) {
        codegen->struct_definitions[codegen->struct_definition_count].name = struct_name;
        codegen->struct_definitions[codegen->struct_definition_count].defined = 0;
        codegen->struct_definition_count++;
    }
}

// 检查结构体是否实现某接口
int struct_implements_interface_c99(C99CodeGenerator *codegen, const char *struct_name, const char *interface_name) {
    ASTNode *s = find_struct_decl_c99(codegen, struct_name);
    if (!s || s->type != AST_STRUCT_DECL || !s->data.struct_decl.interface_names) return 0;
    for (int i = 0; i < s->data.struct_decl.interface_count; i++) {
        if (s->data.struct_decl.interface_names[i] &&
            strcmp(s->data.struct_decl.interface_names[i], interface_name) == 0) {
            return 1;
        }
    }
    return 0;
}

// 查找接口声明
ASTNode *find_interface_decl_c99(C99CodeGenerator *codegen, const char *interface_name) {
    if (!codegen || !interface_name || !codegen->program_node) {
        return NULL;
    }
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_INTERFACE_DECL) continue;
        const char *decl_name = decl->data.interface_decl.name;
        if (decl_name && strcmp(decl_name, interface_name) == 0) {
            return decl;
        }
    }
    return NULL;
}

// 查找结构体声明
ASTNode *find_struct_decl_c99(C99CodeGenerator *codegen, const char *struct_name) {
    if (!codegen || !struct_name || !codegen->program_node) {
        return NULL;
    }
    
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_STRUCT_DECL) {
            continue;
        }
        
        const char *decl_name = decl->data.struct_decl.name;
        if (decl_name && strcmp(decl_name, struct_name) == 0) {
            return decl;
        }
    }
    
    return NULL;
}

// 查找联合体声明
ASTNode *find_union_decl_c99(C99CodeGenerator *codegen, const char *union_name) {
    if (!codegen || !union_name || !codegen->program_node) {
        return NULL;
    }
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_UNION_DECL) continue;
        const char *decl_name = decl->data.union_decl.name;
        if (decl_name && strcmp(decl_name, union_name) == 0) {
            return decl;
        }
    }
    return NULL;
}

// 根据变体名查找包含该变体的联合体声明（用于 match 代码生成）
ASTNode *find_union_decl_by_variant_c99(C99CodeGenerator *codegen, const char *variant_name) {
    if (!codegen || !codegen->program_node || !variant_name) return NULL;
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_UNION_DECL) continue;
        if (find_union_variant_index(decl, variant_name) >= 0) return decl;
    }
    return NULL;
}

// 根据 C 类型后缀（如 "uya_tagged_IntOrFloat"）查找联合体声明
ASTNode *find_union_decl_by_tagged_c99(C99CodeGenerator *codegen, const char *tagged_suffix) {
    if (!codegen || !codegen->program_node || !tagged_suffix || strncmp(tagged_suffix, "uya_tagged_", 11) != 0) return NULL;
    const char *suffix = tagged_suffix + 11;
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_UNION_DECL) continue;
        const char *safe = get_safe_c_identifier(codegen, decl->data.union_decl.name);
        if (safe && strcmp(suffix, safe) == 0) return decl;
    }
    return NULL;
}

// 返回联合体变体索引（0-based），不存在返回 -1
int find_union_variant_index(ASTNode *union_decl, const char *variant_name) {
    if (!union_decl || union_decl->type != AST_UNION_DECL || !variant_name) return -1;
    for (int i = 0; i < union_decl->data.union_decl.variant_count; i++) {
        ASTNode *v = union_decl->data.union_decl.variants[i];
        if (v && v->type == AST_VAR_DECL && v->data.var_decl.name &&
            strcmp(v->data.var_decl.name, variant_name) == 0) {
            return i;
        }
    }
    return -1;
}

// 生成联合体定义：普通联合体生成 union U { ... }; struct uya_tagged_U { ... }；extern union 仅生成 union U { ... };
int gen_union_definition(C99CodeGenerator *codegen, ASTNode *union_decl) {
    if (!codegen || !union_decl || union_decl->type != AST_UNION_DECL) return -1;
    const char *union_name = get_safe_c_identifier(codegen, union_decl->data.union_decl.name);
    if (!union_name) return -1;
    int n = union_decl->data.union_decl.variant_count;
    ASTNode **variants = union_decl->data.union_decl.variants;
    if (n <= 0 || !variants) return -1;
    int is_extern = union_decl->data.union_decl.is_extern;
    c99_emit(codegen, "union %s {\n", union_name);
    codegen->indent_level++;
    for (int i = 0; i < n; i++) {
        ASTNode *v = variants[i];
        if (!v || v->type != AST_VAR_DECL || !v->data.var_decl.name || !v->data.var_decl.type) continue;
        const char *vname = get_safe_c_identifier(codegen, v->data.var_decl.name);
        const char *vtype = c99_type_to_c(codegen, v->data.var_decl.type);
        if (vname && vtype) c99_emit(codegen, "%s %s;\n", vtype, vname);
    }
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    if (!is_extern)
        c99_emit(codegen, "struct uya_tagged_%s { int _tag; union %s u; };\n", union_name, union_name);
    return 0;
}

// 从 C 类型字符串（如 "struct Data"）中提取结构体名并查找声明
ASTNode *find_struct_decl_from_type_c(C99CodeGenerator *codegen, const char *type_c) {
    if (!codegen || !type_c || !codegen->program_node) {
        return NULL;
    }
    const char *p = strstr(type_c, "struct ");
    if (!p) {
        return NULL;
    }
    p += 7;  /* skip "struct " */
    const char *start = p;
    while (*p && *p != ' ' && *p != '*') {
        p++;
    }
    if (p == start) {
        return NULL;
    }
    /* 提取的名称可能是 "Data" 等，与 get_safe_c_identifier 结果一致 */
    char name_buf[128];
    size_t len = (size_t)(p - start);
    if (len >= sizeof(name_buf)) {
        len = sizeof(name_buf) - 1;
    }
    memcpy(name_buf, start, len);
    name_buf[len] = '\0';
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_STRUCT_DECL) {
            continue;
        }
        const char *safe = get_safe_c_identifier(codegen, decl->data.struct_decl.name);
        if (safe && strcmp(safe, name_buf) == 0) {
            return decl;
        }
    }
    return NULL;
}

// 查找结构体字段类型
ASTNode *find_struct_field_type(C99CodeGenerator *codegen, ASTNode *struct_decl, const char *field_name) {
    if (!codegen || !struct_decl || struct_decl->type != AST_STRUCT_DECL || !field_name) {
        return NULL;
    }
    
    for (int i = 0; i < struct_decl->data.struct_decl.field_count; i++) {
        ASTNode *field = struct_decl->data.struct_decl.fields[i];
        if (field && field->type == AST_VAR_DECL) {
            if (field->data.var_decl.name && strcmp(field->data.var_decl.name, field_name) == 0) {
                return field->data.var_decl.type;
            }
        }
    }
    
    return NULL;
}

// 生成结构体定义
int gen_struct_definition(C99CodeGenerator *codegen, ASTNode *struct_decl) {
    if (!struct_decl || struct_decl->type != AST_STRUCT_DECL) {
        return -1;
    }
    
    const char *struct_name = get_safe_c_identifier(codegen, struct_decl->data.struct_decl.name);
    if (!struct_name) {
        return -1;
    }
    
    // 如果已定义，跳过
    if (is_struct_defined(codegen, struct_name)) {
        return 0;
    }
    
    // 添加结构体定义标记
    add_struct_definition(codegen, struct_name);
    
    // 输出结构体定义
    c99_emit(codegen, "struct %s {\n", struct_name);
    codegen->indent_level++;
    
    // 生成字段
    int field_count = struct_decl->data.struct_decl.field_count;
    ASTNode **fields = struct_decl->data.struct_decl.fields;
    
    // 如果是空结构体，添加一个占位符字段以确保大小为 1（符合 Uya 规范）
    if (field_count == 0) {
        c99_emit(codegen, "char _empty;\n");
    } else {
        for (int i = 0; i < field_count; i++) {
            ASTNode *field = fields[i];
            if (!field || field->type != AST_VAR_DECL) {
                return -1;
            }
            
            const char *field_name = get_safe_c_identifier(codegen, field->data.var_decl.name);
            ASTNode *field_type = field->data.var_decl.type;
            
            if (!field_name || !field_type) {
                return -1;
            }
            
            // 检查是否为数组类型
            if (field_type->type == AST_TYPE_ARRAY) {
                ASTNode *element_type = field_type->data.type_array.element_type;
                ASTNode *size_expr = field_type->data.type_array.size_expr;
                const char *elem_type_c = c99_type_to_c(codegen, element_type);
                
                // 评估数组大小
                int array_size = -1;
                if (size_expr) {
                    array_size = eval_const_expr(codegen, size_expr);
                    if (array_size <= 0) {
                        array_size = 1;  // 占位符
                    }
                } else {
                    array_size = 1;  // 占位符
                }
                
                c99_emit(codegen, "%s %s[%d];\n", elem_type_c, field_name, array_size);
            } else {
                const char *field_type_c = c99_type_to_c(codegen, field_type);
                c99_emit(codegen, "%s %s;\n", field_type_c, field_name);
            }
        }
    }
    
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    
    // 标记为已定义
    mark_struct_defined(codegen, struct_name);
    return 0;
}

// 预先生成接口方法签名中使用的错误联合类型结构体定义
static void pregenerate_error_union_structs_for_interface(C99CodeGenerator *codegen, ASTNode *iface_decl) {
    if (!codegen || !iface_decl || iface_decl->type != AST_INTERFACE_DECL) return;
    
    // 遍历所有方法签名，收集错误联合类型
    for (int j = 0; j < iface_decl->data.interface_decl.method_sig_count; j++) {
        ASTNode *msig = iface_decl->data.interface_decl.method_sigs[j];
        if (!msig || msig->type != AST_FN_DECL) continue;
        
        // 检查返回类型
        ASTNode *ret_type = msig->data.fn_decl.return_type;
        if (ret_type && ret_type->type == AST_TYPE_ERROR_UNION) {
            // 预先生成错误联合类型结构体定义（通过调用 c99_type_to_c）
            const char *ret_c = c99_type_to_c(codegen, ret_type);
            (void)ret_c;  // 避免未使用变量警告
        }
        
        // 检查参数类型
        if (msig->data.fn_decl.params) {
            for (int k = 1; k < msig->data.fn_decl.param_count; k++) {
                ASTNode *p = msig->data.fn_decl.params[k];
                if (!p || p->type != AST_VAR_DECL) continue;
                ASTNode *pt = p->data.var_decl.type;
                if (pt && pt->type == AST_TYPE_ERROR_UNION) {
                    // 预先生成错误联合类型结构体定义
                    const char *pt_c = c99_type_to_c(codegen, pt);
                    (void)pt_c;  // 避免未使用变量警告
                }
            }
        }
    }
}

// 生成接口值结构体与 vtable 结构体（不含 vtable 常量，常量需在方法前向声明之后生成）
void emit_interface_structs_and_vtables(C99CodeGenerator *codegen) {
    if (!codegen || !codegen->program_node) return;
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    
    // 第一步：预先生成所有接口方法签名中使用的错误联合类型结构体定义
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_INTERFACE_DECL) continue;
        pregenerate_error_union_structs_for_interface(codegen, decl);
    }
    
    // 第二步：生成接口值结构体与 vtable 结构体
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_INTERFACE_DECL) continue;
        const char *iface_name = decl->data.interface_decl.name;
        if (!iface_name) continue;
        const char *safe_iface = get_safe_c_identifier(codegen, iface_name);
        c99_emit(codegen, "struct uya_interface_%s { void *vtable; void *data; };\n", safe_iface);
        c99_emit(codegen, "struct uya_vtable_%s {\n", safe_iface);
        codegen->indent_level++;
        for (int j = 0; j < decl->data.interface_decl.method_sig_count; j++) {
            ASTNode *msig = decl->data.interface_decl.method_sigs[j];
            if (!msig || msig->type != AST_FN_DECL) continue;
            const char *ret_c = convert_array_return_type(codegen, msig->data.fn_decl.return_type);
            const char *mname = get_safe_c_identifier(codegen, msig->data.fn_decl.name);
            int pc = msig->data.fn_decl.param_count;
            fprintf(codegen->output, "%*s%s (*%s)(void *self", codegen->indent_level * 4, "", ret_c, mname);
            for (int k = 1; k < pc && msig->data.fn_decl.params; k++) {
                ASTNode *p = msig->data.fn_decl.params[k];
                if (!p || p->type != AST_VAR_DECL) continue;
                const char *pt_c = c99_type_to_c(codegen, p->data.var_decl.type);
                fprintf(codegen->output, ", %s", pt_c);
            }
            fputs(");\n", codegen->output);
        }
        codegen->indent_level--;
        c99_emit(codegen, "};\n");
    }
}

// 生成各 struct:interface 的 vtable 常量（需在方法前向声明之后调用）
void emit_vtable_constants(C99CodeGenerator *codegen) {
    if (!codegen || !codegen->program_node) return;
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_STRUCT_DECL) continue;
        const char *struct_name = decl->data.struct_decl.name;
        const char **iface_names = decl->data.struct_decl.interface_names;
        int iface_count = decl->data.struct_decl.interface_count;
        if (!iface_names || iface_count <= 0) continue;
        const char *safe_struct = get_safe_c_identifier(codegen, struct_name);
        for (int j = 0; j < iface_count; j++) {
            const char *iface_name = iface_names[j];
            if (!iface_name) continue;
            ASTNode *iface_decl = find_interface_decl_c99(codegen, iface_name);
            if (!iface_decl) continue;
            const char *safe_iface = get_safe_c_identifier(codegen, iface_name);
            fprintf(codegen->output, "static const struct uya_vtable_%s uya_vtable_%s_%s = { ",
                    safe_iface, safe_iface, safe_struct);
            for (int k = 0; k < iface_decl->data.interface_decl.method_sig_count; k++) {
                ASTNode *msig = iface_decl->data.interface_decl.method_sigs[k];
                if (!msig || msig->type != AST_FN_DECL) continue;
                const char *mname = msig->data.fn_decl.name;
                // 使用 find_method_in_struct_c99 同时查找外部方法块和内部方法
                ASTNode *impl = find_method_in_struct_c99(codegen, struct_name, mname);
                if (!impl) continue;
                const char *cname = get_method_c_name(codegen, struct_name, mname);
                if (k > 0) fputs(", ", codegen->output);
                /* 函数指针转换 (S*)->(void*) 以匹配 vtable 签名 */
                if (cname) {
                    const char *ret_c = convert_array_return_type(codegen, msig->data.fn_decl.return_type);
                    int pc = msig->data.fn_decl.param_count;
                    fprintf(codegen->output, "(%s (*)(void *self", ret_c);
                    for (int ki = 1; ki < pc && msig->data.fn_decl.params; ki++) {
                        ASTNode *pk = msig->data.fn_decl.params[ki];
                        if (pk && pk->type == AST_VAR_DECL) {
                            fprintf(codegen->output, ", %s", c99_type_to_c(codegen, pk->data.var_decl.type));
                        }
                    }
                    fprintf(codegen->output, "))&%s", cname);
                } else {
                    fputs("NULL", codegen->output);
                }
            }
            fputs(" };\n", codegen->output);
        }
    }
}

/* 收集泛型结构体实例化（用于单态化） */
void collect_generic_struct_instance(C99CodeGenerator *codegen, ASTNode *type_node) {
    if (!codegen || !type_node || type_node->type != AST_TYPE_NAMED) {
        return;
    }
    
    // 检查是否有类型参数（如 Vec<i32>）
    if (type_node->data.type_named.type_arg_count == 0) {
        return;  // 不是泛型类型
    }
    
    const char *struct_name = type_node->data.type_named.name;
    if (!struct_name) {
        return;
    }
    
    // 检查类型参数是否都是具体类型（不是类型参数本身）
    // 如果类型参数是类型参数（如 T），则不应该收集
    for (int i = 0; i < type_node->data.type_named.type_arg_count; i++) {
        ASTNode *type_arg = type_node->data.type_named.type_args[i];
        if (!type_arg) {
            return;  // 类型参数为空，跳过
        }
        // 如果类型参数是命名类型且没有类型参数，检查是否是基础类型或结构体
        if (type_arg->type == AST_TYPE_NAMED && type_arg->data.type_named.type_arg_count == 0) {
            const char *type_arg_name = type_arg->data.type_named.name;
            if (!type_arg_name) {
                return;  // 类型参数名称为空，跳过
            }
            // 检查是否是基础类型
            int is_basic_type = (strcmp(type_arg_name, "i8") == 0 || strcmp(type_arg_name, "i16") == 0 ||
                                 strcmp(type_arg_name, "i32") == 0 || strcmp(type_arg_name, "i64") == 0 ||
                                 strcmp(type_arg_name, "u8") == 0 || strcmp(type_arg_name, "u16") == 0 ||
                                 strcmp(type_arg_name, "u32") == 0 || strcmp(type_arg_name, "u64") == 0 ||
                                 strcmp(type_arg_name, "usize") == 0 || strcmp(type_arg_name, "bool") == 0 ||
                                 strcmp(type_arg_name, "byte") == 0 || strcmp(type_arg_name, "f32") == 0 ||
                                 strcmp(type_arg_name, "f64") == 0 || strcmp(type_arg_name, "void") == 0);
            if (!is_basic_type) {
                // 检查是否是结构体声明（不是类型参数）
                ASTNode *arg_struct_decl = find_struct_decl_c99(codegen, type_arg_name);
                if (!arg_struct_decl) {
                    // 不是结构体声明，可能是类型参数，跳过这个实例化
                    return;
                }
            }
        }
    }
    
    // 查找泛型结构体声明
    ASTNode *generic_struct_decl = find_struct_decl_c99(codegen, struct_name);
    if (!generic_struct_decl || generic_struct_decl->type != AST_STRUCT_DECL) {
        return;  // 找不到结构体声明或不是结构体声明
    }
    
    if (generic_struct_decl->data.struct_decl.type_param_count == 0) {
        return;  // 不是泛型结构体
    }
    
    // 生成实例化名称（如 uya_Vec_i32）
    const char *instance_name = c99_type_to_c(codegen, type_node);
    if (!instance_name) {
        return;
    }
    
    // 移除 "struct " 前缀（如果有）
    const char *name_without_struct = instance_name;
    if (strncmp(instance_name, "struct ", 7) == 0) {
        name_without_struct = instance_name + 7;
    }
    
    // 检查是否已经收集过这个实例化（避免重复）
    for (int i = 0; i < codegen->generic_struct_instance_count; i++) {
        if (codegen->generic_struct_instances[i].instance_name && 
            strcmp(codegen->generic_struct_instances[i].instance_name, name_without_struct) == 0) {
            return;  // 已经收集过
        }
    }
    
    if (codegen->generic_struct_instance_count >= C99_MAX_GENERIC_INSTANCES) {
        return;  // 实例化数量已达上限
    }
    
    // 复制类型参数数组
    ASTNode **type_args = type_node->data.type_named.type_args;
    int type_arg_count = type_node->data.type_named.type_arg_count;
    
    ASTNode **type_args_copy = arena_alloc(codegen->arena, sizeof(ASTNode *) * type_arg_count);
    if (!type_args_copy) return;
    for (int i = 0; i < type_arg_count; i++) {
        type_args_copy[i] = type_args[i];
    }
    
    // 复制实例化名称
    const char *instance_name_copy = arena_strdup(codegen->arena, name_without_struct);
    if (!instance_name_copy) return;
    
    // 添加到实例化列表
    struct GenericStructInstance *inst = &codegen->generic_struct_instances[codegen->generic_struct_instance_count];
    inst->generic_struct_decl = generic_struct_decl;
    inst->type_args = type_args_copy;
    inst->type_arg_count = type_arg_count;
    inst->instance_name = instance_name_copy;
    codegen->generic_struct_instance_count++;
}

/* 从 AST 节点递归收集所有泛型结构体实例化 */
void collect_generic_struct_instances_from_node(C99CodeGenerator *codegen, ASTNode *node) {
    if (!codegen || !node) return;
    
    // 处理类型节点（变量声明、函数参数、函数返回类型等）
    switch (node->type) {
        case AST_TYPE_NAMED:
            // 检查是否是泛型结构体类型（如 Vec<i32>）
            collect_generic_struct_instance(codegen, node);
            // 递归处理类型参数
            if (node->data.type_named.type_args) {
                for (int i = 0; i < node->data.type_named.type_arg_count; i++) {
                    if (node->data.type_named.type_args[i]) {
                        collect_generic_struct_instances_from_node(codegen, node->data.type_named.type_args[i]);
                    }
                }
            }
            break;
        case AST_TYPE_POINTER:
            if (node->data.type_pointer.pointed_type) {
                collect_generic_struct_instances_from_node(codegen, node->data.type_pointer.pointed_type);
            }
            break;
        case AST_TYPE_ARRAY:
            if (node->data.type_array.element_type) {
                collect_generic_struct_instances_from_node(codegen, node->data.type_array.element_type);
            }
            break;
        case AST_TYPE_SLICE:
            if (node->data.type_slice.element_type) {
                collect_generic_struct_instances_from_node(codegen, node->data.type_slice.element_type);
            }
            break;
        case AST_VAR_DECL:
            if (node->data.var_decl.type) {
                collect_generic_struct_instances_from_node(codegen, node->data.var_decl.type);
            }
            if (node->data.var_decl.init) {
                collect_generic_struct_instances_from_node(codegen, node->data.var_decl.init);
            }
            break;
        case AST_FN_DECL:
            if (node->data.fn_decl.return_type) {
                collect_generic_struct_instances_from_node(codegen, node->data.fn_decl.return_type);
            }
            if (node->data.fn_decl.params) {
                for (int i = 0; i < node->data.fn_decl.param_count; i++) {
                    if (node->data.fn_decl.params[i]) {
                        collect_generic_struct_instances_from_node(codegen, node->data.fn_decl.params[i]);
                    }
                }
            }
            if (node->data.fn_decl.body) {
                collect_generic_struct_instances_from_node(codegen, node->data.fn_decl.body);
            }
            break;
        case AST_STRUCT_DECL:
            // 处理结构体字段类型
            if (node->data.struct_decl.fields) {
                for (int i = 0; i < node->data.struct_decl.field_count; i++) {
                    if (node->data.struct_decl.fields[i]) {
                        collect_generic_struct_instances_from_node(codegen, node->data.struct_decl.fields[i]);
                    }
                }
            }
            // 处理结构体方法
            if (node->data.struct_decl.methods) {
                for (int i = 0; i < node->data.struct_decl.method_count; i++) {
                    if (node->data.struct_decl.methods[i]) {
                        collect_generic_struct_instances_from_node(codegen, node->data.struct_decl.methods[i]);
                    }
                }
            }
            break;
        case AST_BLOCK:
            if (node->data.block.stmts) {
                for (int i = 0; i < node->data.block.stmt_count; i++) {
                    if (node->data.block.stmts[i]) {
                        collect_generic_struct_instances_from_node(codegen, node->data.block.stmts[i]);
                    }
                }
            }
            break;
        case AST_IF_STMT:
            if (node->data.if_stmt.condition) {
                collect_generic_struct_instances_from_node(codegen, node->data.if_stmt.condition);
            }
            if (node->data.if_stmt.then_branch) {
                collect_generic_struct_instances_from_node(codegen, node->data.if_stmt.then_branch);
            }
            if (node->data.if_stmt.else_branch) {
                collect_generic_struct_instances_from_node(codegen, node->data.if_stmt.else_branch);
            }
            break;
        case AST_WHILE_STMT:
            if (node->data.while_stmt.condition) {
                collect_generic_struct_instances_from_node(codegen, node->data.while_stmt.condition);
            }
            if (node->data.while_stmt.body) {
                collect_generic_struct_instances_from_node(codegen, node->data.while_stmt.body);
            }
            break;
        case AST_FOR_STMT:
            if (node->data.for_stmt.array) {
                collect_generic_struct_instances_from_node(codegen, node->data.for_stmt.array);
            }
            if (node->data.for_stmt.body) {
                collect_generic_struct_instances_from_node(codegen, node->data.for_stmt.body);
            }
            break;
        case AST_RETURN_STMT:
            if (node->data.return_stmt.expr) {
                collect_generic_struct_instances_from_node(codegen, node->data.return_stmt.expr);
            }
            break;
        case AST_ASSIGN:
            if (node->data.assign.dest) {
                collect_generic_struct_instances_from_node(codegen, node->data.assign.dest);
            }
            if (node->data.assign.src) {
                collect_generic_struct_instances_from_node(codegen, node->data.assign.src);
            }
            break;
        case AST_BINARY_EXPR:
            if (node->data.binary_expr.left) {
                collect_generic_struct_instances_from_node(codegen, node->data.binary_expr.left);
            }
            if (node->data.binary_expr.right) {
                collect_generic_struct_instances_from_node(codegen, node->data.binary_expr.right);
            }
            break;
        case AST_UNARY_EXPR:
            if (node->data.unary_expr.operand) {
                collect_generic_struct_instances_from_node(codegen, node->data.unary_expr.operand);
            }
            break;
        case AST_MEMBER_ACCESS:
            if (node->data.member_access.object) {
                collect_generic_struct_instances_from_node(codegen, node->data.member_access.object);
            }
            break;
        case AST_ARRAY_ACCESS:
            if (node->data.array_access.array) {
                collect_generic_struct_instances_from_node(codegen, node->data.array_access.array);
            }
            if (node->data.array_access.index) {
                collect_generic_struct_instances_from_node(codegen, node->data.array_access.index);
            }
            break;
        case AST_CALL_EXPR:
            if (node->data.call_expr.callee) {
                collect_generic_struct_instances_from_node(codegen, node->data.call_expr.callee);
            }
            if (node->data.call_expr.args) {
                for (int i = 0; i < node->data.call_expr.arg_count; i++) {
                    if (node->data.call_expr.args[i]) {
                        collect_generic_struct_instances_from_node(codegen, node->data.call_expr.args[i]);
                    }
                }
            }
            break;
        case AST_STRUCT_INIT:
            if (node->data.struct_init.field_values) {
                for (int i = 0; i < node->data.struct_init.field_count; i++) {
                    if (node->data.struct_init.field_values[i]) {
                        collect_generic_struct_instances_from_node(codegen, node->data.struct_init.field_values[i]);
                    }
                }
            }
            break;
        case AST_ARRAY_LITERAL:
            if (node->data.array_literal.elements) {
                for (int i = 0; i < node->data.array_literal.element_count; i++) {
                    if (node->data.array_literal.elements[i]) {
                        collect_generic_struct_instances_from_node(codegen, node->data.array_literal.elements[i]);
                    }
                }
            }
            break;
        default:
            break;
    }
}

/* 生成泛型结构体实例化的结构体定义（单态化） */
void gen_generic_struct_instance(C99CodeGenerator *codegen, ASTNode *generic_struct_decl, ASTNode **type_args, int type_arg_count, const char *instance_name) {
    if (!codegen || !generic_struct_decl || generic_struct_decl->type != AST_STRUCT_DECL || !type_args || !instance_name) {
        return;
    }
    
    TypeParam *type_params = generic_struct_decl->data.struct_decl.type_params;
    int type_param_count = generic_struct_decl->data.struct_decl.type_param_count;
    
    if (type_param_count != type_arg_count) {
        return;  // 类型参数数量不匹配
    }
    
    // 如果已定义，跳过
    if (is_struct_defined(codegen, instance_name)) {
        return;
    }
    
    // 添加结构体定义标记
    add_struct_definition(codegen, instance_name);
    
    // 输出结构体定义
    c99_emit(codegen, "struct %s {\n", instance_name);
    codegen->indent_level++;
    
    // 生成字段（替换类型参数）
    int field_count = generic_struct_decl->data.struct_decl.field_count;
    ASTNode **fields = generic_struct_decl->data.struct_decl.fields;
    
    // 如果是空结构体，添加一个占位符字段以确保大小为 1（符合 Uya 规范）
    if (field_count == 0) {
        c99_emit(codegen, "char _empty;\n");
    } else {
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
            
            // 替换字段类型中的类型参数
            ASTNode *instance_field_type = replace_type_params_in_type(codegen, field_type, type_params, type_param_count, type_args);
            
            // 检查是否为数组类型
            if (instance_field_type->type == AST_TYPE_ARRAY) {
                ASTNode *element_type = instance_field_type->data.type_array.element_type;
                ASTNode *size_expr = instance_field_type->data.type_array.size_expr;
                const char *elem_type_c = c99_type_to_c(codegen, element_type);
                
                // 评估数组大小
                int array_size = -1;
                if (size_expr) {
                    array_size = eval_const_expr(codegen, size_expr);
                    if (array_size <= 0) {
                        array_size = 1;  // 占位符
                    }
                } else {
                    array_size = 1;  // 占位符
                }
                
                c99_emit(codegen, "%s %s[%d];\n", elem_type_c, field_name, array_size);
            } else {
                const char *field_type_c = c99_type_to_c(codegen, instance_field_type);
                c99_emit(codegen, "%s %s;\n", field_type_c, field_name);
            }
        }
    }
    
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    
    // 标记为已定义
    mark_struct_defined(codegen, instance_name);
}
