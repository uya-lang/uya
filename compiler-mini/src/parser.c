#include "parser.h"
#include <stddef.h>
#include <string.h>

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

// 解析程序（顶层声明列表）
// 暂时返回基础框架，完整实现需要分多个会话完成
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
    
    // TODO: 解析顶层声明列表
    // 这将分多个会话完成：
    // - 会话2：函数和结构体解析
    // - 会话3：语句解析
    // - 会话4：表达式解析
    
    // 暂时只检查是否到达 EOF
    while (parser->current_token != NULL && !parser_match(parser, TOKEN_EOF)) {
        // 跳过所有 Token（临时实现，待后续会话完成）
        parser_consume(parser);
    }
    
    return program;
}

