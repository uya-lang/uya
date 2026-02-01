#include "parser.h"
#include <stddef.h>
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// 初始化 Parser
int parser_init(Parser *parser, Lexer *lexer, Arena *arena) {
    if (parser == NULL || lexer == NULL || arena == NULL) {
        return -1;
    }
    
    parser->lexer = lexer;
    parser->arena = arena;
    parser->context = PARSER_CONTEXT_NORMAL;  // 默认上下文
    
    // 获取第一个 Token
    parser->current_token = lexer_next_token(lexer, arena);
    
    return 0;
}

// 辅助函数：检查当前 Token 类型是否匹配
static int parser_match(Parser *parser, TokenType type) {
    if (parser == NULL || parser->current_token == NULL) {
        return 0;
    }
    return parser->current_token->type == type;
}

// 辅助函数：消费当前 Token 并获取下一个
static Token *parser_consume(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    Token *current = parser->current_token;
    parser->current_token = lexer_next_token(parser->lexer, parser->arena);
    return current;
}

// 辅助函数：期望特定类型的 Token
static Token *parser_expect(Parser *parser, TokenType type) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    if (parser->current_token->type != type) {
        // 错误：期望的类型不匹配
        // 调试输出
        if (type == TOKEN_RIGHT_BRACE && parser->current_token->type == TOKEN_ELSE) {
            fprintf(stderr, "调试: parser_expect 失败 - 期望 '}', 得到 'else'\n");
            fprintf(stderr, "调试: lexer position=%zu, line=%d, column=%d\n", 
                    parser->lexer->position, parser->lexer->line, parser->lexer->column);
        }
        return NULL;
    }
    
    return parser_consume(parser);
}

// 辅助函数：检查当前 token（'{'）后面是否是结构体字段初始化列表的开始
// 结构体字段初始化列表格式：identifier: expr 或 }
// 注意：调用此函数时，parser->current_token 应该是 '{'
static int parser_peek_is_struct_init(Parser *parser) {
    if (parser == NULL || parser->lexer == NULL || parser->current_token == NULL) {
        return 0;
    }
    
    if (parser->current_token->type != TOKEN_LEFT_BRACE) {
        return 0;
    }
    
    Lexer *lexer = parser->lexer;
    /* 在字符串/插值内部不能做 lookahead，会破坏 string_mode/interp_depth 等状态 */
    if (lexer->string_mode || lexer->interp_depth > 0) {
        return 0;
    }
    
    // 保存 lexer 状态（当前 lexer 的 position 已经在 '{' 之后）
    size_t saved_position = lexer->position;
    int saved_line = lexer->line;
    int saved_column = lexer->column;
    
    // 获取 '{' 后面的 token（lexer_next_token 会跳过空白字符和注释）
    Token *after_brace = lexer_next_token(lexer, parser->arena);
    
    if (!after_brace) {
        // 恢复状态
        lexer->position = saved_position;
        lexer->line = saved_line;
        lexer->column = saved_column;
        return 0;
    }
    
    // 保存 lexer 在 after_brace 之后的状态（lexer_next_token 已经跳过了空白字符和注释）
    // 这些变量用于调试目的，但当前未使用
    (void)lexer; // 抑制未使用变量警告
    
    TokenType token_type = after_brace->type;
    int is_struct_init = 0;
    
    // 检查 identifier: 模式或空的 {}
    if (token_type == TOKEN_RIGHT_BRACE) {
        // 空的 {}：在表达式上下文中，可能是结构体字面量，也可能是代码块
        // 但是，如果是在比较表达式之后（如 `p1 == p2 {`），`{` 应该是代码块的开始
        // 而不是结构体字面量。为了区分，我们需要检查上下文。
        // 但是，`parser_peek_is_struct_init` 无法访问上下文信息。
        // 因此，我们采用保守策略：空的 `{}` 在表达式上下文中，优先认为是结构体字面量
        // 这样可以保持变量初始化的兼容性，但需要调用者根据上下文判断
        // 如果是在 if 条件表达式之后，调用者应该直接处理 `{` 作为代码块，而不调用此函数
        is_struct_init = 1;
    } else if (token_type == TOKEN_IDENTIFIER) {
        // 检查标识符后面是否有 ':'
        size_t saved_position2 = lexer->position;
        int saved_line2 = lexer->line;
        int saved_column2 = lexer->column;
        
        Token *after_identifier = lexer_next_token(lexer, parser->arena);
        if (after_identifier && after_identifier->type == TOKEN_COLON) {
            is_struct_init = 1;
        }
        
        // 恢复状态到标识符之前（after_brace 之后）
        lexer->position = saved_position2;
        lexer->line = saved_line2;
        lexer->column = saved_column2;
    }
    
    // 恢复 lexer 状态到 '{' 之后（原始位置）
    // 注意：这里恢复到 '{' 之后的原始位置，而不是 after_brace 之后的位置
    // 因为 parser->current_token 仍然是 '{'，我们需要确保下次调用 lexer_next_token 时
    // 能够正确返回 '{' 后面的 token
    lexer->position = saved_position;
    lexer->line = saved_line;
    lexer->column = saved_column;
    
    return is_struct_init;
}

// 从 Arena 复制字符串
static const char *arena_strdup(Arena *arena, const char *src) {
    if (arena == NULL || src == NULL) {
        return NULL;
    }
    
    size_t len = strlen(src) + 1;
    char *result = (char *)arena_alloc(arena, len);
    if (result == NULL) {
        return NULL;
    }
    
    memcpy(result, src, len);
    return result;
}

// 解析类型（支持命名类型、指针类型和数组类型）
// type = named_type | pointer_type | array_type
// named_type = ID
// pointer_type = '&' type | '*' type
// array_type = '[' type ':' expr ']'
static ASTNode *parser_parse_type(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 错误联合类型 !T
    if (parser->current_token->type == TOKEN_EXCLAMATION) {
        parser_consume(parser);
        ASTNode *payload = parser_parse_type(parser);
        if (payload == NULL) {
            return NULL;
        }
        ASTNode *node = ast_new_node(AST_TYPE_ERROR_UNION, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.type_error_union.payload_type = payload;
        return node;
    }
    
    // 检查是否是元组类型（(T1, T2, ...)）
    if (parser->current_token->type == TOKEN_LEFT_PAREN) {
        parser_consume(parser);  // 消费 '('
        
        ASTNode *first = parser_parse_type(parser);
        if (first == NULL) {
            return NULL;
        }
        
        if (parser->current_token != NULL && parser->current_token->type == TOKEN_COMMA) {
            // 元组类型：(T1, T2, ...)
            ASTNode **elements = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * 16);
            if (elements == NULL) {
                return NULL;
            }
            int cap = 16;
            int count = 0;
            elements[count++] = first;
            
            while (parser->current_token != NULL && parser->current_token->type == TOKEN_COMMA) {
                parser_consume(parser);  // 消费 ','
                ASTNode *elem = parser_parse_type(parser);
                if (elem == NULL) {
                    return NULL;
                }
                if (count >= cap) {
                    ASTNode **new_elements = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * (cap * 2));
                    if (new_elements == NULL) {
                        return NULL;
                    }
                    for (int i = 0; i < count; i++) {
                        new_elements[i] = elements[i];
                    }
                    elements = new_elements;
                    cap *= 2;
                }
                elements[count++] = elem;
            }
            
            if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
                return NULL;
            }
            
            ASTNode *tuple_type = ast_new_node(AST_TYPE_TUPLE, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (tuple_type == NULL) {
                return NULL;
            }
            tuple_type->data.type_tuple.element_types = elements;
            tuple_type->data.type_tuple.element_count = count;
            return tuple_type;
        }
        
        // 单类型括号 (T) => 等价于 T
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            return NULL;
        }
        return first;
    }
    
    // 检查是否是指针类型（&Type 或 *Type）或切片类型（&[T] / &[T: N]）
    if (parser->current_token->type == TOKEN_AMPERSAND) {
        parser_consume(parser);  // 消费 '&'
        
        // 切片类型 &[T] 或 &[T: N]：& 后紧跟 [
        if (parser->current_token != NULL && parser->current_token->type == TOKEN_LEFT_BRACKET) {
            parser_consume(parser);  // 消费 '['
            ASTNode *element_type = parser_parse_type(parser);
            if (element_type == NULL) {
                return NULL;
            }
            ASTNode *size_expr = NULL;
            if (parser->current_token != NULL && parser->current_token->type == TOKEN_COLON) {
                parser_consume(parser);  // 消费 ':'
                size_expr = parser_parse_expression(parser);
                if (size_expr == NULL) {
                    return NULL;
                }
            }
            if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
                return NULL;
            }
            ASTNode *slice_type = ast_new_node(AST_TYPE_SLICE, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (slice_type == NULL) {
                return NULL;
            }
            slice_type->data.type_slice.element_type = element_type;
            slice_type->data.type_slice.size_expr = size_expr;
            return slice_type;
        }
        
        // 普通指针类型 &Type
        ASTNode *pointed_type = parser_parse_type(parser);
        if (pointed_type == NULL) {
            return NULL;
        }
        
        // 创建指针类型节点
        ASTNode *pointer_type = ast_new_node(AST_TYPE_POINTER, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (pointer_type == NULL) {
            return NULL;
        }
        
        pointer_type->data.type_pointer.pointed_type = pointed_type;
        pointer_type->data.type_pointer.is_ffi_pointer = 0;  // 普通指针
        
        return pointer_type;
    } else if (parser->current_token->type == TOKEN_ASTERISK) {
        // FFI 指针类型 *Type（仅用于 extern 函数）
        parser_consume(parser);  // 消费 '*'
        
        // 递归解析指向的类型
        ASTNode *pointed_type = parser_parse_type(parser);
        if (pointed_type == NULL) {
            return NULL;
        }
        
        // 创建 FFI 指针类型节点
        ASTNode *pointer_type = ast_new_node(AST_TYPE_POINTER, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (pointer_type == NULL) {
            return NULL;
        }
        
        pointer_type->data.type_pointer.pointed_type = pointed_type;
        pointer_type->data.type_pointer.is_ffi_pointer = 1;  // FFI 指针
        
        return pointer_type;
    } else if (parser->current_token->type == TOKEN_LEFT_BRACKET) {
        // 数组类型 [Type: Size]
        parser_consume(parser);  // 消费 '['
        
        // 解析元素类型
        ASTNode *element_type = parser_parse_type(parser);
        if (element_type == NULL) {
            return NULL;
        }
        
        // 期望 ':'
        if (!parser_expect(parser, TOKEN_COLON)) {
            return NULL;
        }
        
        // 解析数组大小表达式（必须是编译期常量，但解析阶段先解析为表达式）
        // 注意：这里解析为表达式节点，类型检查阶段会验证是否为编译期常量
        ASTNode *size_expr = parser_parse_expression(parser);
        if (size_expr == NULL) {
            return NULL;
        }
        
        // 期望 ']'
        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
            return NULL;
        }
        
        // 创建数组类型节点
        ASTNode *array_type = ast_new_node(AST_TYPE_ARRAY, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (array_type == NULL) {
            return NULL;
        }
        
        array_type->data.type_array.element_type = element_type;
        array_type->data.type_array.size_expr = size_expr;
        
        return array_type;
    } else if (parser->current_token->type == TOKEN_UNION) {
        /* union TypeName（用于 extern union 类型，如参数/返回值）*/
        parser_consume(parser);
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            return NULL;
        }
        const char *union_type_name = arena_strdup(parser->arena, parser->current_token->value);
        if (union_type_name == NULL) return NULL;
        parser_consume(parser);
        ASTNode *type_node = ast_new_node(AST_TYPE_NAMED, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (type_node == NULL) return NULL;
        type_node->data.type_named.name = union_type_name;
        return type_node;
    } else if (parser->current_token->type == TOKEN_IDENTIFIER) {
        // 命名类型（i32, bool, void, 或结构体名称）
        ASTNode *type_node = ast_new_node(AST_TYPE_NAMED, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (type_node == NULL) {
            return NULL;
        }
        
        // 复制类型名称到 Arena
        const char *type_name = arena_strdup(parser->arena, parser->current_token->value);
        if (type_name == NULL) {
            return NULL;
        }
        
        type_node->data.type_named.name = type_name;
        
        // 消费类型标识符
        parser_consume(parser);
        
        return type_node;
    }
    
    // 无法识别的类型语法
    return NULL;
}

// 前向声明
ASTNode *parser_parse_statement(Parser *parser);
ASTNode *parser_parse_expression(Parser *parser);  // 前向声明，用于递归调用
static ASTNode *parser_parse_unary_expr(Parser *parser);
static ASTNode *parser_parse_mul_expr(Parser *parser);
static ASTNode *parser_parse_add_expr(Parser *parser);
static ASTNode *parser_parse_shift_expr(Parser *parser);
static ASTNode *parser_parse_rel_expr(Parser *parser);
static ASTNode *parser_parse_bitand_expr(Parser *parser);
static ASTNode *parser_parse_eq_expr(Parser *parser);
static ASTNode *parser_parse_and_expr(Parser *parser);
static ASTNode *parser_parse_xor_expr(Parser *parser);
static ASTNode *parser_parse_bitor_expr(Parser *parser);
static ASTNode *parser_parse_or_expr(Parser *parser);
static ASTNode *parser_parse_assign_expr(Parser *parser);

// 解析代码块（完善版本，解析语句列表）
static ASTNode *parser_parse_block(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 期望 '{'
    if (!parser_match(parser, TOKEN_LEFT_BRACE)) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 创建代码块节点
    ASTNode *block = ast_new_node(AST_BLOCK, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (block == NULL) {
        return NULL;
    }
    
    // 初始化语句列表
    ASTNode **stmts = NULL;
    int stmt_count = 0;
    int stmt_capacity = 0;
    
    // 消费 '{'
    parser_consume(parser);
    
    // 解析语句列表（while 条件不消费 token，仅 peek，以便块尾 '}' 由下方 expect 统一消费）
    while (parser->current_token != NULL && 
           parser->current_token->type != TOKEN_RIGHT_BRACE && 
           parser->current_token->type != TOKEN_EOF) {
        
        // 解析语句
        ASTNode *stmt = parser_parse_statement(parser);
        if (stmt == NULL) {
            // 解析失败：检查是否是因为遇到了右大括号（空块或块尾），不消费以便后面 expect 统一消费
            if (parser->current_token != NULL && parser->current_token->type == TOKEN_RIGHT_BRACE) {
                break;
            }
            // 检查是否是 EOF（TOKEN_EOF = 0）
            if (parser->current_token != NULL && parser->current_token->type == TOKEN_EOF) {
                // 遇到文件末尾，正常退出循环（可能是函数体不完整，但这是语法错误，会在其他地方报告）
                break;
            }
            // 否则是真正的解析错误
            // 调试输出
            if (parser->current_token != NULL) {
                fprintf(stderr, "调试: parser_parse_block 解析语句失败，当前 token type=%d\n", parser->current_token->type);
                if (parser->current_token->value) {
                    fprintf(stderr, "调试: token value=%s\n", parser->current_token->value);
                }
            } else {
                fprintf(stderr, "调试: parser_parse_block 解析语句失败，current_token 为 NULL\n");
            }
            return NULL;
        }
        
        // 扩展语句数组（使用 Arena 分配）
        if (stmt_count >= stmt_capacity) {
            int new_capacity = stmt_capacity == 0 ? 4 : stmt_capacity * 2;
            ASTNode **new_stmts = (ASTNode **)arena_alloc(
                parser->arena, 
                sizeof(ASTNode *) * new_capacity
            );
            if (new_stmts == NULL) {
                const char *filename = parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>";
                fprintf(stderr, "错误: Arena 内存不足 (%s:%d:%d): 无法分配语句数组\n", filename, line, column);
                fprintf(stderr, "提示: 请增加 ARENA_BUFFER_SIZE（当前建议至少 16MB）\n");
                return NULL;
            }
            
            // 复制旧语句
            if (stmts != NULL) {
                for (int i = 0; i < stmt_count; i++) {
                    new_stmts[i] = stmts[i];
                }
            }
            
            stmts = new_stmts;
            stmt_capacity = new_capacity;
        }
        
        stmts[stmt_count++] = stmt;
    }
    
    // 期望 '}'
    // 注意：如果当前 token 是 'else'，说明可能是 if 语句的 else 分支
    // 但 block 必须以 '}' 结束，所以这里仍然期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        // 调试输出
        if (parser->current_token != NULL) {
            if (parser->current_token->type == TOKEN_ELSE) {
                fprintf(stderr, "调试: parser_parse_block 期望 '}' 失败，当前 token 是 'else'\n");
                fprintf(stderr, "调试: lexer position=%zu, line=%d, column=%d\n", 
                        parser->lexer->position, parser->lexer->line, parser->lexer->column);
            } else if (parser->current_token->type == TOKEN_EOF) {
                fprintf(stderr, "错误: 代码块未正确关闭 (%s:%d:%d): 期望 '}' 但遇到文件末尾\n",
                        parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>",
                        parser->current_token->line, parser->current_token->column);
                fprintf(stderr, "提示: 可能是函数体缺少右大括号 '}'\n");
            } else {
                const char *filename = parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>";
                fprintf(stderr, "错误: 代码块未正确关闭 (%s:%d:%d): 期望 '}' 但遇到 token type=%d\n",
                        filename, parser->current_token->line, parser->current_token->column, parser->current_token->type);
            }
        } else {
            fprintf(stderr, "错误: 代码块未正确关闭: 期望 '}' 但 current_token 为 NULL\n");
        }
        return NULL;
    }
    
    block->data.block.stmts = stmts;
    block->data.block.stmt_count = stmt_count;
    
    return block;
}

// 解析结构体声明：struct ID { field_list }
// field_list = field { ',' field }
// field = ID ':' type
ASTNode *parser_parse_struct(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 期望 'struct'
    if (!parser_match(parser, TOKEN_STRUCT)) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 消费 'struct'
    parser_consume(parser);
    
    // 期望结构体名称
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }
    
    const char *struct_name = arena_strdup(parser->arena, parser->current_token->value);
    if (struct_name == NULL) {
        return NULL;
    }
    
    // 消费结构体名称
    parser_consume(parser);
    
    // 创建结构体声明节点
    ASTNode *struct_decl = ast_new_node(AST_STRUCT_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (struct_decl == NULL) {
        return NULL;
    }
    
    struct_decl->data.struct_decl.name = struct_name;
    struct_decl->data.struct_decl.interface_names = NULL;
    struct_decl->data.struct_decl.interface_count = 0;
    struct_decl->data.struct_decl.fields = NULL;
    struct_decl->data.struct_decl.field_count = 0;
    
    // 可选的 ': InterfaceName { , InterfaceName }'
    if (parser_match(parser, TOKEN_COLON)) {
        parser_consume(parser);
        const char **ifaces = NULL;
        int iface_capacity = 0;
        int iface_count = 0;
        while (parser_match(parser, TOKEN_IDENTIFIER)) {
            if (iface_count >= iface_capacity) {
                int new_cap = iface_capacity == 0 ? 4 : iface_capacity * 2;
                const char **new_ifaces = (const char **)arena_alloc(parser->arena, sizeof(const char *) * new_cap);
                if (!new_ifaces) return NULL;
                for (int i = 0; i < iface_count; i++) new_ifaces[i] = ifaces[i];
                ifaces = new_ifaces;
                iface_capacity = new_cap;
            }
            ifaces[iface_count] = arena_strdup(parser->arena, parser->current_token->value);
            if (!ifaces[iface_count]) return NULL;
            iface_count++;
            parser_consume(parser);
            if (!parser_match(parser, TOKEN_COMMA)) break;
            parser_consume(parser);
        }
        struct_decl->data.struct_decl.interface_names = ifaces;
        struct_decl->data.struct_decl.interface_count = iface_count;
    }
    
    // 期望 '{'
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) {
        return NULL;
    }
    
    // 解析字段列表和内部方法
    // 字段列表：field { ',' field }
    // field = ID ':' type
    // 内部方法：fn ID '(' params ')' type '{' body '}'
    ASTNode **fields = NULL;
    int field_count = 0;
    int field_capacity = 0;
    
    ASTNode **methods = NULL;
    int method_count = 0;
    int method_capacity = 0;
    
    while (parser->current_token != NULL && 
           !parser_match(parser, TOKEN_RIGHT_BRACE) && 
           !parser_match(parser, TOKEN_EOF)) {
        
        // 检查是否为内部方法定义（fn 关键字）
        if (parser_match(parser, TOKEN_FN)) {
            // 解析内部方法
            ASTNode *method = parser_parse_function(parser);
            if (method == NULL) {
                return NULL;
            }
            
            // 扩展方法数组（使用 Arena 分配）
            if (method_count >= method_capacity) {
                int new_capacity = method_capacity == 0 ? 4 : method_capacity * 2;
                ASTNode **new_methods = (ASTNode **)arena_alloc(
                    parser->arena, 
                    sizeof(ASTNode *) * new_capacity
                );
                if (new_methods == NULL) {
                    const char *filename = parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>";
                    fprintf(stderr, "错误: Arena 内存不足 (%s:%d:%d): 无法分配结构体方法数组\n", filename, method->line, method->column);
                    fprintf(stderr, "提示: 请增加 ARENA_BUFFER_SIZE（当前建议至少 16MB）\n");
                    return NULL;
                }
                
                // 复制旧方法
                if (methods != NULL) {
                    for (int i = 0; i < method_count; i++) {
                        new_methods[i] = methods[i];
                    }
                }
                
                methods = new_methods;
                method_capacity = new_capacity;
            }
            
            methods[method_count++] = method;
            
            // 方法后可选逗号
            if (parser_match(parser, TOKEN_COMMA)) {
                parser_consume(parser);
            }
            continue;
        }
        
        // 解析字段名称
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            return NULL;
        }
        
        int field_line = parser->current_token->line;
        int field_column = parser->current_token->column;
        const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
        if (field_name == NULL) {
            return NULL;
        }
        
        parser_consume(parser);
        
        // 期望 ':'
        if (!parser_expect(parser, TOKEN_COLON)) {
            return NULL;
        }
        
        // 解析字段类型
        ASTNode *field_type = parser_parse_type(parser);
        if (field_type == NULL) {
            return NULL;
        }
        
        // 创建字段节点（使用 AST_VAR_DECL，is_const = 0）
        ASTNode *field = ast_new_node(AST_VAR_DECL, field_line, field_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (field == NULL) {
            return NULL;
        }
        
        field->data.var_decl.name = field_name;
        field->data.var_decl.type = field_type;
        field->data.var_decl.init = NULL;
        field->data.var_decl.is_const = 0;
        
        // 扩展字段数组（使用 Arena 分配）
        if (field_count >= field_capacity) {
            int new_capacity = field_capacity == 0 ? 4 : field_capacity * 2;
            ASTNode **new_fields = (ASTNode **)arena_alloc(
                parser->arena, 
                sizeof(ASTNode *) * new_capacity
            );
            if (new_fields == NULL) {
                const char *filename = parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>";
                fprintf(stderr, "错误: Arena 内存不足 (%s:%d:%d): 无法分配结构体字段数组\n", filename, field_line, field_column);
                fprintf(stderr, "提示: 请增加 ARENA_BUFFER_SIZE（当前建议至少 16MB）\n");
                return NULL;
            }
            
            // 复制旧字段
            if (fields != NULL) {
                for (int i = 0; i < field_count; i++) {
                    new_fields[i] = fields[i];
                }
            }
            
            fields = new_fields;
            field_capacity = new_capacity;
        }
        
        fields[field_count++] = field;
        
        // 检查是否有逗号（可选，最后一个字段后不需要逗号）
        if (parser_match(parser, TOKEN_COMMA)) {
            parser_consume(parser);
        }
    }
    
    // 期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        return NULL;
    }
    
    struct_decl->data.struct_decl.fields = fields;
    struct_decl->data.struct_decl.field_count = field_count;
    struct_decl->data.struct_decl.methods = methods;
    struct_decl->data.struct_decl.method_count = method_count;
    
    return struct_decl;
}

