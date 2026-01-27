#include "internal.h"

// 安全的 LLVMTypeOf 包装函数，避免对标记值调用
LLVMTypeRef safe_LLVMTypeOf(LLVMValueRef val) {
    if (val == (LLVMValueRef)1) {
        return NULL;  // 标记值，返回 NULL
    }
    return LLVMTypeOf(val);
}

// 安全的 LLVMGetElementType 包装函数，避免对无效类型调用
LLVMTypeRef safe_LLVMGetElementType(LLVMTypeRef type) {
    if (!type) {
        return NULL;  // 无效类型，返回 NULL
    }
    
    LLVMTypeRef result = LLVMGetElementType(type);
    
    // 验证返回值是否有效
    // 检查是否是标记值（如 0xffff00000107）
    if (result) {
        unsigned long long result_ptr = (unsigned long long)result;
        // 检查是否是标记值模式：高 32 位是 0xffff0000
        if ((result_ptr >> 32) == 0xffff) {
            fprintf(stderr, "警告: safe_LLVMGetElementType 检测到标记值 %p，返回 NULL\n", (void*)result);
            return NULL;
        }
    }
    
    return result;
}

// 格式化错误位置信息：源文件名(行:列)
void format_error_location(const CodeGenerator *codegen, const ASTNode *node, char *buffer, size_t buffer_size) {
    if (!codegen || !node || !buffer || buffer_size == 0) {
        if (buffer && buffer_size > 0) {
            buffer[0] = '\0';
        }
        return;
    }
    // 优先使用 AST 节点自带的 filename（多文件编译时每个节点来自不同源文件）
    // 回退到 module_name（通常是第一个输入文件名）
    const char *filename = node->filename ? node->filename :
                           (codegen->module_name ? codegen->module_name : "(unknown)");
    snprintf(buffer, buffer_size, "%s(%d:%d)", filename, node->line, node->column);
}

// 获取语句类型的名称（用于错误报告）
const char *get_stmt_type_name(ASTNodeType type) {
    switch (type) {
        case AST_VAR_DECL: return "变量声明";
        case AST_ASSIGN: return "赋值语句";
        case AST_RETURN_STMT: return "return 语句";
        case AST_IF_STMT: return "if 语句";
        case AST_WHILE_STMT: return "while 语句";
        case AST_FOR_STMT: return "for 语句";
        case AST_BREAK_STMT: return "break 语句";
        case AST_CONTINUE_STMT: return "continue 语句";
        case AST_EXPR_STMT: return "表达式语句";
        case AST_BLOCK: return "代码块";
        default: return "未知语句类型";
    }
}

