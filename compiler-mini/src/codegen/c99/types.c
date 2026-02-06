#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdint.h>

/* 方法参数类型映射：将 Self 替换为 struct_name，用于生成结构体方法签名 */
const char *c99_type_to_c_with_self(C99CodeGenerator *codegen, ASTNode *type_node, const char *self_struct_name) {
    return c99_type_to_c_with_self_opt(codegen, type_node, self_struct_name, 0);
}

/* const_self: 仅作为后备标志，实际上根据 is_ffi_pointer 决定是否添加 const
   &Self (is_ffi_pointer=0) -> const struct X *
   *Self (is_ffi_pointer=1) -> struct X *
*/
const char *c99_type_to_c_with_self_opt(C99CodeGenerator *codegen, ASTNode *type_node, const char *self_struct_name, int const_self) {
    (void)const_self; // 保留参数以兼容调用方，实际使用 is_ffi_pointer 决定 const
    if (!type_node || !self_struct_name) return c99_type_to_c(codegen, type_node);
    const char *safe = get_safe_c_identifier(codegen, self_struct_name);
    int is_union = find_union_decl_c99(codegen, self_struct_name) != NULL;
    if (type_node->type == AST_TYPE_POINTER) {
        ASTNode *pt = type_node->data.type_pointer.pointed_type;
        if (pt && pt->type == AST_TYPE_NAMED && pt->data.type_named.name &&
            strcmp(pt->data.type_named.name, "Self") == 0) {
            // 根据 is_ffi_pointer 决定是否添加 const
            // &Self (is_ffi_pointer=0) -> const struct X *
            // *Self (is_ffi_pointer=1) -> struct X *
            int use_const = !type_node->data.type_pointer.is_ffi_pointer;
            const char *struct_fmt = is_union ? 
                (use_const ? "const struct uya_tagged_%s *" : "struct uya_tagged_%s *") : 
                (use_const ? "const struct %s *" : "struct %s *");
            size_t len = strlen(safe) + 32;
            char *buf = arena_alloc(codegen->arena, len);
            if (buf) {
                snprintf(buf, len, struct_fmt, safe);
                return buf;
            }
        }
    } else if (type_node->type == AST_TYPE_NAMED && type_node->data.type_named.name &&
               strcmp(type_node->data.type_named.name, "Self") == 0) {
        const char *named_fmt = is_union ? "struct uya_tagged_%s" : "struct %s";
        size_t len = strlen(safe) + 24;
        char *buf = arena_alloc(codegen->arena, len);
        if (buf) {
            snprintf(buf, len, named_fmt, safe);
            return buf;
        }
    }
    return c99_type_to_c(codegen, type_node);
}

