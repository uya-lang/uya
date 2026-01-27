#include "internal.h"

// 前向声明
ASTNode *find_struct_decl(CodeGenerator *codegen, const char *struct_name);
LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node);
void register_structs_in_node(CodeGenerator *codegen, ASTNode *node);
LLVMValueRef lookup_func(CodeGenerator *codegen, const char *func_name, LLVMTypeRef *func_type_out);

// 查找函数
LLVMValueRef lookup_func(CodeGenerator *codegen, const char *func_name, LLVMTypeRef *func_type_out) {
    if (!codegen || !func_name) {
        return NULL;
    }
    
    // 线性查找
    for (int i = 0; i < codegen->func_map_count; i++) {
        if (codegen->func_map[i].name != NULL && 
            strcmp(codegen->func_map[i].name, func_name) == 0) {
            if (func_type_out) {
                *func_type_out = codegen->func_map[i].func_type;
            }
            return codegen->func_map[i].func;
        }
    }
    
    return NULL;  // 未找到
}

// 声明所有函数
void declare_functions_in_node(CodeGenerator *codegen, ASTNode *node) {
    if (!codegen || !node) {
        return;
    }

    switch (node->type) {
        case AST_PROGRAM: {
            int decl_count = node->data.program.decl_count;
            ASTNode **decls = node->data.program.decls;
            for (int i = 0; i < decl_count; i++) {
                if (decls && decls[i]) {
                    declare_functions_in_node(codegen, decls[i]);
                }
            }
            return;
        }

        case AST_FN_DECL: {
            // 先声明函数本身
            (void)codegen_declare_function(codegen, node);

            // 再递归其函数体，查找/声明嵌套函数
            ASTNode *body = node->data.fn_decl.body;
            if (body) {
                declare_functions_in_node(codegen, body);
            }
            return;
        }

        case AST_BLOCK: {
            int stmt_count = node->data.block.stmt_count;
            ASTNode **stmts = node->data.block.stmts;
            for (int i = 0; i < stmt_count; i++) {
                if (stmts && stmts[i]) {
                    declare_functions_in_node(codegen, stmts[i]);
                }
            }
            return;
        }

        case AST_IF_STMT: {
            if (node->data.if_stmt.then_branch) {
                declare_functions_in_node(codegen, node->data.if_stmt.then_branch);
            }
            if (node->data.if_stmt.else_branch) {
                declare_functions_in_node(codegen, node->data.if_stmt.else_branch);
            }
            return;
        }

        case AST_WHILE_STMT: {
            if (node->data.while_stmt.body) {
                declare_functions_in_node(codegen, node->data.while_stmt.body);
            }
            return;
        }

        case AST_FOR_STMT: {
            if (node->data.for_stmt.body) {
                declare_functions_in_node(codegen, node->data.for_stmt.body);
            }
            return;
        }

        default:
            return;
    }
}

// 在节点中查找函数声明
ASTNode *find_fn_decl_in_node(ASTNode *node, const char *func_name) {
    if (!node || !func_name) {
        return NULL;
    }
    switch (node->type) {
        case AST_FN_DECL: {
            const char *name = node->data.fn_decl.name;
            if (name && strcmp(name, func_name) == 0) {
                return node;
            }
            // 继续在函数体内查找（容忍解析器把函数误解析为嵌套声明的情况）
            ASTNode *body = node->data.fn_decl.body;
            return body ? find_fn_decl_in_node(body, func_name) : NULL;
        }
        case AST_PROGRAM: {
            ASTNode **decls = node->data.program.decls;
            int decl_count = node->data.program.decl_count;
            for (int i = 0; i < decl_count; i++) {
                ASTNode *found = (decls && decls[i]) ? find_fn_decl_in_node(decls[i], func_name) : NULL;
                if (found) {
                    return found;
                }
            }
            return NULL;
        }
        case AST_BLOCK: {
            ASTNode **stmts = node->data.block.stmts;
            int stmt_count = node->data.block.stmt_count;
            for (int i = 0; i < stmt_count; i++) {
                ASTNode *found = (stmts && stmts[i]) ? find_fn_decl_in_node(stmts[i], func_name) : NULL;
                if (found) {
                    return found;
                }
            }
            return NULL;
        }
        case AST_IF_STMT: {
            ASTNode *found = node->data.if_stmt.then_branch ? find_fn_decl_in_node(node->data.if_stmt.then_branch, func_name) : NULL;
            if (found) return found;
            return node->data.if_stmt.else_branch ? find_fn_decl_in_node(node->data.if_stmt.else_branch, func_name) : NULL;
        }
        case AST_WHILE_STMT:
            return node->data.while_stmt.body ? find_fn_decl_in_node(node->data.while_stmt.body, func_name) : NULL;
        case AST_FOR_STMT:
            return node->data.for_stmt.body ? find_fn_decl_in_node(node->data.for_stmt.body, func_name) : NULL;
        default:
            return NULL;
    }
}