// 解析联合体声明主体：当前 token 为联合体名称 ID，解析 ID { variant_list }；is_extern==1 时不解析 fn 方法
static ASTNode *parser_parse_union_body(Parser *parser, int line, int column, int is_extern) {
    if (parser == NULL || parser->current_token == NULL || !parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }
    const char *union_name = arena_strdup(parser->arena, parser->current_token->value);
    if (union_name == NULL) return NULL;
    parser_consume(parser);
    ASTNode *union_decl = ast_new_node(AST_UNION_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (union_decl == NULL) return NULL;
    union_decl->data.union_decl.name = union_name;
    union_decl->data.union_decl.is_extern = is_extern;
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) return NULL;
    ASTNode **variants = NULL;
    int variant_count = 0, variant_capacity = 0;
    ASTNode **methods = NULL;
    int method_count = 0, method_capacity = 0;
    while (parser->current_token != NULL &&
           !parser_match(parser, TOKEN_RIGHT_BRACE) && !parser_match(parser, TOKEN_EOF)) {
        if (!is_extern && parser_match(parser, TOKEN_FN)) {
            ASTNode *method = parser_parse_function(parser);
            if (method == NULL) return NULL;
            if (method_count >= method_capacity) {
                int new_cap = method_capacity == 0 ? 4 : method_capacity * 2;
                ASTNode **new_m = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_cap);
                if (!new_m) return NULL;
                for (int i = 0; i < method_count; i++) new_m[i] = methods[i];
                methods = new_m;
                method_capacity = new_cap;
            }
            methods[method_count++] = method;
            if (parser_match(parser, TOKEN_COMMA)) parser_consume(parser);
            continue;
        }
        if (!parser_match(parser, TOKEN_IDENTIFIER)) return NULL;
        int v_line = parser->current_token->line, v_column = parser->current_token->column;
        const char *variant_name = arena_strdup(parser->arena, parser->current_token->value);
        if (variant_name == NULL) return NULL;
        parser_consume(parser);
        if (!parser_expect(parser, TOKEN_COLON)) return NULL;
        ASTNode *variant_type = parser_parse_type(parser);
        if (variant_type == NULL) return NULL;
        ASTNode *variant = ast_new_node(AST_VAR_DECL, v_line, v_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (variant == NULL) return NULL;
        variant->data.var_decl.name = variant_name;
        variant->data.var_decl.type = variant_type;
        variant->data.var_decl.init = NULL;
        variant->data.var_decl.is_const = 0;
        if (variant_count >= variant_capacity) {
            int new_cap = variant_capacity == 0 ? 4 : variant_capacity * 2;
            ASTNode **new_v = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_cap);
            if (!new_v) return NULL;
            for (int i = 0; i < variant_count; i++) new_v[i] = variants[i];
            variants = new_v;
            variant_capacity = new_cap;
        }
        variants[variant_count++] = variant;
        if (parser_match(parser, TOKEN_COMMA)) parser_consume(parser);
    }
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) return NULL;
    union_decl->data.union_decl.variants = variants;
    union_decl->data.union_decl.variant_count = variant_count;
    union_decl->data.union_decl.methods = methods;
    union_decl->data.union_decl.method_count = method_count;
    return union_decl;
}

// 解析联合体声明：union ID { variant_list }
ASTNode *parser_parse_union(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL || !parser_match(parser, TOKEN_UNION)) {
        return NULL;
    }
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    parser_consume(parser);
    return parser_parse_union_body(parser, line, column, 0);
}

// 解析枚举声明：enum ID '{' variant_list '}'
// variant_list = variant { ',' variant }
// variant = ID [ '=' NUM ]
ASTNode *parser_parse_enum(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 期望 'enum'
    if (!parser_match(parser, TOKEN_ENUM)) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 消费 'enum'
    parser_consume(parser);
    
    // 期望枚举名称
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }
    
    const char *enum_name = arena_strdup(parser->arena, parser->current_token->value);
    if (enum_name == NULL) {
        return NULL;
    }
    
    // 消费枚举名称
    parser_consume(parser);
    
    // 创建枚举声明节点
    ASTNode *enum_decl = ast_new_node(AST_ENUM_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (enum_decl == NULL) {
        return NULL;
    }
    
    enum_decl->data.enum_decl.name = enum_name;
    enum_decl->data.enum_decl.variants = NULL;
    enum_decl->data.enum_decl.variant_count = 0;
    
    // 期望 '{'
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) {
        return NULL;
    }
    
    // 解析变体列表
    // 变体列表：variant { ',' variant }
    // variant = ID
    EnumVariant *variants = NULL;
    int variant_count = 0;
    int variant_capacity = 0;
    
    while (parser->current_token != NULL && 
           !parser_match(parser, TOKEN_RIGHT_BRACE) && 
           !parser_match(parser, TOKEN_EOF)) {
        
        // 解析变体名称
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            return NULL;
        }
        
        const char *variant_name = arena_strdup(parser->arena, parser->current_token->value);
        if (variant_name == NULL) {
            return NULL;
        }
        
        parser_consume(parser);
        
        // 扩展变体数组（使用 Arena 分配）
        if (variant_count >= variant_capacity) {
            int new_capacity = variant_capacity == 0 ? 4 : variant_capacity * 2;
            EnumVariant *new_variants = (EnumVariant *)arena_alloc(
                parser->arena, 
                sizeof(EnumVariant) * new_capacity
            );
            if (new_variants == NULL) {
                return NULL;
            }
            
            // 复制旧变体
            if (variants != NULL) {
                for (int i = 0; i < variant_count; i++) {
                    new_variants[i] = variants[i];
                }
            }
            
            variants = new_variants;
            variant_capacity = new_capacity;
        }
        
        // 解析可选的显式值 (= NUM)
        const char *variant_value = NULL;
        if (parser_match(parser, TOKEN_ASSIGN)) {
            parser_consume(parser);  // 消费 '='
            
            // 期望数字字面量
            if (!parser_match(parser, TOKEN_NUMBER)) {
                return NULL;
            }
            
            // 复制数字值字符串到 Arena
            variant_value = arena_strdup(parser->arena, parser->current_token->value);
            if (variant_value == NULL) {
                return NULL;
            }
            
            parser_consume(parser);  // 消费数字值
        }
        
            // 添加变体（确保数组索引有效）
            if (variant_count < variant_capacity) {
                variants[variant_count].name = variant_name;
                variants[variant_count].value = variant_value;  // NULL 表示没有显式赋值
                variant_count++;
            } else {
                fprintf(stderr, "错误: 枚举变体数量超出容量\n");
                return NULL;
            }
        
        // 检查是否有逗号（可选，最后一个变体后不需要逗号）
        if (parser_match(parser, TOKEN_COMMA)) {
            parser_consume(parser);
        }
    }
    
    // 期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        return NULL;
    }
    
    enum_decl->data.enum_decl.variants = variants;
    enum_decl->data.enum_decl.variant_count = variant_count;
    
    return enum_decl;
}

// 解析预定义错误声明：error ID ';'
static ASTNode *parser_parse_error_decl(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    if (!parser_match(parser, TOKEN_ERROR)) {
        return NULL;
    }
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    parser_consume(parser);
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }
    const char *name = arena_strdup(parser->arena, parser->current_token->value);
    if (name == NULL) {
        return NULL;
    }
    parser_consume(parser);
    if (!parser_expect(parser, TOKEN_SEMICOLON)) {
        return NULL;
    }
    ASTNode *node = ast_new_node(AST_ERROR_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (node == NULL) {
        return NULL;
    }
    node->data.error_decl.name = name;
    return node;
}

// 解析接口声明：interface ID { fn method(self: *Self,...) Ret; ... }
static ASTNode *parser_parse_interface(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) return NULL;
    if (!parser_match(parser, TOKEN_INTERFACE)) return NULL;
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    parser_consume(parser);
    if (!parser_match(parser, TOKEN_IDENTIFIER)) return NULL;
    const char *iface_name = arena_strdup(parser->arena, parser->current_token->value);
    if (!iface_name) return NULL;
    parser_consume(parser);
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) return NULL;
    ASTNode **sigs = NULL;
    int sig_count = 0;
    int sig_cap = 0;
    while (parser->current_token != NULL &&
           !parser_match(parser, TOKEN_RIGHT_BRACE) && !parser_match(parser, TOKEN_EOF)) {
        if (!parser_match(parser, TOKEN_FN)) return NULL;
        int ml = parser->current_token->line;
        int mc = parser->current_token->column;
        parser_consume(parser);
        if (!parser_match(parser, TOKEN_IDENTIFIER)) return NULL;
        const char *method_name = arena_strdup(parser->arena, parser->current_token->value);
        if (!method_name) return NULL;
        parser_consume(parser);
        if (!parser_expect(parser, TOKEN_LEFT_PAREN)) return NULL;
        ASTNode **params = NULL;
        int param_count = 0;
        int param_cap = 0;
        while (parser->current_token != NULL && !parser_match(parser, TOKEN_RIGHT_PAREN) && !parser_match(parser, TOKEN_EOF)) {
            if (!parser_match(parser, TOKEN_IDENTIFIER)) return NULL;
            const char *pname = arena_strdup(parser->arena, parser->current_token->value);
            if (!pname) return NULL;
            parser_consume(parser);
            if (!parser_expect(parser, TOKEN_COLON)) return NULL;
            ASTNode *ptype = parser_parse_type(parser);
            if (!ptype) return NULL;
            if (param_count >= param_cap) {
                int new_cap = param_cap == 0 ? 4 : param_cap * 2;
                ASTNode **new_p = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_cap);
                if (!new_p) return NULL;
                for (int i = 0; i < param_count; i++) new_p[i] = params[i];
                params = new_p;
                param_cap = new_cap;
            }
            ASTNode *pnode = ast_new_node(AST_VAR_DECL, ml, mc, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (!pnode) return NULL;
            pnode->data.var_decl.name = pname;
            pnode->data.var_decl.type = ptype;
            pnode->data.var_decl.init = NULL;
            pnode->data.var_decl.is_const = 0;
            params[param_count++] = pnode;
            if (!parser_match(parser, TOKEN_COMMA)) break;
            parser_consume(parser);
        }
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) return NULL;
        ASTNode *ret_type = parser_parse_type(parser);
        if (!ret_type) return NULL;
        if (!parser_expect(parser, TOKEN_SEMICOLON)) return NULL;
        ASTNode *sig = ast_new_node(AST_FN_DECL, ml, mc, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (!sig) return NULL;
        sig->data.fn_decl.name = method_name;
        sig->data.fn_decl.params = params;
        sig->data.fn_decl.param_count = param_count;
        sig->data.fn_decl.return_type = ret_type;
        sig->data.fn_decl.body = NULL;
        sig->data.fn_decl.is_varargs = 0;
        if (sig_count >= sig_cap) {
            int new_cap = sig_cap == 0 ? 4 : sig_cap * 2;
            ASTNode **new_sigs = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_cap);
            if (!new_sigs) return NULL;
            for (int i = 0; i < sig_count; i++) new_sigs[i] = sigs[i];
            sigs = new_sigs;
            sig_cap = new_cap;
        }
        sigs[sig_count++] = sig;
    }
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) return NULL;
    ASTNode *node = ast_new_node(AST_INTERFACE_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (!node) return NULL;
    node->data.interface_decl.name = iface_name;
    node->data.interface_decl.method_sigs = sigs;
    node->data.interface_decl.method_sig_count = sig_count;
    return node;
}

