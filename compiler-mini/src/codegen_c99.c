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
    codegen->current_function_return_type = NULL;
    
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

// 转义字符串中的特殊字符
static void escape_string_for_c(FILE *output, const char *str) {
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
static void emit_string_constants(C99CodeGenerator *codegen) {
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
        
        default:
            return "void";
    }
}

// 查找枚举声明（从程序节点中查找）
static ASTNode *find_enum_decl(C99CodeGenerator *codegen, const char *enum_name) {
    if (!codegen || !enum_name || !codegen->program_node) {
        return NULL;
    }
    
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_ENUM_DECL) {
            continue;
        }
        
        const char *decl_name = decl->data.enum_decl.name;
        if (decl_name && strcmp(decl_name, enum_name) == 0) {
            return decl;
        }
    }
    
    return NULL;
}

// 查找枚举变体的值（返回-1表示未找到）
static int find_enum_variant_value(C99CodeGenerator *codegen, ASTNode *enum_decl, const char *variant_name) {
    (void)codegen;  // 未使用参数
    if (!enum_decl || enum_decl->type != AST_ENUM_DECL || !variant_name) {
        return -1;
    }
    
    EnumVariant *variants = enum_decl->data.enum_decl.variants;
    int variant_count = enum_decl->data.enum_decl.variant_count;
    int current_value = 0;
    
    for (int i = 0; i < variant_count; i++) {
        EnumVariant *variant = &variants[i];
        if (!variant->name) {
            continue;
        }
        
        // 确定当前变体的值
        if (variant->value) {
            current_value = atoi(variant->value);
        }
        
        // 检查是否匹配
        if (strcmp(variant->name, variant_name) == 0) {
            return current_value;
        }
        
        // 如果没有显式值，下一个变体的值会自动递增
        if (!variant->value) {
            current_value++;
        }
    }
    
    return -1;
}

// 检查标识符是否为指针类型
static int is_identifier_pointer_type(C99CodeGenerator *codegen, const char *name) {
    if (!name) return 0;
    
    // 检查局部变量
    for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
        if (strcmp(codegen->local_variables[i].name, name) == 0) {
            const char *type_c = codegen->local_variables[i].type_c;
            if (!type_c) return 0;
            // 检查类型是否包含'*'（即是指针）
            return (strchr(type_c, '*') != NULL);
        }
    }
    
    // 检查全局变量
    for (int i = 0; i < codegen->global_variable_count; i++) {
        if (strcmp(codegen->global_variables[i].name, name) == 0) {
            const char *type_c = codegen->global_variables[i].type_c;
            if (!type_c) return 0;
            // 检查类型是否包含'*'（即是指针）
            return (strchr(type_c, '*') != NULL);
        }
    }
    
    return 0;
}

// 检查标识符是否是指向数组的指针类型（格式：T (*)[N] 或 T (* const var)[N]）
static int is_identifier_pointer_to_array_type(C99CodeGenerator *codegen, const char *name) {
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

// 检查标识符对应的类型是否为结构体
static int is_identifier_struct_type(C99CodeGenerator *codegen, const char *name) {
    if (!name) return 0;
    
    // 检查局部变量
    for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
        if (strcmp(codegen->local_variables[i].name, name) == 0) {
            const char *type_c = codegen->local_variables[i].type_c;
            if (!type_c) return 0;
            // 检查类型是否以"struct "开头且不包含'*'（即不是指针）
            return (strncmp(type_c, "struct ", 7) == 0 && strchr(type_c, '*') == NULL);
        }
    }
    
    // 检查全局变量
    for (int i = 0; i < codegen->global_variable_count; i++) {
        if (strcmp(codegen->global_variables[i].name, name) == 0) {
            const char *type_c = codegen->global_variables[i].type_c;
            if (!type_c) return 0;
            // 检查类型是否以"struct "开头且不包含'*'（即不是指针）
            return (strncmp(type_c, "struct ", 7) == 0 && strchr(type_c, '*') == NULL);
        }
    }
    
    return 0;
}

