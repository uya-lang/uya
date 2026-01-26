#include "codegen_c99.h"
#include "lexer.h"
#include <stdarg.h>
#include <string.h>
#include <stdlib.h>

// 创建 C99 代码生成器
int c99_codegen_new(C99CodeGenerator *codegen, Arena *arena, FILE *output, const char *module_name) {
    if (!codegen || !arena || !output || !module_name) {
        return -1;
    }
    
    // 初始化字段
    codegen->arena = arena;
    codegen->output = output;
    codegen->indent_level = 0;
    codegen->module_name = module_name;
    
    // 初始化表
    codegen->string_constant_count = 0;
    codegen->struct_definition_count = 0;
    codegen->function_declaration_count = 0;
    codegen->global_variable_count = 0;
    codegen->local_variable_count = 0;
    codegen->current_depth = 0;
    codegen->loop_stack_depth = 0;
    codegen->program_node = NULL;
    
    return 0;
}

// 释放资源（不关闭输出文件）
void c99_codegen_free(C99CodeGenerator *codegen) {
    // 当前没有动态分配的资源需要释放
    (void)codegen;
}

// 缩进输出
void c99_emit_indent(C99CodeGenerator *codegen) {
    for (int i = 0; i < codegen->indent_level; i++) {
        fputs("    ", codegen->output);
    }
}

// 换行
void c99_emit_newline(C99CodeGenerator *codegen) {
    fputc('\n', codegen->output);
}

// 格式化输出（带缩进和换行处理）
void c99_emit(C99CodeGenerator *codegen, const char *format, ...) {
    va_list args;
    va_start(args, format);
    
    // 输出缩进
    c99_emit_indent(codegen);
    
    // 输出格式化内容
    vfprintf(codegen->output, format, args);
    
    va_end(args);
}

// 简单的字符串复制到 Arena（与 parser.c 中的 arena_strdup 类似）
static const char *arena_strdup(Arena *arena, const char *src) {
    if (!src) return NULL;
    size_t len = strlen(src) + 1;
    char *dst = arena_alloc(arena, len);
    if (!dst) return NULL;
    memcpy(dst, src, len);
    return dst;
}

// 添加字符串常量
static const char *add_string_constant(C99CodeGenerator *codegen, const char *value) {
    // 检查是否已存在相同的字符串常量
    for (int i = 0; i < codegen->string_constant_count; i++) {
        if (strcmp(codegen->string_constants[i].value, value) == 0) {
            return codegen->string_constants[i].name;
        }
    }
    
    // 创建新的字符串常量
    if (codegen->string_constant_count >= 256) {
        return NULL;
    }
    
    // 生成常量名称（如 .str0）
    char name[32];
    snprintf(name, sizeof(name), ".str%d", codegen->string_constant_count);
    
    // 存储到表中
    codegen->string_constants[codegen->string_constant_count].name = arena_strdup(codegen->arena, name);
    codegen->string_constants[codegen->string_constant_count].value = value;  // 注意：value 应该已经在 Arena 中
    codegen->string_constant_count++;
    
    return codegen->string_constants[codegen->string_constant_count - 1].name;
}

// 输出所有字符串常量
static void emit_string_constants(C99CodeGenerator *codegen) {
    if (codegen->string_constant_count == 0) {
        return;
    }
    
    fputs("\n// 字符串常量\n", codegen->output);
    for (int i = 0; i < codegen->string_constant_count; i++) {
        fprintf(codegen->output, "static const char %s[] = \"%s\";\n",
                codegen->string_constants[i].name,
                codegen->string_constants[i].value);
    }
}

