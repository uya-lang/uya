#include "internal.h"
#include <stdarg.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

// 创建 C99 代码生成器
int c99_codegen_new(C99CodeGenerator *codegen, Arena *arena, FILE *output, const char *module_name, int emit_line_directives) {
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
    codegen->enum_definition_count = 0;
    codegen->function_declaration_count = 0;
    codegen->global_variable_count = 0;
    codegen->local_variable_count = 0;
    codegen->current_depth = 0;
    codegen->loop_stack_depth = 0;
    codegen->program_node = NULL;
    codegen->current_function_return_type = NULL;
    codegen->current_function_decl = NULL;
    codegen->current_line = 0;  // 当前行号（用于优化 #line 指令）
    codegen->current_filename = NULL;  // 当前文件名（用于优化 #line 指令）
    codegen->emit_line_directives = emit_line_directives;  // 是否生成 #line 指令
    codegen->string_interp_buf = NULL;
    codegen->interp_temp_counter = 0;
    codegen->interp_fill_counter = 0;
    codegen->error_count = 0;
    codegen->defer_stack_depth = 0;
    codegen->slice_struct_count = 0;
    for (int i = 0; i < C99_MAX_CALL_ARGS; i++) {
        codegen->interp_arg_temp_names[i] = NULL;
    }
    for (int i = 0; i < 128; i++) {
        codegen->error_names[i] = NULL;
    }
    
    return 0;
}

// 释放资源（不关闭输出文件）
void c99_codegen_free(C99CodeGenerator *codegen) {
    // 当前没有动态分配的资源需要释放
    (void)codegen;
}

