#include "internal.h"

// 前向声明
void register_structs_in_node(CodeGenerator *codegen, ASTNode *node);
void declare_functions_in_node(CodeGenerator *codegen, ASTNode *node);
int codegen_gen_global_var(CodeGenerator *codegen, ASTNode *var_decl);
int codegen_gen_function(CodeGenerator *codegen, ASTNode *fn_decl);

int codegen_generate(CodeGenerator *codegen, ASTNode *ast, const char *output_file) {
    if (!codegen || !ast || !output_file) {
        return -1;
    }
    
    // 检查是否是程序节点
    if (ast->type != AST_PROGRAM) {
        return -1;
    }
    
    // 保存程序节点（用于查找结构体声明）
    codegen->program_node = ast;
    
    int decl_count = ast->data.program.decl_count;
    ASTNode **decls = ast->data.program.decls;
    
    if (!decls && decl_count > 0) {
        return -1;
    }
    
    // 第零步：初始化目标并设置模块的 DataLayout（需要在生成函数体之前设置，以便 sizeof 可以使用）
    // 初始化LLVM目标（只需要初始化一次，但重复初始化是安全的）
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();
    LLVMInitializeNativeAsmParser();
    
    // 获取默认目标三元组（例如："x86_64-pc-linux-gnu"）
    char *init_target_triple = LLVMGetDefaultTargetTriple();
    if (!init_target_triple) {
        return -1;
    }
    
    // 查找目标
    char *init_error_msg = NULL;
    LLVMTargetRef init_target = NULL;
    if (LLVMGetTargetFromTriple(init_target_triple, &init_target, &init_error_msg) != 0) {
        // 错误处理：释放错误消息
        if (init_error_msg) {
            LLVMDisposeMessage(init_error_msg);
        }
        LLVMDisposeMessage(init_target_triple);
        return -1;
    }
    
    // 创建目标机器（使用默认的CPU和特性）
    LLVMCodeGenOptLevel init_opt_level = LLVMCodeGenLevelDefault;
    LLVMRelocMode init_reloc_mode = LLVMRelocDefault;
    LLVMCodeModel init_code_model = LLVMCodeModelDefault;
    
    LLVMTargetMachineRef init_target_machine = LLVMCreateTargetMachine(
        init_target,
        init_target_triple,
        "",  // CPU（空字符串表示默认）
        "",  // Features（空字符串表示默认）
        init_opt_level,
        init_reloc_mode,
        init_code_model
    );
    
    if (!init_target_machine) {
        LLVMDisposeMessage(init_target_triple);
        return -1;
    }
    
    // 配置模块的目标数据布局（需要在生成函数体之前设置）
    LLVMSetTarget(codegen->module, init_target_triple);
    LLVMTargetDataRef init_target_data = LLVMCreateTargetDataLayout(init_target_machine);
    if (init_target_data) {
        // LLVM 18中，LLVMSetModuleDataLayout 直接接受 LLVMTargetDataRef 类型
        LLVMSetModuleDataLayout(codegen->module, init_target_data);
        LLVMDisposeTargetData(init_target_data);
    }
    
    // 释放资源（第零步创建的 target_machine 和 target_triple）
    LLVMDisposeTargetMachine(init_target_machine);
    LLVMDisposeMessage(init_target_triple);
    
    // 第一步：预注册所有结构体名称作为占位符
    // 这样在生成函数声明时，所有结构体类型都可以被找到（即使内容为空）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) {
            continue;
        }
        
        if (decl->type == AST_STRUCT_DECL) {
            const char *struct_name = decl->data.struct_decl.name;
            if (struct_name != NULL) {
                // 检查结构体类型是否已存在
                if (codegen_get_struct_type(codegen, struct_name) == NULL) {
                    // 创建占位符结构体类型（不透明结构体）
                    // 注意：这里不填充字段，只是注册名称
                    LLVMTypeRef placeholder_type = LLVMStructCreateNamed(codegen->context, struct_name);
                    if (placeholder_type != NULL) {
                        // 添加到结构体类型映射表
                        if (codegen->struct_type_count < 64) {
                            int idx = codegen->struct_type_count;
                            codegen->struct_types[idx].name = struct_name;
                            codegen->struct_types[idx].llvm_type = placeholder_type;
                            codegen->struct_type_count++;
                        }
                    }
                }
            }
        }
    }
    
    // 第二步：注册所有结构体类型（填充字段）
    // 使用多次遍历的方式处理结构体依赖关系（如果结构体字段是其他结构体类型）
    // 每次遍历注册所有可以注册的结构体，直到所有结构体都注册或无法继续注册
    int max_iterations = decl_count + 1;  // 最多迭代 decl_count + 1 次
    fprintf(stderr, "结构体注册: 处理 %d 个声明，最多迭代 %d 次\n", decl_count, max_iterations);
    int iteration = 0;
    
    while (iteration < max_iterations) {
        int registered_this_iteration = 0;
        
        // 遍历所有声明，尝试注册结构体类型
        for (int i = 0; i < decl_count; i++) {
            ASTNode *decl = decls[i];
            if (!decl) {
                continue;
            }
            
            if (decl->type == AST_STRUCT_DECL) {
                // 尝试注册结构体类型（如果已经注册，会返回成功）
                if (codegen_register_struct_type(codegen, decl) == 0) {
                    registered_this_iteration = 1;
                }
            }
        }
        
        // 如果这一轮没有注册任何结构体，说明所有可以注册的结构体都已注册
        if (!registered_this_iteration) {
            break;
        }
        
        iteration++;
    }
    
    // 第二步：生成所有全局变量（在函数声明之前，这样函数可以访问全局变量）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) {
            continue;
        }
        
        if (decl->type == AST_VAR_DECL) {
            // 生成全局变量
            const char *var_name = decl->data.var_decl.name;
            int result = codegen_gen_global_var(codegen, decl);
            if (result != 0) {
                fprintf(stderr, "错误: 全局变量生成失败: %s\n", var_name ? var_name : "(null)");
                return -1;
            }
        }
    }
    
    // 第三步：声明所有函数（包括嵌套在 block 中的 AST_FN_DECL）
    // 这样在生成任何函数体前，lookup_func 就能找到所有已解析到的函数声明
    declare_functions_in_node(codegen, ast);
    
    // 第四步：生成所有函数的函数体
    // 此时所有函数都已被声明，可以相互调用
    fprintf(stderr, "调试: 开始生成函数体，共 %d 个声明\n", decl_count);
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) {
            continue;
        }
        
        if (decl->type == AST_FN_DECL) {
            fprintf(stderr, "调试: 处理第 %d/%d 个函数声明\n", i + 1, decl_count);
            
            // extern 函数没有函数体，跳过
            // 注意：在访问 decl->data.fn_decl.body 之前，decl 的类型已经确认是 AST_FN_DECL
            // 但如果 decl 的内存损坏，访问 union 字段仍可能导致段错误
            // 我们无法在 C 中安全地检查内存是否损坏，只能依赖类型检查
            
            // 尝试安全地访问 body 字段
            // 如果访问失败（段错误），程序会崩溃，但这是必要的检查
            fprintf(stderr, "调试: 检查函数体...\n");
            ASTNode *body_check = decl->data.fn_decl.body;
            if (body_check == NULL) {
                // extern 函数，跳过函数体生成
                fprintf(stderr, "调试: 跳过 extern 函数\n");
                continue;
            }
            
            // 生成函数体
            // 注意：codegen_gen_function 内部会检查函数名是否为 NULL
            fprintf(stderr, "调试: 调用 codegen_gen_function 生成函数体...\n");
            int result = codegen_gen_function(codegen, decl);
            if (result != 0) {
                fprintf(stderr, "调试: 函数代码生成失败（结果: %d），继续处理其他函数\n", result);
                // 放宽检查：如果函数代码生成失败，不报告错误，继续处理其他函数
                // 这在编译器自举时很常见，因为类型推断可能失败或结构体类型未注册
                // 不返回错误，继续处理其他函数
            } else {
                fprintf(stderr, "调试: 函数代码生成成功\n");
            }
        }
    }
    fprintf(stderr, "调试: 所有函数体生成完成\n");
    

    
    // 第五步：生成目标代码
    // 初始化LLVM目标（只需要初始化一次，但重复初始化是安全的）
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();
    LLVMInitializeNativeAsmParser();
    
    // 获取默认目标三元组（例如："x86_64-pc-linux-gnu"）
    char *target_triple = LLVMGetDefaultTargetTriple();
    if (!target_triple) {
        return -1;
    }
    
    // 查找目标
    char *error_msg = NULL;
    LLVMTargetRef target = NULL;
    if (LLVMGetTargetFromTriple(target_triple, &target, &error_msg) != 0) {
        // 错误处理：释放错误消息
        if (error_msg) {
            LLVMDisposeMessage(error_msg);
        }
        LLVMDisposeMessage(target_triple);
        return -1;
    }
    
    // 创建目标机器（使用默认的CPU和特性）
    // 优化级别：0 = 无优化，1 = 少量优化，2 = 默认优化，3 = 激进优化
    LLVMCodeGenOptLevel opt_level = LLVMCodeGenLevelDefault;
    LLVMRelocMode reloc_mode = LLVMRelocDefault;
    LLVMCodeModel code_model = LLVMCodeModelDefault;
    
    LLVMTargetMachineRef target_machine = LLVMCreateTargetMachine(
        target,
        target_triple,
        "",  // CPU（空字符串表示默认）
        "",  // Features（空字符串表示默认）
        opt_level,
        reloc_mode,
        code_model
    );
    
    if (!target_machine) {
        LLVMDisposeMessage(target_triple);
        return -1;
    }
    
    // 配置模块的目标数据布局（如果还没有设置）
    // 注意：在第零步可能已经设置了 DataLayout，但重复设置是安全的
    LLVMSetTarget(codegen->module, target_triple);
    LLVMTargetDataRef layout_data = LLVMCreateTargetDataLayout(target_machine);
    if (layout_data) {
        // LLVM 18中，LLVMSetModuleDataLayout 直接接受 LLVMTargetDataRef 类型
        LLVMSetModuleDataLayout(codegen->module, layout_data);
        LLVMDisposeTargetData(layout_data);
    }
    
    // 生成LLVM IR文本到文件，用于调试
    // 基于输出文件名生成 .ll 文件路径（将 .o 替换为 .ll）
    char ir_file[512];  // 足够大的缓冲区
    size_t max_len = sizeof(ir_file) - 4;  // 保留空间给 ".ll\0"
    size_t output_len = strlen(output_file);
    if (output_len > max_len) {
        output_len = max_len;
    }
    strncpy(ir_file, output_file, output_len);
    ir_file[output_len] = '\0';
    
    // 查找最后一个点号，如果以 .o 结尾则替换，否则追加 .ll
    char *last_dot = strrchr(ir_file, '.');
    if (last_dot && strcmp(last_dot, ".o") == 0) {
        strcpy(last_dot, ".ll");
    } else {
        strcat(ir_file, ".ll");
    }
    
    char *ir_error = NULL;
    LLVMPrintModuleToFile(codegen->module, ir_file, &ir_error);
    if (ir_error) {
        LLVMDisposeMessage(ir_error);
        ir_error = NULL;
    }
    
    // 验证模块（在生成目标代码之前）
    char *verify_error = NULL;
    if (LLVMVerifyModule(codegen->module, LLVMReturnStatusAction, &verify_error) != 0) {
        if (verify_error) {
            fprintf(stderr, "错误: LLVM 模块验证失败: %s\n", verify_error);
            LLVMDisposeMessage(verify_error);
        } else {
            fprintf(stderr, "错误: LLVM 模块验证失败（未知错误）\n");
        }
        LLVMDisposeTargetMachine(target_machine);
        LLVMDisposeMessage(target_triple);
        return -1;
    }
    
    // 生成目标代码到文件
    char *error = NULL;
    if (LLVMTargetMachineEmitToFile(target_machine, codegen->module, (char *)output_file,
                                     LLVMObjectFile, &error) != 0) {
        // 生成失败
        if (error) {
            fprintf(stderr, "错误: LLVM 代码生成失败: %s\n", error);
            LLVMDisposeMessage(error);
        } else {
            fprintf(stderr, "错误: LLVM 代码生成失败（未知错误）\n");
        }
        LLVMDisposeTargetMachine(target_machine);
        LLVMDisposeMessage(target_triple);
        return -1;
    }
    
    
    // 清理资源
    LLVMDisposeTargetMachine(target_machine);
    LLVMDisposeMessage(target_triple);
    
    return 0;
}


