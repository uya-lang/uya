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
        return NULL;
    }
    
    return parser_consume(parser);
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

// 辅助函数：获取 Token 类型的简短字符串表示（用于调试）
static const char *token_type_str(TokenType type) {
    switch (type) {
        case TOKEN_EOF: return "EOF";
        case TOKEN_IDENTIFIER: return "IDENTIFIER";
        case TOKEN_NUMBER: return "NUMBER";
        case TOKEN_STRUCT: return "STRUCT";
        case TOKEN_CONST: return "CONST";
        case TOKEN_VAR: return "VAR";
        case TOKEN_FN: return "FN";
        case TOKEN_EXTERN: return "EXTERN";
        case TOKEN_RETURN: return "RETURN";
        case TOKEN_IF: return "IF";
        case TOKEN_ELSE: return "ELSE";
        case TOKEN_WHILE: return "WHILE";
        case TOKEN_TRUE: return "TRUE";
        case TOKEN_FALSE: return "FALSE";
        case TOKEN_PLUS: return "+";
        case TOKEN_MINUS: return "-";
        case TOKEN_ASTERISK: return "*";
        case TOKEN_SLASH: return "/";
        case TOKEN_PERCENT: return "%";
        case TOKEN_EQUAL: return "==";
        case TOKEN_NOT_EQUAL: return "!=";
        case TOKEN_LESS: return "<";
        case TOKEN_GREATER: return ">";
        case TOKEN_LESS_EQUAL: return "<=";
        case TOKEN_GREATER_EQUAL: return ">=";
        case TOKEN_LOGICAL_AND: return "&&";
        case TOKEN_LOGICAL_OR: return "||";
        case TOKEN_EXCLAMATION: return "!";
        case TOKEN_LEFT_PAREN: return "(";
        case TOKEN_RIGHT_PAREN: return ")";
        case TOKEN_LEFT_BRACE: return "{";
        case TOKEN_RIGHT_BRACE: return "}";
        case TOKEN_SEMICOLON: return ";";
        case TOKEN_COMMA: return ",";
        case TOKEN_ASSIGN: return "=";
        case TOKEN_DOT: return ".";
        case TOKEN_COLON: return ":";
        default: return "UNKNOWN";
    }
}

