#ifndef PARSER_H
#define PARSER_H

#include "ast.h"
#include "lexer.h"
#include "arena.h"

// 语法分析器结构体
// 使用 Lexer 读取 Token，构建 AST
typedef struct Parser {
    Lexer *lexer;           // 词法分析器指针（由调用者提供，不分配）
    Token *current_token;   // 当前 Token（从 Arena 分配）
    Arena *arena;           // Arena 分配器（用于分配 Token 和 AST 节点）
} Parser;

// 初始化 Parser
// 参数：parser - Parser 结构体指针（由调用者提供），lexer - Lexer 指针，arena - Arena 分配器
// 返回：成功返回 0，失败返回 -1
// 注意：Parser 结构体由调用者在栈上或静态分配，此函数只负责初始化
int parser_init(Parser *parser, Lexer *lexer, Arena *arena);

// 解析程序（顶层声明列表）
// 参数：parser - Parser 指针
// 返回：AST_PROGRAM 节点，失败返回 NULL
ASTNode *parser_parse(Parser *parser);

#endif // PARSER_H

