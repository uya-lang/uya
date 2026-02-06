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

// 递归收集接口（包括组合接口）的所有方法签名
// 用于生成 vtable 时包含组合接口的方法
// sigs: 输出方法签名数组，count: 输出方法数量
// 返回收集到的方法数量
static int collect_interface_method_sigs(C99CodeGenerator *codegen, const char *interface_name,
                                          ASTNode **sigs, int max_sigs, int *count) {
    if (!codegen || !interface_name || !sigs || !count) return 0;
    
    ASTNode *iface = find_interface_decl_c99(codegen, interface_name);
    if (!iface) return 0;
    
    // 先收集组合接口的方法（保证继承的方法在前面）
    for (int i = 0; i < iface->data.interface_decl.composed_count; i++) {
        const char *composed_name = iface->data.interface_decl.composed_interfaces[i];
        if (composed_name) {
            collect_interface_method_sigs(codegen, composed_name, sigs, max_sigs, count);
        }
    }
    
    // 再收集本接口的方法
    for (int i = 0; i < iface->data.interface_decl.method_sig_count; i++) {
        ASTNode *msig = iface->data.interface_decl.method_sigs[i];
        if (!msig || msig->type != AST_FN_DECL) continue;
        
        // 检查是否已存在（避免重复，组合的接口可能有同名方法）
        int exists = 0;
        for (int j = 0; j < *count; j++) {
            if (sigs[j] && sigs[j]->data.fn_decl.name && msig->data.fn_decl.name &&
                strcmp(sigs[j]->data.fn_decl.name, msig->data.fn_decl.name) == 0) {
                exists = 1;
                break;
            }
        }
        
        if (!exists && *count < max_sigs) {
            sigs[(*count)++] = msig;
        }
    }
    
    return *count;
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

// 检查接口是否是泛型接口（有类型参数）
static int is_generic_interface_c99(ASTNode *iface_decl) {
    if (!iface_decl || iface_decl->type != AST_INTERFACE_DECL) return 0;
    return iface_decl->data.interface_decl.type_param_count > 0;
}

// 生成接口值结构体与 vtable 结构体（不含 vtable 常量，常量需在方法前向声明之后生成）
void emit_interface_structs_and_vtables(C99CodeGenerator *codegen) {
    if (!codegen || !codegen->program_node) return;
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    
    // 第一步：预先生成所有接口方法签名中使用的错误联合类型结构体定义
    // 跳过泛型接口（类型参数会导致错误联合类型如 err_union_T 无法编译）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_INTERFACE_DECL) continue;
        // 跳过泛型接口，它们只是模板，不应生成代码
        if (is_generic_interface_c99(decl)) continue;
        pregenerate_error_union_structs_for_interface(codegen, decl);
    }
    
    // 第二步：生成接口值结构体与 vtable 结构体
    // 跳过泛型接口
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_INTERFACE_DECL) continue;
        // 跳过泛型接口，它们只是模板，不应生成代码
        if (is_generic_interface_c99(decl)) continue;
        const char *iface_name = decl->data.interface_decl.name;
        if (!iface_name) continue;
        const char *safe_iface = get_safe_c_identifier(codegen, iface_name);
        c99_emit(codegen, "struct uya_interface_%s { void *vtable; void *data; };\n", safe_iface);
        c99_emit(codegen, "struct uya_vtable_%s {\n", safe_iface);
        codegen->indent_level++;
        
        // 使用 collect_interface_method_sigs 收集所有方法（包括组合接口的方法）
        ASTNode *all_sigs[128];
        int sig_count = 0;
        collect_interface_method_sigs(codegen, iface_name, all_sigs, 128, &sig_count);
        
        for (int j = 0; j < sig_count; j++) {
            ASTNode *msig = all_sigs[j];
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
            
            // 使用 collect_interface_method_sigs 收集所有方法（包括组合接口的方法）
            ASTNode *all_sigs[128];
            int sig_count = 0;
            collect_interface_method_sigs(codegen, iface_name, all_sigs, 128, &sig_count);
            
            fprintf(codegen->output, "static const struct uya_vtable_%s uya_vtable_%s_%s = { ",
                    safe_iface, safe_iface, safe_struct);
            for (int k = 0; k < sig_count; k++) {
                ASTNode *msig = all_sigs[k];
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

// 检查结构体是否是泛型结构体（有类型参数）
int is_generic_struct_c99(ASTNode *struct_decl) {
    if (!struct_decl || struct_decl->type != AST_STRUCT_DECL) return 0;
    return struct_decl->data.struct_decl.type_param_count > 0;
}

// 检查单态化实例的类型实参是否包含未解析的类型参数名
// 如果类型实参名称匹配所属泛型声明的某个类型参数，则视为未解析
int has_unresolved_mono_type_args(ASTNode *generic_decl, ASTNode **type_args, int type_arg_count) {
    if (!generic_decl || !type_args || type_arg_count <= 0) return 0;
    
    TypeParam *type_params = NULL;
    int type_param_count = 0;
    
    if (generic_decl->type == AST_STRUCT_DECL) {
        type_params = generic_decl->data.struct_decl.type_params;
        type_param_count = generic_decl->data.struct_decl.type_param_count;
    } else if (generic_decl->type == AST_FN_DECL) {
        type_params = generic_decl->data.fn_decl.type_params;
        type_param_count = generic_decl->data.fn_decl.type_param_count;
    }
    
    if (!type_params || type_param_count == 0) return 0;
    
    for (int i = 0; i < type_arg_count; i++) {
        ASTNode *arg = type_args[i];
        if (arg && arg->type == AST_TYPE_NAMED && arg->data.type_named.name) {
            const char *name = arg->data.type_named.name;
            for (int j = 0; j < type_param_count; j++) {
                if (type_params[j].name && strcmp(type_params[j].name, name) == 0) {
                    return 1;  // 类型实参是未解析的类型参数
                }
            }
        }
    }
    return 0;
}

// 辅助函数：将类型参数追加到后缀字符串中（递归处理嵌套泛型）
static int append_type_arg_suffix(C99CodeGenerator *codegen, ASTNode *type_arg, char *suffix, int suffix_len, int max_len) {
    if (!type_arg || suffix_len >= max_len - 1) return suffix_len;
    
    if (type_arg->type == AST_TYPE_NAMED && type_arg->data.type_named.name) {
        const char *type_name = type_arg->data.type_named.name;
        
        // 在单态化上下文中替换类型参数（如 T → i32）
        ASTNode *resolved_type = NULL;
        if (codegen->current_type_params && codegen->current_type_param_count > 0) {
            for (int j = 0; j < codegen->current_type_param_count && j < codegen->current_type_arg_count; j++) {
                if (codegen->current_type_params[j].name &&
                    strcmp(codegen->current_type_params[j].name, type_name) == 0) {
                    if (codegen->current_type_args && codegen->current_type_args[j]) {
                        resolved_type = codegen->current_type_args[j];
                        if (resolved_type->type == AST_TYPE_NAMED && resolved_type->data.type_named.name) {
                            type_name = resolved_type->data.type_named.name;
                        }
                    }
                    break;
                }
            }
        }
        
        // 添加基础类型名
        while (*type_name && suffix_len < max_len - 1) {
            suffix[suffix_len++] = *type_name++;
        }
        
        // 检查是否有嵌套类型参数（如 Pair<i32, i32>）
        ASTNode *actual_type = resolved_type ? resolved_type : type_arg;
        if (actual_type->type == AST_TYPE_NAMED && 
            actual_type->data.type_named.type_arg_count > 0 &&
            actual_type->data.type_named.type_args) {
            // 递归处理嵌套类型参数
            for (int k = 0; k < actual_type->data.type_named.type_arg_count; k++) {
                if (suffix_len < max_len - 1) {
                    suffix[suffix_len++] = '_';
                }
                suffix_len = append_type_arg_suffix(codegen, 
                    actual_type->data.type_named.type_args[k], 
                    suffix, suffix_len, max_len);
            }
        }
    } else if (type_arg->type == AST_TYPE_POINTER) {
        const char *ptr_prefix = "ptr_";
        while (*ptr_prefix && suffix_len < max_len - 1) {
            suffix[suffix_len++] = *ptr_prefix++;
        }
        ASTNode *pointed = type_arg->data.type_pointer.pointed_type;
        suffix_len = append_type_arg_suffix(codegen, pointed, suffix, suffix_len, max_len);
    }
    
    return suffix_len;
}

// 获取单态化结构体名称
// 例如：Pair<i32, i64> -> Pair_i32_i64
// 嵌套泛型：Box<Pair<i32, i32>> -> Box_Pair_i32_i32
const char *get_mono_struct_name(C99CodeGenerator *codegen, const char *generic_name, ASTNode **type_args, int type_arg_count) {
    if (!codegen || !generic_name || !type_args || type_arg_count <= 0) {
        return generic_name;
    }
    
    // 构建后缀
    char suffix[512] = "";
    int suffix_len = 0;
    
    for (int i = 0; i < type_arg_count; i++) {
        if (i > 0 && suffix_len < 511) {
            suffix[suffix_len++] = '_';
        }
        suffix_len = append_type_arg_suffix(codegen, type_args[i], suffix, suffix_len, 512);
    }
    suffix[suffix_len] = '\0';
    
    // 分配并构建完整名称
    const char *safe_name = get_safe_c_identifier(codegen, generic_name);
    size_t name_len = strlen(safe_name) + 1 + strlen(suffix) + 1;
    char *mono_name = arena_alloc(codegen->arena, name_len);
    if (!mono_name) return generic_name;
    snprintf(mono_name, name_len, "%s_%s", safe_name, suffix);
    
    return mono_name;
}

// 在单态化上下文中将类型参数替换为具体类型
static const char *c99_mono_struct_type_to_c(C99CodeGenerator *codegen, ASTNode *type_node) {
    if (!codegen || !type_node) return "void";
    
    // 如果不在单态化上下文中，直接使用普通类型转换
    if (!codegen->current_type_params || codegen->current_type_param_count == 0) {
        return c99_type_to_c(codegen, type_node);
    }
    
    // 对于命名类型，检查是否是类型参数
    if (type_node->type == AST_TYPE_NAMED && type_node->data.type_named.name) {
        const char *name = type_node->data.type_named.name;
        for (int i = 0; i < codegen->current_type_param_count; i++) {
            if (codegen->current_type_params[i].name &&
                strcmp(codegen->current_type_params[i].name, name) == 0) {
                // 找到匹配的类型参数，返回对应的类型实参
                if (codegen->current_type_args && i < codegen->current_type_arg_count) {
                    return c99_type_to_c(codegen, codegen->current_type_args[i]);
                }
            }
        }
    }
    
    return c99_type_to_c(codegen, type_node);
}

// 辅助函数：在程序 AST 中查找结构体声明
static ASTNode *find_struct_decl_in_program(C99CodeGenerator *codegen, const char *struct_name) {
    if (!codegen->program_node || codegen->program_node->type != AST_PROGRAM) {
        return NULL;
    }
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (decl && decl->type == AST_STRUCT_DECL && decl->data.struct_decl.name &&
            strcmp(decl->data.struct_decl.name, struct_name) == 0) {
            return decl;
        }
    }
    return NULL;
}

// 辅助函数：先生成嵌套泛型依赖的结构体（递归处理）
static void ensure_nested_generic_struct_defined(C99CodeGenerator *codegen, ASTNode *type_node) {
    if (!type_node || type_node->type != AST_TYPE_NAMED) return;
    
    const char *type_name = type_node->data.type_named.name;
    if (!type_name) return;
    
    // 检查是否是类型参数（如 T），如果是，替换为实际类型
    ASTNode *resolved_type = type_node;
    if (codegen->current_type_params && codegen->current_type_param_count > 0) {
        for (int i = 0; i < codegen->current_type_param_count && i < codegen->current_type_arg_count; i++) {
            if (codegen->current_type_params[i].name &&
                strcmp(codegen->current_type_params[i].name, type_name) == 0) {
                if (codegen->current_type_args && codegen->current_type_args[i]) {
                    resolved_type = codegen->current_type_args[i];
                    type_name = resolved_type->data.type_named.name;
                }
                break;
            }
        }
    }
    
    // 如果这个类型有类型参数（是泛型实例化），需要先生成它
    if (resolved_type->type == AST_TYPE_NAMED &&
        resolved_type->data.type_named.type_arg_count > 0 &&
        resolved_type->data.type_named.type_args) {
        // 递归处理嵌套的类型参数
        for (int i = 0; i < resolved_type->data.type_named.type_arg_count; i++) {
            ensure_nested_generic_struct_defined(codegen, resolved_type->data.type_named.type_args[i]);
        }
        
        // 找到泛型结构体的声明
        ASTNode *nested_struct_decl = find_struct_decl_in_program(codegen, resolved_type->data.type_named.name);
        if (nested_struct_decl && is_generic_struct_c99(nested_struct_decl)) {
            // 递归生成嵌套的泛型结构体
            gen_mono_struct_definition(codegen, nested_struct_decl,
                resolved_type->data.type_named.type_args,
                resolved_type->data.type_named.type_arg_count);
            fputs("\n", codegen->output);
        }
    }
}

// 生成单态化结构体定义
int gen_mono_struct_definition(C99CodeGenerator *codegen, ASTNode *struct_decl, ASTNode **type_args, int type_arg_count) {
    if (!struct_decl || struct_decl->type != AST_STRUCT_DECL || !type_args) {
        return -1;
    }
    
    const char *orig_name = struct_decl->data.struct_decl.name;
    const char *mono_name = get_mono_struct_name(codegen, orig_name, type_args, type_arg_count);
    
    // 如果已定义，跳过
    if (is_struct_defined(codegen, mono_name)) {
        return 0;
    }
    
    // 设置单态化上下文
    TypeParam *saved_type_params = codegen->current_type_params;
    int saved_type_param_count = codegen->current_type_param_count;
    ASTNode **saved_type_args = codegen->current_type_args;
    int saved_type_arg_count = codegen->current_type_arg_count;
    
    codegen->current_type_params = struct_decl->data.struct_decl.type_params;
    codegen->current_type_param_count = struct_decl->data.struct_decl.type_param_count;
    codegen->current_type_args = type_args;
    codegen->current_type_arg_count = type_arg_count;
    
    // 先生成依赖的嵌套泛型结构体
    int field_count = struct_decl->data.struct_decl.field_count;
    ASTNode **fields = struct_decl->data.struct_decl.fields;
    for (int i = 0; i < field_count; i++) {
        ASTNode *field = fields[i];
        if (field && field->type == AST_VAR_DECL && field->data.var_decl.type) {
            ensure_nested_generic_struct_defined(codegen, field->data.var_decl.type);
        }
    }
    
    // 再次检查是否已定义（可能在处理依赖时被定义）
    if (is_struct_defined(codegen, mono_name)) {
        codegen->current_type_params = saved_type_params;
        codegen->current_type_param_count = saved_type_param_count;
        codegen->current_type_args = saved_type_args;
        codegen->current_type_arg_count = saved_type_arg_count;
        return 0;
    }
    
    // 添加结构体定义标记
    add_struct_definition(codegen, mono_name);
    
    // 输出结构体定义
    c99_emit(codegen, "struct %s {\n", mono_name);
    codegen->indent_level++;
    
    // 生成字段（field_count 和 fields 已在前面定义）
    if (field_count == 0) {
        c99_emit(codegen, "char _empty;\n");
    } else {
        for (int i = 0; i < field_count; i++) {
            ASTNode *field = fields[i];
            if (!field || field->type != AST_VAR_DECL) {
                codegen->indent_level--;
                codegen->current_type_params = saved_type_params;
                codegen->current_type_param_count = saved_type_param_count;
                codegen->current_type_args = saved_type_args;
                codegen->current_type_arg_count = saved_type_arg_count;
                return -1;
            }
            
            const char *field_name = get_safe_c_identifier(codegen, field->data.var_decl.name);
            ASTNode *field_type = field->data.var_decl.type;
            
            if (!field_name || !field_type) {
                codegen->indent_level--;
                codegen->current_type_params = saved_type_params;
                codegen->current_type_param_count = saved_type_param_count;
                codegen->current_type_args = saved_type_args;
                codegen->current_type_arg_count = saved_type_arg_count;
                return -1;
            }
            
            // 使用单态化类型转换
            const char *field_type_c = c99_mono_struct_type_to_c(codegen, field_type);
            c99_emit(codegen, "%s %s;\n", field_type_c, field_name);
        }
    }
    
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    
    // 标记为已定义
    mark_struct_defined(codegen, mono_name);
    
    // 恢复上下文
    codegen->current_type_params = saved_type_params;
    codegen->current_type_param_count = saved_type_param_count;
    codegen->current_type_args = saved_type_args;
    codegen->current_type_arg_count = saved_type_arg_count;
    
    return 0;
}