// 解析方法块：StructName { fn method(...) { ... } ... }（调用时 struct_name 与 '{' 已消费，当前为块内首 token）
static ASTNode *parser_parse_method_block(Parser *parser, const char *struct_name) {
    if (parser == NULL || parser->current_token == NULL || !struct_name) return NULL;
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    ASTNode **methods = NULL;
    int method_count = 0;
    int method_cap = 0;
    while (parser->current_token != NULL &&
           parser_match(parser, TOKEN_FN) &&
           !parser_match(parser, TOKEN_RIGHT_BRACE) && !parser_match(parser, TOKEN_EOF)) {
        ASTNode *fn = parser_parse_function(parser);
        if (!fn) return NULL;
        if (method_count >= method_cap) {
            int new_cap = method_cap == 0 ? 4 : method_cap * 2;
            ASTNode **new_m = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_cap);
            if (!new_m) return NULL;
            for (int i = 0; i < method_count; i++) new_m[i] = methods[i];
            methods = new_m;
            method_cap = new_cap;
        }
        methods[method_count++] = fn;
    }
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) return NULL;
    ASTNode *node = ast_new_node(AST_METHOD_BLOCK, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (!node) return NULL;
    node->data.method_block.struct_name = struct_name;
    node->data.method_block.methods = methods;
    node->data.method_block.method_count = method_count;
    return node;
}

// 解析函数声明：fn ID '(' [ param_list ] ')' type '{' statements '}'
// param_list = param { ',' param }
// param = ID ':' type
ASTNode *parser_parse_function(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 期望 'fn'
    if (!parser_match(parser, TOKEN_FN)) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 消费 'fn'
    parser_consume(parser);
    
    // 期望函数名称
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }
    
    const char *fn_name = arena_strdup(parser->arena, parser->current_token->value);
    if (fn_name == NULL) {
        return NULL;
    }
    
    // 消费函数名称
    parser_consume(parser);
    
    // 创建函数声明节点
    ASTNode *fn_decl = ast_new_node(AST_FN_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (fn_decl == NULL) {
        return NULL;
    }
    
    fn_decl->data.fn_decl.name = fn_name;
    fn_decl->data.fn_decl.params = NULL;
    fn_decl->data.fn_decl.param_count = 0;
    fn_decl->data.fn_decl.return_type = NULL;
    fn_decl->data.fn_decl.body = NULL;
    fn_decl->data.fn_decl.is_varargs = 0;
    
    // 期望 '('
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        return NULL;
    }
    
    // 解析参数列表（可选，支持可变参数 ...）
    ASTNode **params = NULL;
    int param_count = 0;
    int param_capacity = 0;
    int is_varargs = 0;
    
    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        // 有参数
        while (parser->current_token != NULL && 
               !parser_match(parser, TOKEN_RIGHT_PAREN) && 
               !parser_match(parser, TOKEN_EOF)) {
            
            // 检查是否为可变参数标记（...）
            if (parser_match(parser, TOKEN_ELLIPSIS)) {
                parser_consume(parser);
                is_varargs = 1;
                break;
            }
            
            // 解析参数名称
            if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                return NULL;
            }
            
            int param_line = parser->current_token->line;
            int param_column = parser->current_token->column;
            const char *param_name = arena_strdup(parser->arena, parser->current_token->value);
            if (param_name == NULL) {
                return NULL;
            }
            
            parser_consume(parser);
            
            // 期望 ':'
            if (!parser_expect(parser, TOKEN_COLON)) {
                return NULL;
            }
            
            // 解析参数类型
            ASTNode *param_type = parser_parse_type(parser);
            if (param_type == NULL) {
                return NULL;
            }
            
            // 创建参数节点（使用 AST_VAR_DECL，is_const = 0）
            ASTNode *param = ast_new_node(AST_VAR_DECL, param_line, param_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (param == NULL) {
                return NULL;
            }
            
            param->data.var_decl.name = param_name;
            param->data.var_decl.type = param_type;
            param->data.var_decl.init = NULL;
            param->data.var_decl.is_const = 0;
            
            // 扩展参数数组（使用 Arena 分配）
            if (param_count >= param_capacity) {
                int new_capacity = param_capacity == 0 ? 4 : param_capacity * 2;
                ASTNode **new_params = (ASTNode **)arena_alloc(
                    parser->arena, 
                    sizeof(ASTNode *) * new_capacity
                );
                if (new_params == NULL) {
                    const char *filename = parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>";
                    fprintf(stderr, "错误: Arena 内存不足 (%s:%d:%d): 无法分配函数参数数组\n", filename, line, column);
                    fprintf(stderr, "提示: 请增加 ARENA_BUFFER_SIZE（当前建议至少 16MB）\n");
                    return NULL;
                }
                
                // 复制旧参数
                if (params != NULL) {
                    for (int i = 0; i < param_count; i++) {
                        new_params[i] = params[i];
                    }
                }
                
                params = new_params;
                param_capacity = new_capacity;
            }
            
            params[param_count++] = param;
            
            // 检查是否有逗号或逗号后 ...
            if (parser_match(parser, TOKEN_COMMA)) {
                parser_consume(parser);
            } else if (parser_match(parser, TOKEN_ELLIPSIS)) {
                // 逗号后紧跟 ...，下次循环处理
            }
        }
    }
    
    // 期望 ')'
    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
        return NULL;
    }
    
    // 解析返回类型
    ASTNode *return_type = parser_parse_type(parser);
    if (return_type == NULL) {
        return NULL;
    }
    
    // 解析函数体（代码块）
    ASTNode *body = parser_parse_block(parser);
    if (body == NULL) {
        const char *filename = parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>";
        fprintf(stderr, "错误: 无法解析函数体 (%s:%d:%d): 函数 '%s' 的函数体解析失败\n", 
                filename, line, column, fn_name);
        fprintf(stderr, "提示: 可能是语法错误、内存不足或文件不完整\n");
        return NULL;
    }
    
    fn_decl->data.fn_decl.params = params;
    fn_decl->data.fn_decl.param_count = param_count;
    fn_decl->data.fn_decl.return_type = return_type;
    fn_decl->data.fn_decl.body = body;
    fn_decl->data.fn_decl.is_varargs = is_varargs;
    
    return fn_decl;
}

// 前向声明：解析 extern fn（extern 已消费）
static ASTNode *parser_parse_extern_function_after_extern(Parser *parser);

// 解析 extern 声明：extern 已由调用方消费，当前为 'fn' 或 'union'
// 若为 'union' 则解析 extern union；否则解析 extern fn
static ASTNode *parser_parse_extern_decl(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) return NULL;
    if (parser_match(parser, TOKEN_UNION)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        parser_consume(parser);
        return parser_parse_union_body(parser, line, column, 1);
    }
    return parser_parse_extern_function_after_extern(parser);
}

// 解析 extern 函数声明（extern 已消费，当前为 'fn'）
// 'extern' 'fn' ID '(' [ param_list ] ')' type ';'
static ASTNode *parser_parse_extern_function_after_extern(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) return NULL;
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    if (!parser_expect(parser, TOKEN_FN)) return NULL;
    if (!parser_match(parser, TOKEN_IDENTIFIER)) return NULL;
    const char *fn_name = arena_strdup(parser->arena, parser->current_token->value);
    if (fn_name == NULL) return NULL;
    parser_consume(parser);
    
    // 创建函数声明节点
    ASTNode *fn_decl = ast_new_node(AST_FN_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (fn_decl == NULL) {
        return NULL;
    }
    
    fn_decl->data.fn_decl.name = fn_name;
    fn_decl->data.fn_decl.params = NULL;
    fn_decl->data.fn_decl.param_count = 0;
    fn_decl->data.fn_decl.return_type = NULL;
    fn_decl->data.fn_decl.body = NULL;  // extern 函数没有函数体
    fn_decl->data.fn_decl.is_varargs = 0;  // 默认不是可变参数函数
    
    // 期望 '('
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        return NULL;
    }
    
    // 解析参数列表（可选，支持可变参数）
    ASTNode **params = NULL;
    int param_count = 0;
    int param_capacity = 0;
    int is_varargs = 0;
    
    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        // 有参数
        while (parser->current_token != NULL && 
               !parser_match(parser, TOKEN_RIGHT_PAREN) && 
               !parser_match(parser, TOKEN_EOF)) {
            
            // 检查是否为可变参数标记（...）
            if (parser_match(parser, TOKEN_ELLIPSIS)) {
                // 可变参数标记必须是参数列表的最后一个元素
                parser_consume(parser);  // 消费 '...'
                is_varargs = 1;
                break;  // 遇到 ... 后退出循环
            }
            
            // 解析参数名称
            if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                return NULL;
            }
            
            int param_line = parser->current_token->line;
            int param_column = parser->current_token->column;
            const char *param_name = arena_strdup(parser->arena, parser->current_token->value);
            if (param_name == NULL) {
                return NULL;
            }
            
            parser_consume(parser);
            
            // 期望 ':'
            if (!parser_expect(parser, TOKEN_COLON)) {
                return NULL;
            }
            
            // 解析参数类型
            ASTNode *param_type = parser_parse_type(parser);
            if (param_type == NULL) {
                return NULL;
            }
            
            // 创建参数节点（使用 AST_VAR_DECL，is_const = 0）
            ASTNode *param = ast_new_node(AST_VAR_DECL, param_line, param_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (param == NULL) {
                return NULL;
            }
            
            param->data.var_decl.name = param_name;
            param->data.var_decl.type = param_type;
            param->data.var_decl.init = NULL;
            param->data.var_decl.is_const = 0;
            
            // 扩展参数数组（使用 Arena 分配）
            if (param_count >= param_capacity) {
                int new_capacity = param_capacity == 0 ? 4 : param_capacity * 2;
                ASTNode **new_params = (ASTNode **)arena_alloc(
                    parser->arena, 
                    sizeof(ASTNode *) * new_capacity
                );
                if (new_params == NULL) {
                    return NULL;
                }
                
                // 复制旧参数
                if (params != NULL) {
                    for (int i = 0; i < param_count; i++) {
                        new_params[i] = params[i];
                    }
                }
                
                params = new_params;
                param_capacity = new_capacity;
            }
            
            params[param_count++] = param;
            
            // 检查是否有逗号
            if (parser_match(parser, TOKEN_COMMA)) {
                parser_consume(parser);
            } else if (parser_match(parser, TOKEN_ELLIPSIS)) {
                // 逗号后紧跟 ...，也是合法的
                // 不消费逗号，让下次循环处理 ...
            }
        }
    }
    
    // 期望 ')'
    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
        return NULL;
    }
    
    // 解析返回类型
    ASTNode *return_type = parser_parse_type(parser);
    if (return_type == NULL) {
        return NULL;
    }
    
    // extern 函数以分号结尾，没有函数体
    if (!parser_expect(parser, TOKEN_SEMICOLON)) {
        return NULL;
    }
    
    fn_decl->data.fn_decl.params = params;
    fn_decl->data.fn_decl.param_count = param_count;
    fn_decl->data.fn_decl.return_type = return_type;
    fn_decl->data.fn_decl.body = NULL;  // extern 函数没有函数体
    fn_decl->data.fn_decl.is_varargs = is_varargs;
    return fn_decl;
}

// 解析 extern 函数声明（从 'extern' 开始）
ASTNode *parser_parse_extern_function(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL || !parser_match(parser, TOKEN_EXTERN)) {
        return NULL;
    }
    parser_consume(parser);
    return parser_parse_extern_function_after_extern(parser);
}

// 解析声明（函数、结构体或变量声明）
ASTNode *parser_parse_declaration(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 根据第一个 Token 判断声明类型
    if (parser_match(parser, TOKEN_EXTERN)) {
        parser_consume(parser);
        return parser_parse_extern_decl(parser);
    } else if (parser_match(parser, TOKEN_FN)) {
        return parser_parse_function(parser);
    } else if (parser_match(parser, TOKEN_ENUM)) {
        return parser_parse_enum(parser);
    } else if (parser_match(parser, TOKEN_ERROR)) {
        return parser_parse_error_decl(parser);
    } else if (parser_match(parser, TOKEN_INTERFACE)) {
        return parser_parse_interface(parser);
    } else if (parser_match(parser, TOKEN_STRUCT)) {
        return parser_parse_struct(parser);
    } else if (parser_match(parser, TOKEN_UNION)) {
        return parser_parse_union(parser);
    } else if (parser_match(parser, TOKEN_IDENTIFIER)) {
        const char *name = arena_strdup(parser->arena, parser->current_token->value);
        if (!name) return NULL;
        parser_consume(parser);
        if (parser->current_token != NULL && parser_match(parser, TOKEN_LEFT_BRACE)) {
            parser_consume(parser);
            return parser_parse_method_block(parser, name);
        }
        const char *filename = parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>";
        fprintf(stderr, "错误: 语法分析失败 (%s:%d:%d): 顶层标识符 '%s' 后期望 '{'（方法块）\n",
                filename, parser->current_token ? parser->current_token->line : 0,
                parser->current_token ? parser->current_token->column : 0, name);
        return NULL;
    } else if (parser_match(parser, TOKEN_CONST) || parser_match(parser, TOKEN_VAR)) {
        // 变量声明
        return parser_parse_statement(parser);
    } else {
        // 无法识别的声明类型
        return NULL;
    }
}

