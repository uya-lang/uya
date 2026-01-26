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
    codegen->enum_definition_count = 0;
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
static int is_c_keyword(const char *name) {
    if (!name) return 0;
    for (int i = 0; c99_keywords[i]; i++) {
        if (strcmp(name, c99_keywords[i]) == 0) {
            return 1;
        }
    }
    return 0;
}

// 获取安全的C标识符（如果需要则添加下划线前缀）
static const char *get_safe_c_identifier(C99CodeGenerator *codegen, const char *name) {
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

// 前向声明
static int is_struct_defined(C99CodeGenerator *codegen, const char *struct_name);
static int is_enum_defined(C99CodeGenerator *codegen, const char *enum_name);
static int is_struct_in_table(C99CodeGenerator *codegen, const char *struct_name);
static int is_enum_in_table(C99CodeGenerator *codegen, const char *enum_name);

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
    
    // 生成常量名称（如 str0）
    char name[32];
    snprintf(name, sizeof(name), "str%d", codegen->string_constant_count);
    
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

// 评估编译时常量表达式（返回 -1 表示无法评估）
static int eval_const_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return -1;
    
    switch (expr->type) {
        case AST_NUMBER:
            return expr->data.number.value;
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
                const char *safe_name = get_safe_c_identifier(codegen, name);
                
                // 检查是否是结构体（检查是否在表中，不管是否已定义）
                if (is_struct_in_table(codegen, safe_name)) {
                    // 临时缓冲区来构建类型字符串
                    static char type_buf[256];
                    snprintf(type_buf, sizeof(type_buf), "struct %s", safe_name);
                    return type_buf;
                }
                
                // 检查是否是枚举
                if (is_enum_in_table(codegen, safe_name)) {
                    // 临时缓冲区来构建类型字符串
                    static char type_buf[256];
                    snprintf(type_buf, sizeof(type_buf), "enum %s", safe_name);
                    return type_buf;
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
        
        default:
            return "void";
    }
}

// 检查结构体是否已添加到表中
static int is_struct_in_table(C99CodeGenerator *codegen, const char *struct_name) {
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            return 1;
        }
    }
    return 0;
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

// 检查枚举是否已定义
static int is_enum_defined(C99CodeGenerator *codegen, const char *enum_name) {
    for (int i = 0; i < codegen->enum_definition_count; i++) {
        if (strcmp(codegen->enum_definitions[i].name, enum_name) == 0) {
            return codegen->enum_definitions[i].defined;
        }
    }
    return 0;
}

// 检查枚举是否已添加到表中
static int is_enum_in_table(C99CodeGenerator *codegen, const char *enum_name) {
    for (int i = 0; i < codegen->enum_definition_count; i++) {
        if (strcmp(codegen->enum_definitions[i].name, enum_name) == 0) {
            return 1;
        }
    }
    return 0;
}

// 标记枚举已定义
static void mark_enum_defined(C99CodeGenerator *codegen, const char *enum_name) {
    for (int i = 0; i < codegen->enum_definition_count; i++) {
        if (strcmp(codegen->enum_definitions[i].name, enum_name) == 0) {
            codegen->enum_definitions[i].defined = 1;
            return;
        }
    }
}

// 添加枚举定义
static void add_enum_definition(C99CodeGenerator *codegen, const char *enum_name) {
    // 如果已存在，则返回
    for (int i = 0; i < codegen->enum_definition_count; i++) {
        if (strcmp(codegen->enum_definitions[i].name, enum_name) == 0) {
            return;
        }
    }
    
    if (codegen->enum_definition_count < 64) {
        codegen->enum_definitions[codegen->enum_definition_count].name = enum_name;
        codegen->enum_definitions[codegen->enum_definition_count].defined = 0;
        codegen->enum_definition_count++;
    }
}

// 生成结构体定义
static int gen_struct_definition(C99CodeGenerator *codegen, ASTNode *struct_decl) {
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
    
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    
    // 标记为已定义
    mark_struct_defined(codegen, struct_name);
    return 0;
}