// 查找函数声明
ASTNode *find_fn_decl(CodeGenerator *codegen, const char *func_name) {
    if (!codegen || !func_name) {
        return NULL;
    }
    if (!codegen->program_node) {
        return NULL;
    }
    return find_fn_decl_in_node(codegen->program_node, func_name);
}

// 添加函数到函数表
int add_func(CodeGenerator *codegen, const char *func_name, LLVMValueRef func, LLVMTypeRef func_type) {
    if (!codegen || !func_name || !func || !func_type) {
        return -1;
    }
    
    // 检查映射表是否已满
    if (codegen->func_map_count >= 256) {
        return -1;  // 映射表已满
    }
    
    // 添加到映射表
    int idx = codegen->func_map_count;
    codegen->func_map[idx].name = func_name;
    codegen->func_map[idx].func = func;
    codegen->func_map[idx].func_type = func_type;
    codegen->func_map_count++;
    
    return 0;
}

// 声明函数
int codegen_declare_function(CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!codegen || !fn_decl || fn_decl->type != AST_FN_DECL) {
        return -1;
    }
    
    const char *func_name = fn_decl->data.fn_decl.name;
    ASTNode *return_type_node = fn_decl->data.fn_decl.return_type;
    int param_count = fn_decl->data.fn_decl.param_count;
    ASTNode **params = fn_decl->data.fn_decl.params;
    
    if (!func_name || !return_type_node) {
        // 调试信息
        if (func_name) {
            fprintf(stderr, "调试: 函数声明失败 %s: func_name 或 return_type_node 为空\n", func_name);
        }
        return -1;
    }
    
    // 检查函数是否已经声明（在函数表中查找）
    LLVMTypeRef func_type_check = NULL;
    if (lookup_func(codegen, func_name, &func_type_check) != NULL) {
        return 0;  // 已在函数表中，跳过
    }
    
    // 获取返回类型
    LLVMTypeRef return_type = get_llvm_type_from_ast(codegen, return_type_node);
    if (!return_type) {
        // 放宽检查：如果返回类型获取失败（可能是结构体类型未注册），
        // 尝试使用通用指针类型（i8*）作为返回类型
        // 这在编译器自举时很常见，因为结构体类型可能尚未注册
        if (return_type_node && return_type_node->type == AST_TYPE_POINTER) {
            // 如果是指针类型但获取失败，使用通用指针类型（i8*）
            LLVMTypeRef i8_type = LLVMInt8TypeInContext(codegen->context);
            return_type = LLVMPointerType(i8_type, 0);
        } else {
            // 对于返回类型，如果是命名类型但获取失败，可能是结构体类型未注册
            // 这种情况下，尝试使用通用指针类型（i8*）作为返回类型
            // 这样可以确保函数被声明，即使结构体类型尚未注册
            if (return_type_node && return_type_node->type == AST_TYPE_NAMED) {
                const char *type_name = return_type_node->data.type_named.name;
                if (type_name != NULL) {
                    // 尝试查找结构体类型（可能尚未注册）
                    LLVMTypeRef struct_type = codegen_get_struct_type(codegen, type_name);
                    if (struct_type != NULL) {
                        return_type = struct_type;
                    } else {
                        // 如果结构体类型未找到，使用通用指针类型（i8*）作为返回类型
                        // 这样可以确保函数被声明，即使结构体类型尚未注册
                        // 注意：这可能导致类型不匹配，但在编译器自举时是必要的
                        LLVMTypeRef i8_type = LLVMInt8TypeInContext(codegen->context);
                        return_type = LLVMPointerType(i8_type, 0);
                    }
                } else {
                    return -1;
                }
            } else {
                // 调试信息
                fprintf(stderr, "调试: 函数声明失败 %s: 返回类型获取失败\n", func_name);
                if (return_type_node) {
                    fprintf(stderr, "调试: 返回类型节点类型: %d\n", return_type_node->type);
                }
                return -1;
            }
        }
    }
    
    // 准备参数类型数组
    // 注意：16 字节结构体（4 个 i32）需要转换为两个 i64 参数，所以需要更大的数组
    LLVMTypeRef *param_types = NULL;
    int actual_param_count = param_count;
    if (param_count > 0) {
        if (param_count > 16) {
            return -1;
        }
        // 为可能的参数扩展预留空间（16 字节结构体需要 2 个参数）
        LLVMTypeRef param_types_array[32];
        param_types = param_types_array;
        
        int actual_index = 0;
        int is_extern = (fn_decl->data.fn_decl.body == NULL) ? 1 : 0;
        
        for (int i = 0; i < param_count; i++) {
            ASTNode *param = params[i];
            if (!param || param->type != AST_VAR_DECL) {
                return -1;
            }
            
            ASTNode *param_type_node = param->data.var_decl.type;
            LLVMTypeRef param_type = get_llvm_type_from_ast(codegen, param_type_node);
            if (!param_type) {
                // 放宽检查：如果参数类型获取失败（可能是结构体类型未注册），
                // 尝试使用通用指针类型（i8*）作为参数类型
                // 这在编译器自举时很常见，因为结构体类型可能尚未注册
                if (param_type_node && param_type_node->type == AST_TYPE_POINTER) {
                    // 如果是指针类型但获取失败，使用通用指针类型（i8*）
                    LLVMTypeRef i8_type = LLVMInt8TypeInContext(codegen->context);
                    param_type = LLVMPointerType(i8_type, 0);
                } else if (param_type_node && param_type_node->type == AST_TYPE_NAMED) {
                    // 如果是命名类型但获取失败（可能是结构体类型未注册），
                    // 使用通用指针类型（i8*）作为参数类型
                    LLVMTypeRef i8_type = LLVMInt8TypeInContext(codegen->context);
                    param_type = LLVMPointerType(i8_type, 0);
                } else {
                    // 调试信息
                    fprintf(stderr, "调试: 函数声明失败 %s: 参数 %d 类型获取失败\n", func_name, i);
                    if (param_type_node) {
                        fprintf(stderr, "调试: 参数类型节点类型: %d\n", param_type_node->type);
                        if (param_type_node->type == AST_TYPE_NAMED && param_type_node->data.type_named.name) {
                            fprintf(stderr, "调试: 参数类型名称: %s\n", param_type_node->data.type_named.name);
                        }
                    }
                    return -1;
                }
            }
            
            // 检查是否为 extern 函数，且参数是结构体类型
            // 根据 x86-64 System V ABI：
            // - 8 字节结构体（两个 i32）：转换为单个 i64 参数
            // - 16 字节结构体（四个 i32）：转换为两个 i64 参数
            // - 大于 16 字节的结构体：通过指针传递
            if (is_extern && LLVMGetTypeKind(param_type) == LLVMStructTypeKind) {
                // 计算结构体大小
                LLVMTargetDataRef target_data = LLVMGetModuleDataLayout(codegen->module);
                unsigned long long struct_size = 0;
                unsigned field_count = LLVMCountStructElementTypes(param_type);
                if (target_data) {
                    struct_size = LLVMStoreSizeOfType(target_data, param_type);
                } else {
                    // 如果 target_data 为 NULL，尝试通过字段数估算大小
                    // 对于 i32 字段，每个字段 4 字节
                    struct_size = field_count * 4;  // 简单估算
                }
                
                // 大结构体（>16 字节）：通过指针传递（优先检查，避免字段数检查的复杂性）
                // 如果字段数 >= 6（24 字节），也认为是大结构体
                if (struct_size > 16 || field_count >= 6) {
                    param_type = LLVMPointerType(param_type, 0);
                    param_types[actual_index++] = param_type;
                    continue;
                }
                if (field_count == 2) {
                    LLVMTypeRef field_types[2];
                    LLVMGetStructElementTypes(param_type, field_types);
                    int is_small_struct = 1;
                    for (unsigned j = 0; j < 2; j++) {
                        if (LLVMGetTypeKind(field_types[j]) != LLVMIntegerTypeKind ||
                            LLVMGetIntTypeWidth(field_types[j]) != 32) {
                            is_small_struct = 0;
                            break;
                        }
                    }
                    if (is_small_struct) {
                        // 8 字节结构体（两个 i32）：改为 i64 类型
                        param_type = LLVMInt64TypeInContext(codegen->context);
                        param_types[actual_index++] = param_type;
                        continue;
                    }
                } else if (field_count == 4) {
                    LLVMTypeRef field_types[4];
                    LLVMGetStructElementTypes(param_type, field_types);
                    int is_medium_struct = 1;
                    for (unsigned j = 0; j < 4; j++) {
                        if (LLVMGetTypeKind(field_types[j]) != LLVMIntegerTypeKind ||
                            LLVMGetIntTypeWidth(field_types[j]) != 32) {
                            is_medium_struct = 0;
                            break;
                        }
                    }
                    if (is_medium_struct) {
                        // 16 字节结构体（四个 i32）：转换为两个 i64 参数
                        LLVMTypeRef i64_type = LLVMInt64TypeInContext(codegen->context);
                        param_types[actual_index++] = i64_type;
                        param_types[actual_index++] = i64_type;
                        actual_param_count++;  // 增加一个参数
                        continue;
                    }
                }
            }

            // 数组参数：按引用传递（参数类型使用 “指向数组的指针”）
            // 代码生成中数组变量作为表达式时通常返回数组地址（ptr），因此函数签名也应接受 ptr
            if (LLVMGetTypeKind(param_type) == LLVMArrayTypeKind) {
                param_type = LLVMPointerType(param_type, 0);
            }
            
            param_types[actual_index++] = param_type;
        }
        
        // 更新实际参数数量
        param_count = actual_param_count;
    }
    
    // 处理 extern 函数返回小/中等结构体的 ABI 问题
    if (fn_decl->data.fn_decl.body == NULL && return_type && LLVMGetTypeKind(return_type) == LLVMStructTypeKind) {
        LLVMTargetDataRef target_data = LLVMGetModuleDataLayout(codegen->module);
        if (target_data) {
            unsigned long long struct_size = LLVMStoreSizeOfType(target_data, return_type);
            unsigned field_count = LLVMCountStructElementTypes(return_type);
            
            // 小结构体（8字节，两个i32）：改为 i64 类型返回
            if (struct_size == 8 && field_count == 2) {
                LLVMTypeRef field_types[2];
                LLVMGetStructElementTypes(return_type, field_types);
                int is_small_struct = 1;
                for (unsigned j = 0; j < 2; j++) {
                    if (LLVMGetTypeKind(field_types[j]) != LLVMIntegerTypeKind ||
                        LLVMGetIntTypeWidth(field_types[j]) != 32) {
                        is_small_struct = 0;
                        break;
                    }
                }
                if (is_small_struct) {
                    fprintf(stderr, "调试: 将 extern 函数 %s 的返回类型从 SmallStruct 改为 i64\n", func_name);
                    return_type = LLVMInt64TypeInContext(codegen->context);
                }
            }
            // 中等结构体（16字节，四个i32）：改为两个 i64 类型返回（通过结构体包装）
            else if (struct_size == 16 && field_count == 4) {
                LLVMTypeRef field_types[4];
                LLVMGetStructElementTypes(return_type, field_types);
                int is_medium_struct = 1;
                for (unsigned j = 0; j < 4; j++) {
                    if (LLVMGetTypeKind(field_types[j]) != LLVMIntegerTypeKind ||
                        LLVMGetIntTypeWidth(field_types[j]) != 32) {
                        is_medium_struct = 0;
                        break;
                    }
                }
                if (is_medium_struct) {
                    fprintf(stderr, "调试: 将 extern 函数 %s 的返回类型从 MediumStruct 改为 { i64, i64 }\n", func_name);
                    // 创建 { i64, i64 } 结构体类型，使用正确的上下文
                    LLVMTypeRef i64_type = LLVMInt64TypeInContext(codegen->context);
                    LLVMTypeRef field_types_2i64[2] = { i64_type, i64_type };
                    return_type = LLVMStructTypeInContext(codegen->context, field_types_2i64, 2, 0);
                }
            }
        }
    }
    
    // 创建函数类型（最后一个参数 isVarArg 表示是否为可变参数函数）
    int is_varargs = fn_decl->data.fn_decl.is_varargs;
    LLVMTypeRef func_type = LLVMFunctionType(return_type, param_types, param_count, is_varargs);
    if (!func_type) {
        return -1;
    }
    
    // 创建函数声明（添加到模块）
    LLVMValueRef func = LLVMAddFunction(codegen->module, func_name, func_type);
    if (!func) {
        return -1;
    }
    
    // 添加到函数表
    if (add_func(codegen, func_name, func, func_type) != 0) {
        return -1;
    }
    
    return 0;
}