// 生成数组包装结构体的名称
// 例如：[i32: 3] -> "uya_array_i32_3", [[i32: 2]: 3] -> "uya_array_i32_2_3"
static const char *get_array_wrapper_struct_name(C99CodeGenerator *codegen, ASTNode *array_type) {
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
static void gen_array_wrapper_struct(C99CodeGenerator *codegen, ASTNode *array_type, const char *struct_name) {
    if (!array_type || array_type->type != AST_TYPE_ARRAY || !struct_name) {
        return;
    }
    
    // 检查是否已生成
    if (is_struct_defined(codegen, struct_name)) {
        return;
    }
    
    // 添加到结构体定义表（避免重复生成）
    if (codegen->struct_definition_count < 64) {
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
static const char *convert_array_return_type(C99CodeGenerator *codegen, ASTNode *return_type) {
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

// 前向声明
static void mark_struct_defined(C99CodeGenerator *codegen, const char *struct_name);
static void add_struct_definition(C99CodeGenerator *codegen, const char *struct_name);

// 检查结构体是否已添加到表中
static int is_struct_in_table(C99CodeGenerator *codegen, const char *struct_name) {
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

// 获取数组表达式的元素类型（返回C类型字符串）
// 如果无法确定类型，返回NULL
static const char *get_array_element_type(C99CodeGenerator *codegen, ASTNode *array_expr) {
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
                const char *bracket = strchr(type_c, '[');
                if (bracket) {
                    // 提取元素类型（bracket之前的部分）
                    size_t len = bracket - type_c;
                    char *elem_type = arena_alloc(codegen->arena, len + 1);
                    if (!elem_type) return NULL;
                    memcpy(elem_type, type_c, len);
                    elem_type[len] = '\0';
                    return elem_type;
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
                const char *bracket = strchr(type_c, '[');
                if (bracket) {
                    // 提取元素类型（bracket之前的部分）
                    size_t len = bracket - type_c;
                    char *elem_type = arena_alloc(codegen->arena, len + 1);
                    if (!elem_type) return NULL;
                    memcpy(elem_type, type_c, len);
                    elem_type[len] = '\0';
                    return elem_type;
                }
                return NULL;
            }
        }
        
        return NULL;
    }
    
    // 如果是数组访问，递归获取元素类型
    if (array_expr->type == AST_ARRAY_ACCESS) {
        ASTNode *base_array = array_expr->data.array_access.array;
        return get_array_element_type(codegen, base_array);
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
            
            // 检查是否是结构体比较（== 或 !=）
            int is_struct_comparison = 0;
            if ((op == TOKEN_EQUAL || op == TOKEN_NOT_EQUAL) &&
                left && right) {
                // 检查左操作数是否是结构体类型
                if (left->type == AST_IDENTIFIER) {
                    if (is_identifier_struct_type(codegen, left->data.identifier.name)) {
                        is_struct_comparison = 1;
                    }
                } else if (left->type == AST_STRUCT_INIT) {
                    is_struct_comparison = 1;
                }
            }
            
            if (is_struct_comparison) {
                // 使用memcmp比较结构体
                // 需要获取左操作数的类型来确定结构体大小
                const char *struct_name = NULL;
                if (left->type == AST_IDENTIFIER) {
                    // 对于变量，我们需要查找其类型
                    // 这里简化处理，使用sizeof运算符
                    fputs("memcmp(&", codegen->output);
                    gen_expr(codegen, left);
                    fputs(", &", codegen->output);
                    gen_expr(codegen, right);
                    fputs(", sizeof(", codegen->output);
                    gen_expr(codegen, left);
                    fputs("))", codegen->output);
                } else if (left->type == AST_STRUCT_INIT) {
                    // 对于结构体字面量，使用结构体名称
                    struct_name = left->data.struct_init.struct_name;
                    fputs("memcmp(&", codegen->output);
                    gen_expr(codegen, left);
                    fputs(", &", codegen->output);
                    gen_expr(codegen, right);
                    fprintf(codegen->output, ", sizeof(struct %s))", struct_name);
                } else {
                    // 默认情况，使用sizeof左操作数
                    fputs("memcmp(&", codegen->output);
                    gen_expr(codegen, left);
                    fputs(", &", codegen->output);
                    gen_expr(codegen, right);
                    fputs(", sizeof(", codegen->output);
                    gen_expr(codegen, left);
                    fputs("))", codegen->output);
                }
                if (op == TOKEN_EQUAL) {
                    fputs(" == 0", codegen->output);
                } else if (op == TOKEN_NOT_EQUAL) {
                    fputs(" != 0", codegen->output);
                }
            } else {
                // 普通二元表达式
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
            }
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
            const char *field_name = expr->data.member_access.field_name;
            
            if (!object || !field_name) {
                break;
            }
            
            // 检查是否是枚举值访问（EnumName.Variant）
            if (object->type == AST_IDENTIFIER) {
                const char *enum_name = object->data.identifier.name;
                if (enum_name) {
                    // 检查是否是枚举类型名称（不检查变量表，直接检查枚举声明）
                    ASTNode *enum_decl = find_enum_decl(codegen, enum_name);
                    if (enum_decl != NULL) {
                        // 是枚举类型，查找变体值
                        int enum_value = find_enum_variant_value(codegen, enum_decl, field_name);
                        if (enum_value >= 0) {
                            // 找到变体，直接输出枚举值名称（C中枚举值不需要前缀）
                            const char *safe_variant_name = get_safe_c_identifier(codegen, field_name);
                            fprintf(codegen->output, "%s", safe_variant_name);
                            break;
                        }
                    }
                }
            }
            
            // 普通字段访问（结构体字段）
            const char *safe_field_name = get_safe_c_identifier(codegen, field_name);
            
            // 检查对象是否是指针类型（需要自动解引用）
            int is_pointer = 0;
            if (object->type == AST_IDENTIFIER) {
                // 标识符：检查变量类型是否是指针
                is_pointer = is_identifier_pointer_type(codegen, object->data.identifier.name);
            } else if (object->type == AST_UNARY_EXPR) {
                // 一元表达式：检查操作符
                int op = object->data.unary_expr.op;
                if (op == TOKEN_AMPERSAND) {
                    // &expr：取地址表达式的结果是指针，但这里访问的是 expr 的字段
                    // 实际上不应该发生这种情况，因为 &expr.field 在语法上不合法
                    // 但为了安全，我们假设不是指针
                    is_pointer = 0;
                } else if (op == TOKEN_ASTERISK) {
                    // *ptr：解引用表达式的结果是结构体本身，不是指针
                    // 所以应该使用 . 而不是 ->
                    is_pointer = 0;
                }
                // 其他一元操作符（!, -, +）不影响类型判断
            }
            
            gen_expr(codegen, object);
            if (is_pointer) {
                // 指针类型使用 -> 操作符
                fprintf(codegen->output, "->%s", safe_field_name);
            } else {
                // 非指针类型使用 . 操作符
                fprintf(codegen->output, ".%s", safe_field_name);
            }
            break;
        }
        case AST_ARRAY_ACCESS: {
            ASTNode *array = expr->data.array_access.array;
            ASTNode *index = expr->data.array_access.index;
            
            // 检查数组表达式是否是指向数组的指针
            int is_ptr_to_array = 0;
            if (array->type == AST_IDENTIFIER) {
                const char *array_name = array->data.identifier.name;
                if (array_name) {
                    is_ptr_to_array = is_identifier_pointer_to_array_type(codegen, array_name);
                }
            }
            
            if (is_ptr_to_array) {
                // 指向数组的指针需要先解引用：(*ptr)[index]
                fputc('(', codegen->output);
                fputc('*', codegen->output);
                gen_expr(codegen, array);
                fputc(')', codegen->output);
            } else {
                gen_expr(codegen, array);
            }
            
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
                // 显式检查是否是结构体类型（即使在 c99_type_to_c 中查找失败）
                if (target->type == AST_TYPE_NAMED) {
                    const char *name = target->data.type_named.name;
                    if (name && !is_c_keyword(name)) {
                        // 检查是否是结构体（检查是否在表中，不管是否已定义）
                        const char *safe_name = get_safe_c_identifier(codegen, name);
                        if (is_struct_in_table(codegen, safe_name)) {
                            fprintf(codegen->output, "struct %s", safe_name);
                        } else {
                            // 如果不在表中，尝试从程序节点中查找结构体声明
                            if (codegen->program_node) {
                                ASTNode **decls = codegen->program_node->data.program.decls;
                                int decl_count = codegen->program_node->data.program.decl_count;
                                int found = 0;
                                for (int i = 0; i < decl_count; i++) {
                                    ASTNode *decl = decls[i];
                                    if (decl && decl->type == AST_STRUCT_DECL) {
                                        const char *struct_name = decl->data.struct_decl.name;
                                        if (struct_name) {
                                            const char *safe_struct_name = get_safe_c_identifier(codegen, struct_name);
                                            if (strcmp(safe_struct_name, safe_name) == 0) {
                                                fprintf(codegen->output, "struct %s", safe_name);
                                                found = 1;
                                                break;
                                            }
                                        }
                                    }
                                }
                                if (!found) {
                                    // 不是结构体，使用默认类型转换
                                    const char *type_c = c99_type_to_c(codegen, target);
                                    fprintf(codegen->output, "%s", type_c);
                                }
                            } else {
                                const char *type_c = c99_type_to_c(codegen, target);
                                fprintf(codegen->output, "%s", type_c);
                            }
                        }
                    } else {
                        const char *type_c = c99_type_to_c(codegen, target);
                        fprintf(codegen->output, "%s", type_c);
                    }
                } else {
                    const char *type_c = c99_type_to_c(codegen, target);
                    // 检查是否是数组指针类型（包含 [数字] *，且 * 在末尾）
                    const char *bracket = strchr(type_c, '[');
                    const char *asterisk = strrchr(type_c, '*');  // 从后往前找最后一个 *
                    if (bracket && asterisk && bracket < asterisk) {
                        // 检查 * 是否在末尾（后面只有空格或结束）
                        const char *after_asterisk = asterisk + 1;
                        while (*after_asterisk == ' ') after_asterisk++;
                        if (*after_asterisk == '\0') {
                            // 数组指针类型：T[N] * -> T(*)[N]
                            // 找到 ']' 的位置
                            const char *close_bracket = strchr(bracket, ']');
                            if (close_bracket) {
                                size_t base_len = bracket - type_c;
                                size_t array_spec_len = close_bracket - bracket + 1;
                                fprintf(codegen->output, "%.*s(*)", (int)base_len, type_c);
                                fprintf(codegen->output, "%.*s", (int)array_spec_len, bracket);
                            } else {
                                fprintf(codegen->output, "%s", type_c);
                            }
                        } else {
                            fprintf(codegen->output, "%s", type_c);
                        }
                    } else {
                        fprintf(codegen->output, "%s", type_c);
                    }
                }
            } else {
                // 即使 is_type = 0，也检查是否是结构体标识符（如 sizeof(Point) 中的 Point）
                if (target->type == AST_IDENTIFIER || target->type == AST_TYPE_NAMED) {
                    const char *name = (target->type == AST_IDENTIFIER)
                        ? target->data.identifier.name
                        : target->data.type_named.name;
                    if (name && !is_c_keyword(name)) {
                        const char *safe_name = get_safe_c_identifier(codegen, name);
                        if (is_struct_in_table(codegen, safe_name)) {
                            fprintf(codegen->output, "struct %s", safe_name);
                        } else {
                            int is_enum = is_enum_in_table(codegen, safe_name);
                            if (!is_enum && find_enum_decl(codegen, safe_name)) {
                                is_enum = 1;
                            }
                            if (is_enum) {
                                fprintf(codegen->output, "enum %s", safe_name);
                            } else {
                                gen_expr(codegen, target);
                            }
                        }
                    } else {
                        gen_expr(codegen, target);
                    }
                } else {
                    gen_expr(codegen, target);
                }
            }
            fputc(')', codegen->output);
            break;
        }
        case AST_LEN: {
            ASTNode *array = expr->data.len_expr.array;
            
            // 检查数组表达式是否是标识符（局部变量或参数）
            if (array->type == AST_IDENTIFIER) {
                const char *var_name = array->data.identifier.name;
                
                // 查找变量类型以确定数组大小
                int found = 0;
                int array_size = -1;
                
                // 检查局部变量
                for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
                    if (strcmp(codegen->local_variables[i].name, var_name) == 0) {
                        const char *type_c = codegen->local_variables[i].type_c;
                        if (type_c) {
                            // 从类型字符串中提取数组大小，格式如 "int32_t[3]"
                            const char *bracket = strchr(type_c, '[');
                            if (bracket) {
                                const char *close_bracket = strchr(bracket + 1, ']');
                                if (close_bracket) {
                                    // 提取数字部分
                                    int len = close_bracket - bracket - 1;
                                    char num_buf[32];
                                    if (len < (int)sizeof(num_buf)) {
                                        memcpy(num_buf, bracket + 1, len);
                                        num_buf[len] = '\0';
                                        array_size = atoi(num_buf);
                                        if (array_size > 0) {
                                            fprintf(codegen->output, "%d", array_size);
                                            found = 1;
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                        break;
                    }
                }
                
                // 如果找到数组大小，直接输出
                if (found) {
                    break;
                }
            }
            
            // 备用方案：使用 sizeof 计算（适用于非参数数组）
            // 注意：这只适用于栈分配的数组，不适用于函数参数
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
            fputs("uya_alignof(", codegen->output);
            if (is_type) {
                const char *type_c = c99_type_to_c(codegen, target);
                fprintf(codegen->output, "%s", type_c);
            } else {
                // 即使 is_type = 0，也检查是否是结构体标识符（如 sizeof(Point) 中的 Point）
                if (target->type == AST_IDENTIFIER) {
                    const char *name = target->data.identifier.name;
                    if (name && !is_c_keyword(name)) {
                        const char *safe_name = get_safe_c_identifier(codegen, name);
                        if (is_struct_in_table(codegen, safe_name)) {
                            fprintf(codegen->output, "struct %s", safe_name);
                        } else {
                            gen_expr(codegen, target);
                        }
                    } else {
                        gen_expr(codegen, target);
                    }
                } else {
                    gen_expr(codegen, target);
                }
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
            const char *name = expr->data.identifier.name;
            if (name && strcmp(name, "null") == 0) {
                fputs("NULL", codegen->output);
            } else {
                const char *safe_name = get_safe_c_identifier(codegen, name);
                fprintf(codegen->output, "%s", safe_name);
            }
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
            
            // 检查左侧是否是数组类型
            int is_array_assign = 0;
            if (dest->type == AST_IDENTIFIER) {
                const char *var_name = dest->data.identifier.name;
                // 检查局部变量
                for (int i = codegen->local_variable_count - 1; i >= 0; i--) {
                    if (strcmp(codegen->local_variables[i].name, var_name) == 0) {
                        const char *type_c = codegen->local_variables[i].type_c;
                        if (type_c && strchr(type_c, '[') != NULL) {
                            is_array_assign = 1;
                        }
                        break;
                    }
                }
                // 检查全局变量
                if (!is_array_assign) {
                    for (int i = 0; i < codegen->global_variable_count; i++) {
                        if (strcmp(codegen->global_variables[i].name, var_name) == 0) {
                            const char *type_c = codegen->global_variables[i].type_c;
                            if (type_c && strchr(type_c, '[') != NULL) {
                                is_array_assign = 1;
                            }
                            break;
                        }
                    }
                }
            }
            
            if (is_array_assign) {
                // 数组赋值：使用 memcpy
                c99_emit(codegen, "memcpy(");
                gen_expr(codegen, dest);
                fputs(", ", codegen->output);
                gen_expr(codegen, src);
                fputs(", sizeof(", codegen->output);
                gen_expr(codegen, dest);
                fputs("));\n", codegen->output);
            } else {
                // 普通赋值
                c99_emit(codegen, "");
                gen_expr(codegen, dest);
                fputs(" = ", codegen->output);
                gen_expr(codegen, src);
                fputs(";\n", codegen->output);
            }
            break;
        }
        case AST_RETURN_STMT: {
            ASTNode *expr = stmt->data.return_stmt.expr;
            
            // 检查函数返回类型是否为数组
            int is_array_return = 0;
            ASTNode *return_type = codegen->current_function_return_type;
            if (return_type && return_type->type == AST_TYPE_ARRAY) {
                is_array_return = 1;
            }
            
            if (is_array_return && expr) {
                // 返回数组类型：需要包装在结构体中
                const char *struct_name = get_array_wrapper_struct_name(codegen, return_type);
                if (struct_name) {
                    // 生成包装结构体定义（如果尚未生成）
                    gen_array_wrapper_struct(codegen, return_type, struct_name);
                    
                    // 生成返回语句：return (struct uya_array_xxx) { .data = { ... } };
                    c99_emit(codegen, "return (struct %s) { .data = ", struct_name);
                    
                    if (expr->type == AST_ARRAY_LITERAL) {
                        // 数组字面量
                        fputc('{', codegen->output);
                        ASTNode **elements = expr->data.array_literal.elements;
                        int element_count = expr->data.array_literal.element_count;
                        for (int i = 0; i < element_count; i++) {
                            if (i > 0) fputs(", ", codegen->output);
                            gen_expr(codegen, elements[i]);
                        }
                        fputc('}', codegen->output);
                    } else {
                        // 其他表达式（如变量）
                        gen_expr(codegen, expr);
                    }
                    
                    fputs(" };\n", codegen->output);
                } else {
                    // 回退到普通返回
                    c99_emit(codegen, "return ");
                    gen_expr(codegen, expr);
                    fputs(";\n", codegen->output);
                }
            } else {
                // 非数组返回类型，正常处理
                c99_emit(codegen, "return ");
                if (expr) {
                    gen_expr(codegen, expr);
                } else {
                    fputs("0", codegen->output);
                }
                fputs(";\n", codegen->output);
            }
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
            
            // 计算类型字符串
            const char *type_c = NULL;
            if (var_type->type == AST_TYPE_ARRAY) {
                // 使用 c99_type_to_c 来处理数组类型（包括多维数组）
                // 它会返回正确的格式，如 "int32_t[3][2]" 对于 [[i32: 2]: 3]
                type_c = c99_type_to_c(codegen, var_type);
                
                // 解析类型字符串，分离基类型和数组维度
                // 例如："int32_t[3][2]" -> 基类型="int32_t", 维度="[3][2]"
                // 或者 "int32_t[3]" -> 基类型="int32_t", 维度="[3]"
                const char *first_bracket = strchr(type_c, '[');
                if (first_bracket) {
                    // 找到第一个 '['，分割基类型和维度
                    size_t base_len = first_bracket - type_c;
                    char *base_type = arena_alloc(codegen->arena, base_len + 1);
                    if (base_type) {
                        memcpy(base_type, type_c, base_len);
                        base_type[base_len] = '\0';
                        
                        // 维度部分是从 '[' 开始到结尾
                        const char *dimensions = type_c + base_len;
                        
                        // 生成数组声明：const base_type var_name dimensions
                        if (is_const) {
                            fprintf(codegen->output, "const %s %s%s", base_type, var_name, dimensions);
                        } else {
                            fprintf(codegen->output, "%s %s%s", base_type, var_name, dimensions);
                        }
                        type_c = NULL; // 已处理，避免后续重复输出
                    }
                }
                
                // 如果上面的解析失败，回退到简单处理
                if (type_c) {
                    if (is_const) {
                        c99_emit(codegen, "const %s %s", type_c, var_name);
                    } else {
                        c99_emit(codegen, "%s %s", type_c, var_name);
                    }
                }
            } else {
                // 非数组类型
                type_c = c99_type_to_c(codegen, var_type);
                if (is_const && var_type->type == AST_TYPE_POINTER) {
                    // 检查是否是指向数组的指针类型（格式：T (*)[N]）
                    const char *open_paren = strstr(type_c, "(*");
                    if (open_paren) {
                        // 找到对应的 ')' 和 '['
                        const char *close_paren = strchr(open_paren, ')');
                        const char *bracket = strchr(open_paren, '[');
                        if (close_paren && bracket && close_paren < bracket) {
                            // 这是指向数组的指针：T (*)[N]
                            // 需要生成：T (* const var_name)[N]
                            size_t prefix_len = open_paren - type_c;
                            size_t suffix_len = strlen(bracket);
                            fprintf(codegen->output, "%.*s(* const %s)%.*s", 
                                    (int)prefix_len, type_c, var_name, (int)suffix_len, bracket);
                        } else {
                            // 普通指针：T * -> T * const var_name
                            c99_emit(codegen, "%s const %s", type_c, var_name);
                        }
                    } else {
                        // 普通指针：T * -> T * const var_name
                        c99_emit(codegen, "%s const %s", type_c, var_name);
                    }
                } else if (is_const) {
                    c99_emit(codegen, "const %s %s", type_c, var_name);
                } else {
                    c99_emit(codegen, "%s %s", type_c, var_name);
                }
            }
            
            if (init_expr) {
                // 检查是否是数组类型且初始化表达式是函数调用（返回数组）
                int is_array_from_function = 0;
                if (var_type->type == AST_TYPE_ARRAY && init_expr->type == AST_CALL_EXPR) {
                    // 需要检查函数返回类型是否为数组
                    // 这里简化处理：假设函数调用返回数组类型
                    is_array_from_function = 1;
                }
                
                // 检查是否是数组类型且初始化表达式是另一个数组（需要memcpy）
                int needs_memcpy = 0;
                if (var_type->type == AST_TYPE_ARRAY && init_expr->type == AST_IDENTIFIER) {
                    needs_memcpy = 1;
                }
                
                if (is_array_from_function) {
                    // 从函数调用接收数组：需要从包装结构体中提取
                    // 先完成变量声明（不包含初始化）
                    fputs(";\n", codegen->output);
                    // 然后使用 memcpy 从结构体中提取数组
                    c99_emit(codegen, "memcpy(");
                    c99_emit(codegen, "%s", var_name);
                    fputs(", ", codegen->output);
                    gen_expr(codegen, init_expr);
                    fputs(".data, sizeof(", codegen->output);
                    c99_emit(codegen, "%s", var_name);
                    fputs("));\n", codegen->output);
                } else if (needs_memcpy) {
                    // 数组初始化：使用memcpy
                    fputs(";\n", codegen->output);
                    c99_emit(codegen, "memcpy(");
                    c99_emit(codegen, "%s", var_name);
                    fputs(", ", codegen->output);
                    gen_expr(codegen, init_expr);
                    fputs(", sizeof(", codegen->output);
                    c99_emit(codegen, "%s", var_name);
                    fputs("));\n", codegen->output);
                } else {
                    // 普通初始化
                    fputs(" = ", codegen->output);
                    gen_expr(codegen, init_expr);
                    fputs(";\n", codegen->output);
                }
            } else {
                fputs(";\n", codegen->output);
            }
            
            // 添加到局部变量表（用于类型检测）
            if (var_name && type_c && codegen->local_variable_count < 128) {
                codegen->local_variables[codegen->local_variable_count].name = var_name;
                codegen->local_variables[codegen->local_variable_count].type_c = type_c;
                codegen->local_variable_count++;
            }
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
            
            // 获取数组元素类型
            const char *elem_type_c = get_array_element_type(codegen, array);
            if (!elem_type_c) {
                // 如果无法推断类型，使用int作为默认类型
                elem_type_c = "int32_t";
            }
            
            // 生成临时变量保存数组和长度
            c99_emit(codegen, "{\n");
            codegen->indent_level++;
            c99_emit(codegen, "// for loop - array traversal\n");
            // 生成数组长度计算
            c99_emit(codegen, "size_t _len = sizeof(");
            gen_expr(codegen, array);
            c99_emit(codegen, ") / sizeof(");
            gen_expr(codegen, array);
            c99_emit(codegen, "[0]);\n");
            c99_emit(codegen, "for (size_t _i = 0; _i < _len; _i++) {\n");
            codegen->indent_level++;
            if (is_ref) {
                // 引用迭代：生成指针类型
                c99_emit(codegen, "%s *%s = &", elem_type_c, var_name);
                gen_expr(codegen, array);
                c99_emit(codegen, "[_i];\n");
            } else {
                // 值迭代：生成值类型
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

// 格式化函数参数类型（将数组类型从 T[N] 转换为 T name[N]）
static void format_param_type(C99CodeGenerator *codegen, const char *type_c, const char *param_name, FILE *output) {
    if (!type_c || !param_name) return;
    
    // 检查是否是数组类型（包含 [数字]）
    const char *bracket = strchr(type_c, '[');
    if (bracket) {
        // 提取元素类型（bracket之前的部分）
        size_t len = bracket - type_c;
        fprintf(output, "%.*s %s%s", (int)len, type_c, param_name, bracket);
    } else {
        // 非数组类型，直接输出
        fprintf(output, "%s %s", type_c, param_name);
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
    ASTNode *body = fn_decl->data.fn_decl.body;
    
    // 检查是否为extern函数（body为NULL表示extern函数）
    int is_extern = (body == NULL) ? 1 : 0;
    
    // 返回类型（如果是数组类型，转换为指针类型）
    const char *return_c = convert_array_return_type(codegen, return_type);
    
    // 对于extern函数，添加extern关键字
    if (is_extern) {
        fprintf(codegen->output, "extern %s %s(", return_c, func_name);
    } else {
        fprintf(codegen->output, "%s %s(", return_c, func_name);
    }
    
    // 参数列表
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        format_param_type(codegen, param_type_c, param_name, codegen->output);
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
    
    // 返回类型（如果是数组类型，转换为指针类型）
    const char *return_c = convert_array_return_type(codegen, return_type);
    fprintf(codegen->output, "%s %s(", return_c, func_name);
    
    // 参数列表
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = get_safe_c_identifier(codegen, param->data.var_decl.name);
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        format_param_type(codegen, param_type_c, param_name, codegen->output);
        if (i < param_count - 1) fputs(", ", codegen->output);
    }
    
    // 处理可变参数
    if (is_varargs) {
        if (param_count > 0) fputs(", ", codegen->output);
        fputs("...", codegen->output);
    }
    
    fputs(") {\n", codegen->output);
    codegen->indent_level++;
    
    // 保存当前函数的返回类型（用于生成返回语句）
    codegen->current_function_return_type = return_type;
    
    // 将函数参数添加到局部变量表（用于类型检查）
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) continue;
        
        const char *param_name = param->data.var_decl.name;
        ASTNode *param_type = param->data.var_decl.type;
        const char *param_type_c = c99_type_to_c(codegen, param_type);
        
        if (param_name && param_type_c && codegen->local_variable_count < 128) {
            codegen->local_variables[codegen->local_variable_count].name = param_name;
            codegen->local_variables[codegen->local_variable_count].type_c = param_type_c;
            codegen->local_variable_count++;
        }
    }
    
    // 生成函数体
    gen_stmt(codegen, body);
    
    // 清除当前函数的返回类型
    codegen->current_function_return_type = NULL;
    
    codegen->indent_level--;
    c99_emit(codegen, "}\n");
}

// 生成全局作用域兼容的初始化表达式（不使用复合字面量）
static void gen_global_init_expr(C99CodeGenerator *codegen, ASTNode *expr) {
    if (!expr) return;
    
    switch (expr->type) {
        case AST_STRUCT_INIT: {
            // 对于全局作用域，生成标准初始化器列表，不使用复合字面量
            int field_count = expr->data.struct_init.field_count;
            const char **field_names = expr->data.struct_init.field_names;
            ASTNode **field_values = expr->data.struct_init.field_values;
            fputc('{', codegen->output);
            for (int i = 0; i < field_count; i++) {
                const char *safe_field_name = get_safe_c_identifier(codegen, field_names[i]);
                fprintf(codegen->output, ".%s = ", safe_field_name);
                gen_global_init_expr(codegen, field_values[i]);
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
                gen_global_init_expr(codegen, elements[i]);
                if (i < element_count - 1) fputs(", ", codegen->output);
            }
            fputc('}', codegen->output);
            break;
        }
        default:
            // 对于其他表达式类型（数字、布尔值、字符串等），使用标准生成方式
            gen_expr(codegen, expr);
            break;
    }
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
    
    // 初始化表达式（使用全局作用域兼容的生成方式）
    if (init_expr) {
        fputs(" = ", codegen->output);
        gen_global_init_expr(codegen, init_expr);
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
    fputs("#include <string.h>\n", codegen->output);  // for memcmp
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

    // 第五步：生成所有结构体和枚举定义（确保函数原型有完整类型）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) continue;
        if (decl->type == AST_STRUCT_DECL) {
            gen_struct_definition(codegen, decl);
            fputs("\n", codegen->output);
        } else if (decl->type == AST_ENUM_DECL) {
            gen_enum_definition(codegen, decl);
            fputs("\n", codegen->output);
        }
    }

    // 第六步：生成所有函数的前向声明（解决相互递归调用）
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