// 生成枚举定义
static int gen_enum_definition(C99CodeGenerator *codegen, ASTNode *enum_decl) {
    if (!enum_decl || enum_decl->type != AST_ENUM_DECL) {
        return -1;
    }
    
    const char *enum_name = get_safe_c_identifier(codegen, enum_decl->data.enum_decl.name);
    if (!enum_name) {
        return -1;
    }
    
    // 如果已定义，跳过
    if (is_enum_defined(codegen, enum_name)) {
        return 0;
    }
    
    // 添加枚举定义标记
    add_enum_definition(codegen, enum_name);
    
    // 输出枚举定义
    c99_emit(codegen, "enum %s {\n", enum_name);
    codegen->indent_level++;
    
    EnumVariant *variants = enum_decl->data.enum_decl.variants;
    int variant_count = enum_decl->data.enum_decl.variant_count;
    int current_value = 0;
    
    for (int i = 0; i < variant_count; i++) {
        EnumVariant *variant = &variants[i];
        if (!variant->name) {
            return -1;
        }
        
        // 确定变体的值
        if (variant->value) {
            // 有显式值，使用atoi转换
            const char *safe_variant_name = get_safe_c_identifier(codegen, variant->name);
            current_value = atoi(variant->value);
            c99_emit(codegen, "%s = %d", safe_variant_name, current_value);
        } else {
            // 无显式值，使用当前值（从0开始或基于前一个值）
            const char *safe_variant_name = get_safe_c_identifier(codegen, variant->name);
            c99_emit(codegen, "%s", safe_variant_name);
            // 当前值保持不变，供下一个变体使用（C中隐式递增）
        }
        
        // 添加逗号（除非是最后一个）
        if (i < variant_count - 1) {
            fputs(",", codegen->output);
        }
        fputs("\n", codegen->output);
    }
    
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    
    // 标记为已定义
    mark_enum_defined(codegen, enum_name);
    return 0;
}

// 收集表达式中的字符串常量（不生成代码）
static void collect_string_constants_from_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return;
    
    switch (expr->type) {
        case AST_STRING:
            add_string_constant(codegen, expr->data.string_literal.value);
            break;
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
        case AST_STRUCT_INIT:
            for (int i = 0; i < expr->data.struct_init.field_count; i++) {
                collect_string_constants_from_expr(codegen, expr->data.struct_init.field_values[i]);
            }
            break;
        case AST_ARRAY_LITERAL:
            for (int i = 0; i < expr->data.array_literal.element_count; i++) {
                collect_string_constants_from_expr(codegen, expr->data.array_literal.elements[i]);
            }
            break;
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
static void collect_string_constants_from_stmt(C99CodeGenerator *codegen, ASTNode *stmt) {
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
        default:
            // 可能是表达式节点（如 AST_BINARY_EXPR 等）
            // 在这种情况下，将其视为表达式处理
            collect_string_constants_from_expr(codegen, stmt);
            break;
    }
}