// 解析程序（顶层声明列表）
ASTNode *parser_parse(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 创建程序节点
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    ASTNode *program = ast_new_node(AST_PROGRAM, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
    if (program == NULL) {
        return NULL;
    }
    
    // 初始化声明列表
    program->data.program.decls = NULL;
    program->data.program.decl_count = 0;
    
    // 解析顶层声明列表
    ASTNode **decls = NULL;
    int decl_count = 0;
    int decl_capacity = 0;
    
    while (parser->current_token != NULL && !parser_match(parser, TOKEN_EOF)) {
        ASTNode *decl = parser_parse_declaration(parser);
        if (decl == NULL) {
            // 解析失败：检查是否因为到达文件末尾（EOF）还是真正的错误
            // 如果当前 token 不是 EOF，说明遇到了真正的解析错误
            if (parser->current_token != NULL && !parser_match(parser, TOKEN_EOF)) {
                // 真正的解析错误：输出错误信息并返回 NULL
                const char *filename = parser->lexer->filename ? parser->lexer->filename : "<unknown>";
                const char *token_value = parser->current_token->value ? parser->current_token->value : "";
                fprintf(stderr, "错误: 语法分析失败 (%s:%d:%d): 意外的 token", 
                        filename, parser->current_token->line, parser->current_token->column);
                if (token_value[0] != '\0') {
                    fprintf(stderr, " '%s'", token_value);
                }
                fprintf(stderr, "\n");
                // 调试输出
                if (parser->current_token->type == TOKEN_ELSE) {
                    fprintf(stderr, "调试: 在 parser_parse 中遇到意外的 'else'\n");
                    fprintf(stderr, "调试: lexer position=%zu, line=%d, column=%d\n", 
                            parser->lexer->position, parser->lexer->line, parser->lexer->column);
                }
                return NULL;
            }
            // 到达文件末尾，正常退出循环
            break;
        }
        
        // 扩展声明数组（使用 Arena 分配）
        if (decl_count >= decl_capacity) {
            int new_capacity = decl_capacity == 0 ? 4 : decl_capacity * 2;
            ASTNode **new_decls = (ASTNode **)arena_alloc(
                parser->arena, 
                sizeof(ASTNode *) * new_capacity
            );
            if (new_decls == NULL) {
                return NULL;
            }
            
            // 复制旧声明
            if (decls != NULL) {
                for (int i = 0; i < decl_count; i++) {
                    new_decls[i] = decls[i];
                }
            }
            
            decls = new_decls;
            decl_capacity = new_capacity;
        }
        
        decls[decl_count++] = decl;
    }
    
    program->data.program.decls = decls;
    program->data.program.decl_count = decl_count;
    
    return program;
}

// 解析基础表达式
// 支持：数字、标识符、布尔字面量、括号表达式、函数调用、结构体字面量、字段访问
static ASTNode *parser_parse_primary_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 解析整数字面量
    if (parser->current_token->type == TOKEN_NUMBER) {
        ASTNode *node = ast_new_node(AST_NUMBER, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        // 将字符串转换为整数
        int value = atoi(parser->current_token->value);
        node->data.number.value = value;
        
        parser_consume(parser);
        return node;
    }
    
    // 解析浮点字面量
    if (parser->current_token->type == TOKEN_FLOAT) {
        ASTNode *node = ast_new_node(AST_FLOAT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        double value = strtod(parser->current_token->value, NULL);
        node->data.float_literal.value = value;
        
        parser_consume(parser);
        return node;
    }
    
    // 解析布尔字面量
    if (parser->current_token->type == TOKEN_TRUE) {
        ASTNode *node = ast_new_node(AST_BOOL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.bool_literal.value = 1;  // true
        
        parser_consume(parser);
        return node;
    }
    
    if (parser->current_token->type == TOKEN_FALSE) {
        ASTNode *node = ast_new_node(AST_BOOL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.bool_literal.value = 0;  // false
        
        parser_consume(parser);
        return node;
    }
    
    // 解析字符串插值（"text${expr}text" 或 "text${expr:spec}text"），以 TOKEN_INTERP_TEXT 或 TOKEN_INTERP_OPEN 开始
    if (parser->current_token->type == TOKEN_INTERP_TEXT || parser->current_token->type == TOKEN_INTERP_OPEN) {
        #define MAX_INTERP_SEGMENTS 64
        struct { int is_text; const char *text; ASTNode *expr; const char *format_spec; } segs[MAX_INTERP_SEGMENTS];
        int seg_count = 0;
        int saw_end = 0;
        while (seg_count < MAX_INTERP_SEGMENTS && parser->current_token != NULL) {
            if (parser->current_token->type == TOKEN_INTERP_TEXT) {
                segs[seg_count].is_text = 1;
                segs[seg_count].text = parser->current_token->value;
                segs[seg_count].expr = NULL;
                segs[seg_count].format_spec = NULL;
                seg_count++;
                parser_consume(parser);
                continue;
            }
            if (parser->current_token->type == TOKEN_INTERP_OPEN) {
                parser_consume(parser);
                ASTNode *expr = parser_parse_expression(parser);
                if (expr == NULL) {
                    return NULL;
                }
                const char *spec = NULL;
                if (parser->current_token != NULL && parser->current_token->type == TOKEN_INTERP_SPEC) {
                    spec = parser->current_token->value;
                    parser_consume(parser);
                    /* 有 :spec 时 lexer 已消费 }，无需再读 INTERP_CLOSE */
                } else {
                    if (parser->current_token == NULL || parser->current_token->type != TOKEN_INTERP_CLOSE) {
                        fprintf(stderr, "错误: 字符串插值缺少 }\n");
                        return NULL;
                    }
                    parser_consume(parser);
                }
                segs[seg_count].is_text = 0;
                segs[seg_count].text = NULL;
                segs[seg_count].expr = expr;
                segs[seg_count].format_spec = spec;
                seg_count++;
                continue;
            }
            if (parser->current_token->type == TOKEN_INTERP_END) {
                parser_consume(parser);
                saw_end = 1;
                break;
            }
            /* INTERP_SPEC 出现在循环顶：应为 ${expr} 后已消费，若未消费说明上一段是插值且缺 spec，补上 */
            if (parser->current_token->type == TOKEN_INTERP_SPEC && seg_count > 0 &&
                !segs[seg_count - 1].is_text && segs[seg_count - 1].expr != NULL && segs[seg_count - 1].format_spec == NULL) {
                segs[seg_count - 1].format_spec = parser->current_token->value;
                parser_consume(parser);
                continue;
            }
            fprintf(stderr, "错误: 字符串插值中出现意外 token (type=%d)\n", (int)parser->current_token->type);
            return NULL;
        }
        if (!saw_end || seg_count == 0 || seg_count >= MAX_INTERP_SEGMENTS) {
            if (seg_count >= MAX_INTERP_SEGMENTS) {
                fprintf(stderr, "错误: 字符串插值段数超过上限 %d\n", MAX_INTERP_SEGMENTS);
            } else if (!saw_end) {
                fprintf(stderr, "错误: 字符串插值未闭合\n");
            }
            return NULL;
        }
        ASTNode *node = ast_new_node(AST_STRING_INTERP, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.string_interp.segments = (ASTStringInterpSegment *)arena_alloc(parser->arena, (size_t)seg_count * sizeof(ASTStringInterpSegment));
        if (node->data.string_interp.segments == NULL) {
            return NULL;
        }
        for (int i = 0; i < seg_count; i++) {
            node->data.string_interp.segments[i].is_text = segs[i].is_text;
            node->data.string_interp.segments[i].text = segs[i].text;
            node->data.string_interp.segments[i].expr = segs[i].expr;
            node->data.string_interp.segments[i].format_spec = segs[i].format_spec;
        }
        node->data.string_interp.segment_count = seg_count;
        return node;
    }
    
    // 解析字符串字面量（无插值）
    if (parser->current_token->type == TOKEN_STRING) {
        ASTNode *node = ast_new_node(AST_STRING, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        // 复制字符串内容到 Arena（token 的 value 已经在 Arena 中）
        const char *str_value = parser->current_token->value;
        if (str_value == NULL) {
            return NULL;
        }
        
        // 字符串内容已经在 token 中，直接使用（token 的 value 存储在 Arena 中）
        node->data.string_literal.value = str_value;
        
        parser_consume(parser);
        return node;
    }
    
    // 解析 error.Name（错误值，用于 return error.X）
    if (parser->current_token->type == TOKEN_ERROR) {
        parser_consume(parser);
        if (!parser_match(parser, TOKEN_DOT)) {
            return NULL;
        }
        parser_consume(parser);
        if (parser->current_token == NULL || parser->current_token->type != TOKEN_IDENTIFIER) {
            return NULL;
        }
        const char *err_name = arena_strdup(parser->arena, parser->current_token->value);
        if (err_name == NULL) {
            return NULL;
        }
        ASTNode *node = ast_new_node(AST_ERROR_VALUE, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.error_value.name = err_name;
        parser_consume(parser);
        return node;
    }
    
    // 解析 match 表达式：match expr { pat => expr, ... [else => expr] }
    if (parser->current_token->type == TOKEN_MATCH) {
        parser_consume(parser);
        ASTNode *match_expr_node = ast_new_node(AST_MATCH_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (match_expr_node == NULL) return NULL;
        ASTNode *expr_val = parser_parse_expression(parser);
        if (expr_val == NULL) return NULL;
        match_expr_node->data.match_expr.expr = expr_val;
        if (!parser_expect(parser, TOKEN_LEFT_BRACE)) return NULL;
        ASTMatchArm arms[64];
        int arm_count = 0;
        while (arm_count < 64 && parser->current_token != NULL && parser->current_token->type != TOKEN_RIGHT_BRACE) {
            MatchPatternKind kind = MATCH_PAT_ELSE;
            ASTNode *lit_expr = NULL;
            const char *enum_name = NULL, *variant_name = NULL, *err_name = NULL, *bind_name = NULL;
            if (parser->current_token->type == TOKEN_ELSE) {
                kind = MATCH_PAT_ELSE;
                parser_consume(parser);
            } else if (parser->current_token->type == TOKEN_NUMBER) {
                kind = MATCH_PAT_LITERAL;
                lit_expr = ast_new_node(AST_NUMBER, parser->current_token->line, parser->current_token->column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (lit_expr) lit_expr->data.number.value = atoi(parser->current_token->value);
                parser_consume(parser);
            } else if (parser->current_token->type == TOKEN_TRUE) {
                kind = MATCH_PAT_LITERAL;
                lit_expr = ast_new_node(AST_BOOL, parser->current_token->line, parser->current_token->column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (lit_expr) lit_expr->data.bool_literal.value = 1;
                parser_consume(parser);
            } else if (parser->current_token->type == TOKEN_FALSE) {
                kind = MATCH_PAT_LITERAL;
                lit_expr = ast_new_node(AST_BOOL, parser->current_token->line, parser->current_token->column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (lit_expr) lit_expr->data.bool_literal.value = 0;
                parser_consume(parser);
            } else if (parser->current_token->type == TOKEN_ERROR) {
                kind = MATCH_PAT_ERROR;
                parser_consume(parser);
                if (!parser_match(parser, TOKEN_DOT) || parser->current_token == NULL) return NULL;
                parser_consume(parser);
                if (parser->current_token->type != TOKEN_IDENTIFIER) return NULL;
                err_name = arena_strdup(parser->arena, parser->current_token->value);
                parser_consume(parser);
            } else if (parser->current_token->type == TOKEN_DOT) {
                kind = MATCH_PAT_UNION;
                parser_consume(parser);
                if (parser->current_token == NULL || parser->current_token->type != TOKEN_IDENTIFIER) return NULL;
                variant_name = arena_strdup(parser->arena, parser->current_token->value);
                if (variant_name == NULL) return NULL;
                parser_consume(parser);
                if (!parser_expect(parser, TOKEN_LEFT_PAREN)) return NULL;
                if (parser->current_token != NULL && parser->current_token->type == TOKEN_IDENTIFIER && parser->current_token->value != NULL && strcmp(parser->current_token->value, "_") == 0) {
                    bind_name = arena_strdup(parser->arena, "_");
                    parser_consume(parser);
                } else if (parser->current_token != NULL && parser->current_token->type == TOKEN_IDENTIFIER) {
                    bind_name = arena_strdup(parser->arena, parser->current_token->value);
                    if (bind_name == NULL) return NULL;
                    parser_consume(parser);
                } else {
                    return NULL;
                }
                if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) return NULL;
            } else if (parser->current_token->type == TOKEN_IDENTIFIER) {
                const char *first = parser->current_token->value;
                parser_consume(parser);
                if (parser_match(parser, TOKEN_DOT)) {
                    kind = MATCH_PAT_ENUM;
                    enum_name = first;
                    parser_consume(parser);
                    if (parser->current_token == NULL || parser->current_token->type != TOKEN_IDENTIFIER) return NULL;
                    variant_name = arena_strdup(parser->arena, parser->current_token->value);
                    if (variant_name == NULL) return NULL;
                    parser_consume(parser);
                } else {
                    kind = MATCH_PAT_BIND;
                    bind_name = arena_strdup(parser->arena, first);
                }
            } else if (parser->current_token->type == TOKEN_IDENTIFIER && parser->current_token->value != NULL && strcmp(parser->current_token->value, "_") == 0) {
                kind = MATCH_PAT_WILDCARD;
                parser_consume(parser);
            } else {
                fprintf(stderr, "错误: match 中期望模式，得到 token type=%d\n", (int)parser->current_token->type);
                return NULL;
            }
            if (!parser_expect(parser, TOKEN_FAT_ARROW)) return NULL;
            ASTNode *result_expr = NULL;
            if (parser_match(parser, TOKEN_LEFT_BRACE)) {
                result_expr = parser_parse_block(parser);
            } else {
                result_expr = parser_parse_expression(parser);
            }
            if (result_expr == NULL) return NULL;
            arms[arm_count].kind = kind;
            arms[arm_count].result_expr = result_expr;
            if (kind == MATCH_PAT_LITERAL) arms[arm_count].data.literal.expr = lit_expr;
            else if (kind == MATCH_PAT_ENUM) { arms[arm_count].data.enum_pat.enum_name = enum_name; arms[arm_count].data.enum_pat.variant_name = variant_name; }
            else if (kind == MATCH_PAT_UNION) { arms[arm_count].data.union_pat.variant_name = variant_name; arms[arm_count].data.union_pat.var_name = bind_name; }
            else if (kind == MATCH_PAT_ERROR) arms[arm_count].data.error_pat.error_name = err_name;
            else if (kind == MATCH_PAT_BIND) arms[arm_count].data.bind.var_name = bind_name;
            arm_count++;
            if (parser->current_token != NULL && parser->current_token->type == TOKEN_COMMA) parser_consume(parser);
        }
        if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) return NULL;
        match_expr_node->data.match_expr.arms = (ASTMatchArm *)arena_alloc(parser->arena, (size_t)arm_count * sizeof(ASTMatchArm));
        if (match_expr_node->data.match_expr.arms == NULL) return NULL;
        for (int i = 0; i < arm_count; i++) {
            match_expr_node->data.match_expr.arms[i] = arms[i];
        }
        match_expr_node->data.match_expr.arm_count = arm_count;
        return match_expr_node;
    }
    
    // 解析 null 字面量（null 被解析为标识符节点，在代码生成阶段通过字符串比较识别）
    if (parser->current_token->type == TOKEN_NULL) {
        ASTNode *node = ast_new_node(AST_IDENTIFIER, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        // 复制 "null" 字符串到 Arena（代码生成器会通过字符串比较识别）
        const char *null_name = arena_strdup(parser->arena, parser->current_token->value);
        if (null_name == NULL) {
            return NULL;
        }
        node->data.identifier.name = null_name;
        
        parser_consume(parser);
        return node;
    }
    
    // 解析 @params（函数体内参数元组），支持 @params.0、@params.1 等后缀
    if (parser->current_token->type == TOKEN_AT_IDENTIFIER && parser->current_token->value != NULL &&
        strcmp(parser->current_token->value, "params") == 0) {
        ASTNode *node = ast_new_node(AST_PARAMS, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        parser_consume(parser);
        ASTNode *result = node;
        while (parser->current_token != NULL && parser_match(parser, TOKEN_DOT)) {
            parser_consume(parser);
            if (parser->current_token == NULL || (parser->current_token->type != TOKEN_IDENTIFIER && parser->current_token->type != TOKEN_NUMBER)) {
                return NULL;
            }
            const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
            if (field_name == NULL) return NULL;
            int field_line = parser->current_token->line;
            int field_column = parser->current_token->column;
            parser_consume(parser);
            ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (member_access == NULL) return NULL;
            member_access->data.member_access.object = result;
            member_access->data.member_access.field_name = field_name;
            result = member_access;
        }
        return result;
    }
    
    // 解析 @max/@min 整数极值字面量（类型由 Checker 从上下文推断）
    if (parser->current_token->type == TOKEN_AT_IDENTIFIER && parser->current_token->value != NULL &&
        strcmp(parser->current_token->value, "max") == 0) {
        ASTNode *node = ast_new_node(AST_INT_LIMIT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.int_limit.is_max = 1;
        node->data.int_limit.resolved_kind = 0;
        parser_consume(parser);
        return node;
    }
    if (parser->current_token->type == TOKEN_AT_IDENTIFIER && parser->current_token->value != NULL &&
        strcmp(parser->current_token->value, "min") == 0) {
        ASTNode *node = ast_new_node(AST_INT_LIMIT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.int_limit.is_max = 0;
        node->data.int_limit.resolved_kind = 0;
        parser_consume(parser);
        return node;
    }
    
    // 解析 @sizeof 表达式：@sizeof(Type) 或 @sizeof(expr)
    if (parser->current_token->type == TOKEN_AT_IDENTIFIER && parser->current_token->value != NULL &&
        strcmp(parser->current_token->value, "sizeof") == 0) {
        parser_consume(parser);  // 消费 'sizeof'
        
        // 期望 '('
        if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
            return NULL;
        }
        
        ASTNode *sizeof_node = ast_new_node(AST_SIZEOF, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (sizeof_node == NULL) {
            return NULL;
        }
        
        // 尝试解析类型，如果失败则解析表达式
        // 先检查是否是类型语法（基础类型或 struct 关键字）
        int is_type = 0;
        ASTNode *target = NULL;
        
        if (parser->current_token != NULL) {
            if (parser->current_token->type == TOKEN_IDENTIFIER) {
                const char *type_name = parser->current_token->value;
                // 检查是否是基础类型或 struct 关键字
                if (strcmp(type_name, "i32") == 0 || 
                    strcmp(type_name, "usize") == 0 ||
                    strcmp(type_name, "bool") == 0 || 
                    strcmp(type_name, "byte") == 0 ||
                    strcmp(type_name, "f32") == 0 ||
                    strcmp(type_name, "f64") == 0 ||
                    strcmp(type_name, "void") == 0 ||
                    strcmp(type_name, "struct") == 0) {
                    // 尝试解析类型
                    target = parser_parse_type(parser);
                    if (target != NULL) {
                        is_type = 1;
                    }
                }
            } else if (parser->current_token->type == TOKEN_AMPERSAND || 
                      parser->current_token->type == TOKEN_ASTERISK ||
                      parser->current_token->type == TOKEN_LEFT_BRACKET ||
                      parser->current_token->type == TOKEN_LEFT_PAREN) {
                // 指针类型、数组类型或元组类型开始
                target = parser_parse_type(parser);
                if (target != NULL) {
                    is_type = 1;
                }
            }
        }
        
        // 如果不是类型，则解析表达式
        if (target == NULL) {
            target = parser_parse_expression(parser);
            if (target == NULL) {
                return NULL;
            }
            is_type = 0;
        }
        
        sizeof_node->data.sizeof_expr.target = target;
        sizeof_node->data.sizeof_expr.is_type = is_type;
        
        // 期望 ')'
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            return NULL;
        }
        
        return sizeof_node;
    }
    
    // 解析 @alignof 表达式：@alignof(Type) 或 @alignof(expr)
    if (parser->current_token->type == TOKEN_AT_IDENTIFIER && parser->current_token->value != NULL &&
        strcmp(parser->current_token->value, "alignof") == 0) {
        parser_consume(parser);  // 消费 'alignof'
        
        // 期望 '('
        if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
            return NULL;
        }
        
        ASTNode *alignof_node = ast_new_node(AST_ALIGNOF, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (alignof_node == NULL) {
            return NULL;
        }
        
        // 尝试解析类型，如果失败则解析表达式
        // 先检查是否是类型语法（基础类型或 struct 关键字）
        int is_type = 0;
        ASTNode *target = NULL;
        
        if (parser->current_token != NULL) {
            if (parser->current_token->type == TOKEN_IDENTIFIER) {
                const char *type_name = parser->current_token->value;
                // 检查是否是基础类型或 struct 关键字
                if (strcmp(type_name, "i32") == 0 || 
                    strcmp(type_name, "usize") == 0 ||
                    strcmp(type_name, "bool") == 0 || 
                    strcmp(type_name, "byte") == 0 ||
                    strcmp(type_name, "f32") == 0 ||
                    strcmp(type_name, "f64") == 0 ||
                    strcmp(type_name, "void") == 0 ||
                    strcmp(type_name, "struct") == 0) {
                    // 尝试解析类型
                    target = parser_parse_type(parser);
                    if (target != NULL) {
                        is_type = 1;
                    }
                }
            } else if (parser->current_token->type == TOKEN_AMPERSAND || 
                      parser->current_token->type == TOKEN_ASTERISK ||
                      parser->current_token->type == TOKEN_LEFT_BRACKET ||
                      parser->current_token->type == TOKEN_LEFT_PAREN) {
                // 指针类型、数组类型或元组类型开始
                target = parser_parse_type(parser);
                if (target != NULL) {
                    is_type = 1;
                }
            }
        }
        
        // 如果不是类型，则解析表达式
        if (target == NULL) {
            target = parser_parse_expression(parser);
            if (target == NULL) {
                return NULL;
            }
            is_type = 0;
        }
        
        alignof_node->data.alignof_expr.target = target;
        alignof_node->data.alignof_expr.is_type = is_type;
        
        // 期望 ')'
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            return NULL;
        }
        
        return alignof_node;
    }
    
    // 解析 @len 表达式：@len(array)
    if (parser->current_token->type == TOKEN_AT_IDENTIFIER && parser->current_token->value != NULL &&
        strcmp(parser->current_token->value, "len") == 0) {
        parser_consume(parser);  // 消费 'len'
        
        // 期望 '('
        if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
            return NULL;
        }
        
        ASTNode *len_node = ast_new_node(AST_LEN, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (len_node == NULL) {
            return NULL;
        }
        
        // 解析数组表达式
        ASTNode *array_expr = parser_parse_expression(parser);
        if (array_expr == NULL) {
            return NULL;
        }
        
        len_node->data.len_expr.array = array_expr;
        
        // 期望 ')'
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            return NULL;
        }
        
        return len_node;
    }
    
    // 解析标识符（可能是普通标识符、函数调用、或结构体字面量的开始）
    // 忽略占位 _：仅允许在赋值左侧、解构中使用，生成 AST_UNDERSCORE
    if (parser->current_token->type == TOKEN_IDENTIFIER) {
        if (parser->current_token->value != NULL && strcmp(parser->current_token->value, "_") == 0) {
            ASTNode *node = ast_new_node(AST_UNDERSCORE, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (node == NULL) {
                return NULL;
            }
            parser_consume(parser);
            return node;
        }
        const char *name = arena_strdup(parser->arena, parser->current_token->value);
        if (name == NULL) {
            return NULL;
        }
        
        parser_consume(parser);  // 消费标识符
        
        // 检查下一个 token 类型
        if (parser->current_token != NULL && parser->current_token->type == TOKEN_LEFT_PAREN) {
            // 函数调用：ID '(' [ arg_list ] ')'
            ASTNode *call = ast_new_node(AST_CALL_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (call == NULL) {
                return NULL;
            }
            
            // 创建标识符节点作为被调用的函数
            ASTNode *callee = ast_new_node(AST_IDENTIFIER, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (callee == NULL) {
                return NULL;
            }
            callee->data.identifier.name = name;
            call->data.call_expr.callee = callee;
            call->data.call_expr.has_ellipsis_forward = 0;
            
            // 消费 '('
            parser_consume(parser);
            
            // 解析参数列表（可选），末尾允许 ... 表示转发可变参数
            ASTNode **args = NULL;
            int arg_count = 0;
            int arg_capacity = 0;
            
            if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
                // 有参数
                while (parser->current_token != NULL && 
                       !parser_match(parser, TOKEN_RIGHT_PAREN) && 
                       !parser_match(parser, TOKEN_EOF)) {
                    
                    // 检查是否为末尾的 ...（转发可变参数）
                    if (parser_match(parser, TOKEN_ELLIPSIS)) {
                        parser_consume(parser);
                        call->data.call_expr.has_ellipsis_forward = 1;
                        break;
                    }
                    
                    // 解析参数表达式
                    ASTNode *arg = parser_parse_expression(parser);
                    if (arg == NULL) {
                        return NULL;
                    }
                    
                    // 扩展参数数组
                    if (arg_count >= arg_capacity) {
                        int new_capacity = arg_capacity == 0 ? 4 : arg_capacity * 2;
                        ASTNode **new_args = (ASTNode **)arena_alloc(
                            parser->arena, 
                            sizeof(ASTNode *) * new_capacity
                        );
                        if (new_args == NULL) {
                            return NULL;
                        }
                        
                        // 复制旧参数
                        if (args != NULL) {
                            for (int i = 0; i < arg_count; i++) {
                                new_args[i] = args[i];
                            }
                        }
                        
                        args = new_args;
                        arg_capacity = new_capacity;
                    }
                    
                    args[arg_count++] = arg;
                    
                    // 检查是否有逗号或逗号后 ...
                    if (parser_match(parser, TOKEN_COMMA)) {
                        parser_consume(parser);
                    }
                }
            }
            
            // 期望 ')'
            if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
                return NULL;
            }
            
            call->data.call_expr.args = args;
            call->data.call_expr.arg_count = arg_count;
            
            // 字段访问和数组访问可能跟在函数调用后面（例如：f().field 或 f()[0]）
            ASTNode *result = call;
            
            // 处理字段访问和数组访问链
            while (parser->current_token != NULL) {
                if (parser_match(parser, TOKEN_DOT)) {
                    // 字段访问：.field
                    parser_consume(parser);  // 消费 '.'
                    
                    // 期望字段名称或元组下标（.0, .1, ...）
                    if (parser->current_token == NULL || (parser->current_token->type != TOKEN_IDENTIFIER && parser->current_token->type != TOKEN_NUMBER)) {
                        return NULL;
                    }
                    
                    const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
                    if (field_name == NULL) {
                        return NULL;
                    }
                    
                    int field_line = parser->current_token->line;
                    int field_column = parser->current_token->column;
                    parser_consume(parser);  // 消费字段名称
                    
                    // 创建字段访问节点
                    ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (member_access == NULL) {
                        return NULL;
                    }
                    
                    member_access->data.member_access.object = result;
                    member_access->data.member_access.field_name = field_name;
                    
                    result = member_access;
                } else if (parser_match(parser, TOKEN_LEFT_PAREN)) {
                    // 方法调用：obj.method(args)
                    parser_consume(parser);
                    ASTNode *call = ast_new_node(AST_CALL_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (call == NULL) return NULL;
                    call->data.call_expr.callee = result;
                    call->data.call_expr.has_ellipsis_forward = 0;
                    ASTNode **args = NULL;
                    int arg_count = 0;
                    int arg_cap = 0;
                    while (parser->current_token != NULL && !parser_match(parser, TOKEN_RIGHT_PAREN) && !parser_match(parser, TOKEN_EOF)) {
                        if (parser_match(parser, TOKEN_ELLIPSIS)) {
                            parser_consume(parser);
                            call->data.call_expr.has_ellipsis_forward = 1;
                            break;
                        }
                        ASTNode *arg = parser_parse_expression(parser);
                        if (arg == NULL) return NULL;
                        if (arg_count >= arg_cap) {
                            int new_cap = arg_cap == 0 ? 4 : arg_cap * 2;
                            ASTNode **new_a = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_cap);
                            if (!new_a) return NULL;
                            for (int i = 0; i < arg_count; i++) new_a[i] = args[i];
                            args = new_a;
                            arg_cap = new_cap;
                        }
                        args[arg_count++] = arg;
                        if (!parser_match(parser, TOKEN_COMMA)) break;
                        parser_consume(parser);
                    }
                    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) return NULL;
                    call->data.call_expr.args = args;
                    call->data.call_expr.arg_count = arg_count;
                    result = call;
                } else if (parser_match(parser, TOKEN_LEFT_BRACKET)) {
                    int bracket_line = parser->current_token->line;
                    int bracket_column = parser->current_token->column;
                    parser_consume(parser);  // 消费 '['
                    ASTNode *first_expr = parser_parse_expression(parser);
                    if (first_expr == NULL) return NULL;
                    if (parser->current_token != NULL && parser->current_token->type == TOKEN_COLON) {
                        parser_consume(parser);
                        ASTNode *len_expr = parser_parse_expression(parser);
                        if (len_expr == NULL) return NULL;
                        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) return NULL;
                        ASTNode *slice_expr = ast_new_node(AST_SLICE_EXPR, bracket_line, bracket_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                        if (slice_expr == NULL) return NULL;
                        slice_expr->data.slice_expr.base = result;
                        slice_expr->data.slice_expr.start_expr = first_expr;
                        slice_expr->data.slice_expr.len_expr = len_expr;
                        result = slice_expr;
                    } else {
                        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) return NULL;
                        ASTNode *array_access = ast_new_node(AST_ARRAY_ACCESS, bracket_line, bracket_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                        if (array_access == NULL) return NULL;
                        array_access->data.array_access.array = result;
                        array_access->data.array_access.index = first_expr;
                        result = array_access;
                    }
                } else {
                    break;
                }
            }
            
            return result;
        } else if (parser->current_token != NULL && parser->current_token->type == TOKEN_LEFT_BRACE) {
            // 使用 peek 机制检测是否是结构体字面量
            // 注意：在表达式解析中，如果标识符后面是 '{'，我们需要区分是结构体字面量还是代码块
            // 但是，在表达式解析的上下文中，如果 '{' 后面是 '}' 或 'identifier:' 模式，它应该是结构体字面量
            // 然而，在某些情况下（如 if 条件表达式后），'{' 应该是代码块的开始
            // 为了区分，我们检查 '{' 后面是否是空的 '}'，如果是，我们需要更仔细地判断
            // 如果是在比较表达式之后（如 `p1 == p2 {`），`{` 应该是代码块的开始
            // 但在变量初始化等上下文中，空的 `{}` 应该是结构体字面量
            // 由于 `parser_peek_is_struct_init` 无法访问上下文，我们采用保守策略：
            // 如果 '{' 后面是 '}'（空块），我们假设它是结构体字面量（因为变量初始化更常见）
            // 但如果调用者知道这是代码块上下文，应该直接处理，而不调用此函数
            int is_struct_init = parser_peek_is_struct_init(parser);
            
            // 特殊情况：如果 '{' 后面是 '}'（空块），且这是在表达式解析中，
            // 我们需要检查这是否是在比较表达式之后（如 `p1 == p2 {`）
            // 如果是，`{` 应该是代码块的开始，而不是结构体字面量
            // 但是，我们无法直接知道这是否是在比较表达式之后
            // 因此，我们采用启发式方法：如果标识符后面直接是 '{'，且 '{' 后面是 '}'（空块），
            // 我们需要更仔细地判断
            // 如果是在变量初始化等上下文中（如 `var e1: Empty = Empty{};`），空的 `{}` 应该是结构体字面量
            // 如果是在 if 条件表达式之后（如 `if p1 == p2 {`），`{` 应该是代码块的开始
            // 由于我们无法区分上下文，我们采用保守策略：假设它是结构体字面量
            // 如果这导致问题（如 if 条件表达式），我们需要在更高层处理
            // 实际上，我们已经在 `parser_parse_eq_expr` 中处理了这种情况
            // 所以这里我们保持 `is_struct_init` 的值不变
            // 但是，为了兼容变量初始化，我们需要检查：如果这是在变量初始化等上下文中，
            // 空的 `{}` 应该是结构体字面量
            // 由于我们无法区分上下文，我们采用保守策略：假设它是结构体字面量
            // 如果这导致问题（如 if 条件表达式），我们需要在更高层处理
            // 实际上，我们已经在 `parser_parse_eq_expr` 中处理了这种情况
            // 所以这里我们保持 `is_struct_init` 的值不变
            
            if (!is_struct_init) {
                // 不是结构体字面量，创建普通标识符（后面的'{'是代码块的开始，不是表达式的一部分）
                // 这种情况不应该出现在表达式解析中，但为了健壮性，我们处理它
                ASTNode *node = ast_new_node(AST_IDENTIFIER, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (node == NULL) {
                    return NULL;
                }
                
                node->data.identifier.name = name;
                
                // 字段访问可能跟在标识符后面（例如：obj.field）
                ASTNode *result = node;
                
                // 处理字段访问链（左结合：a.b.c 解析为 (a.b).c）
                while (parser->current_token != NULL && parser_match(parser, TOKEN_DOT)) {
                    parser_consume(parser);  // 消费 '.'
                    
                    // 期望字段名称或元组下标（.0, .1, ...）
                    if (parser->current_token == NULL || (parser->current_token->type != TOKEN_IDENTIFIER && parser->current_token->type != TOKEN_NUMBER)) {
                        return NULL;
                    }
                    
                    const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
                    if (field_name == NULL) {
                        return NULL;
                    }
                    
                    int field_line = parser->current_token->line;
                    int field_column = parser->current_token->column;
                    parser_consume(parser);  // 消费字段名称
                    
                    // 创建字段访问节点
                    ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (member_access == NULL) {
                        return NULL;
                    }
                    
                    member_access->data.member_access.object = result;
                    member_access->data.member_access.field_name = field_name;
                    
                    result = member_access;
                }
                
                // 方法调用：obj.method(args) 或 obj.field 后的 (args)
                while (parser->current_token != NULL && parser_match(parser, TOKEN_LEFT_PAREN)) {
                    parser_consume(parser);
                    ASTNode *call = ast_new_node(AST_CALL_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (call == NULL) return NULL;
                    call->data.call_expr.callee = result;
                    call->data.call_expr.has_ellipsis_forward = 0;
                    ASTNode **args = NULL;
                    int arg_count = 0;
                    int arg_cap = 0;
                    while (parser->current_token != NULL && !parser_match(parser, TOKEN_RIGHT_PAREN) && !parser_match(parser, TOKEN_EOF)) {
                        if (parser_match(parser, TOKEN_ELLIPSIS)) {
                            parser_consume(parser);
                            call->data.call_expr.has_ellipsis_forward = 1;
                            break;
                        }
                        ASTNode *arg = parser_parse_expression(parser);
                        if (arg == NULL) return NULL;
                        if (arg_count >= arg_cap) {
                            int new_cap = arg_cap == 0 ? 4 : arg_cap * 2;
                            ASTNode **new_a = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_cap);
                            if (!new_a) return NULL;
                            for (int i = 0; i < arg_count; i++) new_a[i] = args[i];
                            args = new_a;
                            arg_cap = new_cap;
                        }
                        args[arg_count++] = arg;
                        if (!parser_match(parser, TOKEN_COMMA)) break;
                        parser_consume(parser);
                    }
                    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) return NULL;
                    call->data.call_expr.args = args;
                    call->data.call_expr.arg_count = arg_count;
                    result = call;
                }
                
                return result;
            }
            
            // 结构体字面量：ID '{' field_init_list '}'
            // 但是，如果 '{' 后面是 '}'（空块），且这是在表达式解析中，
            // 我们需要检查这是否是在比较表达式之后（如 `p1 == p2 {`）
            // 如果是，`{` 应该是代码块的开始，而不是结构体字面量的一部分
            // 为了区分，我们检查 '{' 后面是否是 '}'（空块）
            // 如果是，我们假设这是代码块的开始，而不是结构体字面量
            // 这样可以解决 if 条件表达式的问题，但可能会破坏变量初始化的情况
            // 为了兼容，我们需要检查：如果这是在变量初始化等上下文中，
            // 空的 `{}` 应该是结构体字面量
            // 由于我们无法区分上下文，我们采用保守策略：假设它是结构体字面量
            // 如果这导致问题（如 if 条件表达式），我们需要在更高层处理
            // 实际上，我们已经在 `parser_parse_eq_expr` 中处理了这种情况
            // 所以这里我们继续解析结构体字面量
            // 但是，如果 '{' 后面是 '}'（空块），我们需要检查这是否是在比较表达式之后
            // 如果是，我们不应该解析结构体字面量，而应该返回标识符
            // 为了检查，我们 peek 一下 '{' 后面的内容
            Lexer *lexer = parser->lexer;
            size_t saved_position = lexer->position;
            int saved_line = lexer->line;
            int saved_column = lexer->column;
            
            // Peek '{' 后面的 token
            Token *after_brace = lexer_next_token(lexer, parser->arena);
            if (after_brace && after_brace->type == TOKEN_RIGHT_BRACE) {
                // '{' 后面是 '}'（空块）
                // 恢复 lexer 状态
                lexer->position = saved_position;
                lexer->line = saved_line;
                lexer->column = saved_column;
                
                // 根据上下文判断
                if (parser->context == PARSER_CONTEXT_CONDITION) {
                    // 在条件表达式上下文中，`{}` 应该是代码块的开始
                    // 返回标识符，让调用者处理 '{' 作为代码块
                    ASTNode *node = ast_new_node(AST_IDENTIFIER, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (node == NULL) {
                        return NULL;
                    }
                    
                    node->data.identifier.name = name;
                    return node;
                }
                // 在变量初始化上下文或普通上下文中，`{}` 应该是结构体字面量
                // 继续解析结构体字面量
            }
            
            // 恢复 lexer 状态
            lexer->position = saved_position;
            lexer->line = saved_line;
            lexer->column = saved_column;
            
            // 继续解析结构体字面量
            ASTNode *struct_init = ast_new_node(AST_STRUCT_INIT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (struct_init == NULL) {
                return NULL;
            }
            
            struct_init->data.struct_init.struct_name = name;
            
            // 消费 '{'
            parser_consume(parser);
            
            // 解析字段初始化列表
            const char **field_names = NULL;
            ASTNode **field_values = NULL;
            int field_count = 0;
            int field_capacity = 0;
            
            if (!parser_match(parser, TOKEN_RIGHT_BRACE)) {
                // 有字段初始化
                while (parser->current_token != NULL && 
                       !parser_match(parser, TOKEN_RIGHT_BRACE) && 
                       !parser_match(parser, TOKEN_EOF)) {
                    
                    // 解析字段名称
                    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                        return NULL;
                    }
                    
                    const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
                    if (field_name == NULL) {
                        return NULL;
                    }
                    
                    parser_consume(parser);  // 消费字段名称
                    
                    // 期望 ':'
                    if (!parser_expect(parser, TOKEN_COLON)) {
                        return NULL;
                    }
                    
                    // 解析字段值表达式
                    ASTNode *field_value = parser_parse_expression(parser);
                    if (field_value == NULL) {
                        return NULL;
                    }
                    
                    // 扩展字段数组
                    if (field_count >= field_capacity) {
                        int new_capacity = field_capacity == 0 ? 4 : field_capacity * 2;
                        const char **new_field_names = (const char **)arena_alloc(
                            parser->arena, 
                            sizeof(const char *) * new_capacity
                        );
                        ASTNode **new_field_values = (ASTNode **)arena_alloc(
                            parser->arena, 
                            sizeof(ASTNode *) * new_capacity
                        );
                        if (new_field_names == NULL || new_field_values == NULL) {
                            return NULL;
                        }
                        
                        // 复制旧字段
                        if (field_names != NULL && field_values != NULL) {
                            for (int i = 0; i < field_count; i++) {
                                new_field_names[i] = field_names[i];
                                new_field_values[i] = field_values[i];
                            }
                        }
                        
                        field_names = new_field_names;
                        field_values = new_field_values;
                        field_capacity = new_capacity;
                    }
                    
                    field_names[field_count] = field_name;
                    field_values[field_count] = field_value;
                    field_count++;
                    
                    // 检查是否有逗号
                    if (parser_match(parser, TOKEN_COMMA)) {
                        parser_consume(parser);
                    }
                }
            }
            
            // 期望 '}'
            if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
                return NULL;
            }
            
            struct_init->data.struct_init.field_names = field_names;
            struct_init->data.struct_init.field_values = field_values;
            struct_init->data.struct_init.field_count = field_count;
            
            // 字段访问可能跟在结构体字面量后面（例如：Point{x:1,y:2}.x）
            ASTNode *result = struct_init;
            
            // 处理字段访问链
            while (parser->current_token != NULL && parser_match(parser, TOKEN_DOT)) {
                parser_consume(parser);  // 消费 '.'
                
                // 期望字段名称
                if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                    return NULL;
                }
                
                const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
                if (field_name == NULL) {
                    return NULL;
                }
                
                int field_line = parser->current_token->line;
                int field_column = parser->current_token->column;
                parser_consume(parser);  // 消费字段名称
                
                // 创建字段访问节点
                ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (member_access == NULL) {
                    return NULL;
                }
                
                member_access->data.member_access.object = result;
                member_access->data.member_access.field_name = field_name;
                
                result = member_access;
            }
            
            return result;
        } else {
            // 普通标识符
            ASTNode *node = ast_new_node(AST_IDENTIFIER, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (node == NULL) {
                return NULL;
            }
            
            node->data.identifier.name = name;
            
            // 字段访问和数组访问可能跟在标识符后面（例如：obj.field 或 arr[0]）
            ASTNode *result = node;
            
            // 处理字段访问和数组访问链（左结合：a.b.c 解析为 (a.b).c，arr[0][1] 解析为 (arr[0])[1]）
            while (parser->current_token != NULL) {
                if (parser_match(parser, TOKEN_DOT)) {
                    // 字段访问：.field
                    parser_consume(parser);  // 消费 '.'
                    
                    // 期望字段名称或元组下标（.0, .1, ...）
                    if (parser->current_token == NULL || (parser->current_token->type != TOKEN_IDENTIFIER && parser->current_token->type != TOKEN_NUMBER)) {
                        return NULL;
                    }
                    
                    const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
                    if (field_name == NULL) {
                        return NULL;
                    }
                    
                    int field_line = parser->current_token->line;
                    int field_column = parser->current_token->column;
                    parser_consume(parser);  // 消费字段名称
                    
                    // 创建字段访问节点
                    ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (member_access == NULL) {
                        return NULL;
                    }
                    
                    member_access->data.member_access.object = result;
                    member_access->data.member_access.field_name = field_name;
                    
                    result = member_access;
                } else if (parser_match(parser, TOKEN_LEFT_PAREN)) {
                    parser_consume(parser);
                    ASTNode *call = ast_new_node(AST_CALL_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (call == NULL) return NULL;
                    call->data.call_expr.callee = result;
                    call->data.call_expr.has_ellipsis_forward = 0;
                    ASTNode **args = NULL;
                    int arg_count = 0;
                    int arg_cap = 0;
                    while (parser->current_token != NULL && !parser_match(parser, TOKEN_RIGHT_PAREN) && !parser_match(parser, TOKEN_EOF)) {
                        if (parser_match(parser, TOKEN_ELLIPSIS)) {
                            parser_consume(parser);
                            call->data.call_expr.has_ellipsis_forward = 1;
                            break;
                        }
                        ASTNode *arg = parser_parse_expression(parser);
                        if (arg == NULL) return NULL;
                        if (arg_count >= arg_cap) {
                            int new_cap = arg_cap == 0 ? 4 : arg_cap * 2;
                            ASTNode **new_a = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_cap);
                            if (!new_a) return NULL;
                            for (int i = 0; i < arg_count; i++) new_a[i] = args[i];
                            args = new_a;
                            arg_cap = new_cap;
                        }
                        args[arg_count++] = arg;
                        if (!parser_match(parser, TOKEN_COMMA)) break;
                        parser_consume(parser);
                    }
                    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) return NULL;
                    call->data.call_expr.args = args;
                    call->data.call_expr.arg_count = arg_count;
                    result = call;
                } else if (parser_match(parser, TOKEN_LEFT_BRACKET)) {
                    int bracket_line = parser->current_token->line;
                    int bracket_column = parser->current_token->column;
                    parser_consume(parser);
                    ASTNode *first_expr = parser_parse_expression(parser);
                    if (first_expr == NULL) return NULL;
                    if (parser->current_token != NULL && parser->current_token->type == TOKEN_COLON) {
                        parser_consume(parser);
                        ASTNode *len_expr = parser_parse_expression(parser);
                        if (len_expr == NULL) return NULL;
                        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) return NULL;
                        ASTNode *slice_expr = ast_new_node(AST_SLICE_EXPR, bracket_line, bracket_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                        if (slice_expr == NULL) return NULL;
                        slice_expr->data.slice_expr.base = result;
                        slice_expr->data.slice_expr.start_expr = first_expr;
                        slice_expr->data.slice_expr.len_expr = len_expr;
                        result = slice_expr;
                    } else {
                        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) return NULL;
                        ASTNode *array_access = ast_new_node(AST_ARRAY_ACCESS, bracket_line, bracket_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                        if (array_access == NULL) return NULL;
                        array_access->data.array_access.array = result;
                        array_access->data.array_access.index = first_expr;
                        result = array_access;
                    }
                } else {
                    break;
                }
            }
            
            return result;
        }
    }
    
    // 解析数组字面量：[expr1, expr2, ..., exprN]、[value: N] 或 []
    if (parser->current_token->type == TOKEN_LEFT_BRACKET) {
        int array_line = parser->current_token->line;
        int array_column = parser->current_token->column;
        parser_consume(parser);  // 消费 '['
        
        // 创建数组字面量节点
        ASTNode *array_literal = ast_new_node(AST_ARRAY_LITERAL, array_line, array_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (array_literal == NULL) {
            return NULL;
        }
        
        // 检查是否为空数组
        if (parser_match(parser, TOKEN_RIGHT_BRACKET)) {
            parser_consume(parser);  // 消费 ']'
            array_literal->data.array_literal.elements = NULL;
            array_literal->data.array_literal.element_count = 0;
            array_literal->data.array_literal.repeat_count_expr = NULL;
        } else {
            // 解析第一个表达式（可能是列表的第一个元素，或 [value: N] 的 value）
            ASTNode *first = parser_parse_expression(parser);
            if (first == NULL) {
                return NULL;
            }
            // 检查是否为重复形式 [value: N]（与数组类型 [T: N] 一致）
            if (parser->current_token != NULL && parser->current_token->type == TOKEN_COLON) {
                parser_consume(parser);  // 消费 ':'
                ASTNode *count_expr = parser_parse_expression(parser);
                if (count_expr == NULL) {
                    return NULL;
                }
                if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
                    return NULL;
                }
                ASTNode **elements = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *));
                if (elements == NULL) {
                    return NULL;
                }
                elements[0] = first;
                array_literal->data.array_literal.elements = elements;
                array_literal->data.array_literal.element_count = 1;
                array_literal->data.array_literal.repeat_count_expr = count_expr;
            } else {
                // 列表形式：已有 first，继续解析剩余元素
                ASTNode **elements = NULL;
                int element_count = 0;
                int element_capacity = 0;
                if (element_count >= element_capacity) {
                    int new_capacity = element_capacity == 0 ? 4 : element_capacity * 2;
                    ASTNode **new_elements = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_capacity);
                    if (new_elements == NULL) {
                        return NULL;
                    }
                    if (elements != NULL) {
                        for (int i = 0; i < element_count; i++) {
                            new_elements[i] = elements[i];
                        }
                    }
                    elements = new_elements;
                    element_capacity = new_capacity;
                }
                elements[element_count++] = first;
                while (parser->current_token != NULL &&
                       !parser_match(parser, TOKEN_RIGHT_BRACKET) &&
                       !parser_match(parser, TOKEN_EOF)) {
                    if (parser_match(parser, TOKEN_COMMA)) {
                        parser_consume(parser);
                    }
                    /* 尾随逗号：消费逗号后若已是 ] 则不再解析元素 */
                    if (parser->current_token != NULL && parser_match(parser, TOKEN_RIGHT_BRACKET)) {
                        break;
                    }
                    ASTNode *element = parser_parse_expression(parser);
                    if (element == NULL) {
                        return NULL;
                    }
                    if (element_count >= element_capacity) {
                        int new_capacity = element_capacity == 0 ? 4 : element_capacity * 2;
                        ASTNode **new_elements = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * new_capacity);
                        if (new_elements == NULL) {
                            return NULL;
                        }
                        for (int i = 0; i < element_count; i++) {
                            new_elements[i] = elements[i];
                        }
                        elements = new_elements;
                        element_capacity = new_capacity;
                    }
                    elements[element_count++] = element;
                }
                if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
                    return NULL;
                }
                array_literal->data.array_literal.elements = elements;
                array_literal->data.array_literal.element_count = element_count;
                array_literal->data.array_literal.repeat_count_expr = NULL;
            }
        }
        
        // 字段访问和数组访问可能跟在数组字面量后面（例如：[1,2,3][0]）
        ASTNode *result = array_literal;
        
        // 处理字段访问和数组访问链
        while (parser->current_token != NULL) {
            if (parser_match(parser, TOKEN_DOT)) {
                // 字段访问：.field 或元组下标 .0/.1
                parser_consume(parser);  // 消费 '.'
                
                // 期望字段名称或元组下标（.0, .1, ...）
                if (parser->current_token == NULL || (parser->current_token->type != TOKEN_IDENTIFIER && parser->current_token->type != TOKEN_NUMBER)) {
                    return NULL;
                }
                
                const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
                if (field_name == NULL) {
                    return NULL;
                }
                
                int field_line = parser->current_token->line;
                int field_column = parser->current_token->column;
                parser_consume(parser);  // 消费字段名称或元组下标
                
                // 创建字段访问节点
                ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (member_access == NULL) {
                    return NULL;
                }
                
                member_access->data.member_access.object = result;
                member_access->data.member_access.field_name = field_name;
                
                result = member_access;
            } else if (parser_match(parser, TOKEN_LEFT_BRACKET)) {
                int bracket_line = parser->current_token->line;
                int bracket_column = parser->current_token->column;
                parser_consume(parser);
                ASTNode *first_expr = parser_parse_expression(parser);
                if (first_expr == NULL) return NULL;
                if (parser->current_token != NULL && parser->current_token->type == TOKEN_COLON) {
                    parser_consume(parser);
                    ASTNode *len_expr = parser_parse_expression(parser);
                    if (len_expr == NULL) return NULL;
                    if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) return NULL;
                    ASTNode *slice_expr = ast_new_node(AST_SLICE_EXPR, bracket_line, bracket_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (slice_expr == NULL) return NULL;
                    slice_expr->data.slice_expr.base = result;
                    slice_expr->data.slice_expr.start_expr = first_expr;
                    slice_expr->data.slice_expr.len_expr = len_expr;
                    result = slice_expr;
                } else {
                    if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) return NULL;
                    ASTNode *array_access = ast_new_node(AST_ARRAY_ACCESS, bracket_line, bracket_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (array_access == NULL) return NULL;
                    array_access->data.array_access.array = result;
                    array_access->data.array_access.index = first_expr;
                    result = array_access;
                }
            } else {
                // 既不是字段访问也不是数组访问，退出循环
                break;
            }
        }
        
        return result;
    }
    
    // 解析括号表达式或元组字面量
    if (parser->current_token->type == TOKEN_LEFT_PAREN) {
        int paren_line = parser->current_token->line;
        int paren_column = parser->current_token->column;
        parser_consume(parser);  // 消费 '('
        
        ASTNode *first = parser_parse_expression(parser);
        if (first == NULL) {
            return NULL;
        }
        
        ASTNode *result;
        if (parser->current_token != NULL && parser->current_token->type == TOKEN_COMMA) {
            // 元组字面量：(expr1, expr2, ...)
            ASTNode **elements = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * 16);
            if (elements == NULL) {
                return NULL;
            }
            int cap = 16;
            int count = 0;
            elements[count++] = first;
            
            while (parser->current_token != NULL && parser->current_token->type == TOKEN_COMMA) {
                parser_consume(parser);  // 消费 ','
                ASTNode *elem = parser_parse_expression(parser);
                if (elem == NULL) {
                    return NULL;
                }
                if (count >= cap) {
                    ASTNode **new_elements = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *) * (cap * 2));
                    if (new_elements == NULL) {
                        return NULL;
                    }
                    for (int i = 0; i < count; i++) {
                        new_elements[i] = elements[i];
                    }
                    elements = new_elements;
                    cap *= 2;
                }
                elements[count++] = elem;
            }
            
            if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
                return NULL;
            }
            
            ASTNode *tuple_lit = ast_new_node(AST_TUPLE_LITERAL, paren_line, paren_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (tuple_lit == NULL) {
                return NULL;
            }
            tuple_lit->data.tuple_literal.elements = elements;
            tuple_lit->data.tuple_literal.element_count = count;
            
            result = tuple_lit;
            goto post_paren_suffix;
        }
        
        // 单表达式括号 (expr) => expr
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            return NULL;
        }
        
        result = first;
post_paren_suffix:
        
        // 处理字段访问和数组访问链
        while (parser->current_token != NULL) {
            if (parser_match(parser, TOKEN_DOT)) {
                // 字段访问：.field
                parser_consume(parser);  // 消费 '.'
                
                // 期望字段名称或元组下标（.0, .1, ...）
                if (parser->current_token == NULL || (parser->current_token->type != TOKEN_IDENTIFIER && parser->current_token->type != TOKEN_NUMBER)) {
                    return NULL;
                }
                
                const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
                if (field_name == NULL) {
                    return NULL;
                }
                
                int field_line = parser->current_token->line;
                int field_column = parser->current_token->column;
                parser_consume(parser);  // 消费字段名称或元组下标
                
                // 创建字段访问节点
                ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (member_access == NULL) {
                    return NULL;
                }
                
                member_access->data.member_access.object = result;
                member_access->data.member_access.field_name = field_name;
                
                result = member_access;
            } else if (parser_match(parser, TOKEN_LEFT_BRACKET)) {
                int bracket_line = parser->current_token->line;
                int bracket_column = parser->current_token->column;
                parser_consume(parser);
                ASTNode *first_expr = parser_parse_expression(parser);
                if (first_expr == NULL) return NULL;
                if (parser->current_token != NULL && parser->current_token->type == TOKEN_COLON) {
                    parser_consume(parser);
                    ASTNode *len_expr = parser_parse_expression(parser);
                    if (len_expr == NULL) return NULL;
                    if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) return NULL;
                    ASTNode *slice_expr = ast_new_node(AST_SLICE_EXPR, bracket_line, bracket_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (slice_expr == NULL) return NULL;
                    slice_expr->data.slice_expr.base = result;
                    slice_expr->data.slice_expr.start_expr = first_expr;
                    slice_expr->data.slice_expr.len_expr = len_expr;
                    result = slice_expr;
                } else {
                    if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) return NULL;
                    ASTNode *array_access = ast_new_node(AST_ARRAY_ACCESS, bracket_line, bracket_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                    if (array_access == NULL) return NULL;
                    array_access->data.array_access.array = result;
                    array_access->data.array_access.index = first_expr;
                    result = array_access;
                }
            } else {
                // 既不是字段访问也不是数组访问，退出循环
                break;
            }
        }
        
        return result;
    }
    
    // 无法识别的基础表达式
    return NULL;
}