// 类型映射函数
const char *c99_type_to_c(C99CodeGenerator *codegen, ASTNode *type_node) {
    if (!type_node) {
        return "void";
    }
    
    // 在单态化上下文中，先进行类型参数替换
    if (codegen->current_type_params && codegen->current_type_param_count > 0 &&
        type_node->type == AST_TYPE_NAMED && type_node->data.type_named.name) {
        const char *name = type_node->data.type_named.name;
        // 检查是否是类型参数
        for (int i = 0; i < codegen->current_type_param_count; i++) {
            if (codegen->current_type_params[i].name &&
                strcmp(codegen->current_type_params[i].name, name) == 0) {
                // 找到匹配的类型参数，使用对应的类型实参
                if (codegen->current_type_args && i < codegen->current_type_arg_count) {
                    // 防止无限递归：如果替换后的类型实参和当前节点相同，跳过
                    if (codegen->current_type_args[i] == type_node) {
                        return name;  // 返回原始名称，避免无限递归
                    }
                    return c99_type_to_c(codegen, codegen->current_type_args[i]);
                }
            }
        }
    }
    
    // 处理复合类型中的类型参数替换（指针、数组、切片等）
    if (codegen->current_type_params && codegen->current_type_param_count > 0) {
        // 指针类型：递归处理内部类型
        if (type_node->type == AST_TYPE_POINTER && type_node->data.type_pointer.pointed_type) {
            ASTNode *inner = type_node->data.type_pointer.pointed_type;
            // 检查内部类型是否是类型参数
            if (inner->type == AST_TYPE_NAMED && inner->data.type_named.name) {
                for (int i = 0; i < codegen->current_type_param_count; i++) {
                    if (codegen->current_type_params[i].name &&
                        strcmp(codegen->current_type_params[i].name, inner->data.type_named.name) == 0) {
                        if (codegen->current_type_args && i < codegen->current_type_arg_count) {
                            // 获取替换后的内部类型
                            const char *inner_c = c99_type_to_c(codegen, codegen->current_type_args[i]);
                            size_t len = strlen(inner_c) + 4;  // " * " + '\0'
                            char *buf = arena_alloc(codegen->arena, len);
                            if (buf) {
                                snprintf(buf, len, "%s *", inner_c);
                                return buf;
                            }
                        }
                    }
                }
            }
        }
    }
    
    switch (type_node->type) {
        case AST_TYPE_NAMED: {
            const char *name = type_node->data.type_named.name;
            if (!name) {
                return "void";
            }
            
            // 检查是否有类型实参（泛型结构体实例化）
            if (type_node->data.type_named.type_arg_count > 0 && 
                type_node->data.type_named.type_args != NULL) {
                // 使用单态化结构体名称
                const char *mono_name = get_mono_struct_name(codegen, name,
                    type_node->data.type_named.type_args,
                    type_node->data.type_named.type_arg_count);
                size_t len = strlen(mono_name) + 8;  // "struct " + name + '\0'
                char *buf = arena_alloc(codegen->arena, len);
                if (buf) {
                    snprintf(buf, len, "struct %s", mono_name);
                    return buf;
                }
                return "void";
            }
            
            // 基础类型映射
            if (strcmp(name, "i8") == 0) {
                return "int8_t";
            } else if (strcmp(name, "i16") == 0) {
                return "int16_t";
            } else if (strcmp(name, "i32") == 0) {
                return "int32_t";
            } else if (strcmp(name, "i64") == 0) {
                return "int64_t";
            } else if (strcmp(name, "u8") == 0) {
                return "uint8_t";
            } else if (strcmp(name, "u16") == 0) {
                return "uint16_t";
            } else if (strcmp(name, "u32") == 0) {
                return "uint32_t";
            } else if (strcmp(name, "usize") == 0) {
                return "size_t";
            } else if (strcmp(name, "u64") == 0) {
                return "uint64_t";
            } else if (strcmp(name, "bool") == 0) {
                return "bool";
            } else if (strcmp(name, "byte") == 0) {
                return "uint8_t";
            } else if (strcmp(name, "f32") == 0) {
                return "float";
            } else if (strcmp(name, "f64") == 0) {
                return "double";
            } else if (strcmp(name, "void") == 0) {
                return "void";
            } else {
                // 检查是否有泛型类型参数（如 Vec<i32>）
                if (type_node->data.type_named.type_arg_count > 0) {
                    // 生成泛型实例化的名称（如 uya_Vec_i32）
                    const char *safe_name = get_safe_c_identifier(codegen, name);
                    size_t total_len = strlen(safe_name) + 1;  // 基础名称 + "_"
                    
                    // 计算所有类型参数名称的总长度
                    for (int i = 0; i < type_node->data.type_named.type_arg_count; i++) {
                        ASTNode *type_arg = type_node->data.type_named.type_args[i];
                        if (type_arg != NULL) {
                            const char *type_arg_c = c99_type_to_c(codegen, type_arg);
                            total_len += strlen(type_arg_c) + 1;  // 类型名 + "_"
                        }
                    }
                    
                    // 分配缓冲区并构建名称
                    char *buf = arena_alloc(codegen->arena, total_len + 1);
                    if (buf) {
                        strcpy(buf, "uya_");
                        strcat(buf, safe_name);
                        for (int i = 0; i < type_node->data.type_named.type_arg_count; i++) {
                            ASTNode *type_arg = type_node->data.type_named.type_args[i];
                            if (type_arg != NULL) {
                                const char *type_arg_c = c99_type_to_c(codegen, type_arg);
                                strcat(buf, "_");
                                // 移除 "struct " 前缀（如果有）以简化名称
                                if (strncmp(type_arg_c, "struct ", 7) == 0) {
                                    strcat(buf, type_arg_c + 7);
                                } else {
                                    strcat(buf, type_arg_c);
                                }
                            }
                        }
                        
                        // 检查是否是结构体
                        if (is_struct_in_table(codegen, safe_name)) {
                            size_t struct_len = strlen(buf) + 8;
                            char *struct_buf = arena_alloc(codegen->arena, struct_len);
                            if (struct_buf) {
                                snprintf(struct_buf, struct_len, "struct %s", buf);
                                return struct_buf;
                            }
                        }
                        return buf;
                    }
                }
                
                // 结构体或枚举类型（非泛型）
                const char *safe_name = get_safe_c_identifier(codegen, name);
                
                // 显式检查是否是结构体（检查是否在表中，不管是否已定义）
                // 优先使用表查找，更可靠
                if (is_struct_in_table(codegen, safe_name)) {
                    // 使用 arena 分配器来分配字符串，避免 static 缓冲区被覆盖
                    // "struct " (7 chars) + name + '\0' = strlen(safe_name) + 8
                    size_t len = strlen(safe_name) + 8;
                    char *buf = arena_alloc(codegen->arena, len);
                    if (buf) {
                        snprintf(buf, len, "struct %s", safe_name);
                        return buf;
                    }
                    return "void"; // 内存不足时的回退方案
                }
                
                // 如果表查找失败，尝试从程序节点中查找结构体声明（备用方案）
                if (codegen->program_node) {
                    ASTNode **decls = codegen->program_node->data.program.decls;
                    int decl_count = codegen->program_node->data.program.decl_count;
                    for (int i = 0; i < decl_count; i++) {
                        ASTNode *decl = decls[i];
                        if (decl && decl->type == AST_STRUCT_DECL) {
                            const char *struct_name = decl->data.struct_decl.name;
                            if (struct_name) {
                                const char *safe_struct_name = get_safe_c_identifier(codegen, struct_name);
                                // 比较 safe_name 和 safe_struct_name
                                if (strcmp(safe_struct_name, safe_name) == 0) {
                                    // 找到结构体声明，添加 struct 前缀
                                    size_t len = strlen(safe_name) + 8; // "struct " + name + '\0'
                                    char *buf = arena_alloc(codegen->arena, len);
                                    if (buf) {
                                        snprintf(buf, len, "struct %s", safe_name);
                                        return buf;
                                    }
                                    return "void";
                                }
                            }
                        }
                    }
                }
                
                // 检查是否是枚举（检查是否在表中，不管是否已定义）
                if (is_enum_in_table(codegen, safe_name)) {
                    // 使用 arena 分配器来分配字符串
                    // "enum " (5 chars) + name + '\0' = strlen(safe_name) + 6
                    size_t len = strlen(safe_name) + 6;
                    char *buf = arena_alloc(codegen->arena, len);
                    if (buf) {
                        snprintf(buf, len, "enum %s", safe_name);
                        return buf;
                    }
                    return "void";
                }
                
                // 如果不在表中，尝试从程序节点中查找枚举声明（备用方案）
                if (codegen->program_node) {
                    ASTNode **decls = codegen->program_node->data.program.decls;
                    int decl_count = codegen->program_node->data.program.decl_count;
                    for (int i = 0; i < decl_count; i++) {
                        ASTNode *decl = decls[i];
                        if (decl && decl->type == AST_ENUM_DECL) {
                            const char *enum_name = decl->data.enum_decl.name;
                            if (enum_name) {
                                const char *safe_enum_name = get_safe_c_identifier(codegen, enum_name);
                                // 比较 safe_name 和 safe_enum_name
                                if (strcmp(safe_enum_name, safe_name) == 0) {
                                    // 找到枚举声明，添加 enum 前缀
                                    size_t len = strlen(safe_name) + 6; // "enum " + name + '\0'
                                    char *buf = arena_alloc(codegen->arena, len);
                                    if (buf) {
                                        snprintf(buf, len, "enum %s", safe_name);
                                        return buf;
                                    }
                                    return "void";
                                }
                            }
                        }
                    }
                }
                
                // 检查是否是接口类型（struct uya_interface_InterfaceName）
                if (find_interface_decl_c99(codegen, name) != NULL) {
                    size_t len = strlen(safe_name) + 24;  // "struct uya_interface_" + name + '\0'
                    char *buf = arena_alloc(codegen->arena, len);
                    if (buf) {
                        snprintf(buf, len, "struct uya_interface_%s", safe_name);
                        return buf;
                    }
                    return "void";
                }
                // 检查是否是联合体类型：extern union 用 union Name，普通联合体用 struct uya_tagged_Name
                {
                    ASTNode *ud = find_union_decl_c99(codegen, name);
                    if (ud != NULL) {
                        if (ud->data.union_decl.is_extern) {
                            size_t len = strlen(safe_name) + 10;  // "union " + name + '\0'
                            char *buf = arena_alloc(codegen->arena, len);
                            if (buf) {
                                snprintf(buf, len, "union %s", safe_name);
                                return buf;
                            }
                        } else {
                            size_t len = strlen(safe_name) + 22;  // "struct uya_tagged_" + name + '\0'
                            char *buf = arena_alloc(codegen->arena, len);
                            if (buf) {
                                snprintf(buf, len, "struct uya_tagged_%s", safe_name);
                                return buf;
                            }
                        }
                        return "void";
                    }
                }
                
                // 未知类型，直接返回名称
                return safe_name;
            }
        }
        
        case AST_TYPE_POINTER: {
            ASTNode *pointed_type = type_node->data.type_pointer.pointed_type;
            const char *pointee_type = c99_type_to_c(codegen, pointed_type);
            
            // 分配缓冲区（在 Arena 中）
            size_t len = strlen(pointee_type) + 3;  // 类型 + " *" + null
            char *result = arena_alloc(codegen->arena, len);
            if (!result) {
                return "void*";
            }
            
            // 如果指向数组类型，生成指向数组的指针（T [N] -> T (*)[N]）
            const char *bracket = strchr(pointee_type, '[');
            if (bracket) {
                size_t base_len = bracket - pointee_type;
                const char *dims = bracket;
                size_t dims_len = strlen(dims);
                // 重新分配更大的缓冲区
                size_t total_len = base_len + dims_len + 6; // " (*)" + null
                char *arr_ptr = arena_alloc(codegen->arena, total_len);
                if (!arr_ptr) {
                    snprintf(result, len, "%s *", pointee_type);
                    return result;
                }
                snprintf(arr_ptr, total_len, "%.*s (*)%s", (int)base_len, pointee_type, dims);
                return arr_ptr;
            }
            
            snprintf(result, len, "%s *", pointee_type);
            return result;
        }
        
        case AST_TYPE_ARRAY: {
            ASTNode *element_type = type_node->data.type_array.element_type;
            ASTNode *size_expr = type_node->data.type_array.size_expr;
            
            // 评估数组大小（编译时常量）
            int array_size = -1;
            if (size_expr) {
                array_size = eval_const_expr(codegen, size_expr);
                if (array_size <= 0) {
                    // 如果评估失败或大小无效，使用占位符大小
                    array_size = 1;  // 占位符
                }
            } else {
                // 无大小表达式（如 [T]），在 C99 中需要指定大小
                // 暂时使用占位符
                array_size = 1;
            }
            
            // 对于嵌套数组，需要正确处理维度顺序
            // 例如：[[i32: 2]: 3] 应该生成 int32_t[3][2]，而不是 int32_t[2][3]
            
            // 如果元素类型也是数组，先获取其基础类型和累积维度
            if (element_type->type == AST_TYPE_ARRAY) {
                // 递归获取内部数组的维度和基础类型
                const char *base_type = NULL;
                int dims[10];
                int dim_count = 0;
                
                ASTNode *current_type = type_node;
                while (current_type && current_type->type == AST_TYPE_ARRAY && dim_count < 10) {
                    ASTNode *curr_size_expr = current_type->data.type_array.size_expr;
                    int curr_size = 1;
                    if (curr_size_expr) {
                        curr_size = eval_const_expr(codegen, curr_size_expr);
                        if (curr_size <= 0) curr_size = 1;
                    }
                    dims[dim_count++] = curr_size;
                    current_type = current_type->data.type_array.element_type;
                }
                
                // 现在 current_type 是基础类型（不是数组）
                base_type = c99_type_to_c(codegen, current_type);
                
                // 构建结果类型：base_type[dims[0]][dims[1]]...
                // 维度按顺序输出：外层维度在前，内层维度在后
                // 例如：[[i32: 2]: 3] -> dims = [3, 2] -> int32_t[3][2]
                size_t total_len = strlen(base_type) + dim_count * 16 + 1;  // 足够空间
                char *result = arena_alloc(codegen->arena, total_len);
                if (!result) return "void";
                
                strcpy(result, base_type);
                for (int i = 0; i < dim_count; i++) {
                    char dim_str[16];
                    snprintf(dim_str, sizeof(dim_str), "[%d]", dims[i]);
                    strcat(result, dim_str);
                }
                
                return result;
            } else {
                // 单层数组，直接生成
                const char *element_c = c99_type_to_c(codegen, element_type);
                
                // 分配缓冲区
                size_t len = strlen(element_c) + 32;  // 元素类型 + "[%d]" + null
                char *result = arena_alloc(codegen->arena, len);
                if (!result) {
                    return "void";
                }
                
                snprintf(result, len, "%s[%d]", element_c, array_size);
                return result;
            }
        }
        
        case AST_TYPE_ERROR_UNION: {
            /* 错误联合类型 !T -> struct { uint32_t error_id; T value; } */
            ASTNode *payload_node = type_node->data.type_error_union.payload_type;
            if (!payload_node) return "void";
            const char *payload_c = c99_type_to_c(codegen, payload_node);
            int is_void = (payload_node->type == AST_TYPE_NAMED && payload_node->data.type_named.name &&
                strcmp(payload_node->data.type_named.name, "void") == 0);
            char struct_name_buf[128];
            if (is_void) {
                snprintf(struct_name_buf, sizeof(struct_name_buf), "err_union_void");
            } else {
                char safe[64];
                size_t j = 0;
                for (const char *p = payload_c; *p && j < sizeof(safe) - 1; p++) {
                    if ((*p >= 'a' && *p <= 'z') || (*p >= 'A' && *p <= 'Z') || (*p >= '0' && *p <= '9') || *p == '_')
                        safe[j++] = *p;
                }
                safe[j] = '\0';
                snprintf(struct_name_buf, sizeof(struct_name_buf), "err_union_%s", safe[0] ? safe : "T");
            }
            const char *name_copy = (const char *)arena_strdup(codegen->arena, struct_name_buf);
            if (!name_copy) return "void";
            if (!is_struct_defined(codegen, name_copy)) {
                add_struct_definition(codegen, name_copy);
                fprintf(codegen->output, "struct %s { uint32_t error_id;", name_copy);
                if (!is_void) {
                    fprintf(codegen->output, " %s value;", payload_c);
                }
                fprintf(codegen->output, " };\n");
                mark_struct_defined(codegen, name_copy);
            }
            size_t len = strlen(name_copy) + 9;
            char *result = arena_alloc(codegen->arena, len);
            if (!result) return "void";
            snprintf(result, len, "struct %s", name_copy);
            return result;
        }
        
        case AST_TYPE_ATOMIC: {
            /* 原子类型 atomic T -> _Atomic(T) */
            ASTNode *inner_type = type_node->data.type_atomic.inner_type;
            if (!inner_type) return "void";
            const char *inner_c = c99_type_to_c(codegen, inner_type);
            size_t len = strlen(inner_c) + 12;  // "_Atomic()" + inner type + null
            char *result = arena_alloc(codegen->arena, len);
            if (!result) return "void";
            snprintf(result, len, "_Atomic(%s)", inner_c);
            return result;
        }
        
        case AST_TYPE_SLICE: {
            ASTNode *element_type = type_node->data.type_slice.element_type;
            if (!element_type) return "void";
            const char *elem_c = c99_type_to_c(codegen, element_type);
            if (!elem_c) return "void";
            const char *elem_simple = elem_c;
            if (strncmp(elem_c, "struct ", 7) == 0) elem_simple = elem_c + 7;
            else if (strncmp(elem_c, "enum ", 5) == 0) elem_simple = elem_c + 5;
            // 去除指针类型中的 "*" 和前面的空格（用于生成结构体名称）
            // 例如 "uint8_t *" -> "uint8_t"
            size_t elem_len = strlen(elem_simple);
            const char *elem_clean = elem_simple;
            if (elem_len > 0 && elem_simple[elem_len - 1] == '*') {
                // 找到最后一个 '*'，向前查找并去除空格
                size_t end = elem_len - 1;
                while (end > 0 && elem_simple[end - 1] == ' ') {
                    end--;
                }
                // 创建临时缓冲区存储去除 "*" 后的名称
                char temp_buf[128];
                if (end < sizeof(temp_buf)) {
                    memcpy(temp_buf, elem_simple, end);
                    temp_buf[end] = '\0';
                    elem_clean = arena_strdup(codegen->arena, temp_buf);
                    if (!elem_clean) return "void";
                }
            }
            char name_buf[128];
            snprintf(name_buf, sizeof(name_buf), "uya_slice_%s", elem_clean);
            const char *safe = arena_strdup(codegen->arena, name_buf);
            if (!safe) return "void";
            if (is_struct_defined(codegen, safe)) {
                size_t len = strlen(safe) + 9;
                char *result = arena_alloc(codegen->arena, len);
                if (!result) return "void";
                snprintf(result, len, "struct %s", safe);
                return result;
            }
            int found = 0;
            for (int i = 0; i < codegen->slice_struct_count; i++) {
                if (codegen->slice_struct_names[i] && strcmp(codegen->slice_struct_names[i], safe) == 0) {
                    found = 1;
                    break;
                }
            }
            if (!found && codegen->slice_struct_count < C99_MAX_SLICE_STRUCTS) {
                codegen->slice_struct_names[codegen->slice_struct_count] = safe;
                codegen->slice_struct_element_types[codegen->slice_struct_count] = element_type;
                codegen->slice_struct_count++;
                add_struct_definition(codegen, safe);
            }
            {
                size_t len = strlen(safe) + 9;
                char *result = arena_alloc(codegen->arena, len);
                if (!result) return "void";
                snprintf(result, len, "struct %s", safe);
                return result;
            }
        }
        
        case AST_TYPE_TUPLE: {
            /* 元组类型 (T1, T2, ...) -> struct { T0 f0; T1 f1; ... } */
            int n = type_node->data.type_tuple.element_count;
            ASTNode **element_types = type_node->data.type_tuple.element_types;
            if (n <= 0 || !element_types) {
                return "void";
            }
            size_t total_len = 64;
            for (int i = 0; i < n; i++) {
                const char *et = c99_type_to_c(codegen, element_types[i]);
                total_len += (et ? strlen(et) : 4) + 24;
            }
            char *result = arena_alloc(codegen->arena, total_len);
            if (!result) return "void";
            size_t off = 0;
            off += (size_t)snprintf(result + off, total_len - off, "struct { ");
            for (int i = 0; i < n; i++) {
                const char *et = c99_type_to_c(codegen, element_types[i]);
                if (!et) et = "void";
                off += (size_t)snprintf(result + off, total_len - off, "%s f%d; ", et, i);
            }
            snprintf(result + off, total_len - off, "}");
            return result;
        }
        
        default:
            return "void";
    }
}