// 解析类型（Uya Mini 只支持命名类型：i32, bool, void, 或结构体名称）
static ASTNode *parser_parse_type(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // Uya Mini 只支持命名类型（标识符）
    if (parser->current_token->type != TOKEN_IDENTIFIER) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 创建类型节点
    ASTNode *type_node = ast_new_node(AST_TYPE_NAMED, line, column, parser->arena);
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

// 前向声明
ASTNode *parser_parse_statement(Parser *parser);
ASTNode *parser_parse_expression(Parser *parser);  // 前向声明，用于递归调用
static ASTNode *parser_parse_unary_expr(Parser *parser);
static ASTNode *parser_parse_mul_expr(Parser *parser);
static ASTNode *parser_parse_add_expr(Parser *parser);
static ASTNode *parser_parse_rel_expr(Parser *parser);
static ASTNode *parser_parse_eq_expr(Parser *parser);
static ASTNode *parser_parse_and_expr(Parser *parser);
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
    ASTNode *block = ast_new_node(AST_BLOCK, line, column, parser->arena);
    if (block == NULL) {
        return NULL;
    }
    
    // 初始化语句列表
    block->data.block.stmts = NULL;
    block->data.block.stmt_count = 0;
    
    // 消费 '{'
    parser_consume(parser);
    
    // 解析语句列表
    ASTNode **stmts = NULL;
    int stmt_count = 0;
    int stmt_capacity = 0;
    
    while (parser->current_token != NULL && 
           !parser_match(parser, TOKEN_RIGHT_BRACE) && 
           !parser_match(parser, TOKEN_EOF)) {
        
        // 解析语句
        ASTNode *stmt = parser_parse_statement(parser);
        if (stmt == NULL) {
            // 解析失败
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
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
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
    ASTNode *struct_decl = ast_new_node(AST_STRUCT_DECL, line, column, parser->arena);
    if (struct_decl == NULL) {
        return NULL;
    }
    
    struct_decl->data.struct_decl.name = struct_name;
    struct_decl->data.struct_decl.fields = NULL;
    struct_decl->data.struct_decl.field_count = 0;
    
    // 期望 '{'
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) {
        return NULL;
    }
    
    // 解析字段列表
    // 字段列表：field { ',' field }
    // field = ID ':' type
    ASTNode **fields = NULL;
    int field_count = 0;
    int field_capacity = 0;
    
    while (parser->current_token != NULL && 
           !parser_match(parser, TOKEN_RIGHT_BRACE) && 
           !parser_match(parser, TOKEN_EOF)) {
        
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
        ASTNode *field = ast_new_node(AST_VAR_DECL, field_line, field_column, parser->arena);
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
    
    return struct_decl;
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
    ASTNode *fn_decl = ast_new_node(AST_FN_DECL, line, column, parser->arena);
    if (fn_decl == NULL) {
        return NULL;
    }
    
    fn_decl->data.fn_decl.name = fn_name;
    fn_decl->data.fn_decl.params = NULL;
    fn_decl->data.fn_decl.param_count = 0;
    fn_decl->data.fn_decl.return_type = NULL;
    fn_decl->data.fn_decl.body = NULL;
    
    // 期望 '('
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        return NULL;
    }
    
    // 解析参数列表（可选）
    ASTNode **params = NULL;
    int param_count = 0;
    int param_capacity = 0;
    
    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        // 有参数
        while (parser->current_token != NULL && 
               !parser_match(parser, TOKEN_RIGHT_PAREN) && 
               !parser_match(parser, TOKEN_EOF)) {
            
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
            ASTNode *param = ast_new_node(AST_VAR_DECL, param_line, param_column, parser->arena);
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
        return NULL;
    }
    
    fn_decl->data.fn_decl.params = params;
    fn_decl->data.fn_decl.param_count = param_count;
    fn_decl->data.fn_decl.return_type = return_type;
    fn_decl->data.fn_decl.body = body;
    
    return fn_decl;
}

// 解析 extern 函数声明
// extern_decl = 'extern' 'fn' ID '(' [ param_list ] ')' type ';'
ASTNode *parser_parse_extern_function(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 期望 'extern'
    if (!parser_match(parser, TOKEN_EXTERN)) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 消费 'extern'
    parser_consume(parser);
    
    // 期望 'fn'
    if (!parser_expect(parser, TOKEN_FN)) {
        return NULL;
    }
    
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
    ASTNode *fn_decl = ast_new_node(AST_FN_DECL, line, column, parser->arena);
    if (fn_decl == NULL) {
        return NULL;
    }
    
    fn_decl->data.fn_decl.name = fn_name;
    fn_decl->data.fn_decl.params = NULL;
    fn_decl->data.fn_decl.param_count = 0;
    fn_decl->data.fn_decl.return_type = NULL;
    fn_decl->data.fn_decl.body = NULL;  // extern 函数没有函数体
    
    // 期望 '('
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        return NULL;
    }
    
    // 解析参数列表（可选，与普通函数相同）
    ASTNode **params = NULL;
    int param_count = 0;
    int param_capacity = 0;
    
    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        // 有参数
        while (parser->current_token != NULL && 
               !parser_match(parser, TOKEN_RIGHT_PAREN) && 
               !parser_match(parser, TOKEN_EOF)) {
            
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
            ASTNode *param = ast_new_node(AST_VAR_DECL, param_line, param_column, parser->arena);
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
    
    return fn_decl;
}

// 解析声明（函数、结构体或变量声明）
ASTNode *parser_parse_declaration(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 根据第一个 Token 判断声明类型
    if (parser_match(parser, TOKEN_EXTERN)) {
        // extern 函数声明
        return parser_parse_extern_function(parser);
    } else if (parser_match(parser, TOKEN_FN)) {
        return parser_parse_function(parser);
    } else if (parser_match(parser, TOKEN_STRUCT)) {
        return parser_parse_struct(parser);
    } else {
        // TODO: 变量声明将在后续会话实现
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
    
    ASTNode *program = ast_new_node(AST_PROGRAM, line, column, parser->arena);
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
                // 真正的解析错误：返回 NULL 表示失败
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
        fprintf(stderr, "[解析] parser_parse_primary_expr: parser 或 current_token 为 NULL\n");
        return NULL;
    }
    
    fprintf(stderr, "[解析] parser_parse_primary_expr: 开始，当前 token: %s\n",
            token_type_str(parser->current_token->type));
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 解析数字字面量
    if (parser->current_token->type == TOKEN_NUMBER) {
        ASTNode *node = ast_new_node(AST_NUMBER, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        // 将字符串转换为整数
        int value = atoi(parser->current_token->value);
        node->data.number.value = value;
        
        parser_consume(parser);
        return node;
    }
    
    // 解析布尔字面量
    if (parser->current_token->type == TOKEN_TRUE) {
        ASTNode *node = ast_new_node(AST_BOOL, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.bool_literal.value = 1;  // true
        
        parser_consume(parser);
        return node;
    }
    
    if (parser->current_token->type == TOKEN_FALSE) {
        ASTNode *node = ast_new_node(AST_BOOL, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.bool_literal.value = 0;  // false
        
        parser_consume(parser);
        return node;
    }
    
    // 解析标识符（可能是普通标识符、函数调用、或结构体字面量的开始）
    if (parser->current_token->type == TOKEN_IDENTIFIER) {
        const char *name = arena_strdup(parser->arena, parser->current_token->value);
        if (name == NULL) {
            return NULL;
        }
        
        parser_consume(parser);  // 消费标识符
        
        // 检查下一个 token 类型
        if (parser->current_token != NULL && parser->current_token->type == TOKEN_LEFT_PAREN) {
            // 函数调用：ID '(' [ arg_list ] ')'
            ASTNode *call = ast_new_node(AST_CALL_EXPR, line, column, parser->arena);
            if (call == NULL) {
                return NULL;
            }
            
            // 创建标识符节点作为被调用的函数
            ASTNode *callee = ast_new_node(AST_IDENTIFIER, line, column, parser->arena);
            if (callee == NULL) {
                return NULL;
            }
            callee->data.identifier.name = name;
            call->data.call_expr.callee = callee;
            
            // 消费 '('
            parser_consume(parser);
            
            // 解析参数列表（可选）
            ASTNode **args = NULL;
            int arg_count = 0;
            int arg_capacity = 0;
            
            if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
                // 有参数
                while (parser->current_token != NULL && 
                       !parser_match(parser, TOKEN_RIGHT_PAREN) && 
                       !parser_match(parser, TOKEN_EOF)) {
                    
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
                    
                    // 检查是否有逗号
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
            
            // 字段访问可能跟在函数调用后面（例如：f().field），所以继续处理字段访问
            // 但先返回函数调用，字段访问会在后续的循环中处理
            ASTNode *result = call;
            
            // 处理字段访问链（左结合：a.b.c 解析为 (a.b).c）
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
                ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena);
                if (member_access == NULL) {
                    return NULL;
                }
                
                member_access->data.member_access.object = result;  // 左操作数是当前结果
                member_access->data.member_access.field_name = field_name;
                
                result = member_access;
            }
            
            return result;
        } else if (parser->current_token != NULL && parser->current_token->type == TOKEN_LEFT_BRACE) {
            // 检查是否是有效的结构体字面量
            // 保存当前token以便回退
            Token *saved_token = parser->current_token;
            
            // 消费 '{'
            parser_consume(parser);
            
            // 检查{后面的内容是否匹配结构体字段初始化列表
            int is_struct_init = 0;
            
            if (parser_match(parser, TOKEN_RIGHT_BRACE)) {
                // 空的字段初始化列表，是有效的结构体字面量
                is_struct_init = 1;
            } else if (parser_match(parser, TOKEN_IDENTIFIER)) {
                // 检查字段名称后面是否有冒号
                Token *field_token = parser->current_token;
                parser_consume(parser);
                if (parser_match(parser, TOKEN_COLON)) {
                    is_struct_init = 1;
                }
                // 回退到字段名称之前的位置
                parser->current_token = field_token;
            }
            
            // 回退到原始位置
            parser->current_token = saved_token;
            
            if (!is_struct_init) {
                // 不是结构体字面量，创建普通标识符
                fprintf(stderr, "[解析] parser_parse_primary_expr: 标识符后是 {，但不是结构体字面量，创建普通标识符\n");
                ASTNode *node = ast_new_node(AST_IDENTIFIER, line, column, parser->arena);
                if (node == NULL) {
                    fprintf(stderr, "[解析] parser_parse_primary_expr: 标识符节点创建失败\n");
                    return NULL;
                }
                
                node->data.identifier.name = name;
                
                // 字段访问可能跟在标识符后面（例如：obj.field）
                ASTNode *result = node;
                
                // 处理字段访问链（左结合：a.b.c 解析为 (a.b).c）
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
                    ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena);
                    if (member_access == NULL) {
                        return NULL;
                    }
                    
                    member_access->data.member_access.object = result;
                    member_access->data.member_access.field_name = field_name;
                    
                    result = member_access;
                }
                
                return result;
            }
            
            // 结构体字面量：ID '{' field_init_list '}'
            fprintf(stderr, "[解析] parser_parse_primary_expr: 标识符后是 {，解析结构体字面量\n");
            ASTNode *struct_init = ast_new_node(AST_STRUCT_INIT, line, column, parser->arena);
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
                ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena);
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
            fprintf(stderr, "[解析] parser_parse_primary_expr: 创建普通标识符节点\n");
            ASTNode *node = ast_new_node(AST_IDENTIFIER, line, column, parser->arena);
            if (node == NULL) {
                fprintf(stderr, "[解析] parser_parse_primary_expr: 标识符节点创建失败\n");
                return NULL;
            }
            
            node->data.identifier.name = name;
            
            // 字段访问可能跟在标识符后面（例如：obj.field）
            ASTNode *result = node;
            
            // 处理字段访问链（左结合：a.b.c 解析为 (a.b).c）
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
                ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena);
                if (member_access == NULL) {
                    return NULL;
                }
                
                member_access->data.member_access.object = result;
                member_access->data.member_access.field_name = field_name;
                
                result = member_access;
            }
            
            return result;
        }
    }
    
    // 解析括号表达式
    if (parser->current_token->type == TOKEN_LEFT_PAREN) {
        parser_consume(parser);  // 消费 '('
        
        // 解析内部表达式（递归调用）
        ASTNode *expr = parser_parse_expression(parser);
        if (expr == NULL) {
            return NULL;
        }
        
        // 期望 ')'
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            return NULL;
        }
        
        // 字段访问可能跟在括号表达式后面（例如：(expr).field）
        ASTNode *result = expr;
        
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
            ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS, field_line, field_column, parser->arena);
            if (member_access == NULL) {
                return NULL;
            }
            
            member_access->data.member_access.object = result;
            member_access->data.member_access.field_name = field_name;
            
            result = member_access;
        }
        
        return result;
    }
    
    // 无法识别的基础表达式
    fprintf(stderr, "[解析] parser_parse_primary_expr: 无法识别的基础表达式，当前 token: %s\n",
            parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
    return NULL;
}