// 生成 #line 指令（用于调试，让C编译器错误信息指向原始Uya源文件）
// 优化：只在行号或文件名变化时才生成，避免重复
void emit_line_directive(C99CodeGenerator *codegen, int line, const char *filename) {
    if (!codegen || !codegen->output) return;
    
    // 如果禁用了 #line 指令生成，跳过
    if (!codegen->emit_line_directives) return;
    
    // 如果行号无效（<=0），跳过
    if (line <= 0) return;
    
    // 如果行号和文件名都没有变化，跳过
    if (codegen->current_line == line && 
        codegen->current_filename == filename) {
        return;
    }
    
    // 更新当前行号和文件名
    codegen->current_line = line;
    codegen->current_filename = filename;
    
    if (filename && filename[0] != '\0') {
        // 转义文件名中的特殊字符（如引号、反斜杠）
        fprintf(codegen->output, "#line %d \"", line);
        const char *p = filename;
        while (*p) {
            if (*p == '\\' || *p == '"') {
                fputc('\\', codegen->output);
            }
            fputc(*p, codegen->output);
            p++;
        }
        fprintf(codegen->output, "\"\n");
    } else {
        fprintf(codegen->output, "#line %d\n", line);
    }
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
const char *arena_strdup(Arena *arena, const char *src) {
    if (!src) return NULL;
    size_t len = strlen(src) + 1;
    char *dst = arena_alloc(arena, len);
    if (!dst) return NULL;
    memcpy(dst, src, len);
    return dst;
}

static uint32_t hash_error_name(const char *name) {
    uint32_t h = 5381;
    unsigned char c;
    while ((c = (unsigned char)*name++) != 0) {
        h = ((h << 5) + h) + c;
    }
    return (h == 0) ? 1 : h;
}

// 获取或注册错误名称，返回 hash(error_name) 作为 error_id，0 表示失败
unsigned get_or_add_error_id(C99CodeGenerator *codegen, const char *name) {
    if (!codegen || !name) return 0;
    uint32_t h = hash_error_name(name);
    for (int i = 0; i < codegen->error_count; i++) {
        if (codegen->error_names[i] && strcmp(codegen->error_names[i], name) == 0) {
            return codegen->error_hashes[i];
        }
    }
    if (codegen->error_count >= 128) return 0;
    const char *copy = arena_strdup(codegen->arena, name);
    if (!copy) return 0;
    codegen->error_names[codegen->error_count] = copy;
    codegen->error_hashes[codegen->error_count] = h;
    codegen->error_count++;
    return h;
}

// C99 关键字列表
static const char *c99_keywords[] = {
    "auto", "break", "case", "char", "const", "continue", "default", "do",
    "double", "else", "enum", "extern", "float", "for", "goto", "if",
    "int", "long", "register", "return", "short", "signed", "sizeof", "static",
    "struct", "switch", "typedef", "union", "unsigned", "void", "volatile", "while",
    "bool", "_Bool", "_Complex", "_Imaginary", "inline", "restrict",
    NULL
};

// 检查标识符是否为C关键字
int is_c_keyword(const char *name) {
    if (!name) return 0;
    for (int i = 0; c99_keywords[i]; i++) {
        if (strcmp(name, c99_keywords[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

// 获取安全的C标识符（如果需要则添加下划线前缀）
const char *get_safe_c_identifier(C99CodeGenerator *codegen, const char *name) {
    if (!name) return NULL;
    
    // 如果不是关键字，直接返回原名称
    if (!is_c_keyword(name)) {
        return name;
    }
    
    // 如果是关键字，添加前缀（最多尝试几次以避免重复）
    for (int prefix = 1; prefix <= 3; prefix++) {
        char buf[128];
        if (prefix == 1) {
            snprintf(buf, sizeof(buf), "_%s", name);
        } else if (prefix == 2) {
            snprintf(buf, sizeof(buf), "_%s_", name);
        } else {
            snprintf(buf, sizeof(buf), "uya_%s", name);
        }
        
        // 检查这个名称是否已经用作关键字（理论上应该不会冲突）
        if (!is_c_keyword(buf)) {
            return arena_strdup(codegen->arena, buf);
        }
    }
    
    // 如果仍然冲突，返回原名称（虽然可能导致编译错误）
    return name;
}

// 添加字符串常量
const char *add_string_constant(C99CodeGenerator *codegen, const char *value) {
    // 检查是否已存在相同的字符串常量
    for (int i = 0; i < codegen->string_constant_count; i++) {
        if (strcmp(codegen->string_constants[i].value, value) == 0) {
            return codegen->string_constants[i].name;
        }
    }
    
    // 创建新的字符串常量
    if (codegen->string_constant_count >= C99_MAX_STRING_CONSTANTS) {
        return NULL;
    }
    
    // 生成常量名称（如 str0）
    char name[32];
    snprintf(name, sizeof(name), "str%d", codegen->string_constant_count);
    
    // 存储到表中（value 用 arena 持久化，避免收集阶段局部 fmt_buf 等栈指针失效）
    const char *value_copy = arena_strdup(codegen->arena, value);
    if (!value_copy) return NULL;
    codegen->string_constants[codegen->string_constant_count].name = arena_strdup(codegen->arena, name);
    codegen->string_constants[codegen->string_constant_count].value = value_copy;
    codegen->string_constant_count++;
    
    return codegen->string_constants[codegen->string_constant_count - 1].name;
}

// 转义字符串中的特殊字符
void escape_string_for_c(FILE *output, const char *str) {
    if (!str) return;
    
    for (const char *p = str; *p != '\0'; p++) {
        switch (*p) {
            case '\n':
                fputs("\\n", output);
                break;
            case '\t':
                fputs("\\t", output);
                break;
            case '\r':
                fputs("\\r", output);
                break;
            case '\\':
                fputs("\\\\", output);
                break;
            case '"':
                fputs("\\\"", output);
                break;
            default:
                fputc(*p, output);
                break;
        }
    }
}

// 输出所有字符串常量
void emit_string_constants(C99CodeGenerator *codegen) {
    if (codegen->string_constant_count == 0) {
        return;
    }
    
    fputs("\n// 字符串常量\n", codegen->output);
    for (int i = 0; i < codegen->string_constant_count; i++) {
        fprintf(codegen->output, "static const char %s[] = \"", codegen->string_constants[i].name);
        escape_string_for_c(codegen->output, codegen->string_constants[i].value);
        fputs("\";\n", codegen->output);
    }
}

// 评估编译时常量表达式（返回 -1 表示无法评估）
int eval_const_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return -1;
    
    switch (expr->type) {
        case AST_NUMBER:
            return expr->data.number.value;
        case AST_IDENTIFIER: {
            // 查找常量变量声明
            if (!codegen || !codegen->program_node) return -1;
            
            const char *const_name = expr->data.identifier.name;
            if (!const_name) return -1;
            
            // 从程序节点中查找常量变量声明
            ASTNode *program = codegen->program_node;
            if (program->type != AST_PROGRAM) return -1;
            
            for (int i = 0; i < program->data.program.decl_count; i++) {
                ASTNode *decl = program->data.program.decls[i];
                if (decl != NULL && decl->type == AST_VAR_DECL) {
                    const char *var_name = decl->data.var_decl.name;
                    if (var_name != NULL && strcmp(var_name, const_name) == 0) {
                        // 找到常量变量，检查是否为 const
                        if (decl->data.var_decl.is_const) {
                            // 递归评估初始值表达式
                            // 注意：这里不检查循环引用，因为常量应该是编译时确定的简单表达式
                            ASTNode *init_expr = decl->data.var_decl.init;
                            if (init_expr != NULL) {
                                // 如果初始值也是标识符，递归查找（支持常量链）
                                return eval_const_expr(codegen, init_expr);
                            }
                        }
                        break;
                    }
                }
            }
            // 未找到常量变量或不是 const
            return -1;
        }
        case AST_BINARY_EXPR: {
            ASTNode *left = expr->data.binary_expr.left;
            ASTNode *right = expr->data.binary_expr.right;
            int op = expr->data.binary_expr.op;
            int left_val = eval_const_expr(codegen, left);
            int right_val = eval_const_expr(codegen, right);
            if (left_val == -1 || right_val == -1) return -1;
            
            switch (op) {
                case TOKEN_PLUS: return left_val + right_val;
                case TOKEN_MINUS: return left_val - right_val;
                case TOKEN_ASTERISK: return left_val * right_val;
                case TOKEN_SLASH: 
                    if (right_val == 0) return -1;
                    return left_val / right_val;
                case TOKEN_PERCENT: 
                    if (right_val == 0) return -1;
                    return left_val % right_val;
                default:
                    // 不支持的操作符
                    return -1;
            }
        }
        case AST_UNARY_EXPR: {
            int op = expr->data.unary_expr.op;
            ASTNode *operand = expr->data.unary_expr.operand;
            int operand_val = eval_const_expr(codegen, operand);
            if (operand_val == -1) return -1;
            
            if (op == TOKEN_PLUS) return operand_val;
            if (op == TOKEN_MINUS) return -operand_val;
            // 不支持的其他一元操作符
            return -1;
        }
        default:
            // 不是常量表达式
            return -1;
    }
}

// 收集表达式中的字符串常量（不生成代码）
void collect_string_constants_from_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return;
    
    switch (expr->type) {
        case AST_STRING:
            add_string_constant(codegen, expr->data.string_literal.value);
            break;
        case AST_STRING_INTERP: {
            for (int i = 0; i < expr->data.string_interp.segment_count; i++) {
                ASTStringInterpSegment *seg = &expr->data.string_interp.segments[i];
                if (seg->is_text && seg->text) {
                    add_string_constant(codegen, seg->text);
                } else if (!seg->is_text) {
                    if (seg->expr)
                        collect_string_constants_from_expr(codegen, seg->expr);
                    if (seg->format_spec && seg->format_spec[0]) {
                        char fmt_buf[64];
                        snprintf(fmt_buf, sizeof(fmt_buf), "%%%s", seg->format_spec);
                        add_string_constant(codegen, fmt_buf);
                    } else {
                        add_string_constant(codegen, "%d");
                    }
                }
            }
            break;
        }
        case AST_BINARY_EXPR:
            collect_string_constants_from_expr(codegen, expr->data.binary_expr.left);
            collect_string_constants_from_expr(codegen, expr->data.binary_expr.right);
            break;
        case AST_UNARY_EXPR:
            collect_string_constants_from_expr(codegen, expr->data.unary_expr.operand);
            break;
        case AST_CALL_EXPR: {
            collect_string_constants_from_expr(codegen, expr->data.call_expr.callee);
            for (int i = 0; i < expr->data.call_expr.arg_count; i++) {
                collect_string_constants_from_expr(codegen, expr->data.call_expr.args[i]);
            }
            break;
        }
        case AST_MEMBER_ACCESS:
            collect_string_constants_from_expr(codegen, expr->data.member_access.object);
            break;
        case AST_ARRAY_ACCESS:
            collect_string_constants_from_expr(codegen, expr->data.array_access.array);
            collect_string_constants_from_expr(codegen, expr->data.array_access.index);
            break;
        case AST_SLICE_EXPR:
            collect_string_constants_from_expr(codegen, expr->data.slice_expr.base);
            collect_string_constants_from_expr(codegen, expr->data.slice_expr.start_expr);
            collect_string_constants_from_expr(codegen, expr->data.slice_expr.len_expr);
            break;
        case AST_STRUCT_INIT:
            for (int i = 0; i < expr->data.struct_init.field_count; i++) {
                collect_string_constants_from_expr(codegen, expr->data.struct_init.field_values[i]);
            }
            break;
        case AST_ARRAY_LITERAL: {
            ASTNode *repeat = expr->data.array_literal.repeat_count_expr;
            int count = expr->data.array_literal.element_count;
            if (repeat != NULL && count >= 1) {
                collect_string_constants_from_expr(codegen, expr->data.array_literal.elements[0]);
            } else {
                for (int i = 0; i < count; i++) {
                    collect_string_constants_from_expr(codegen, expr->data.array_literal.elements[i]);
                }
            }
            break;
        }
        case AST_SIZEOF:
        case AST_LEN:
        case AST_ALIGNOF:
            // 这些表达式内部可能包含表达式或类型，但类型节点不包含字符串
            // 暂时忽略
            break;
        case AST_CAST_EXPR:
            collect_string_constants_from_expr(codegen, expr->data.cast_expr.expr);
            break;
        default:
            // 其他表达式类型（标识符、数字、布尔值）不包含字符串
            break;
    }
}

// 收集语句中的字符串常量
void collect_string_constants_from_stmt(C99CodeGenerator *codegen, ASTNode *stmt) {
    if (!stmt) return;
    
    switch (stmt->type) {
        case AST_EXPR_STMT:
            // 表达式语句的数据存储在表达式的节点中，直接忽略此节点
            break;
        case AST_ASSIGN: {
            ASTNode *dest = stmt->data.assign.dest;
            ASTNode *src = stmt->data.assign.src;
            collect_string_constants_from_expr(codegen, dest);
            collect_string_constants_from_expr(codegen, src);
            break;
        }
        case AST_RETURN_STMT: {
            ASTNode *expr = stmt->data.return_stmt.expr;
            collect_string_constants_from_expr(codegen, expr);
            break;
        }
        case AST_BLOCK: {
            ASTNode **stmts = stmt->data.block.stmts;
            int stmt_count = stmt->data.block.stmt_count;
            for (int i = 0; i < stmt_count; i++) {
                collect_string_constants_from_stmt(codegen, stmts[i]);
            }
            break;
        }
        case AST_VAR_DECL: {
            ASTNode *init_expr = stmt->data.var_decl.init;
            if (init_expr) {
                collect_string_constants_from_expr(codegen, init_expr);
            }
            break;
        }
        case AST_IF_STMT: {
            ASTNode *condition = stmt->data.if_stmt.condition;
            ASTNode *then_branch = stmt->data.if_stmt.then_branch;
            ASTNode *else_branch = stmt->data.if_stmt.else_branch;
            collect_string_constants_from_expr(codegen, condition);
            collect_string_constants_from_stmt(codegen, then_branch);
            if (else_branch) {
                collect_string_constants_from_stmt(codegen, else_branch);
            }
            break;
        }
        case AST_WHILE_STMT: {
            ASTNode *condition = stmt->data.while_stmt.condition;
            ASTNode *body = stmt->data.while_stmt.body;
            collect_string_constants_from_expr(codegen, condition);
            collect_string_constants_from_stmt(codegen, body);
            break;
        }
        case AST_FOR_STMT: {
            ASTNode *array = stmt->data.for_stmt.array;
            ASTNode *body = stmt->data.for_stmt.body;
            collect_string_constants_from_expr(codegen, array);
            collect_string_constants_from_stmt(codegen, body);
            break;
        }
        case AST_BREAK_STMT:
        case AST_CONTINUE_STMT:
            // 不包含表达式
            break;
        case AST_DEFER_STMT:
            if (stmt->data.defer_stmt.body)
                collect_string_constants_from_stmt(codegen, stmt->data.defer_stmt.body);
            break;
        case AST_ERRDEFER_STMT:
            if (stmt->data.errdefer_stmt.body)
                collect_string_constants_from_stmt(codegen, stmt->data.errdefer_stmt.body);
            break;
        default:
            // 可能是表达式节点（如 AST_BINARY_EXPR 等）
            // 在这种情况下，将其视为表达式处理
            collect_string_constants_from_expr(codegen, stmt);
            break;
    }
}

// 收集声明中的字符串常量（全局变量初始化、函数体）
void collect_string_constants_from_decl(C99CodeGenerator *codegen, ASTNode *decl) {
    if (!decl) return;
    
    switch (decl->type) {
        case AST_VAR_DECL:
            if (decl->data.var_decl.init) {
                collect_string_constants_from_expr(codegen, decl->data.var_decl.init);
            }
            break;
        case AST_FN_DECL: {
            ASTNode *body = decl->data.fn_decl.body;
            if (body) {
                collect_string_constants_from_stmt(codegen, body);
            }
            break;
        }
        default:
            break;
    }
}