void emit_pending_slice_structs(C99CodeGenerator *codegen) {
    if (!codegen) return;
    for (int i = 0; i < codegen->slice_struct_count; i++) {
        const char *name = codegen->slice_struct_names[i];
        ASTNode *elem = codegen->slice_struct_element_types[i];
        if (!name || !elem) continue;
        if (is_struct_defined(codegen, name)) continue;
        const char *elem_c = c99_type_to_c(codegen, elem);
        if (!elem_c) continue;
        fprintf(codegen->output, "struct %s { %s *ptr; size_t len; };\n", name, elem_c);
        mark_struct_defined(codegen, name);
    }
}

// 计算结构体大小（估算，每个 i32 字段 4 字节）
int calculate_struct_size(C99CodeGenerator *codegen, ASTNode *type_node) {
    if (!codegen || !type_node) {
        return 0;
    }
    
    // 如果是命名类型（结构体），查找结构体声明
    if (type_node->type == AST_TYPE_NAMED) {
        const char *struct_name = type_node->data.type_named.name;
        if (!struct_name) return 0;
        
        ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
        if (!struct_decl || struct_decl->type != AST_STRUCT_DECL) {
            return 0;
        }
        
        int field_count = struct_decl->data.struct_decl.field_count;
        // 简单估算：每个字段 4 字节（i32）
        // 实际大小可能因对齐而不同，但用于判断是否 >16 字节足够
        return field_count * 4;
    }
    
    return 0;
}
// 检查成员访问表达式的结果类型是否是指针
int is_member_access_pointer_type(C99CodeGenerator *codegen, ASTNode *member_access) {
    if (!codegen || !member_access || member_access->type != AST_MEMBER_ACCESS) {
        return 0;
    }
    
    ASTNode *object = member_access->data.member_access.object;
    const char *field_name = member_access->data.member_access.field_name;
    
    if (!object || !field_name) {
        return 0;
    }
    
    // 如果 object 是标识符，查找变量类型，然后查找结构体字段类型
    if (object->type == AST_IDENTIFIER) {
        const char *var_name = object->data.identifier.name;
        if (!var_name) return 0;
        
        // 查找变量类型
        const char *var_type_c = NULL;
        for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
            if (strcmp(codegen->local_variables[i].name, var_name) == 0) {
                var_type_c = codegen->local_variables[i].type_c;
                break;
            }
        }
        if (!var_type_c) {
            for (int i = 0; i < codegen->global_variable_count; i++) {
                if (strcmp(codegen->global_variables[i].name, var_name) == 0) {
                    var_type_c = codegen->global_variables[i].type_c;
                    break;
                }
            }
        }
        
        if (!var_type_c) return 0;
        
            // 提取结构体名称（去除 "struct " 前缀和 "*" 后缀）
            const char *struct_name = NULL;
            if (strncmp(var_type_c, "struct ", 7) == 0) {
                const char *start = var_type_c + 7;
                // 查找 '*' 或空格后的 '*'
                const char *asterisk = strchr(start, '*');
                if (asterisk) {
                    // 提取 '*' 之前的部分，去除尾部空格
                    size_t len = asterisk - start;
                    // 去除尾部空格
                    while (len > 0 && (start[len - 1] == ' ' || start[len - 1] == '\t')) {
                        len--;
                    }
                    if (len > 0) {
                        char *name_buf = arena_alloc(codegen->arena, len + 1);
                        if (name_buf) {
                            memcpy(name_buf, start, len);
                            name_buf[len] = '\0';
                            struct_name = name_buf;
                        }
                    }
                } else {
                    struct_name = start;
                }
            }
        
        if (!struct_name) return 0;
        
        // 查找结构体声明
        ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
        if (!struct_decl) return 0;
        
        // 查找字段类型
        ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_name);
        if (!field_type) return 0;
        
        // 检查字段类型是否是指针
        return (field_type->type == AST_TYPE_POINTER);
    }
    
    // 如果 object 是嵌套的成员访问，递归检查
    if (object->type == AST_MEMBER_ACCESS) {
        // 递归检查嵌套成员访问的结果类型
        // 对于 parser.current_token，需要：
        // 1. 检查 parser 的类型（应该是 struct Parser *）
        // 2. 查找 Parser 结构体的 current_token 字段类型（应该是 &Token）
        // 3. 如果字段类型是指针，则当前访问应该使用 ->
        ASTNode *nested_object = object->data.member_access.object;
        const char *nested_field_name = object->data.member_access.field_name;
        
        if (nested_object && nested_object->type == AST_IDENTIFIER && nested_field_name) {
            const char *var_name = nested_object->data.identifier.name;
            if (!var_name) return 0;
            
            // 查找变量类型
            const char *var_type_c = NULL;
            for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
                if (strcmp(codegen->local_variables[i].name, var_name) == 0) {
                    var_type_c = codegen->local_variables[i].type_c;
                    break;
                }
            }
            if (!var_type_c) {
                for (int i = 0; i < codegen->global_variable_count; i++) {
                    if (strcmp(codegen->global_variables[i].name, var_name) == 0) {
                        var_type_c = codegen->global_variables[i].type_c;
                        break;
                    }
                }
            }
            
            if (!var_type_c) return 0;
            
            // 提取结构体名称
            const char *struct_name = NULL;
            if (strncmp(var_type_c, "struct ", 7) == 0) {
                const char *start = var_type_c + 7;
                const char *asterisk = strchr(start, '*');
                if (asterisk) {
                    size_t len = asterisk - start;
                    char *name_buf = arena_alloc(codegen->arena, len + 1);
                    if (name_buf) {
                        memcpy(name_buf, start, len);
                        name_buf[len] = '\0';
                        struct_name = name_buf;
                    }
                } else {
                    struct_name = start;
                }
            }
            
            if (!struct_name) return 0;
            
            // 查找结构体声明
            ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
            if (!struct_decl) return 0;
            
            // 查找嵌套字段类型（如 parser.current_token 中的 current_token）
            ASTNode *nested_field_type = find_struct_field_type(codegen, struct_decl, nested_field_name);
            if (!nested_field_type) return 0;
            
            // 检查嵌套字段类型是否是指针
            if (nested_field_type->type == AST_TYPE_POINTER) {
                // 嵌套字段是指针，所以当前字段访问应该使用 ->
                return 1;
            }
        }
        
        return 0;
    }
    
    return 0;
}
// 检查标识符是否为指针类型
int is_identifier_pointer_type(C99CodeGenerator *codegen, const char *name) {
    if (!name) return 0;
    
    // 检查局部变量（从后向前查找，支持变量遮蔽）
    for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
        if (codegen->local_variables[i].name && strcmp(codegen->local_variables[i].name, name) == 0) {
            const char *type_c = codegen->local_variables[i].type_c;
            if (!type_c) return 0;
            
            // 检查类型是否包含'*'（即是指针）
            // 注意：'*' 可能在类型名称之后（如 "struct Type *"）或之前（如 "*Type"）
            const char *asterisk = strchr(type_c, '*');
            if (asterisk) {
                // 找到 '*'，确认它是指针类型的一部分
                // 简单检查：'*' 前后可能有空格，但应该是指针类型
                return 1;
            }
            return 0;
        }
    }
    
    // 检查全局变量
    for (int i = 0; i < codegen->global_variable_count; i++) {
        if (codegen->global_variables[i].name && strcmp(codegen->global_variables[i].name, name) == 0) {
            const char *type_c = codegen->global_variables[i].type_c;
            if (!type_c) return 0;
            // 检查类型是否包含'*'（即是指针）
            const char *asterisk = strchr(type_c, '*');
            if (asterisk) {
                return 1;
            }
            return 0;
        }
    }
    
    return 0;
}