// 解析一元表达式（! 和 -，右结合）
// unary_expr = ('!' | '-') unary_expr | primary_expr
static ASTNode *parser_parse_unary_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        fprintf(stderr, "[解析] parser_parse_unary_expr: parser 或 current_token 为 NULL\n");
        return NULL;
    }
    
    fprintf(stderr, "[解析] parser_parse_unary_expr: 开始，当前 token: %s\n",
            token_type_str(parser->current_token->type));
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 检查一元运算符
    if (parser_match(parser, TOKEN_EXCLAMATION) || parser_match(parser, TOKEN_MINUS)) {
        TokenType op = parser->current_token->type;
        fprintf(stderr, "[解析] parser_parse_unary_expr: 找到一元运算符 %s\n", token_type_str(op));
        parser_consume(parser);  // 消费运算符
        
        // 递归解析一元表达式（右结合）
        ASTNode *operand = parser_parse_unary_expr(parser);
        if (operand == NULL) {
            fprintf(stderr, "[解析] parser_parse_unary_expr: 操作数解析失败\n");
            return NULL;
        }
        
        // 创建一元表达式节点
        ASTNode *node = ast_new_node(AST_UNARY_EXPR, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.unary_expr.op = op;
        node->data.unary_expr.operand = operand;
        
        fprintf(stderr, "[解析] parser_parse_unary_expr: 一元表达式节点创建成功\n");
        return node;
    }
    
    // 不是一元运算符，解析基础表达式
    fprintf(stderr, "[解析] parser_parse_unary_expr: 不是一元运算符，调用 parser_parse_primary_expr\n");
    ASTNode *result = parser_parse_primary_expr(parser);
    if (result == NULL) {
        fprintf(stderr, "[解析] parser_parse_unary_expr: primary_expr 解析失败，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
    } else {
        fprintf(stderr, "[解析] parser_parse_unary_expr: primary_expr 解析成功\n");
    }
    return result;
}

// 解析乘除模表达式（左结合）
// mul_expr = unary_expr { ('*' | '/' | '%') unary_expr }
static ASTNode *parser_parse_mul_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        fprintf(stderr, "[解析] parser_parse_mul_expr: parser 或 current_token 为 NULL\n");
        return NULL;
    }
    
    fprintf(stderr, "[解析] parser_parse_mul_expr: 开始，当前 token: %s\n",
            token_type_str(parser->current_token->type));
    
    // 解析左操作数
    ASTNode *left = parser_parse_unary_expr(parser);
    if (left == NULL) {
        fprintf(stderr, "[解析] parser_parse_mul_expr: 左操作数解析失败，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        return NULL;
    }
    fprintf(stderr, "[解析] parser_parse_mul_expr: 左操作数解析成功\n");
    
    // 解析连续的乘除模运算符（左结合）
    while (parser->current_token != NULL && (
        parser_match(parser, TOKEN_ASTERISK) ||
        parser_match(parser, TOKEN_SLASH) ||
        parser_match(parser, TOKEN_PERCENT)
    )) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        ASTNode *right = parser_parse_unary_expr(parser);
        if (right == NULL) {
            return NULL;
        }
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena);
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
        fprintf(stderr, "[解析] parser_parse_add_expr: parser 或 current_token 为 NULL\n");
        return NULL;
    }
    
    fprintf(stderr, "[解析] parser_parse_add_expr: 开始，当前 token: %s\n",
            token_type_str(parser->current_token->type));
    
    // 解析左操作数
    ASTNode *left = parser_parse_mul_expr(parser);
    if (left == NULL) {
        fprintf(stderr, "[解析] parser_parse_add_expr: 左操作数解析失败，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        return NULL;
    }
    fprintf(stderr, "[解析] parser_parse_add_expr: 左操作数解析成功\n");
    
    // 解析连续的加减运算符（左结合）
    while (parser->current_token != NULL && (
        parser_match(parser, TOKEN_PLUS) ||
        parser_match(parser, TOKEN_MINUS)
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
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena);
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

// 解析比较表达式（左结合）
// rel_expr = add_expr { ('<' | '>' | '<=' | '>=') add_expr }
static ASTNode *parser_parse_rel_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        fprintf(stderr, "[解析] parser_parse_rel_expr: parser 或 current_token 为 NULL\n");
        return NULL;
    }
    
    fprintf(stderr, "[解析] parser_parse_rel_expr: 开始，当前 token: %s\n",
            token_type_str(parser->current_token->type));
    
    // 解析左操作数
    ASTNode *left = parser_parse_add_expr(parser);
    if (left == NULL) {
        fprintf(stderr, "[解析] parser_parse_rel_expr: 左操作数解析失败，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        return NULL;
    }
    fprintf(stderr, "[解析] parser_parse_rel_expr: 左操作数解析成功\n");
    
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
        fprintf(stderr, "[解析] parser_parse_rel_expr: 找到比较运算符 %s (line %d, col %d)\n",
                token_type_str(op), line, column);
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        fprintf(stderr, "[解析] parser_parse_rel_expr: 开始解析右操作数，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        ASTNode *right = parser_parse_add_expr(parser);
        if (right == NULL) {
            fprintf(stderr, "[解析] parser_parse_rel_expr: 右操作数解析失败，当前 token: %s\n",
                    parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
            return NULL;
        }
        fprintf(stderr, "[解析] parser_parse_rel_expr: 右操作数解析成功\n");
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena);
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

// 解析相等性表达式（左结合）
// eq_expr = rel_expr { ('==' | '!=') rel_expr }
static ASTNode *parser_parse_eq_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        fprintf(stderr, "[解析] parser_parse_eq_expr: parser 或 current_token 为 NULL\n");
        return NULL;
    }
    
    fprintf(stderr, "[解析] parser_parse_eq_expr: 开始，当前 token: %s\n",
            token_type_str(parser->current_token->type));
    
    // 解析左操作数
    ASTNode *left = parser_parse_rel_expr(parser);
    if (left == NULL) {
        fprintf(stderr, "[解析] parser_parse_eq_expr: 左操作数解析失败，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        return NULL;
    }
    fprintf(stderr, "[解析] parser_parse_eq_expr: 左操作数解析成功\n");
    
    // 解析连续的相等性运算符（左结合）
    while (parser->current_token != NULL && (
        parser_match(parser, TOKEN_EQUAL) ||
        parser_match(parser, TOKEN_NOT_EQUAL)
    )) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        fprintf(stderr, "[解析] parser_parse_eq_expr: 找到相等性运算符 %s (line %d, col %d)\n",
                token_type_str(op), line, column);
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        fprintf(stderr, "[解析] parser_parse_eq_expr: 开始解析右操作数，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        ASTNode *right = parser_parse_rel_expr(parser);
        if (right == NULL) {
            fprintf(stderr, "[解析] parser_parse_eq_expr: 右操作数解析失败，当前 token: %s\n",
                    parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
            return NULL;
        }
        fprintf(stderr, "[解析] parser_parse_eq_expr: 右操作数解析成功\n");
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena);
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

// 解析逻辑与表达式（左结合）
// and_expr = eq_expr { '&&' eq_expr }
static ASTNode *parser_parse_and_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        fprintf(stderr, "[解析] parser_parse_and_expr: parser 或 current_token 为 NULL\n");
        return NULL;
    }
    
    fprintf(stderr, "[解析] parser_parse_and_expr: 开始，当前 token: %s\n",
            token_type_str(parser->current_token->type));
    
    // 解析左操作数
    ASTNode *left = parser_parse_eq_expr(parser);
    if (left == NULL) {
        fprintf(stderr, "[解析] parser_parse_and_expr: 左操作数解析失败，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        return NULL;
    }
    fprintf(stderr, "[解析] parser_parse_and_expr: 左操作数解析成功\n");
    
    // 解析连续的逻辑与运算符（左结合）
    while (parser->current_token != NULL && parser_match(parser, TOKEN_LOGICAL_AND)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        fprintf(stderr, "[解析] parser_parse_and_expr: 找到 && 运算符 (line %d, col %d)\n", line, column);
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        fprintf(stderr, "[解析] parser_parse_and_expr: 开始解析右操作数，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        ASTNode *right = parser_parse_eq_expr(parser);
        if (right == NULL) {
            fprintf(stderr, "[解析] parser_parse_and_expr: 右操作数解析失败，当前 token: %s\n",
                    parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
            return NULL;
        }
        fprintf(stderr, "[解析] parser_parse_and_expr: 右操作数解析成功\n");
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        
        left = node;  // 左结合：继续以当前节点作为左操作数
        fprintf(stderr, "[解析] parser_parse_and_expr: 逻辑与表达式节点创建成功\n");
    }
    
    fprintf(stderr, "[解析] parser_parse_and_expr: 完成，返回节点\n");
    return left;
}

// 解析逻辑或表达式（左结合）
// or_expr = and_expr { '||' and_expr }
static ASTNode *parser_parse_or_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        fprintf(stderr, "[解析] parser_parse_or_expr: parser 或 current_token 为 NULL\n");
        return NULL;
    }
    
    fprintf(stderr, "[解析] parser_parse_or_expr: 开始，当前 token: %s\n",
            token_type_str(parser->current_token->type));
    
    // 解析左操作数
    ASTNode *left = parser_parse_and_expr(parser);
    if (left == NULL) {
        fprintf(stderr, "[解析] parser_parse_or_expr: 左操作数解析失败\n");
        return NULL;
    }
    fprintf(stderr, "[解析] parser_parse_or_expr: 左操作数解析成功\n");
    
    // 解析连续的逻辑或运算符（左结合）
    while (parser->current_token != NULL && parser_match(parser, TOKEN_LOGICAL_OR)) {
        int line = parser->current_token->line;
        int column = parser->current_token->column;
        TokenType op = parser->current_token->type;
        fprintf(stderr, "[解析] parser_parse_or_expr: 找到 || 运算符 (line %d, col %d)\n", line, column);
        parser_consume(parser);  // 消费运算符
        
        // 解析右操作数
        ASTNode *right = parser_parse_and_expr(parser);
        if (right == NULL) {
            fprintf(stderr, "[解析] parser_parse_or_expr: 右操作数解析失败\n");
            return NULL;
        }
        fprintf(stderr, "[解析] parser_parse_or_expr: 右操作数解析成功\n");
        
        // 创建二元表达式节点
        ASTNode *node = ast_new_node(AST_BINARY_EXPR, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.binary_expr.left = left;
        node->data.binary_expr.op = op;
        node->data.binary_expr.right = right;
        
        left = node;  // 左结合：继续以当前节点作为左操作数
        fprintf(stderr, "[解析] parser_parse_or_expr: 逻辑或表达式节点创建成功\n");
    }
    
    fprintf(stderr, "[解析] parser_parse_or_expr: 完成，返回节点\n");
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
        ASTNode *node = ast_new_node(AST_ASSIGN, line, column, parser->arena);
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
    if (parser_match(parser, TOKEN_RETURN)) {
        // 解析 return 语句
        parser_consume(parser);  // 消费 'return'
        
        ASTNode *stmt = ast_new_node(AST_RETURN_STMT, line, column, parser->arena);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析返回值表达式（可选，void 函数可以没有返回值）
        if (parser_match(parser, TOKEN_SEMICOLON)) {
            // 没有返回值（void 函数）
            stmt->data.return_stmt.expr = NULL;
        } else {
            // 有返回值表达式
            ASTNode *expr = parser_parse_expression(parser);
            if (expr == NULL) {
                return NULL;
            }
            stmt->data.return_stmt.expr = expr;
        }
        
        // 期望 ';'
        if (!parser_expect(parser, TOKEN_SEMICOLON)) {
            return NULL;
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_IF)) {
        // 解析 if 语句
        fprintf(stderr, "[解析] 进入 if 语句解析，当前 token: %s (line %d, col %d)\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL",
                parser->current_token ? parser->current_token->line : -1,
                parser->current_token ? parser->current_token->column : -1);
        parser_consume(parser);  // 消费 'if'
        
        ASTNode *stmt = ast_new_node(AST_IF_STMT, line, column, parser->arena);
        if (stmt == NULL) {
            fprintf(stderr, "[解析] if 语句节点创建失败\n");
            return NULL;
        }
        
        // 解析条件表达式
        fprintf(stderr, "[解析] 开始解析 if 条件表达式，当前 token: %s\n",
                parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
        ASTNode *condition = parser_parse_expression(parser);
        if (condition == NULL) {
            fprintf(stderr, "[解析] if 条件表达式解析失败，当前 token: %s\n",
                    parser->current_token ? token_type_str(parser->current_token->type) : "NULL");
            return NULL;
        }
        fprintf(stderr, "[解析] if 条件表达式解析成功\n");
        stmt->data.if_stmt.condition = condition;
        
        // 解析 then 分支（代码块）
        ASTNode *then_branch = parser_parse_block(parser);
        if (then_branch == NULL) {
            return NULL;
        }
        stmt->data.if_stmt.then_branch = then_branch;
        
        // 解析 else 分支（可选）
        if (parser_match(parser, TOKEN_ELSE)) {
            parser_consume(parser);  // 消费 'else'
            
            ASTNode *else_branch = parser_parse_block(parser);
            if (else_branch == NULL) {
                return NULL;
            }
            stmt->data.if_stmt.else_branch = else_branch;
        } else {
            stmt->data.if_stmt.else_branch = NULL;
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_WHILE)) {
        // 解析 while 语句
        parser_consume(parser);  // 消费 'while'
        
        ASTNode *stmt = ast_new_node(AST_WHILE_STMT, line, column, parser->arena);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析条件表达式
        ASTNode *condition = parser_parse_expression(parser);
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
    
    if (parser_match(parser, TOKEN_CONST) || parser_match(parser, TOKEN_VAR)) {
        // 解析变量声明
        int is_const = parser_match(parser, TOKEN_CONST);
        parser_consume(parser);  // 消费 'const' 或 'var'
        
        // 期望变量名称
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            return NULL;
        }
        
        const char *var_name = arena_strdup(parser->arena, parser->current_token->value);
        if (var_name == NULL) {
            return NULL;
        }
        
        parser_consume(parser);  // 消费变量名称
        
        ASTNode *stmt = ast_new_node(AST_VAR_DECL, line, column, parser->arena);
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
            return NULL;
        }
        
        // 解析初始值表达式
        ASTNode *init = parser_parse_expression(parser);
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
    
    if (parser_match(parser, TOKEN_LEFT_BRACE)) {
        // 解析代码块语句
        return parser_parse_block(parser);
    }
    
    // 解析表达式语句（表达式后加分号）
    // 注意：AST_EXPR_STMT 节点在 union 中没有对应的数据结构
    // 根据 ast.c 的注释，表达式语句的数据存储在表达式的节点中
    // 所以这里直接返回表达式节点（表达式节点本身可以作为语句）
    ASTNode *expr = parser_parse_expression(parser);
    if (expr == NULL) {
        return NULL;
    }
    
    // 期望 ';'
    if (!parser_expect(parser, TOKEN_SEMICOLON)) {
        return NULL;
    }
    
    // 直接返回表达式节点（表达式节点可以作为语句）
    return expr;
}

