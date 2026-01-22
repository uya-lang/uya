#ifndef PARSER_INTERNAL_H
#define PARSER_INTERNAL_H

#include "parser.h"
#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// 辅助函数（在 parser_core.c 中实现）
Token *parser_peek(Parser *parser);
Token *parser_consume(Parser *parser);
int parser_match(Parser *parser, TokenType type);
Token *parser_expect(Parser *parser, TokenType type);

// 类型解析（在 parser_type.c 中实现）
ASTNode *parser_parse_type(Parser *parser);

// 表达式解析（在 parser_expression.c 中实现）
ASTNode *parser_parse_expression(Parser *parser);
ASTNode *parser_parse_comparison_or_higher(Parser *parser);

// Match 和元组解析（在 parser_match.c 中实现）
ASTNode *parser_parse_match_expr(Parser *parser);
ASTNode *parser_parse_tuple_literal(Parser *parser);

// 语句解析（在 parser_statement.c 中实现）
ASTNode *parser_parse_statement(Parser *parser);
ASTNode *parser_parse_if_stmt(Parser *parser);
ASTNode *parser_parse_while_stmt(Parser *parser);
ASTNode *parser_parse_for_stmt(Parser *parser);
ASTNode *parser_parse_block(Parser *parser);
ASTNode *parser_parse_var_decl(Parser *parser);
ASTNode *parser_parse_return_stmt(Parser *parser);
ASTNode *parser_parse_defer_stmt(Parser *parser);
ASTNode *parser_parse_errdefer_stmt(Parser *parser);

// 声明解析（在 parser_declaration.c 中实现）
ASTNode *parser_parse_declaration(Parser *parser);
ASTNode *parser_parse_fn_decl(Parser *parser);
ASTNode *parser_parse_extern_decl(Parser *parser);
ASTNode *parser_parse_struct_decl(Parser *parser);
ASTNode *parser_parse_enum_decl(Parser *parser);
ASTNode *parser_parse_error_decl(Parser *parser);
ASTNode *parser_parse_impl_decl(Parser *parser);
ASTNode *parser_parse_test_block(Parser *parser);
ASTNode *parser_parse_param(Parser *parser);

// 字符串插值解析（在 parser_string_interp.c 中实现）
ASTNode *parser_parse_string_interpolation(Parser *parser, Token *string_token);

// 字符串插值辅助函数（在 parser_string_interp.c 中实现）
Lexer *create_temp_lexer_from_string(const char *expr_str, int line, int col, const char *filename);
FormatSpec parse_format_spec(const char *spec_str);

#endif // PARSER_INTERNAL_H