// 收集声明中的字符串常量（全局变量初始化、函数体）
static void collect_string_constants_from_decl(C99CodeGenerator *codegen, ASTNode *decl) {
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

// 生成表达式
static void gen_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return;
    
    switch (expr->type) {
        case AST_NUMBER:
            fprintf(codegen->output, "%d", expr->data.number.value);
            break;
        case AST_BOOL:
            fprintf(codegen->output, "%s", expr->data.bool_literal.value ? "true" : "false");
            break;
        case AST_STRING: {
            const char *str_const = add_string_constant(codegen, expr->data.string_literal.value);
            if (str_const) {
                fprintf(codegen->output, "%s", str_const);
            } else {
                fputs("\"\"", codegen->output);
            }
            break;
        }
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
            } else if (op == TOKEN_PERCENT) {
                fputs(" % ", codegen->output);
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
            } else if (op == TOKEN_LOGICAL_AND) {
                fputs(" && ", codegen->output);
            } else if (op == TOKEN_LOGICAL_OR) {
                fputs(" || ", codegen->output);
            } else {
                fputs(" + ", codegen->output); // 默认为加法
            }
            gen_expr(codegen, right);
            fputc(')', codegen->output);
            break;
        }
        case AST_UNARY_EXPR: {
            int op = expr->data.unary_expr.op;
            ASTNode *operand = expr->data.unary_expr.operand;
            fputc('(', codegen->output);
            if (op == TOKEN_ASTERISK) {
                fputs("*", codegen->output);
            } else if (op == TOKEN_AMPERSAND) {
                fputs("&", codegen->output);
            } else if (op == TOKEN_MINUS) {
                fputs("-", codegen->output);
            } else if (op == TOKEN_EXCLAMATION) {
                fputs("!", codegen->output);
            } else if (op == TOKEN_PLUS) {
                fputs("+", codegen->output);
            } else {
                fputs("+", codegen->output); // 默认
            }
            gen_expr(codegen, operand);
            fputc(')', codegen->output);
            break;
        }
        case AST_MEMBER_ACCESS: {
            ASTNode *object = expr->data.member_access.object;
            const char *field_name = get_safe_c_identifier(codegen, expr->data.member_access.field_name);
            gen_expr(codegen, object);
            fprintf(codegen->output, ".%s", field_name);
            break;
        }
        case AST_ARRAY_ACCESS: {
            ASTNode *array = expr->data.array_access.array;
            ASTNode *index = expr->data.array_access.index;
            gen_expr(codegen, array);
            fputc('[', codegen->output);
            gen_expr(codegen, index);
            fputc(']', codegen->output);
            break;
        }
        case AST_STRUCT_INIT: {
            const char *struct_name = get_safe_c_identifier(codegen, expr->data.struct_init.struct_name);
            int field_count = expr->data.struct_init.field_count;
            const char **field_names = expr->data.struct_init.field_names;
            ASTNode **field_values = expr->data.struct_init.field_values;
            fprintf(codegen->output, "(struct %s){", struct_name);
            for (int i = 0; i < field_count; i++) {
                const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                fprintf(codegen->output, ".%s = ", safe_field_name);
                gen_expr(codegen, field_values[i]);
                if (i < field_count - 1) fputs(", ", codegen->output);
            }
            fputc('}', codegen->output);
            break;
        }
        case AST_ARRAY_LITERAL: {
            ASTNode **elements = expr->data.array_literal.elements;
            int element_count = expr->data.array_literal.element_count;
            fputc('{', codegen->output);
            for (int i = 0; i < element_count; i++) {
                gen_expr(codegen, elements[i]);
                if (i < element_count - 1) fputs(", ", codegen->output);
            }
            fputc('}', codegen->output);
            break;
        }
        case AST_SIZEOF: {
            ASTNode *target = expr->data.sizeof_expr.target;
            int is_type = expr->data.sizeof_expr.is_type;
            fputs("sizeof(", codegen->output);
            if (is_type) {
                const char *type_c = c99_type_to_c(codegen, target);
                fprintf(codegen->output, "%s", type_c);
            } else {
                gen_expr(codegen, target);
            }
            fputc(')', codegen->output);
            break;
        }
        case AST_LEN: {
            ASTNode *array = expr->data.len_expr.array;
            fputs("sizeof(", codegen->output);
            gen_expr(codegen, array);
            fputs(") / sizeof((", codegen->output);
            gen_expr(codegen, array);
            fputs(")[0])", codegen->output);
            break;
        }
        case AST_ALIGNOF: {
            ASTNode *target = expr->data.alignof_expr.target;
            int is_type = expr->data.alignof_expr.is_type;
            fputs("_Alignof(", codegen->output);
            if (is_type) {
                const char *type_c = c99_type_to_c(codegen, target);
                fprintf(codegen->output, "%s", type_c);
            } else {
                gen_expr(codegen, target);
            }
            fputc(')', codegen->output);
            break;
        }
        case AST_CAST_EXPR: {
            ASTNode *src_expr = expr->data.cast_expr.expr;
            ASTNode *target_type = expr->data.cast_expr.target_type;
            const char *type_c = c99_type_to_c(codegen, target_type);
            fputc('(', codegen->output);
            fprintf(codegen->output, "%s)", type_c);
            gen_expr(codegen, src_expr);
            break;
        }
        case AST_IDENTIFIER: {
            const char *safe_name = get_safe_c_identifier(codegen, expr->data.identifier.name);
            fprintf(codegen->output, "%s", safe_name);
            break;
        }
        case AST_CALL_EXPR: {
            ASTNode *callee = expr->data.call_expr.callee;
            ASTNode **args = expr->data.call_expr.args;
            int arg_count = expr->data.call_expr.arg_count;
            
            // 生成被调用函数名
            if (callee && callee->type == AST_IDENTIFIER) {
                const char *safe_name = get_safe_c_identifier(codegen, callee->data.identifier.name);
                fprintf(codegen->output, "%s(", safe_name);
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
        case AST_EXPR_STMT:
            // 表达式语句的数据存储在表达式的节点中，直接忽略此节点
            break;
        case AST_ASSIGN: {
            ASTNode *dest = stmt->data.assign.dest;
            ASTNode *src = stmt->data.assign.src;
            c99_emit(codegen, "");
            gen_expr(codegen, dest);
            fputs(" = ", codegen->output);
            gen_expr(codegen, src);
            fputs(";\n", codegen->output);
            break;
        }
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
            const char *var_name = get_safe_c_identifier(codegen, stmt->data.var_decl.name);
            ASTNode *var_type = stmt->data.var_decl.type;
            ASTNode *init_expr = stmt->data.var_decl.init;
            int is_const = stmt->data.var_decl.is_const;
            
            if (var_type->type == AST_TYPE_ARRAY) {
                // 数组类型特殊处理
                ASTNode *element_type = var_type->data.type_array.element_type;
                ASTNode *size_expr = var_type->data.type_array.size_expr;
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
                
                // 生成数组声明：const elem_type var_name[size]
                c99_emit(codegen, "/* array type */ %s %s %s[%d]", is_const ? "const" : "", elem_type_c, var_name, array_size);
            } else {
                // 非数组类型
                const char *type_c = c99_type_to_c(codegen, var_type);
                c99_emit(codegen, "%s %s %s", is_const ? "const" : "", type_c, var_name);
            }
            
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
        case AST_WHILE_STMT: {
            ASTNode *condition = stmt->data.while_stmt.condition;
            ASTNode *body = stmt->data.while_stmt.body;
            
            c99_emit(codegen, "while (");
            gen_expr(codegen, condition);
            fputs(") {\n", codegen->output);
            codegen->indent_level++;
            gen_stmt(codegen, body);
            codegen->indent_level--;
            c99_emit(codegen, "}\n");
            break;
        }
        case AST_FOR_STMT: {
            // Uya Mini 的 for 循环是数组遍历：for item in array { ... }
            ASTNode *array = stmt->data.for_stmt.array;
            const char *var_name = get_safe_c_identifier(codegen, stmt->data.for_stmt.var_name);
            int is_ref = stmt->data.for_stmt.is_ref;
            ASTNode *body = stmt->data.for_stmt.body;
            
            // 生成临时变量保存数组和长度
            c99_emit(codegen, "{\n");
            codegen->indent_level++;
            c99_emit(codegen, "// for loop - array traversal\n");
            // 声明临时变量存储数组指针和长度
            const char *elem_type_c = "int"; // 暂时使用int，后续需要根据数组元素类型调整
            // 生成数组表达式
            c99_emit(codegen, "size_t _len = sizeof(");
            gen_expr(codegen, array);
            c99_emit(codegen, ") / sizeof(");
            gen_expr(codegen, array);
            c99_emit(codegen, "[0]);\n");
            c99_emit(codegen, "for (size_t _i = 0; _i < _len; _i++) {\n");
            codegen->indent_level++;
            if (is_ref) {
                c99_emit(codegen, "%s *%s = &", elem_type_c, var_name);
                gen_expr(codegen, array);
                c99_emit(codegen, "[_i];\n");
            } else {
                c99_emit(codegen, "%s %s = ", elem_type_c, var_name);
                gen_expr(codegen, array);
                c99_emit(codegen, "[_i];\n");
            }
            gen_stmt(codegen, body);
            codegen->indent_level--;
            c99_emit(codegen, "}\n");
            codegen->indent_level--;
            c99_emit(codegen, "}\n");
            break;
        }
        case AST_BREAK_STMT:
            c99_emit(codegen, "break;\n");
            break;
        case AST_CONTINUE_STMT:
            c99_emit(codegen, "continue;\n");
            break;
        default:
            // 检查是否为表达式节点
            if (stmt->type >= AST_BINARY_EXPR && stmt->type <= AST_STRING) {
                c99_emit(codegen, "");
                gen_expr(codegen, stmt);
                fputs(";\n", codegen->output);
            }
            // 忽略其他语句
            break;
    }
}

