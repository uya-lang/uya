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
        if (parser->current_token && (type == 58 || type == 51)) {  // TOKEN_EQUAL 或 TOKEN_PLUS
            void *caller_addr = __builtin_return_address(0);
            fprintf(stderr, "[DEBUG parser_expect] 调用者地址: %p, 期望 %d (TOKEN_EQUAL/TOKEN_PLUS), 实际 %d, 位置 %s:%d:%d\n",
                    caller_addr, type, parser->current_token->type,
                    parser->current_token->filename, parser->current_token->line, parser->current_token->column);
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