// 解析一元表达式（!, -, &, *, try，右结合）
// unary_expr = ('!' | '-' | '&' | '*' | 'try') unary_expr | primary_expr
static ASTNode *parser_parse_unary_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // try expr（错误传播）
    if (parser_match(parser, TOKEN_TRY)) {
        parser_consume(parser);
        ASTNode *operand = parser_parse_unary_expr(parser);
        if (operand == NULL) {
            return NULL;
        }
        ASTNode *node = ast_new_node(AST_TRY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.try_expr.operand = operand;
        return node;
    }
    
    // 检查一元运算符（!, -, &, *）
    if (parser_match(parser, TOKEN_EXCLAMATION) || 
        parser_match(parser, TOKEN_MINUS) ||
        parser_match(parser, TOKEN_TILDE) ||
        parser_match(parser, TOKEN_AMPERSAND) ||
        parser_match(parser, TOKEN_ASTERISK)) {
        TokenType op = parser->current_token->type;
        parser_consume(parser);  // 消费运算符
        
        // 递归解析一元表达式（右结合）
        ASTNode *operand = parser_parse_unary_expr(parser);
        if (operand == NULL) {
            return NULL;
        }
        
        // 创建一元表达式节点
        ASTNode *node = ast_new_node(AST_UNARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.unary_expr.op = op;
        node->data.unary_expr.operand = operand;
        
        return node;
    }
    
    // 不是一元运算符，解析基础表达式
    return parser_parse_primary_expr(parser);
}

// 解析类型转换表达式（右结合），支持后缀 catch
// cast_expr = unary_expr [ 'as' type ] { 'catch' [ '|' ID '|' ] '{' statements '}' }
static ASTNode *parser_parse_cast_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 解析左操作数（一元表达式）
    ASTNode *expr = parser_parse_unary_expr(parser);
    if (expr == NULL) {
        return NULL;
    }
    
    // 检查是否有 'as' 或 'as!' 关键字（类型转换）
    if (parser->current_token != NULL && (parser->current_token->type == TOKEN_AS || parser->current_token->type == TOKEN_AS_BANG)) {
        int is_force_cast = (parser->current_token->type == TOKEN_AS_BANG);
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        parser_consume(parser);  // 消费 'as' 或 'as!'
        
        // 解析目标类型
        ASTNode *target_type = parser_parse_type(parser);
        if (target_type == NULL) {
            return NULL;
        }
        
        // 创建类型转换节点
        ASTNode *node = ast_new_node(AST_CAST_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.cast_expr.expr = expr;
        node->data.cast_expr.target_type = target_type;
        node->data.cast_expr.is_force_cast = is_force_cast;
        
        expr = node;
    }
    
    // 后缀 catch：expr catch [ |err| ] { stmts }（可多个，左结合）
    while (parser->current_token != NULL && parser_match(parser, TOKEN_CATCH)) {
        int catch_line = parser->current_token->line;
        int catch_column = parser->current_token->column;
        parser_consume(parser);
        const char *err_name = NULL;
        if (parser->current_token != NULL && parser_match(parser, TOKEN_PIPE)) {
            parser_consume(parser);
            if (parser->current_token == NULL || parser->current_token->type != TOKEN_IDENTIFIER) {
                return NULL;
            }
            err_name = arena_strdup(parser->arena, parser->current_token->value);
            if (err_name == NULL) {
                return NULL;
            }
            parser_consume(parser);
            if (!parser_expect(parser, TOKEN_PIPE)) {
                return NULL;
            }
        }
        // parser_parse_block 会消费 '{' 并解析到 '}'
        ASTNode *catch_block = parser_parse_block(parser);
        if (catch_block == NULL) {
            return NULL;
        }
        ASTNode *catch_node = ast_new_node(AST_CATCH_EXPR, catch_line, catch_column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (catch_node == NULL) {
            return NULL;
        }
        catch_node->data.catch_expr.operand = expr;
        catch_node->data.catch_expr.err_name = err_name;
        catch_node->data.catch_expr.catch_block = catch_block;
        expr = catch_node;
    }
    
    return expr;
}

// 解析乘除模表达式（左结合）
// mul_expr = cast_expr { ('*' | '/' | '%') cast_expr }
static ASTNode *parser_parse_mul_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 解析左操作数（类型转换表达式）
    ASTNode *left = parser_parse_cast_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    
    // 解析连续的乘除模运算符（左结合），含饱和乘法 *|、包装乘法 *%
    while (parser->current_token != NULL && (
        parser_match(parser, TOKEN_ASTERISK) ||
        parser_match(parser, TOKEN_SLASH) ||
        parser_match(parser, TOKEN_PERCENT) ||
        parser_match(parser, TOKEN_ASTERISK_PIPE) ||
        parser_match(parser, TOKEN_ASTERISK_PERCENT)
    )) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数（类型转换表达式）
        ASTNode *right = parser_parse_cast_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        
        left = node;  // 左结合：继续以当前节点作为左操作数
    }
    
    return left;
}