// 类型映射函数
const char *c99_type_to_c(C99CodeGenerator *codegen, ASTNode *type_node) {
    if (!type_node) {
        return "void";
    }
    
    switch (type_node->type) {
        case AST_TYPE_NAMED: {
            const char *name = type_node->data.type_named.name;
            if (!name) {
                return "void";
            }
            
            // 基础类型映射
            if (strcmp(name, "i32") == 0) {
                return "int32_t";
            } else if (strcmp(name, "usize") == 0) {
                return "size_t";
            } else if (strcmp(name, "bool") == 0) {
                return "bool";
            } else if (strcmp(name, "byte") == 0) {
                return "uint8_t";
            } else if (strcmp(name, "void") == 0) {
                return "void";
            } else {
                // 结构体或枚举类型
                return name;
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
            
            snprintf(result, len, "%s *", pointee_type);
            return result;
        }
        
        case AST_TYPE_ARRAY: {
            ASTNode *element_type = type_node->data.type_array.element_type;
            // size_expr 是一个表达式节点，需要评估编译时常量
            // 暂时返回一个通用数组类型，后续实现常量评估
            const char *element_c = c99_type_to_c(codegen, element_type);
            
            // 分配缓冲区
            size_t len = strlen(element_c) + 32;  // 元素类型 + "[%d]" + null
            char *result = arena_alloc(codegen->arena, len);
            if (!result) {
                return "void";
            }
            
            // 假设大小为 1，占位符
            snprintf(result, len, "%s[1]", element_c);
            return result;
        }
        
        default:
            return "void";
    }
}

// 检查结构体是否已定义
static int is_struct_defined(C99CodeGenerator *codegen, const char *struct_name) {
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            return codegen->struct_definitions[i].defined;
        }
    }
    return 0;
}

// 标记结构体已定义
static void mark_struct_defined(C99CodeGenerator *codegen, const char *struct_name) {
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            codegen->struct_definitions[i].defined = 1;
            return;
        }
    }
    
    // 如果不在表中，添加
    if (codegen->struct_definition_count < 64) {
        codegen->struct_definitions[codegen->struct_definition_count].name = struct_name;
        codegen->struct_definitions[codegen->struct_definition_count].defined = 1;
        codegen->struct_definition_count++;
    }
}

// 添加结构体定义
static void add_struct_definition(C99CodeGenerator *codegen, const char *struct_name) {
    if (is_struct_defined(codegen, struct_name)) {
        return;
    }
    
    if (codegen->struct_definition_count < 64) {
        codegen->struct_definitions[codegen->struct_definition_count].name = struct_name;
        codegen->struct_definitions[codegen->struct_definition_count].defined = 0;
        codegen->struct_definition_count++;
    }
}

// 生成结构体定义
static int gen_struct_definition(C99CodeGenerator *codegen, ASTNode *struct_decl) {
    if (!struct_decl || struct_decl->type != AST_STRUCT_DECL) {
        return -1;
    }
    
    const char *struct_name = struct_decl->data.struct_decl.name;
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
    
    for (int i = 0; i < field_count; i++) {
        ASTNode *field = fields[i];
        if (!field || field->type != AST_VAR_DECL) {
            return -1;
        }
        
        const char *field_name = field->data.var_decl.name;
        ASTNode *field_type = field->data.var_decl.type;
        
        if (!field_name || !field_type) {
            return -1;
        }
        
        const char *field_type_c = c99_type_to_c(codegen, field_type);
        c99_emit(codegen, "%s %s;\n", field_type_c, field_name);
    }
    
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    
    // 标记为已定义
    mark_struct_defined(codegen, struct_name);
    return 0;
}

// 生成表达式
static void gen_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return;
    
    switch (expr->type) {
        case AST_NUMBER:
            fprintf(codegen->output, "%d", expr->data.number.value);
            break;
        case AST_BINARY_EXPR: {
            ASTNode *left = expr->data.binary_expr.left;
            ASTNode *right = expr->data.binary_expr.right;
            int op = expr->data.binary_expr.op;
            fputc('(', codegen->output);
            gen_expr(codegen, left);
            // 操作符映射
            if (op == TOKEN_PLUS) {
                fputs(" + ", codegen->output);
            } else if (op == TOKEN_MINUS) {
                fputs(" - ", codegen->output);
            } else if (op == TOKEN_ASTERISK) {
                fputs(" * ", codegen->output);
            } else if (op == TOKEN_SLASH) {
                fputs(" / ", codegen->output);
            } else if (op == TOKEN_EQUAL) {
                fputs(" == ", codegen->output);
            } else if (op == TOKEN_NOT_EQUAL) {
                fputs(" != ", codegen->output);
            } else if (op == TOKEN_LESS) {
                fputs(" < ", codegen->output);
            } else if (op == TOKEN_GREATER) {
                fputs(" > ", codegen->output);
            } else if (op == TOKEN_LESS_EQUAL) {
                fputs(" <= ", codegen->output);
            } else if (op == TOKEN_GREATER_EQUAL) {
                fputs(" >= ", codegen->output);
            } else {
                fputs(" + ", codegen->output); // 默认为加法
            }
            gen_expr(codegen, right);
            fputc(')', codegen->output);
            break;
        }
        case AST_IDENTIFIER:
            fprintf(codegen->output, "%s", expr->data.identifier.name);
            break;
        case AST_CALL_EXPR: {
            ASTNode *callee = expr->data.call_expr.callee;
            ASTNode **args = expr->data.call_expr.args;
            int arg_count = expr->data.call_expr.arg_count;
            
            // 生成被调用函数名
            if (callee && callee->type == AST_IDENTIFIER) {
                fprintf(codegen->output, "%s(", callee->data.identifier.name);
            } else {
                fputs("unknown(", codegen->output);
            }
            
            // 生成参数
            for (int i = 0; i < arg_count; i++) {
                gen_expr(codegen, args[i]);
                if (i < arg_count - 1) fputs(", ", codegen->output);
            }
            fputc(')', codegen->output);
            break;
        }
        default:
            fputs("0", codegen->output);
            break;
    }
}