// 检查标识符是否是指向数组的指针类型（格式：T (*)[N] 或 T (* const var)[N]）
int is_identifier_pointer_to_array_type(C99CodeGenerator *codegen, const char *name) {
    if (!name) return 0;
    
    const char *type_c = NULL;
    
    // 检查局部变量
    for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
        if (strcmp(codegen->local_variables[i].name, name) == 0) {
            type_c = codegen->local_variables[i].type_c;
            break;
        }
    }
    
    // 如果局部变量中没找到，检查全局变量
    if (!type_c) {
        for (int i = 0; i < codegen->global_variable_count; i++) {
            if (strcmp(codegen->global_variables[i].name, name) == 0) {
                type_c = codegen->global_variables[i].type_c;
                break;
            }
        }
    }
    
    if (!type_c) return 0;
    
    // 检查是否是指向数组的指针格式：包含 "(*" 和 ")["
    const char *open_paren_asterisk = strstr(type_c, "(*");
    if (open_paren_asterisk) {
        const char *close_paren_bracket = strstr(open_paren_asterisk, ")[");
        if (close_paren_bracket) {
            return 1;  // 是指向数组的指针
        }
    }
    
    return 0;
}

// 检查数组访问表达式的结果类型是否是指针
// 例如：如果 arr 的类型是 [&ASTNode: 64]，那么 arr[i] 的结果类型是 &ASTNode，在 C 中是 struct ASTNode *
int is_array_access_pointer_type(C99CodeGenerator *codegen, ASTNode *array_access) {
    if (!codegen || !array_access || array_access->type != AST_ARRAY_ACCESS) {
        return 0;
    }
    
    ASTNode *array = array_access->data.array_access.array;
    if (!array) return 0;
    
    // 如果数组表达式是标识符，查找变量类型
    if (array->type == AST_IDENTIFIER) {
        const char *array_name = array->data.identifier.name;
        if (!array_name) return 0;
        
        // 查找变量类型
        const char *array_type_c = NULL;
        for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
            if (codegen->local_variables[i].name && strcmp(codegen->local_variables[i].name, array_name) == 0) {
                array_type_c = codegen->local_variables[i].type_c;
                break;
            }
        }
        if (!array_type_c) {
            for (int i = 0; i < codegen->global_variable_count; i++) {
                if (codegen->global_variables[i].name && strcmp(codegen->global_variables[i].name, array_name) == 0) {
                    array_type_c = codegen->global_variables[i].type_c;
                    break;
                }
            }
        }
        
        if (!array_type_c) return 0;
        
        // 指针的指针（类型中含 " * *"）：x[i] 为指针，用 ->
        if (strstr(array_type_c, " * *") != NULL) {
            return 1;
        }
        
        // 检查数组类型：如果类型字符串包含 '['，说明是数组类型
        // 数组元素类型是指针类型，如果元素类型字符串包含 '*'
        // 例如："struct ASTNode *[64]" 表示数组元素是指针类型
        const char *bracket = strchr(array_type_c, '[');
        if (bracket) {
            // 这是数组类型，检查元素类型是否包含 '*'
            const char *asterisk = strchr(array_type_c, '*');
            if (asterisk && asterisk < bracket) {
                return 1;
            }
        }
    }
    
    // 如果数组表达式是嵌套的数组访问，递归检查
    if (array->type == AST_ARRAY_ACCESS) {
        return is_array_access_pointer_type(codegen, array);
    }
    
    // 如果数组表达式是成员访问，检查成员访问的结果类型
    if (array->type == AST_MEMBER_ACCESS) {
        ASTNode *object = array->data.member_access.object;
        const char *field_name = array->data.member_access.field_name;
        
        if (!object || !field_name) return 0;
        
        // 获取对象的类型（类似 is_member_access_pointer_type 的逻辑）
        const char *var_type_c = NULL;
        const char *var_name = NULL;
        
        if (object->type == AST_IDENTIFIER) {
            var_name = object->data.identifier.name;
            if (!var_name) return 0;
            
            // 查找变量类型
            for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
                if (codegen->local_variables[i].name && strcmp(codegen->local_variables[i].name, var_name) == 0) {
                    var_type_c = codegen->local_variables[i].type_c;
                    break;
                }
            }
            if (!var_type_c) {
                for (int i = 0; i < codegen->global_variable_count; i++) {
                    if (codegen->global_variables[i].name && strcmp(codegen->global_variables[i].name, var_name) == 0) {
                        var_type_c = codegen->global_variables[i].type_c;
                        break;
                    }
                }
            }
        } else if (object->type == AST_MEMBER_ACCESS) {
            // 嵌套成员访问：递归处理（暂时简化，只处理一层嵌套）
            // 对于 codegen->nodes[i]，object 是 codegen（标识符），所以上面已经处理了
            return 0;
        } else {
            return 0;
        }
        
        if (!var_type_c) return 0;
        
        // 提取结构体名称（去除 "struct " 前缀和 "*" 后缀）
        const char *struct_name = NULL;
        if (strncmp(var_type_c, "struct ", 7) == 0) {
            const char *start = var_type_c + 7;
            const char *asterisk = strchr(start, '*');
            if (asterisk) {
                // 提取 '*' 之前的部分，去除尾部空格
                size_t len = asterisk - start;
                while (len > 0 && (start[len - 1] == ' ' || start[len - 1] == '\t')) {
                    len--;
                }
                if (len > 0) {
                    char *name_buf = arena_alloc(codegen->arena, len + 1);
                    if (name_buf) {
                        memcpy(name_buf, start, len);
                        name_buf[len] = '\0';
                        struct_name = name_buf;
                    }
                }
            } else {
                struct_name = start;
            }
        }
        
        if (!struct_name) return 0;
        
        // 查找结构体声明
        ASTNode *struct_decl = find_struct_decl_c99(codegen, struct_name);
        if (!struct_decl) return 0;
        
        // 查找字段类型
        ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_name);
        if (!field_type) return 0;
        
        // 检查字段类型是否是数组类型
        if (field_type->type == AST_TYPE_ARRAY) {
            ASTNode *element_type = field_type->data.type_array.element_type;
            if (!element_type) return 0;
            return (element_type->type == AST_TYPE_POINTER);
        }
        
        // 字段为“指针的指针”（& & T）时索引结果为指针，用 ->；单指针 &T 索引结果为值，用 .
        if (field_type->type == AST_TYPE_POINTER) {
            ASTNode *pointee = field_type->data.type_pointer.pointed_type;
            return (pointee && pointee->type == AST_TYPE_POINTER);
        }
        
        return 0;
    }
    
    return 0;
}