// 解析加减表达式（左结合）
// add_expr = mul_expr { ('+' | '-') mul_expr }
static ASTNode *parser_parse_add_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 解析左操作数
    ASTNode *left = parser_parse_mul_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    
    // 解析连续的加减运算符（左结合），含饱和 +|/-|、包装 +%/-% 
    while (parser->current_token != NULL && (
        parser_match(parser, TOKEN_PLUS) ||
        parser_match(parser, TOKEN_MINUS) ||
        parser_match(parser, TOKEN_PLUS_PIPE) ||
        parser_match(parser, TOKEN_MINUS_PIPE) ||
        parser_match(parser, TOKEN_PLUS_PERCENT) ||
        parser_match(parser, TOKEN_MINUS_PERCENT)
    )) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        ASTNode *right = parser_parse_mul_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        
        left = node;  // 左结合：继续以当前节点作为左操作数
    }
    
    return left;
}

// 解析位移表达式（左结合）
// shift_expr = add_expr { ('<<' | '>>') add_expr }
static ASTNode *parser_parse_shift_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    ASTNode *left = parser_parse_add_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    
    while (parser->current_token != NULL && (
        parser_match(parser, TOKEN_LSHIFT) ||
        parser_match(parser, TOKEN_RSHIFT)
    )) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);
        ASTNode *right = parser_parse_add_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        left = node;
    }
    return left;
}