// 生成函数原型（前向声明）
static void gen_function_prototype(C99CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL) return;
    
    const char *func_name = get_safe_c_identifier(codegen, fn_decl->data.fn_decl.name);
    ASTNode *return_type = fn_decl->data.fn_decl.return_type;
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    int is_varargs = fn_decl->data.fn_decl.is_varargs;
    
    // 返回类型
    const char *return_c = c99_type_to_c(codegen, return_type);
    fprintf(codegen->output, "%s %s(", return_c, func_name);
    
    // 参数列表
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        fprintf(codegen->output, "%s %s", param_type_c, param_name);
        if (i < param_count - 1) fputs(", ", codegen->output);
    }
    
    // 处理可变参数
    if (is_varargs) {
        if (param_count > 0) fputs(", ", codegen->output);
        fputs("...", codegen->output);
    }
    
    fputs(");\n", codegen->output);
}

// 生成函数定义
static void gen_function(C99CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL) return;
    
    const char *func_name = get_safe_c_identifier(codegen, fn_decl->data.fn_decl.name);
    ASTNode *return_type = fn_decl->data.fn_decl.return_type;
    ASTNode **params = fn_decl->data.fn_decl.params;
    int param_count = fn_decl->data.fn_decl.param_count;
    int is_varargs = fn_decl->data.fn_decl.is_varargs;
    ASTNode *body = fn_decl->data.fn_decl.body;
    
    // 如果没有函数体（外部函数），则不生成定义
    if (!body) return;
    
    // 返回类型
    const char *return_c = c99_type_to_c(codegen, return_type);
    fprintf(codegen->output, "%s %s(", return_c, func_name);
    
    // 参数列表
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        fprintf(codegen->output, "%s %s", param_type_c, param_name);
        if (i < param_count - 1) fputs(", ", codegen->output);
    }
    
    // 处理可变参数
    if (is_varargs) {
        if (param_count > 0) fputs(", ", codegen->output);
        fputs("...", codegen->output);
    }
    
    fputs(") {\n", codegen->output);
    codegen->indent_level++;
    
    // 生成函数体
    gen_stmt(codegen, body);
    
    codegen->indent_level--;
    c99_emit(codegen, "}\n");
}