// 检查标识符对应的类型是否为结构体
int is_identifier_struct_type(C99CodeGenerator *codegen, const char *name) {
    if (!name) return 0;
    
    // 检查局部变量
    for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
        if (strcmp(codegen->local_variables[i].name, name) == 0) {
            const char *type_c = codegen->local_variables[i].type_c;
            if (!type_c) return 0;
            // 检查类型是否包含"struct "且不包含'*'（即不是指针）
            // 支持 "const struct Point" 和 "struct Point" 两种情况
            return (strstr(type_c, "struct ") != NULL && strchr(type_c, '*') == NULL);
        }
    }
    
    // 检查全局变量
    for (int i = 0; i < codegen->global_variable_count; i++) {
        if (strcmp(codegen->global_variables[i].name, name) == 0) {
            const char *type_c = codegen->global_variables[i].type_c;
            if (!type_c) return 0;
            // 检查类型是否包含"struct "且不包含'*'（即不是指针）
            // 支持 "const struct Point" 和 "struct Point" 两种情况
            return (strstr(type_c, "struct ") != NULL && strchr(type_c, '*') == NULL);
        }
    }
    
    return 0;
}

// 获取标识符（变量）的 C 类型字符串，用于按字段比较时查找结构体
const char *get_identifier_type_c(C99CodeGenerator *codegen, const char *name) {
    if (!name) return NULL;
    for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
        if (strcmp(codegen->local_variables[i].name, name) == 0) {
            return codegen->local_variables[i].type_c;
        }
    }
    for (int i = 0; i < codegen->global_variable_count; i++) {
        if (strcmp(codegen->global_variables[i].name, name) == 0) {
            return codegen->global_variables[i].type_c;
        }
    }
    return NULL;
}