// 解析比较表达式（左结合）
// rel_expr = shift_expr { ('<' | '>' | '<=' | '>=') shift_expr }
static ASTNode *parser_parse_rel_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 解析左操作数
    ASTNode *left = parser_parse_shift_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    
    // 解析连续的比较运算符（左结合）
    while (parser->current_token != NULL && (
        parser_match(parser, TOKEN_LESS) ||
        parser_match(parser, TOKEN_GREATER) ||
        parser_match(parser, TOKEN_LESS_EQUAL) ||
        parser_match(parser, TOKEN_GREATER_EQUAL)
    )) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        ASTNode *right = parser_parse_shift_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        
        left = node;  // 左结合：继续以当前节点作为左操作数
    }
    
    return left;
}

// 解析按位与表达式（左结合）
// bitand_expr = eq_expr { '&' eq_expr }
static ASTNode *parser_parse_bitand_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    ASTNode *left = parser_parse_eq_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    while (parser->current_token != NULL && parser_match(parser, TOKEN_AMPERSAND)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);
        ASTNode *right = parser_parse_eq_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        left = node;
    }
    return left;
}

// 解析相等性表达式（左结合）
// eq_expr = rel_expr { ('==' | '!=') rel_expr }
static ASTNode *parser_parse_eq_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 解析左操作数
    ASTNode *left = parser_parse_rel_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    
    // 解析连续的相等性运算符（左结合）
    while (parser->current_token != NULL && (
        parser_match(parser, TOKEN_EQUAL) ||
        parser_match(parser, TOKEN_NOT_EQUAL)
    )) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        ASTNode *right = parser_parse_rel_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        
        // 特殊情况：如果右操作数是结构体初始化，且当前 token 是 '{'，且 '{' 后面是 '}'（空块），
        // 这可能是代码块的开始（如 `if p1 == p2 {`），而不是结构体字面量的一部分
        // 为了区分，我们检查当前 token 是否是 '{'
        // 如果是，我们 peek 一下 '{' 后面的内容，如果是 '}'（空块），我们假设这是代码块的开始
        // 在这种情况下，我们需要回退：如果 right 是结构体初始化，我们需要将其替换为标识符
        if (parser->current_token != NULL && 
            parser->current_token->type == TOKEN_LEFT_BRACE) {
            // 调试输出
            fprintf(stderr, "调试: parser_parse_eq_expr 检测到 '{'，right type=%d\n", right->type);
            
            // 保存 lexer 状态
            Lexer *lexer = parser->lexer;
            size_t saved_position = lexer->position;
            int saved_line = lexer->line;
            int saved_column = lexer->column;
            
            // Peek '{' 后面的 token
            Token *after_brace = lexer_next_token(lexer, parser->arena);
            if (after_brace && after_brace->type == TOKEN_RIGHT_BRACE) {
                // '{' 后面是 '}'（空块），这可能是代码块的开始
                // 恢复 lexer 状态
                lexer->position = saved_position;
                lexer->line = saved_line;
                lexer->column = saved_column;
                
                fprintf(stderr, "调试: parser_parse_eq_expr 检测到空块，right type=%d\n", right->type);
                
                // 如果 right 是结构体初始化，我们需要将其替换为标识符
                // 因为 '{' 应该是代码块的开始，而不是结构体字面量的一部分
                if (right->type == AST_STRUCT_INIT) {
                    // 获取结构体名称
                    const char *struct_name = right->data.struct_init.struct_name;
                    if (struct_name) {
                        fprintf(stderr, "调试: 将结构体初始化替换为标识符 '%s'\n", struct_name);
                        // 创建标识符节点
                        ASTNode *identifier = ast_new_node(AST_IDENTIFIER, right->line, right->column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                        if (identifier != NULL) {
                            identifier->data.identifier.name = struct_name;
                            right = identifier;
                        }
                    }
                }
                
                // 停止表达式解析，返回完整的比较表达式（不包含 '{'）
                // 调用者（如 if 语句解析）会处理 '{' 作为代码块
                ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (node == NULL) {
                    return NULL;
                }
                
                node->data.binary_expr.left = left;
                node->data.binary_expr.op = op;
                node->data.binary_expr.right = right;
                
                return node;
            }
            
            // 恢复 lexer 状态
            lexer->position = saved_position;
            lexer->line = saved_line;
            lexer->column = saved_column;
        }
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        
        left = node;  // 左结合：继续以当前节点作为左操作数
    }
    
    return left;
}

// 解析按位异或表达式（左结合）
// xor_expr = and_expr { '^' and_expr }
static ASTNode *parser_parse_xor_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    ASTNode *left = parser_parse_and_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    while (parser->current_token != NULL && parser_match(parser, TOKEN_CARET)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);
        ASTNode *right = parser_parse_and_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        left = node;
    }
    return left;
}

// 解析按位或表达式（左结合）
// bitor_expr = xor_expr { '|' xor_expr }
static ASTNode *parser_parse_bitor_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    ASTNode *left = parser_parse_xor_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    while (parser->current_token != NULL && parser_match(parser, TOKEN_PIPE)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);
        ASTNode *right = parser_parse_xor_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        left = node;
    }
    return left;
}

// 解析逻辑与表达式（左结合）
// and_expr = bitand_expr { '&&' bitand_expr }
static ASTNode *parser_parse_and_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 解析左操作数
    ASTNode *left = parser_parse_bitand_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    
    // 解析连续的逻辑与运算符（左结合）
    while (parser->current_token != NULL && parser_match(parser, TOKEN_LOGICAL_AND)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        ASTNode *right = parser_parse_bitand_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        
        left = node;  // 左结合：继续以当前节点作为左操作数
    }
    
    return left;
}

// 解析逻辑或表达式（左结合）
// or_expr = bitor_expr { '||' bitor_expr }
static ASTNode *parser_parse_or_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 解析左操作数
    ASTNode *left = parser_parse_bitor_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    
    // 解析连续的逻辑或运算符（左结合）
    while (parser->current_token != NULL && parser_match(parser, TOKEN_LOGICAL_OR)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        ASTNode *right = parser_parse_bitor_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        
        left = node;  // 左结合：继续以当前节点作为左操作数
    }
    
    return left;
}

