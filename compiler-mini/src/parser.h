#ifndef PARSER_H
#define PARSER_H

#include "ast.h"
#include "lexer.h"
#include "arena.h"

// 解析上下文类型
typedef enum {
    PARSER_CONTEXT_NORMAL,          // 普通表达式上下文
    PARSER_CONTEXT_VAR_INIT,        // 变量初始化上下文（var/const 声明中的 = 后面的表达式）
    PARSER_CONTEXT_CONDITION        // 条件表达式上下文（if/while 后面的表达式）
} ParserContext;

// 语法分析器结构体
// 使用 Lexer 读取 Token，构建 AST
typedef struct Parser {
    Lexer *lexer;           // 词法分析器指针（由调用者提供，不分配）
    Token *current_token;   // 当前 Token（从 Arena 分配）
    Arena *arena;           // Arena 分配器（用于分配 Token 和 AST 节点）
    ParserContext context;  // 当前解析上下文
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

// 解析声明（函数、结构体或变量声明）
// 参数：parser - Parser 指针
// 返回：声明节点（AST_FN_DECL, AST_STRUCT_DECL, 或 AST_VAR_DECL），失败返回 NULL
ASTNode *parser_parse_declaration(Parser *parser);

// 解析函数声明
// 参数：parser - Parser 指针
// 返回：AST_FN_DECL 节点，失败返回 NULL
ASTNode *parser_parse_function(Parser *parser);

// 解析 extern 函数声明
// 参数：parser - Parser 指针
// 返回：AST_FN_DECL 节点（body 为 NULL），失败返回 NULL
ASTNode *parser_parse_extern_function(Parser *parser);

// 解析结构体声明
// 参数：parser - Parser 指针
// 返回：AST_STRUCT_DECL 节点，失败返回 NULL
ASTNode *parser_parse_struct(Parser *parser);

// 解析枚举声明
// 参数：parser - Parser 指针
// 返回：AST_ENUM_DECL 节点，失败返回 NULL
ASTNode *parser_parse_enum(Parser *parser);

// 解析语句
// 参数：parser - Parser 指针
// 返回：语句节点，失败返回 NULL
ASTNode *parser_parse_statement(Parser *parser);

// 解析表达式（基础版本，会话4将扩展为完整版本）
// 参数：parser - Parser 指针
// 返回：表达式节点，失败返回 NULL
ASTNode *parser_parse_expression(Parser *parser);

#endif // PARSER_H