// 生成语句
static void gen_stmt(C99CodeGenerator *codegen, ASTNode *stmt) {
    if (!stmt) return;
    
    switch (stmt->type) {
        case AST_RETURN_STMT: {
            ASTNode *expr = stmt->data.return_stmt.expr;
            c99_emit(codegen, "return ");
            gen_expr(codegen, expr);
            fputs(";\n", codegen->output);
            break;
        }
        case AST_BLOCK: {
            ASTNode **stmts = stmt->data.block.stmts;
            int stmt_count = stmt->data.block.stmt_count;
            for (int i = 0; i < stmt_count; i++) {
                gen_stmt(codegen, stmts[i]);
            }
            break;
        }
        case AST_VAR_DECL: {
            const char *var_name = stmt->data.var_decl.name;
            ASTNode *var_type = stmt->data.var_decl.type;
            ASTNode *init_expr = stmt->data.var_decl.init;
            int is_const = stmt->data.var_decl.is_const;
            
            const char *type_c = c99_type_to_c(codegen, var_type);
            c99_emit(codegen, "%s %s %s", is_const ? "const" : "", type_c, var_name);
            if (init_expr) {
                fputs(" = ", codegen->output);
                gen_expr(codegen, init_expr);
            }
            fputs(";\n", codegen->output);
            break;
        }
        case AST_IF_STMT: {
            ASTNode *condition = stmt->data.if_stmt.condition;
            ASTNode *then_branch = stmt->data.if_stmt.then_branch;
            ASTNode *else_branch = stmt->data.if_stmt.else_branch;
            
            c99_emit(codegen, "if (");
            gen_expr(codegen, condition);
            fputs(") {\n", codegen->output);
            codegen->indent_level++;
            gen_stmt(codegen, then_branch);
            codegen->indent_level--;
            c99_emit(codegen, "}");
            if (else_branch) {
                fputs(" else {\n", codegen->output);
                codegen->indent_level++;
                gen_stmt(codegen, else_branch);
                codegen->indent_level--;
                c99_emit(codegen, "}");
            }
            fputs("\n", codegen->output);
            break;
        }
        default:
            // 忽略其他语句
            break;
    }
}

// 生成函数定义
static void gen_function(C99CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL) return;
    
    const char *func_name = fn_decl->data.fn_decl.name;
    ASTNode *return_type = fn_decl->data.fn_decl.return_type;
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    ASTNode *body = fn_decl->data.fn_decl.body;
    
    // 返回类型
    const char *return_c = c99_type_to_c(codegen, return_type);
    fprintf(codegen->output, "%s %s(", return_c, func_name);
    
    // 参数列表
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = param->data.var_decl.name;
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        fprintf(codegen->output, "%s %s", param_type_c, param_name);
        if (i < param_count - 1) fputs(", ", codegen->output);
    }
    
    fputs(") {\n", codegen->output);
    codegen->indent_level++;
    
    // 生成函数体
    if (body) {
        gen_stmt(codegen, body);
    }
    
    codegen->indent_level--;
    c99_emit(codegen, "}\n");
}

// 主生成函数
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
    fputs("\n", codegen->output);
    
    // 遍历所有声明
    ASTNode **decls = ast->data.program.decls;
    int decl_count = ast->data.program.decl_count;
    
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        
        switch (decl->type) {
            case AST_FN_DECL:
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