/* 从切片表达式推断切片结构体 C 类型（struct uya_slice_X） */
static const char *get_slice_struct_type_c(C99CodeGenerator *codegen, ASTNode *slice_expr) {
    if (!codegen || !slice_expr || slice_expr->type != AST_SLICE_EXPR) return "struct uya_slice_int32_t";
    ASTNode *base = slice_expr->data.slice_expr.base;
    if (base->type == AST_SLICE_EXPR) {
        return get_slice_struct_type_c(codegen, base);
    }
    if (base->type == AST_IDENTIFIER) {
        const char *type_c = get_identifier_type_c(codegen, base->data.identifier.name);
        if (type_c && strstr(type_c, "uya_slice_")) {
            return type_c;
        }
        const char *elem_c = get_array_element_type(codegen, base);
        if (!elem_c) return "struct uya_slice_int32_t";
        const char *elem_simple = elem_c;
        if (strncmp(elem_c, "struct ", 7) == 0) elem_simple = elem_c + 7;
        else if (strncmp(elem_c, "enum ", 5) == 0) elem_simple = elem_c + 5;
        char name_buf[128];
        snprintf(name_buf, sizeof(name_buf), "uya_slice_%s", elem_simple);
        const char *safe = get_safe_c_identifier(codegen, name_buf);
        if (!safe) return "struct uya_slice_int32_t";
        size_t len = strlen(safe) + 9;
        char *result = arena_alloc(codegen->arena, len);
        if (!result) return "struct uya_slice_int32_t";
        snprintf(result, len, "struct %s", safe);
        return result;
    }
    return "struct uya_slice_int32_t";
}