// 解析赋值表达式（右结合）
// assign_expr = or_expr [ '=' assign_expr ]
static ASTNode *parser_parse_assign_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 解析左操作数
    ASTNode *left = parser_parse_or_expr(parser);
    if (left == NULL) {
        return NULL;
    }
    
    // 检查是否有赋值运算符
    if (parser->current_token != NULL && parser_match(parser, TOKEN_ASSIGN)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        parser_consume(parser);  // 消费 '='
        
        // 递归解析赋值表达式（右结合）
        ASTNode *right = parser_parse_assign_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        
        // 创建赋值节点
        ASTNode *node = ast_new_node(AST_ASSIGN, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.assign.dest = left;
        node->data.assign.src = right;
        
        return node;
    }
    
    // 没有赋值运算符，返回左操作数
    return left;
}

// 解析表达式（完整版本）
// expr = assign_expr
ASTNode *parser_parse_expression(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 从赋值表达式开始解析（最低优先级）
    return parser_parse_assign_expr(parser);
}

// 解析语句
ASTNode *parser_parse_statement(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 根据第一个 Token 判断语句类型
    if (parser->current_token->type == TOKEN_RETURN) {
        // 解析 return 语句
        parser_consume(parser);  // 消费 'return'
        
        ASTNode *stmt = ast_new_node(AST_RETURN_STMT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析返回值表达式（可选，void 函数可以没有返回值）
        if (parser_match(parser, TOKEN_SEMICOLON)) {
            // 没有返回值（void 函数）
            stmt->data.return_stmt.expr = NULL;
            parser_consume(parser);  // 消费 ';'
        } else {
            // 有返回值表达式
            ASTNode *expr = parser_parse_expression(parser);
            if (expr == NULL) {
                return NULL;
            }
            stmt->data.return_stmt.expr = expr;
            
            // 期望 ';'
            if (!parser_expect(parser, TOKEN_SEMICOLON)) {
                return NULL;
            }
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_BREAK)) {
        // 解析 break 语句
        parser_consume(parser);  // 消费 'break'
        
        ASTNode *stmt = ast_new_node(AST_BREAK_STMT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 期望 ';'
        if (!parser_expect(parser, TOKEN_SEMICOLON)) {
            return NULL;
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_CONTINUE)) {
        // 解析 continue 语句
        parser_consume(parser);  // 消费 'continue'
        
        ASTNode *stmt = ast_new_node(AST_CONTINUE_STMT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 期望 ';'
        if (!parser_expect(parser, TOKEN_SEMICOLON)) {
            return NULL;
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_DEFER)) {
        parser_consume(parser);
        ASTNode *stmt = ast_new_node(AST_DEFER_STMT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) return NULL;
        if (parser_match(parser, TOKEN_LEFT_BRACE)) {
            stmt->data.defer_stmt.body = parser_parse_block(parser);
        } else {
            stmt->data.defer_stmt.body = parser_parse_statement(parser);
        }
        if (stmt->data.defer_stmt.body == NULL) return NULL;
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_ERRDEFER)) {
        parser_consume(parser);
        ASTNode *stmt = ast_new_node(AST_ERRDEFER_STMT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) return NULL;
        if (parser_match(parser, TOKEN_LEFT_BRACE)) {
            stmt->data.errdefer_stmt.body = parser_parse_block(parser);
        } else {
            stmt->data.errdefer_stmt.body = parser_parse_statement(parser);
        }
        if (stmt->data.errdefer_stmt.body == NULL) return NULL;
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_IF)) {
        // 解析 if 语句
        parser_consume(parser);  // 消费 'if'
        
        ASTNode *stmt = ast_new_node(AST_IF_STMT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析条件表达式
        // 设置上下文为条件表达式上下文，以便在解析表达式时正确区分结构体字面量和代码块
        ParserContext saved_context = parser->context;
        parser->context = PARSER_CONTEXT_CONDITION;
        ASTNode *condition = parser_parse_expression(parser);
        parser->context = saved_context;  // 恢复上下文
        if (condition == NULL) {
            return NULL;
        }
        stmt->data.if_stmt.condition = condition;
        
        // 解析 then 分支：允许 { block } 或单条语句（如 if (x) return 2;）
        ASTNode *then_branch = NULL;
        if (parser_match(parser, TOKEN_LEFT_BRACE)) {
            then_branch = parser_parse_block(parser);
        } else {
            ASTNode *single = parser_parse_statement(parser);
            if (single == NULL) {
                return NULL;
            }
            // 包装单条语句为块节点
            ASTNode *block = ast_new_node(AST_BLOCK, single->line, single->column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (block == NULL) {
                return NULL;
            }
            ASTNode **stmts = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *));
            if (stmts == NULL) {
                return NULL;
            }
            stmts[0] = single;
            block->data.block.stmts = stmts;
            block->data.block.stmt_count = 1;
            then_branch = block;
        }
        if (then_branch == NULL) {
            return NULL;
        }
        stmt->data.if_stmt.then_branch = then_branch;
        
        // 解析 else 分支（可选）
        // 支持 else if 语法：else 后面可以是代码块，也可以是 if 语句
        if (parser_match(parser, TOKEN_ELSE)) {
            parser_consume(parser);  // 消费 'else'
            
            // 检查是否是 else if（下一个 token 是 if）
            if (parser_match(parser, TOKEN_IF)) {
                // else if：递归解析 if 语句作为 else 分支
                ASTNode *else_if_stmt = parser_parse_statement(parser);
                if (else_if_stmt == NULL) {
                    return NULL;
                }
                // else if 语句本身作为 else 分支
                // 注意：这里将整个 if 语句作为 else 分支，而不是只取 then 分支
                stmt->data.if_stmt.else_branch = else_if_stmt;
            } else if (parser_match(parser, TOKEN_LEFT_BRACE)) {
                // else { block }：解析代码块
                ASTNode *else_branch = parser_parse_block(parser);
                if (else_branch == NULL) {
                    return NULL;
                }
                stmt->data.if_stmt.else_branch = else_branch;
            } else {
                // else 单条语句：包装为块
                ASTNode *single = parser_parse_statement(parser);
                if (single == NULL) {
                    return NULL;
                }
                ASTNode *block = ast_new_node(AST_BLOCK, single->line, single->column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
                if (block == NULL) {
                    return NULL;
                }
                ASTNode **stmts = (ASTNode **)arena_alloc(parser->arena, sizeof(ASTNode *));
                if (stmts == NULL) {
                    return NULL;
                }
                stmts[0] = single;
                block->data.block.stmts = stmts;
                block->data.block.stmt_count = 1;
                stmt->data.if_stmt.else_branch = block;
            }
        } else {
            stmt->data.if_stmt.else_branch = NULL;
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_WHILE)) {
        // 解析 while 语句
        parser_consume(parser);  // 消费 'while'
        
        ASTNode *stmt = ast_new_node(AST_WHILE_STMT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析条件表达式
        // 设置上下文为条件表达式上下文，以便在解析表达式时正确区分结构体字面量和代码块
        ParserContext saved_context = parser->context;
        parser->context = PARSER_CONTEXT_CONDITION;
        ASTNode *condition = parser_parse_expression(parser);
        parser->context = saved_context;  // 恢复上下文
        if (condition == NULL) {
            return NULL;
        }
        stmt->data.while_stmt.condition = condition;
        
        // 解析循环体（代码块）
        ASTNode *body = parser_parse_block(parser);
        if (body == NULL) {
            return NULL;
        }
        stmt->data.while_stmt.body = body;
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_FOR)) {
        // 解析 for 语句：数组遍历 或 整数范围（for start..end |v| / for start..end { }）
        parser_consume(parser);  // 消费 'for'
        
        ASTNode *stmt = ast_new_node(AST_FOR_STMT, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析第一个表达式（数组或范围起始）
        ASTNode *first_expr = parser_parse_xor_expr(parser);
        if (first_expr == NULL) {
            return NULL;
        }
        
        if (parser->current_token != NULL && parser->current_token->type == TOKEN_DOT_DOT) {
            // 整数范围形式：for start..end [|v|] { }
            stmt->data.for_stmt.is_range = 1;
            stmt->data.for_stmt.array = NULL;
            stmt->data.for_stmt.range_start = first_expr;
            parser_consume(parser);  // 消费 '..'
            if (parser->current_token != NULL && parser->current_token->type != TOKEN_PIPE && parser->current_token->type != TOKEN_LEFT_BRACE) {
                ASTNode *end_expr = parser_parse_xor_expr(parser);
                if (end_expr == NULL) {
                    return NULL;
                }
                stmt->data.for_stmt.range_end = end_expr;
            } else {
                stmt->data.for_stmt.range_end = NULL;  /* start.. 无限范围 */
            }
            stmt->data.for_stmt.is_ref = 0;
            if (parser->current_token != NULL && parser->current_token->type == TOKEN_PIPE) {
                parser_consume(parser);  // 消费 '|'
                if (parser_match(parser, TOKEN_AMPERSAND)) {
                    parser_consume(parser);
                    stmt->data.for_stmt.is_ref = 1;
                }
                if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                    return NULL;
                }
                stmt->data.for_stmt.var_name = arena_strdup(parser->arena, parser->current_token->value);
                parser_consume(parser);
                if (!parser_expect(parser, TOKEN_PIPE)) {
                    return NULL;
                }
            } else {
                stmt->data.for_stmt.var_name = NULL;  /* 丢弃形式 */
            }
        } else {
            // 数组遍历形式：for expr | ID | { } 或 for expr | &ID | { }
            stmt->data.for_stmt.is_range = 0;
            stmt->data.for_stmt.range_start = NULL;
            stmt->data.for_stmt.range_end = NULL;
            stmt->data.for_stmt.array = first_expr;
            if (!parser_expect(parser, TOKEN_PIPE)) {
                return NULL;
            }
            int is_ref = 0;
            if (parser_match(parser, TOKEN_AMPERSAND)) {
                parser_consume(parser);
                is_ref = 1;
            }
            if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                return NULL;
            }
            stmt->data.for_stmt.var_name = arena_strdup(parser->arena, parser->current_token->value);
            parser_consume(parser);
            if (!parser_expect(parser, TOKEN_PIPE)) {
                return NULL;
            }
            stmt->data.for_stmt.is_ref = is_ref;
        }
        
        ASTNode *body = parser_parse_block(parser);
        if (body == NULL) {
            return NULL;
        }
        stmt->data.for_stmt.body = body;
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_CONST) || parser_match(parser, TOKEN_VAR)) {
        // 解析变量声明或解构声明
        int is_const = parser_match(parser, TOKEN_CONST);
        parser_consume(parser);  // 消费 'const' 或 'var'
        
        // 解构声明：const (x, y) = expr; 或 var (x, _) = expr;
        if (parser->current_token != NULL && parser->current_token->type == TOKEN_LEFT_PAREN) {
            parser_consume(parser);  // 消费 '('
            
            const char **names = (const char **)arena_alloc(parser->arena, sizeof(const char *) * 16);
            if (names == NULL) {
                return NULL;
            }
            int cap = 16;
            int count = 0;
            
            while (parser->current_token != NULL && parser->current_token->type != TOKEN_RIGHT_PAREN) {
                if (count > 0) {
                    if (!parser_expect(parser, TOKEN_COMMA)) {
                        return NULL;
                    }
                }
                if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                    fprintf(stderr, "错误: 解构中期望标识符或 _ (%s:%d:%d)\n",
                        parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>",
                        parser->current_token ? parser->current_token->line : line,
                        parser->current_token ? parser->current_token->column : column);
                    return NULL;
                }
                const char *name = arena_strdup(parser->arena, parser->current_token->value);
                if (name == NULL) {
                    return NULL;
                }
                parser_consume(parser);  // 消费标识符
                if (count >= cap) {
                    const char **new_names = (const char **)arena_alloc(parser->arena, sizeof(const char *) * (cap * 2));
                    if (new_names == NULL) {
                        return NULL;
                    }
                    for (int i = 0; i < count; i++) {
                        new_names[i] = names[i];
                    }
                    names = new_names;
                    cap *= 2;
                }
                names[count++] = name;
            }
            
            if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
                return NULL;
            }
            if (!parser_expect(parser, TOKEN_ASSIGN)) {
                fprintf(stderr, "错误: 解构声明期望 '=' (%s:%d:%d)\n",
                    parser->lexer && parser->lexer->filename ? parser->lexer->filename : "<unknown>",
                    parser->current_token ? parser->current_token->line : line,
                    parser->current_token ? parser->current_token->column : column);
                return NULL;
            }
            
            ParserContext saved_ctx = parser->context;
            parser->context = PARSER_CONTEXT_VAR_INIT;
            ASTNode *init = parser_parse_expression(parser);
            parser->context = saved_ctx;
            if (init == NULL) {
                return NULL;
            }
            if (!parser_expect(parser, TOKEN_SEMICOLON)) {
                return NULL;
            }
            
            ASTNode *stmt = ast_new_node(AST_DESTRUCTURE_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
            if (stmt == NULL) {
                return NULL;
            }
            stmt->data.destructure_decl.names = names;
            stmt->data.destructure_decl.name_count = count;
            stmt->data.destructure_decl.is_const = is_const ? 1 : 0;
            stmt->data.destructure_decl.init = init;
            return stmt;
        }
        
        // 普通变量声明
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            return NULL;
        }
        
        const char *var_name = arena_strdup(parser->arena, parser->current_token->value);
        if (var_name == NULL) {
            return NULL;
        }
        
        parser_consume(parser);  // 消费变量名称
        
        ASTNode *stmt = ast_new_node(AST_VAR_DECL, line, column, parser->arena, parser->lexer ? parser->lexer->filename : NULL);
        if (stmt == NULL) {
            return NULL;
        }
        
        stmt->data.var_decl.name = var_name;
        stmt->data.var_decl.is_const = is_const ? 1 : 0;
        
        // 期望 ':'
        if (!parser_expect(parser, TOKEN_COLON)) {
            return NULL;
        }
        
        // 解析类型
        ASTNode *type = parser_parse_type(parser);
        if (type == NULL) {
            return NULL;
        }
        stmt->data.var_decl.type = type;
        
        // 期望 '='
        if (!parser_expect(parser, TOKEN_ASSIGN)) {
            // 变量未初始化：给出明确的错误提示
            const char *filename = parser->lexer->filename ? parser->lexer->filename : "<unknown>";
            int error_line = line;
            int error_column = column;
            if (parser->current_token != NULL) {
                error_line = parser->current_token->line;
                error_column = parser->current_token->column;
            }
            const char *token_value = "";
            if (parser->current_token != NULL && parser->current_token->value != NULL) {
                token_value = parser->current_token->value;
            }
            fprintf(stderr, "错误: 变量 %s 未初始化 (%s:%d:%d)\n", var_name, filename, error_line, error_column);
            fprintf(stderr, "提示: 所有变量必须初始化，请使用 '=' 提供初始值\n");
            if (token_value[0] != '\0') {
                fprintf(stderr, "      当前 token: '%s'\n", token_value);
            }
            return NULL;
        }
        
        // 解析初始值表达式
        // 设置上下文为变量初始化上下文，以便在解析表达式时正确区分结构体字面量和代码块
        ParserContext saved_context = parser->context;
        parser->context = PARSER_CONTEXT_VAR_INIT;
        ASTNode *init = parser_parse_expression(parser);
        parser->context = saved_context;  // 恢复上下文
        if (init == NULL) {
            return NULL;
        }
        stmt->data.var_decl.init = init;
        
        // 期望 ';'
        if (!parser_expect(parser, TOKEN_SEMICOLON)) {
            return NULL;
        }
        
        return stmt;
    }
    
    // 注意：根据规范，enum 和 struct 只能在顶层定义，不能在函数内部或其他局部作用域内定义
    // 因此这里不处理 TOKEN_STRUCT 和 TOKEN_ENUM
    // 函数内部也不允许定义函数（嵌套函数不支持）
    
    if (parser_match(parser, TOKEN_LEFT_BRACE)) {
        // 解析代码块语句
        return parser_parse_block(parser);
    }
    
    // 解析表达式语句（表达式后加分号）
    // 注意：AST_EXPR_STMT 节点在 union 中没有对应的数据结构
    // 根据 ast.c 的注释，表达式语句的数据存储在表达式的节点中
    // 所以这里直接返回表达式节点（表达式节点本身可以作为语句）
    
    // 如果当前 token 是右大括号，说明块尾，返回 NULL（不消费，由 block 的 expect 统一消费）
    if (parser->current_token != NULL && parser->current_token->type == TOKEN_RIGHT_BRACE) {
        return NULL;
    }
    
    ASTNode *expr = parser_parse_expression(parser);
    if (expr == NULL) {
        // 如果当前 token 是右大括号，说明块尾，返回 NULL（不消费）
        if (parser->current_token != NULL && parser->current_token->type == TOKEN_RIGHT_BRACE) {
            return NULL;
        }
        return NULL;
    }
    
    // 期望 ';'
    if (!parser_expect(parser, TOKEN_SEMICOLON)) {
        return NULL;
    }
    
    // 直接返回表达式节点（表达式节点可以作为语句）
    return expr;
}

