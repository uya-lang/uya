#include "internal.h"
#include <string.h>
#include <stdlib.h>
#include <stdarg.h>

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
    fputs("#include <string.h>\n", codegen->output);  // for memcmp
    fputs("#include <stdio.h>\n", codegen->output);  // for standard I/O functions (printf, puts, etc.)
    fputs("\n", codegen->output);
    // bridge.c 提供的初始化函数（用于 main 函数初始化命令行参数）
    fputs("extern void bridge_init(int argc, char **argv);\n", codegen->output);
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
    
    // 第三步：收集所有结构体和枚举定义（添加到表中但不生成代码）
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
    
    // 第六步：生成所有结构体定义（在枚举之后）
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
        if (!decl || decl->type != AST_FN_DECL) continue;
        gen_function_prototype(codegen, decl);
    }
    fputs("\n", codegen->output);

    // 第七步：生成所有声明（全局变量、函数定义）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        
        switch (decl->type) {
            case AST_STRUCT_DECL:
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
            // 忽略其他声明类型（暂时）
            default:
                break;
        }
    }
    
    return 0;
}