/* 从表达式推断 C 类型字符串（用于元组字面量复合字面量），尽力而为 */
const char *get_c_type_of_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!codegen || !expr) return "int32_t";
    switch (expr->type) {
        case AST_UNARY_EXPR: {
            int op = expr->data.unary_expr.op;
            ASTNode *operand = expr->data.unary_expr.operand;
            if (!operand) return "int32_t";
            if (op == TOKEN_ASTERISK) {
                const char *ptr_type = get_c_type_of_expr(codegen, operand);
                if (!ptr_type) return "int32_t";
                const char *asterisk = strchr(ptr_type, '*');
                if (!asterisk) return "int32_t";
                size_t len = (size_t)(asterisk - ptr_type);
                while (len > 0 && (ptr_type[len - 1] == ' ' || ptr_type[len - 1] == '\t')) len--;
                char *buf = arena_alloc(codegen->arena, len + 1);
                if (!buf) return "int32_t";
                memcpy(buf, ptr_type, len);
                buf[len] = '\0';
                return buf;
            }
            return "int32_t";
        }
        case AST_NUMBER:
            return "int32_t";
        case AST_FLOAT:
            return "double";
        case AST_BOOL:
            return "bool";
        case AST_IDENTIFIER: {
            const char *t = get_identifier_type_c(codegen, expr->data.identifier.name);
            return t ? t : "int32_t";
        }
        case AST_SLICE_EXPR:
            return get_slice_struct_type_c(codegen, expr);
        case AST_MEMBER_ACCESS: {
            ASTNode *object = expr->data.member_access.object;
            const char *field_name = expr->data.member_access.field_name;
            if (!object || !field_name) return "int32_t";
            const char *base_type_c = NULL;
            if (object->type == AST_IDENTIFIER) {
                base_type_c = get_identifier_type_c(codegen, object->data.identifier.name);
            } else if (object->type == AST_MEMBER_ACCESS) {
                base_type_c = get_c_type_of_expr(codegen, object);
            } else if (object->type == AST_ARRAY_ACCESS) {
                base_type_c = get_c_type_of_expr(codegen, object);
            }
            if (!base_type_c) return "int32_t";
            /* 接口类型：obj.method 为方法调用，返回类型从接口方法签名获取 */
            if (strstr(base_type_c, "uya_interface_") != NULL) {
                const char *p = strstr(base_type_c, "uya_interface_");
                if (p) {
                    p += 14;  /* skip "uya_interface_" */
                    const char *iface_name = p;
                    ASTNode *iface = find_interface_decl_c99(codegen, iface_name);
                    if (iface) {
                        for (int i = 0; i < iface->data.interface_decl.method_sig_count; i++) {
                            ASTNode *msig = iface->data.interface_decl.method_sigs[i];
                            if (msig && msig->type == AST_FN_DECL && msig->data.fn_decl.name &&
                                strcmp(msig->data.fn_decl.name, field_name) == 0) {
                                return c99_type_to_c(codegen, msig->data.fn_decl.return_type);
                            }
                        }
                    }
                }
                return "int32_t";
            }
            ASTNode *struct_decl = find_struct_decl_from_type_c(codegen, base_type_c);
            if (!struct_decl) return "int32_t";
            // 先尝试查找字段
            ASTNode *field_type = find_struct_field_type(codegen, struct_decl, field_name);
            if (field_type) {
                return c99_type_to_c(codegen, field_type);
            }
            // 字段不存在，尝试查找方法
            ASTNode *method = find_method_in_struct_c99(codegen, struct_decl->data.struct_decl.name, field_name);
            if (method && method->type == AST_FN_DECL) {
                return c99_type_to_c(codegen, method->data.fn_decl.return_type);
            }
            return "int32_t";
        }
        case AST_CAST_EXPR: {
            ASTNode *target_type = expr->data.cast_expr.target_type;
            if (!target_type) return "int32_t";
            if (expr->data.cast_expr.is_force_cast) {
                /* as! 返回 !T，需返回错误联合结构体类型 */
                ASTNode tmp = {0};
                tmp.type = AST_TYPE_ERROR_UNION;
                tmp.data.type_error_union.payload_type = target_type;
                return c99_type_to_c(codegen, &tmp);
            }
            return c99_type_to_c(codegen, target_type);
        }
        case AST_ARRAY_ACCESS:
            return "int32_t";
        case AST_CALL_EXPR: {
            // 方法调用：callee 为 obj.method，需要推断方法返回类型
            ASTNode *callee = expr->data.call_expr.callee;
            if (callee && callee->type == AST_MEMBER_ACCESS) {
                // 递归调用 AST_MEMBER_ACCESS 的处理逻辑来获取方法返回类型
                return get_c_type_of_expr(codegen, callee);
            }
            // 普通函数调用：无法推断返回类型，返回默认类型
            return "int32_t";
        }
        default:
            return "int32_t";
    }
}

// 生成数组包装结构体的名称
// 例如：[i32: 3] -> "uya_array_i32_3", [[i32: 2]: 3] -> "uya_array_i32_2_3"
const char *get_array_wrapper_struct_name(C99CodeGenerator *codegen, ASTNode *array_type) {
    if (!array_type || array_type->type != AST_TYPE_ARRAY) {
        return NULL;
    }
    
    // 构建结构体名称
    char name_buf[256] = "uya_array_";
    int pos = strlen(name_buf);
    
    // 递归处理数组维度
    ASTNode *current = array_type;
    int first = 1;
    while (current && current->type == AST_TYPE_ARRAY) {
        ASTNode *element_type = current->data.type_array.element_type;
        ASTNode *size_expr = current->data.type_array.size_expr;
        
        // 获取元素类型名称
        const char *elem_name = NULL;
        if (element_type->type == AST_TYPE_NAMED) {
            const char *type_name = element_type->data.type_named.name;
            if (type_name) {
                // 简化类型名称（i32 -> i32, Point -> Point）
                if (strcmp(type_name, "i32") == 0) {
                    elem_name = "i32";
                } else if (strcmp(type_name, "i64") == 0) {
                    elem_name = "i64";
                } else if (strcmp(type_name, "i16") == 0) {
                    elem_name = "i16";
                } else if (strcmp(type_name, "i8") == 0 || strcmp(type_name, "byte") == 0) {
                    elem_name = "i8";
                } else if (strcmp(type_name, "bool") == 0) {
                    elem_name = "bool";
                } else {
                    // 结构体或其他类型，使用简化名称
                    const char *safe_name = get_safe_c_identifier(codegen, type_name);
                    elem_name = safe_name;
                }
            }
        }
        
        if (!elem_name) {
            elem_name = "unknown";
        }
        
        if (!first) {
            name_buf[pos++] = '_';
        }
        first = 0;
        
        // 添加元素类型名称
        int name_len = strlen(elem_name);
        if (pos + name_len < 255) {
            memcpy(name_buf + pos, elem_name, name_len);
            pos += name_len;
        }
        
        // 添加数组大小
        if (size_expr) {
            int size = eval_const_expr(codegen, size_expr);
            if (size > 0) {
                char size_str[32];
                snprintf(size_str, sizeof(size_str), "_%d", size);
                int size_len = strlen(size_str);
                if (pos + size_len < 255) {
                    memcpy(name_buf + pos, size_str, size_len);
                    pos += size_len;
                }
            }
        }
        
        current = element_type;
    }
    
    name_buf[pos] = '\0';
    return arena_strdup(codegen->arena, name_buf);
}