// 生成全局变量定义
static void gen_global_var(C99CodeGenerator *codegen, ASTNode *var_decl) {
    if (!var_decl || var_decl->type != AST_VAR_DECL) return;
    
    const char *var_name = get_safe_c_identifier(codegen, var_decl->data.var_decl.name);
    ASTNode *var_type = var_decl->data.var_decl.type;
    ASTNode *init_expr = var_decl->data.var_decl.init;
    int is_const = var_decl->data.var_decl.is_const;
    
    if (!var_name || !var_type) return;
    
    const char *type_c = NULL;
    int array_size = -1;
    
    // 检查是否为数组类型
    if (var_type->type == AST_TYPE_ARRAY) {
        ASTNode *element_type = var_type->data.type_array.element_type;
        ASTNode *size_expr = var_type->data.type_array.size_expr;
        type_c = c99_type_to_c(codegen, element_type);
        
        // 评估数组大小
        if (size_expr) {
            array_size = eval_const_expr(codegen, size_expr);
            if (array_size <= 0) {
                array_size = 1;  // 占位符
            }
        } else {
            array_size = 1;  // 占位符
        }
        
        // 生成数组声明：const elem_type var_name[size]
        if (is_const) {
            fprintf(codegen->output, "const %s %s[%d]", type_c, var_name, array_size);
        } else {
            fprintf(codegen->output, "%s %s[%d]", type_c, var_name, array_size);
        }
    } else {
        type_c = c99_type_to_c(codegen, var_type);
        if (is_const) {
            fprintf(codegen->output, "const %s %s", type_c, var_name);
        } else {
            fprintf(codegen->output, "%s %s", type_c, var_name);
        }
    }
    
    // 初始化表达式
    if (init_expr) {
        fputs(" = ", codegen->output);
        gen_expr(codegen, init_expr);
    }
    
    fputs(";\n", codegen->output);
    
    // 添加到全局变量表（可选，用于后续引用）
    if (codegen->global_variable_count < 128) {
        codegen->global_variables[codegen->global_variable_count].name = var_name;
        codegen->global_variables[codegen->global_variable_count].type_c = type_c;
        codegen->global_variables[codegen->global_variable_count].is_const = is_const;
        codegen->global_variable_count++;
    }
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
    
    // 第二步：收集所有结构体和枚举定义（添加到表中但不生成代码）
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
    
    // 第三步：生成所有函数的前向声明（解决相互递归调用）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_FN_DECL) continue;
        gen_function_prototype(codegen, decl);
    }
    fputs("\n", codegen->output);
    
    // 第四步：生成所有声明（结构体、枚举、全局变量、函数定义）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        
        switch (decl->type) {
            case AST_ENUM_DECL:
                gen_enum_definition(codegen, decl);
                fputs("\n", codegen->output);
                break;
            case AST_STRUCT_DECL:
                gen_struct_definition(codegen, decl);
                fputs("\n", codegen->output);
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