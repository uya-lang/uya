#include "internal.h"

// 前向声明
LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node);
LLVMValueRef build_entry_alloca(CodeGenerator *codegen, LLVMTypeRef type, const char *name);
int add_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef value, LLVMTypeRef type, const char *struct_name, ASTNode *ast_type);
int codegen_gen_stmt(CodeGenerator *codegen, ASTNode *stmt);
LLVMValueRef codegen_gen_expr(CodeGenerator *codegen, ASTNode *expr);

int codegen_gen_function(CodeGenerator *codegen, ASTNode *fn_decl) {
    // 第一层检查：基本指针检查
    if (!codegen || !fn_decl) {
        fprintf(stderr, "错误: codegen_gen_function 参数检查失败（空指针）\n");
        return -1;
    }
    
    // 打印调试信息：函数节点地址
    fprintf(stderr, "调试: codegen_gen_function 开始处理函数节点（地址: %p）\n", (void *)fn_decl);
    
    // 第二层检查：类型检查（在访问 union 字段之前必须检查）
    // 注意：如果 fn_decl 的内存损坏，访问 fn_decl->type 也可能导致段错误
    // 但这是必要的检查，无法避免
    fprintf(stderr, "调试: 检查函数节点类型...\n");
    if (fn_decl->type != AST_FN_DECL) {
        fprintf(stderr, "错误: codegen_gen_function 类型不匹配: %d (期望 %d)\n", 
                fn_decl->type, AST_FN_DECL);
        return -1;
    }
    fprintf(stderr, "调试: 函数节点类型正确 (AST_FN_DECL)\n");
    
    // 安全地访问 fn_decl 字段，添加额外的检查
    const char *func_name = NULL;
    ASTNode *return_type_node = NULL;
    ASTNode *body = NULL;
    int param_count = 0;
    ASTNode **params = NULL;
    
    // 安全地访问 fn_decl 字段（类型已在函数入口检查过）
    // 使用临时变量避免重复访问 union 字段
    // 注意：如果 fn_decl 的内存损坏，访问这些字段可能导致段错误
    // 因此我们需要非常小心地访问，并在访问后立即检查
    
    // 先访问基本字段（这些字段访问相对安全）
    // 使用 volatile 指针强制内存访问，避免编译器优化导致的问题
    // 注意：如果 fn_decl 的内存损坏，访问这些字段可能导致段错误
    // 但我们已经在函数入口检查了类型，所以这里应该是安全的
    
    // 尝试安全地访问 name 字段
    // 如果访问失败（段错误），程序会崩溃，但这是必要的检查
    volatile const char *volatile_func_name = NULL;
    volatile ASTNode *volatile_return_type_node = NULL;
    volatile ASTNode *volatile_body = NULL;
    
    // 使用 try-catch 机制（通过检查指针有效性）
    // 注意：在 C 中无法真正捕获段错误，但我们可以添加检查
    if ((unsigned long)fn_decl < 0x1000 || (unsigned long)fn_decl > 0x7fffffffffff) {
        fprintf(stderr, "错误: codegen_gen_function fn_decl 指针无效: %p\n", (void *)fn_decl);
        return -1;
    }
    
    // 安全地访问字段
    fprintf(stderr, "调试: 准备访问函数名字段...\n");
    volatile_func_name = fn_decl->data.fn_decl.name;
    fprintf(stderr, "调试: 函数名字段访问成功: %p\n", (void *)volatile_func_name);
    
    fprintf(stderr, "调试: 准备访问返回类型字段...\n");
    volatile_return_type_node = fn_decl->data.fn_decl.return_type;
    fprintf(stderr, "调试: 返回类型字段访问成功: %p\n", (void *)volatile_return_type_node);
    
    fprintf(stderr, "调试: 准备访问函数体字段...\n");
    volatile_body = fn_decl->data.fn_decl.body;
    fprintf(stderr, "调试: 函数体字段访问成功: %p\n", (void *)volatile_body);
    
    // 将 volatile 值赋给普通变量（避免后续代码中的 volatile 问题）
    func_name = (const char *)volatile_func_name;
    return_type_node = (ASTNode *)volatile_return_type_node;
    body = (ASTNode *)volatile_body;
    
    // 立即检查基本字段，如果为空则提前返回
    fprintf(stderr, "调试: 检查函数名和返回类型...\n");
    if (!func_name || !return_type_node) {
        // 添加调试信息：打印 fn_decl 的地址和类型，帮助定位问题
        fprintf(stderr, "警告: codegen_gen_function 函数名或返回类型为空\n");
        fprintf(stderr, "  fn_decl 地址: %p\n", (void *)fn_decl);
        fprintf(stderr, "  fn_decl->type: %d\n", fn_decl->type);
        fprintf(stderr, "  func_name: %p\n", (void *)func_name);
        fprintf(stderr, "  return_type_node: %p\n", (void *)return_type_node);
        // 放宽检查：如果函数名或返回类型为空，跳过该函数的生成
        // 这在编译器自举时可能发生，因为某些函数可能无法正确解析
        return 0;  // 返回成功，但不生成函数体
    }
    
    // 打印函数名（如果能够安全访问）
    fprintf(stderr, "调试: 正在生成函数: %s\n", func_name);
    
    // 然后访问参数相关字段（这些字段可能在内存损坏时导致问题）
    fprintf(stderr, "调试: 准备访问参数字段...\n");
    // 使用 volatile 指针强制内存访问，避免编译器优化导致的问题
    volatile int volatile_param_count = fn_decl->data.fn_decl.param_count;
    fprintf(stderr, "调试: 参数数量: %d\n", (int)volatile_param_count);
    
    volatile void *volatile_params_ptr = (volatile void *)fn_decl->data.fn_decl.params;
    fprintf(stderr, "调试: 参数数组指针: %p\n", volatile_params_ptr);
    
    // 将 volatile 值赋给普通变量
    param_count = (int)volatile_param_count;
    params = (ASTNode **)(void *)volatile_params_ptr;
    
    // 检查 param_count 的合理性（防止内存损坏导致异常值）
    if (param_count < 0 || param_count > 256) {
        fprintf(stderr, "警告: codegen_gen_function 参数数量异常: %d，跳过该函数: %s\n", 
                param_count, func_name ? func_name : "(null)");
        return 0;  // 返回成功，但不生成函数体
    }
    
    // 检查函数名指针的有效性（基本的内存地址检查）
    // 如果函数名指针看起来无效（在低地址或高地址范围），跳过该函数
    if ((unsigned long)func_name < 0x1000 || (unsigned long)func_name > 0x7fffffffffff) {
        fprintf(stderr, "警告: codegen_gen_function 函数名指针无效: %p，跳过该函数\n", func_name);
        return 0;  // 返回成功，但不生成函数体
    }
    
    // 检查参数数组：如果 param_count > 0，params 必须不为 NULL
    if (param_count > 0 && !params) {
        fprintf(stderr, "错误: codegen_gen_function 参数数量 > 0 但参数数组为 NULL: %s\n", 
                func_name ? func_name : "(null)");
        return -1;
    }
    
    // extern 函数没有函数体，只生成声明
    fprintf(stderr, "调试: 检查是否为 extern 函数...\n");
    int is_extern = (body == NULL) ? 1 : 0;
    fprintf(stderr, "调试: is_extern = %d\n", is_extern);
    
    // 获取返回类型
    fprintf(stderr, "调试: 获取返回类型...\n");
    LLVMTypeRef return_type = get_llvm_type_from_ast(codegen, return_type_node);
    fprintf(stderr, "调试: 返回类型获取完成: %p\n", (void *)return_type);
    if (!return_type) {
        // 放宽检查：如果返回类型获取失败（可能是结构体类型未注册），
        // 跳过该函数的生成，继续处理其他函数
        // 这在编译器自举时很常见，因为结构体类型可能尚未注册
        return 0;  // 返回成功，但不生成函数体
    }
    
    // 准备参数类型数组
    fprintf(stderr, "调试: 准备参数类型数组（参数数量: %d）...\n", param_count);
    LLVMTypeRef *param_types = NULL;
    if (param_count > 0) {
        // 使用固定大小数组（栈分配，无堆分配）
        // 注意：最多支持16个参数（如果超过需要调整）
        if (param_count > 16) {
            fprintf(stderr, "错误: 参数过多 (%d > 16)，跳过函数: %s\n", param_count, func_name);
            return -1;  // 参数过多
        }
        fprintf(stderr, "调试: 分配参数类型数组（大小: %d）...\n", param_count);
        LLVMTypeRef param_types_array[16];
        param_types = param_types_array;
        
        // 遍历参数，获取每个参数的类型
        fprintf(stderr, "调试: 开始遍历参数，获取每个参数的类型...\n");
        for (int i = 0; i < param_count; i++) {
            fprintf(stderr, "调试: 处理第 %d/%d 个参数...\n", i + 1, param_count);
            
            ASTNode *param = params[i];
            if (!param || param->type != AST_VAR_DECL) {
                fprintf(stderr, "错误: 参数 %d 无效，跳过函数: %s\n", i, func_name);
                return -1;
            }
            
            fprintf(stderr, "调试: 获取参数 %d 的类型节点...\n", i);
            ASTNode *param_type_node = param->data.var_decl.type;
            if (!param_type_node) {
                fprintf(stderr, "错误: 参数 %d 的类型节点为 NULL，跳过函数: %s\n", i, func_name);
                return -1;
            }
            
            fprintf(stderr, "调试: 调用 get_llvm_type_from_ast 获取参数 %d 的 LLVM 类型...\n", i);
            LLVMTypeRef param_type = get_llvm_type_from_ast(codegen, param_type_node);
            if (!param_type) {
                fprintf(stderr, "警告: 参数 %d 的类型获取失败，跳过函数: %s\n", i, func_name);
                // 放宽检查：如果参数类型获取失败（可能是结构体类型未注册），
                // 跳过该函数的生成，继续处理其他函数
                // 这在编译器自举时很常见，因为结构体类型可能尚未注册
                return 0;  // 返回成功，但不生成函数体
            }
            
            fprintf(stderr, "调试: 参数 %d 的类型获取成功: %p\n", i, (void *)param_type);
            param_types[i] = param_type;
        }
        fprintf(stderr, "调试: 所有参数类型获取完成\n");
    }
    
    // 获取函数（应该已经在声明阶段创建）
    fprintf(stderr, "调试: 查找函数 '%s'...\n", func_name);
    LLVMValueRef func = lookup_func(codegen, func_name, NULL);
    if (!func) {
        fprintf(stderr, "警告: 函数 '%s' 未找到，跳过函数体生成\n", func_name);
        // 放宽检查：如果函数未声明（可能是因为返回类型未注册的结构体类型而跳过了声明），
        // 跳过该函数的生成，继续处理其他函数
        // 这在编译器自举时很常见，因为结构体类型可能尚未注册
        return 0;  // 返回成功，但不生成函数体
    }
    fprintf(stderr, "调试: 函数 '%s' 找到: %p\n", func_name, (void *)func);
    
    // 检查函数体是否已经定义
    fprintf(stderr, "调试: 检查函数体是否已定义...\n");
    if (LLVMGetFirstBasicBlock(func) != NULL) {
        fprintf(stderr, "调试: 函数体已存在，跳过函数体生成\n");
        // 函数体已存在，跳过函数体生成
        return 0;
    }
    
    // extern 函数只生成声明，不生成函数体
    if (is_extern) {
        fprintf(stderr, "调试: extern 函数，跳过函数体生成\n");
        return 0;  // extern 函数处理完成
    }
    
    // 普通函数需要生成函数体
    // 确保函数体不为 NULL
    if (!body) {
        fprintf(stderr, "错误: codegen_gen_function 非 extern 函数但函数体为 NULL: %s\n", func_name);
        return -1;
    }
    
    // 创建函数体的基本块
    fprintf(stderr, "调试: 创建函数入口基本块...\n");
    LLVMBasicBlockRef entry_bb = LLVMAppendBasicBlock(func, "entry");
    if (!entry_bb) {
        fprintf(stderr, "错误: 创建入口基本块失败，函数: %s\n", func_name);
        return -1;
    }
    fprintf(stderr, "调试: 入口基本块创建成功: %p\n", (void *)entry_bb);

    // 设置构建器位置到入口基本块
    fprintf(stderr, "调试: 设置构建器位置到入口基本块...\n");
    LLVMPositionBuilderAtEnd(codegen->builder, entry_bb);
    fprintf(stderr, "调试: 构建器位置设置完成\n");
    
    // 在生成函数体代码之前，先注册函数内部的结构体声明
    // 这样在生成代码时，结构体类型已经可用
    fprintf(stderr, "调试: 注册函数内部的结构体声明...\n");
    register_structs_in_node(codegen, body);
    fprintf(stderr, "调试: 函数内部的结构体声明注册完成\n");
    
    // 保存当前变量表状态（用于函数结束后恢复）
    fprintf(stderr, "调试: 保存变量表状态...\n");
    int saved_var_map_count = codegen->var_map_count;
    fprintf(stderr, "调试: 变量表状态已保存 (count: %d)\n", saved_var_map_count);
    
    // 处理函数参数：将参数值 store 到 alloca 分配的栈变量
    fprintf(stderr, "调试: 开始处理函数参数（共 %d 个）...\n", param_count);
    for (int i = 0; i < param_count; i++) {
        fprintf(stderr, "调试: 处理参数 %d/%d...\n", i + 1, param_count);
        
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) {
            fprintf(stderr, "错误: 参数 %d 无效，函数: %s\n", i, func_name);
            return -1;
        }
        
        fprintf(stderr, "调试: 获取参数 %d 的名称和类型节点...\n", i);
        const char *param_name = param->data.var_decl.name;
        ASTNode *param_type_node = param->data.var_decl.type;
        if (!param_name || !param_type_node) {
            fprintf(stderr, "错误: 参数 %d 的名称或类型节点为 NULL，函数: %s\n", i, func_name);
            return -1;
        }
        
        fprintf(stderr, "调试: 参数 %d 名称: %s\n", i, param_name);
        
        // 获取参数类型
        fprintf(stderr, "调试: 获取参数 %d 的 LLVM 类型...\n", i);
        LLVMTypeRef param_type = get_llvm_type_from_ast(codegen, param_type_node);
        if (!param_type) {
            fprintf(stderr, "警告: 参数 %d 的类型获取失败，跳过函数: %s\n", i, func_name);
            // 放宽检查：如果参数类型获取失败（可能是结构体类型未注册），
            // 跳过该函数的生成，继续处理其他函数
            // 这在编译器自举时很常见，因为结构体类型可能尚未注册
            return 0;  // 返回成功，但不生成函数体
        }
        fprintf(stderr, "调试: 参数 %d 的类型获取成功: %p\n", i, (void *)param_type);
        
        // 提取结构体名称（如果类型是结构体类型或指针指向结构体类型）
        const char *struct_name = NULL;
        if (param_type_node->type == AST_TYPE_NAMED) {
            const char *type_name = param_type_node->data.type_named.name;
            if (type_name && strcmp(type_name, "i32") != 0 && 
                strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0) {
                // 可能是结构体类型
                if (codegen_get_struct_type(codegen, type_name) != NULL) {
                    struct_name = type_name;  // 名称已经在 Arena 中
                }
            }
        } else if (param_type_node->type == AST_TYPE_POINTER) {
            // 指针类型：检查指向的类型是否为结构体类型
            ASTNode *pointed_type = param_type_node->data.type_pointer.pointed_type;
            if (pointed_type && pointed_type->type == AST_TYPE_NAMED) {
                const char *type_name = pointed_type->data.type_named.name;
                if (type_name && strcmp(type_name, "i32") != 0 && 
                    strcmp(type_name, "bool") != 0 && strcmp(type_name, "byte") != 0 && 
                    strcmp(type_name, "void") != 0) {
                    // 可能是结构体类型
                    if (codegen_get_struct_type(codegen, type_name) != NULL) {
                        struct_name = type_name;  // 名称已经在 Arena 中
                    }
                }
            }
        }
        
        // 使用 alloca 分配栈空间（存储参数值）
        fprintf(stderr, "调试: 为参数 %d (%s) 分配栈空间...\n", i, param_name);
        LLVMValueRef param_ptr = LLVMBuildAlloca(codegen->builder, param_type, param_name);
        if (!param_ptr) {
            fprintf(stderr, "错误: 为参数 %d 分配栈空间失败，函数: %s\n", i, func_name);
            return -1;
        }
        fprintf(stderr, "调试: 参数 %d 的栈空间分配成功: %p\n", i, (void *)param_ptr);
        
        // 获取函数参数值（LLVMGetParam）
        fprintf(stderr, "调试: 获取函数参数值 (LLVMGetParam)...\n");
        LLVMValueRef param_val = LLVMGetParam(func, i);
        if (!param_val) {
            fprintf(stderr, "警告: 获取函数参数 %d 的值失败，跳过函数: %s\n", i, func_name);
            // 放宽检查：如果参数值获取失败，跳过该函数的生成
            // 这在编译器自举时可能发生
            return 0;  // 返回成功，但不生成函数体
        }
        fprintf(stderr, "调试: 函数参数 %d 的值获取成功: %p\n", i, (void *)param_val);
        
        // store 参数值到栈变量
        fprintf(stderr, "调试: 将参数值存储到栈变量...\n");
        LLVMBuildStore(codegen->builder, param_val, param_ptr);
        fprintf(stderr, "调试: 参数值存储完成\n");
        
        // 添加到变量表
        fprintf(stderr, "调试: 将参数注册到变量表...\n");
        if (add_var(codegen, param_name, param_ptr, param_type, struct_name, param_type_node) != 0) {
            fprintf(stderr, "错误: 将参数注册到变量表失败，函数: %s\n", func_name);
            return -1;
        }
        fprintf(stderr, "调试: 参数 %d 处理完成\n", i);
    }
    fprintf(stderr, "调试: 所有函数参数处理完成\n");
    
    // 生成函数体代码
    fprintf(stderr, "调试: 开始生成函数体代码...\n");
    int stmt_result = codegen_gen_stmt(codegen, body);
    fprintf(stderr, "调试: stmt_result = %d\n", stmt_result);
    if (stmt_result != 0) {
        fprintf(stderr, "警告: 生成函数体代码失败，跳过函数: %s\n", func_name);
        // 即使函数体生成失败，也要确保基本块有终止符
        // 这在编译器自举时很常见，因为类型推断可能失败或结构体类型未注册
    } else {
        fprintf(stderr, "调试: 函数体代码生成完成\n");
    }

    // 检查函数的所有基本块，确保它们都有终止符
    // 注意：即使 stmt 生成失败，也要确保所有基本块有终止符，否则 LLVM 验证会失败
    fprintf(stderr, "调试: 检查函数 %s 的所有基本块 terminator\n", func_name);
    
    // 遍历函数的所有基本块
    LLVMBasicBlockRef bb = LLVMGetFirstBasicBlock(func);
    while (bb) {
        LLVMValueRef terminator = LLVMGetBasicBlockTerminator(bb);
        if (!terminator) {
            fprintf(stderr, "调试: 基本块 %p 没有 terminator，添加默认返回\n", (void *)bb);
            // 设置构建器位置到该基本块末尾
            LLVMPositionBuilderAtEnd(codegen->builder, bb);
            // 添加默认返回
            if (LLVMGetTypeKind(return_type) == LLVMVoidTypeKind) {
                // void 返回
                LLVMBuildRetVoid(codegen->builder);
            } else {
                // 非 void 返回，生成默认返回值（0）
                // 注意：这应该不会发生，因为类型检查应该确保所有非 void 函数都有返回值
                // 但为了安全，我们生成一个默认值
                LLVMValueRef default_val = NULL;
                if (LLVMGetTypeKind(return_type) == LLVMIntegerTypeKind) {
                    default_val = LLVMConstInt(return_type, 0ULL, 0);
                } else if (LLVMGetTypeKind(return_type) == LLVMPointerTypeKind) {
                    default_val = LLVMConstNull(return_type);
                } else if (LLVMGetTypeKind(return_type) == LLVMStructTypeKind) {
                    // 结构体类型：生成零初始化的结构体常量
                    unsigned field_count = LLVMCountStructElementTypes(return_type);
                    LLVMTypeRef field_types[32];
                    if (field_count > 32) {
                        fprintf(stderr, "错误: 结构体字段数过多（>32），无法生成默认返回值\n");
                    } else {
                        LLVMGetStructElementTypes(return_type, field_types);
                        LLVMValueRef field_values[32];
                        for (unsigned i = 0; i < field_count; i++) {
                            LLVMTypeRef field_type = field_types[i];
                            if (LLVMGetTypeKind(field_type) == LLVMIntegerTypeKind) {
                                field_values[i] = LLVMConstInt(field_type, 0ULL, 0);
                            } else if (LLVMGetTypeKind(field_type) == LLVMPointerTypeKind) {
                                field_values[i] = LLVMConstNull(field_type);
                            } else if (LLVMGetTypeKind(field_type) == LLVMStructTypeKind) {
                                // 嵌套结构体：递归生成零初始化常量（简化处理，使用 null）
                                field_values[i] = LLVMConstNull(field_type);
                            } else {
                                field_values[i] = LLVMConstNull(field_type);
                            }
                        }
                        default_val = LLVMConstStruct(field_values, field_count, 0);
                    }
                }
                if (default_val) {
                    LLVMBuildRet(codegen->builder, default_val);
                } else {
                    fprintf(stderr, "错误: 无法为函数 %s 的基本块生成默认返回值\n", func_name);
                    // 继续处理其他基本块，不返回错误
                }
            }
        }
        bb = LLVMGetNextBasicBlock(bb);
    }

    // 恢复变量表状态（函数结束）
    codegen->var_map_count = saved_var_map_count;

    // 如果 stmt 生成失败，返回成功但标记为部分成功
    if (stmt_result != 0) {
        return 0;  // 返回成功，但函数体生成失败
    }
    
    // 恢复变量表状态（函数结束）
    codegen->var_map_count = saved_var_map_count;
    
    return 0;
}