// 生成数组包装结构体的定义
void gen_array_wrapper_struct(C99CodeGenerator *codegen, ASTNode *array_type, const char *struct_name) {
    if (!array_type || array_type->type != AST_TYPE_ARRAY || !struct_name) {
        return;
    }
    
    // 检查是否已生成
    if (is_struct_defined(codegen, struct_name)) {
        return;
    }
    
    // 添加到结构体定义表（避免重复生成）
    if (codegen->struct_definition_count < C99_MAX_STRUCT_DEFINITIONS) {
        codegen->struct_definitions[codegen->struct_definition_count].name = struct_name;
        codegen->struct_definitions[codegen->struct_definition_count].defined = 0;
        codegen->struct_definition_count++;
    }
    
    // 生成结构体定义
    fprintf(codegen->output, "struct %s {\n", struct_name);
    
    // 生成数组字段：需要将数组类型转换为正确的格式
    // 例如：[i32: 3] -> int32_t data[3]
    ASTNode *element_type = array_type->data.type_array.element_type;
    ASTNode *size_expr = array_type->data.type_array.size_expr;
    const char *elem_type_c = c99_type_to_c(codegen, element_type);
    
    int array_size = -1;
    if (size_expr) {
        array_size = eval_const_expr(codegen, size_expr);
        if (array_size <= 0) {
            array_size = 1;
        }
    } else {
        array_size = 1;
    }
    
    fprintf(codegen->output, "    %s data[%d];\n", elem_type_c, array_size);
    
    fprintf(codegen->output, "};\n");
    
    // 标记为已定义
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            codegen->struct_definitions[i].defined = 1;
            break;
        }
    }
}

// 将数组返回类型转换为包装结构体类型（C99不允许函数返回数组）
// 例如：[i32: 3] -> struct uya_array_i32_3
const char *convert_array_return_type(C99CodeGenerator *codegen, ASTNode *return_type) {
    if (!return_type || return_type->type != AST_TYPE_ARRAY) {
        return c99_type_to_c(codegen, return_type);
    }
    
    // 生成包装结构体名称
    const char *struct_name = get_array_wrapper_struct_name(codegen, return_type);
    if (!struct_name) {
        return "void";
    }
    
    // 生成包装结构体定义（如果尚未生成）
    gen_array_wrapper_struct(codegen, return_type, struct_name);
    
    // 返回结构体类型
    size_t len = strlen(struct_name) + 8;  // "struct " + name + '\0'
    char *result = arena_alloc(codegen->arena, len);
    if (!result) {
        return "void";
    }
    
    snprintf(result, len, "struct %s", struct_name);
    return result;
}
// 获取数组表达式的元素类型（返回C类型字符串）
// 如果无法确定类型，返回NULL
const char *get_array_element_type(C99CodeGenerator *codegen, ASTNode *array_expr) {
    if (!array_expr) return NULL;
    
    // 如果是标识符，从变量表查找类型
    if (array_expr->type == AST_IDENTIFIER) {
        const char *var_name = array_expr->data.identifier.name;
        if (!var_name) return NULL;
        
        // 检查局部变量
        for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
            if (strcmp(codegen->local_variables[i].name, var_name) == 0) {
                const char *type_c = codegen->local_variables[i].type_c;
                if (!type_c) return NULL;
                
                // 检查是否为数组类型（包含'['）
                const char *first_bracket = strchr(type_c, '[');
                if (first_bracket) {
                    // 检查是否有第二个 '['（多维数组）
                    const char *second_bracket = strchr(first_bracket + 1, '[');
                    if (second_bracket) {
                        // 多维数组：提取基类型 + 从第二个 '[' 开始的所有维度
                        // 例如：int32_t[3][2] -> int32_t[2]
                        size_t base_len = first_bracket - type_c;
                        size_t inner_dims_len = strlen(second_bracket);
                        char *elem_type = arena_alloc(codegen->arena, base_len + inner_dims_len + 1);
                        if (!elem_type) return NULL;
                        memcpy(elem_type, type_c, base_len);
                        memcpy(elem_type + base_len, second_bracket, inner_dims_len);
                        elem_type[base_len + inner_dims_len] = '\0';
                        return elem_type;
                    } else {
                        // 单层数组：提取基类型
                        size_t len = first_bracket - type_c;
                        char *elem_type = arena_alloc(codegen->arena, len + 1);
                        if (!elem_type) return NULL;
                        memcpy(elem_type, type_c, len);
                        elem_type[len] = '\0';
                        return elem_type;
                    }
                }
                return NULL;
            }
        }
        
        // 检查全局变量
        for (int i = 0; i < codegen->global_variable_count; i++) {
            if (strcmp(codegen->global_variables[i].name, var_name) == 0) {
                const char *type_c = codegen->global_variables[i].type_c;
                if (!type_c) return NULL;
                
                // 检查是否为数组类型（包含'['）
                const char *first_bracket = strchr(type_c, '[');
                if (first_bracket) {
                    // 检查是否有第二个 '['（多维数组）
                    const char *second_bracket = strchr(first_bracket + 1, '[');
                    if (second_bracket) {
                        // 多维数组：提取基类型 + 从第二个 '[' 开始的所有维度
                        // 例如：int32_t[3][2] -> int32_t[2]
                        size_t base_len = first_bracket - type_c;
                        size_t inner_dims_len = strlen(second_bracket);
                        char *elem_type = arena_alloc(codegen->arena, base_len + inner_dims_len + 1);
                        if (!elem_type) return NULL;
                        memcpy(elem_type, type_c, base_len);
                        memcpy(elem_type + base_len, second_bracket, inner_dims_len);
                        elem_type[base_len + inner_dims_len] = '\0';
                        return elem_type;
                    } else {
                        // 单层数组：提取基类型
                        size_t len = first_bracket - type_c;
                        char *elem_type = arena_alloc(codegen->arena, len + 1);
                        if (!elem_type) return NULL;
                        memcpy(elem_type, type_c, len);
                        elem_type[len] = '\0';
                        return elem_type;
                    }
                }
                return NULL;
            }
        }
        
        return NULL;
    }
    
    if (array_expr->type == AST_ARRAY_ACCESS) {
        ASTNode *base_array = array_expr->data.array_access.array;
        return get_array_element_type(codegen, base_array);
    }
    
    if (array_expr->type == AST_SLICE_EXPR) {
        ASTNode *base = array_expr->data.slice_expr.base;
        if (base->type == AST_SLICE_EXPR) {
            return get_array_element_type(codegen, base);
        }
        if (base->type == AST_IDENTIFIER) {
            const char *type_c = get_identifier_type_c(codegen, base->data.identifier.name);
            if (type_c) {
                const char *p = strstr(type_c, "uya_slice_");
                if (p) {
                    p += 10;
                    size_t len = strlen(p);
                    char *elem = arena_alloc(codegen->arena, len + 1);
                    if (elem) {
                        memcpy(elem, p, len + 1);
                        return elem;
                    }
                }
            }
            return get_array_element_type(codegen, base);
        }
        return NULL;
    }
    
    // 如果是数组字面量，从第一个元素推断类型
    if (array_expr->type == AST_ARRAY_LITERAL) {
        ASTNode **elements = array_expr->data.array_literal.elements;
        int element_count = array_expr->data.array_literal.element_count;
        if (element_count > 0 && elements[0]) {
            // 对于数组字面量，我们需要推断第一个元素的类型
            // 这是一个简化实现，实际应该从类型检查器获取类型信息
            // 暂时返回NULL，让调用者使用默认类型
            return NULL;
        }
        return NULL;
    }
    
    return NULL;
}