// 生成详细的错误信息（包含原因和建议）
void report_stmt_error(const CodeGenerator *codegen, const ASTNode *stmt, int stmt_index, const char *context) {
    (void)codegen;  // 暂时未使用，保留以备将来使用
    (void)context;   // 暂时未使用，保留以备将来使用
    
    if (!stmt) {
        fprintf(stderr, "错误: 语句节点为 NULL\n");
        return;
    }
    
    const char *filename = stmt->filename ? stmt->filename : "<unknown>";
    const char *stmt_type_name = get_stmt_type_name(stmt->type);
    
    fprintf(stderr, "错误: 处理 AST_BLOCK 中的第 %d 个语句失败 (%s:%d:%d)\n", 
            stmt_index, filename, stmt->line, stmt->column);
    fprintf(stderr, "  语句类型: %s (类型代码: %d)\n", stmt_type_name, (int)stmt->type);
    
    // 根据语句类型提供具体的错误原因和修改建议
    switch (stmt->type) {
        case AST_VAR_DECL: {
            const char *var_name = stmt->data.var_decl.name;
            fprintf(stderr, "  错误原因: 变量声明 '%s' 的代码生成失败\n", var_name ? var_name : "(未命名)");
            fprintf(stderr, "  可能原因:\n");
            fprintf(stderr, "    - 变量类型未定义或无效\n");
            fprintf(stderr, "    - 初始值表达式包含错误（如未定义的变量、类型不匹配等）\n");
            fprintf(stderr, "    - 数组大小表达式不是编译期常量\n");
            fprintf(stderr, "  修改建议:\n");
            fprintf(stderr, "    - 检查变量类型是否正确声明\n");
            fprintf(stderr, "    - 检查初始值表达式中使用的变量是否已定义\n");
            fprintf(stderr, "    - 确保数组大小是编译期常量表达式\n");
            break;
        }
        case AST_ASSIGN: {
            ASTNode *dest = stmt->data.assign.dest;
            const char *dest_name = dest && dest->type == AST_IDENTIFIER ? dest->data.identifier.name : NULL;
            fprintf(stderr, "  错误原因: 赋值语句代码生成失败\n");
            if (dest_name) {
                fprintf(stderr, "  目标变量: %s\n", dest_name);
            }
            fprintf(stderr, "  可能原因:\n");
            fprintf(stderr, "    - 目标变量未定义\n");
            fprintf(stderr, "    - 目标不是左值（不能赋值，如常量或表达式结果）\n");
            fprintf(stderr, "    - 源表达式类型与目标类型不匹配\n");
            fprintf(stderr, "    - 源表达式包含错误（如未定义的变量、函数调用失败等）\n");
            fprintf(stderr, "  修改建议:\n");
            if (dest_name) {
                fprintf(stderr, "    - 检查变量 '%s' 是否已声明\n", dest_name);
            }
            fprintf(stderr, "    - 确保赋值目标是一个变量或可修改的左值\n");
            fprintf(stderr, "    - 检查源表达式的类型是否与目标变量类型兼容\n");
            fprintf(stderr, "    - 检查源表达式中使用的变量和函数是否已定义\n");
            break;
        }
        case AST_RETURN_STMT: {
            ASTNode *return_expr = stmt->data.return_stmt.expr;
            fprintf(stderr, "  错误原因: return 语句代码生成失败\n");
            fprintf(stderr, "  可能原因:\n");
            if (return_expr) {
                fprintf(stderr, "    - 返回值表达式生成失败\n");
                fprintf(stderr, "    - 返回值类型与函数返回类型不匹配\n");
            } else {
                fprintf(stderr, "    - 函数期望返回值但使用了 void return\n");
                fprintf(stderr, "    - 函数期望 void 返回但提供了返回值\n");
            }
            fprintf(stderr, "  修改建议:\n");
            if (return_expr) {
                fprintf(stderr, "    - 检查返回值表达式是否正确\n");
                fprintf(stderr, "    - 确保返回值类型与函数声明的返回类型匹配\n");
            } else {
                fprintf(stderr, "    - 检查函数返回类型声明是否正确\n");
            }
            break;
        }
        case AST_IF_STMT:
        case AST_WHILE_STMT:
        case AST_FOR_STMT: {
            fprintf(stderr, "  错误原因: 控制流语句代码生成失败\n");
            fprintf(stderr, "  可能原因:\n");
            fprintf(stderr, "    - 条件表达式生成失败或类型不是布尔类型\n");
            fprintf(stderr, "    - 循环体或分支代码块包含错误\n");
            fprintf(stderr, "  修改建议:\n");
            fprintf(stderr, "    - 检查条件表达式是否正确且返回布尔值\n");
            fprintf(stderr, "    - 检查循环体或分支中的语句是否正确\n");
            break;
        }
        case AST_EXPR_STMT: {
            fprintf(stderr, "  错误原因: 表达式语句代码生成失败\n");
            fprintf(stderr, "  可能原因:\n");
            fprintf(stderr, "    - 表达式包含未定义的变量或函数\n");
            fprintf(stderr, "    - 表达式类型错误或操作数类型不匹配\n");
            fprintf(stderr, "    - 函数调用失败（函数未定义或参数不匹配）\n");
            fprintf(stderr, "  修改建议:\n");
            fprintf(stderr, "    - 检查表达式中使用的变量和函数是否已定义\n");
            fprintf(stderr, "    - 检查操作数类型是否匹配\n");
            fprintf(stderr, "    - 检查函数调用的参数类型和数量是否正确\n");
            break;
        }
        default:
            fprintf(stderr, "  错误原因: 语句代码生成失败\n");
            fprintf(stderr, "  可能原因: 语句包含语法错误或语义错误\n");
            fprintf(stderr, "  修改建议: 检查语句的语法和语义是否正确\n");
            break;
    }
    
    if (context && strlen(context) > 0) {
        fprintf(stderr, "  上下文: %s\n", context);
    }
}

