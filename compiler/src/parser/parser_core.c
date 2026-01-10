#include "parser_internal.h"

// 前瞻当前token
Token *parser_peek(Parser *parser) {
    return parser->current_token;
}

// 消费当前token并获取下一个
Token *parser_consume(Parser *parser) {
    Token *current = parser->current_token;
    parser->current_token = lexer_next_token(parser->lexer);
    return current;
}

// 检查当前token类型
int parser_match(Parser *parser, TokenType type) {
    return parser->current_token && parser->current_token->type == type;
}

// 期望特定类型的token
Token *parser_expect(Parser *parser, TokenType type) {
    if (!parser->current_token || parser->current_token->type != type) {
        // 调试：追踪错误来源（使用 __builtin_return_address 获取调用者地址）
        if (parser->current_token) {
            void *caller_addr = __builtin_return_address(0);
            // 打印调用栈信息，帮助定位问题
            fprintf(stderr, "[DEBUG parser_expect] 调用者地址: %p, 期望 %d (%s), 实际 %d (%s), 位置 %s:%d:%d\n",
                    caller_addr, type, 
                    type == TOKEN_PLUS ? "TOKEN_PLUS" : 
                    type == TOKEN_AS ? "TOKEN_AS" : 
                    type == TOKEN_IDENTIFIER ? "TOKEN_IDENTIFIER" :
                    type == TOKEN_RIGHT_PAREN ? "TOKEN_RIGHT_PAREN" :
                    type == TOKEN_COLON ? "TOKEN_COLON" :
                    type == TOKEN_LEFT_BRACE ? "TOKEN_LEFT_BRACE" :
                    "OTHER",
                    parser->current_token->type, 
                    parser->current_token->type == TOKEN_IDENTIFIER ? "TOKEN_IDENTIFIER" :
                    parser->current_token->type == TOKEN_PLUS ? "TOKEN_PLUS" :
                    parser->current_token->type == TOKEN_AS ? "TOKEN_AS" :
                    parser->current_token->type == TOKEN_RIGHT_PAREN ? "TOKEN_RIGHT_PAREN" :
                    parser->current_token->type == TOKEN_COLON ? "TOKEN_COLON" :
                    parser->current_token->type == TOKEN_LEFT_BRACE ? "TOKEN_LEFT_BRACE" :
                    "OTHER",
                    parser->current_token->filename, parser->current_token->line, parser->current_token->column);
            // 打印当前token的内容
            fprintf(stderr, "[DEBUG parser_expect] 当前token内容: %s\n", parser->current_token->value);
        }
        fprintf(stderr, "语法错误: 期望 %d, 但在 %s:%d:%d 发现 %d\n",
                type, parser->current_token ? parser->current_token->filename : "unknown",
                parser->current_token ? parser->current_token->line : 0,
                parser->current_token ? parser->current_token->column : 0,
                parser->current_token ? parser->current_token->type : -1);
        return NULL;
    }
    return parser_consume(parser);
}

Parser *parser_new(Lexer *lexer) {
    Parser *parser = malloc(sizeof(Parser));
    if (!parser) {
        return NULL;
    }

    parser->lexer = lexer;
    parser->current_token = lexer_next_token(lexer);

    return parser;
}

void parser_free(Parser *parser) {
    if (parser) {
        if (parser->current_token) {
            token_free(parser->current_token);
        }
        free(parser);
    }
}

ASTNode *parser_parse(Parser *parser) {
    if (!parser || !parser->current_token) {
        return NULL;
    }

    ASTNode *program = ast_new_node(AST_PROGRAM,
                                    parser->current_token->line,
                                    parser->current_token->column,
                                    parser->current_token->filename);
    if (!program) {
        return NULL;
    }

    // 初始化声明列表
    program->data.program.decls = NULL;
    program->data.program.decl_count = 0;
    int capacity = 0;

    // 解析所有顶级声明
    while (parser->current_token && !parser_match(parser, TOKEN_EOF)) {
        ASTNode *decl = parser_parse_declaration(parser);
        if (!decl) {
            // 如果解析声明失败，跳过到下一个可能的声明开始
            while (parser->current_token &&
                   !parser_match(parser, TOKEN_FN) &&
                   !parser_match(parser, TOKEN_STRUCT) &&
                   !parser_match(parser, TOKEN_ENUM) &&
                   !parser_match(parser, TOKEN_EXTERN) &&
                   !parser_match(parser, TOKEN_IDENTIFIER) && // 可能是接口实现（新语法）
                   !parser_match(parser, TOKEN_EOF)) {
                parser_consume(parser);
            }
            continue;
        }

        // 扩容声明列表
        if (program->data.program.decl_count >= capacity) {
            int new_capacity = capacity == 0 ? 8 : capacity * 2;
            ASTNode **new_decls = realloc(program->data.program.decls,
                                          new_capacity * sizeof(ASTNode*));
            if (!new_decls) {
                ast_free(decl);
                ast_free(program);
                return NULL;
            }
            program->data.program.decls = new_decls;
            capacity = new_capacity;
        }

        program->data.program.decls[program->data.program.decl_count] = decl;
        program->data.program.decl_count++;
    }

    return program;
}
