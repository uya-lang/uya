#ifndef LEXER_H
#define LEXER_H

#include "arena.h"
#include <stddef.h>
#include <stdint.h>

// 条件编译，避免与Windows的TokenType冲突
#ifdef _WIN32
    #undef TokenType
    #undef TOKEN_TYPE
#endif

// Token 类型枚举
// Uya Mini 仅包含最小子集需要的 Token 类型
typedef enum {
    // 基础 Token
    TOKEN_EOF,          // 文件结束
    TOKEN_IDENTIFIER,   // 标识符
    TOKEN_NUMBER,       // 数字字面量
    
    // 关键字
    TOKEN_STRUCT,       // struct
    TOKEN_CONST,        // const
    TOKEN_VAR,          // var
    TOKEN_FN,           // fn
    TOKEN_EXTERN,       // extern
    TOKEN_RETURN,       // return
    TOKEN_IF,           // if
    TOKEN_ELSE,         // else
    TOKEN_WHILE,        // while
    TOKEN_FOR,          // for
    TOKEN_BREAK,        // break
    TOKEN_CONTINUE,     // continue
    TOKEN_TRUE,         // true
    TOKEN_FALSE,        // false
    TOKEN_NULL,         // null（空指针字面量）
    TOKEN_SIZEOF,       // sizeof
    TOKEN_LEN,          // len
    TOKEN_AS,           // as（类型转换关键字）
    
    // 运算符
    TOKEN_PLUS,         // +
    TOKEN_MINUS,        // -
    TOKEN_ASTERISK,     // *
    TOKEN_SLASH,        // /
    TOKEN_PERCENT,      // %
    TOKEN_EQUAL,        // ==
    TOKEN_NOT_EQUAL,    // !=
    TOKEN_LESS,         // <
    TOKEN_GREATER,      // >
    TOKEN_LESS_EQUAL,   // <=
    TOKEN_GREATER_EQUAL,// >=
    TOKEN_LOGICAL_AND,  // &&
    TOKEN_LOGICAL_OR,   // ||
    TOKEN_EXCLAMATION,  // !
    TOKEN_AMPERSAND,    // &（取地址运算符）
    
    // 标点符号
    TOKEN_LEFT_PAREN,   // (
    TOKEN_RIGHT_PAREN,  // )
    TOKEN_LEFT_BRACE,   // {
    TOKEN_RIGHT_BRACE,  // }
    TOKEN_LEFT_BRACKET, // [
    TOKEN_RIGHT_BRACKET,// ]
    TOKEN_SEMICOLON,    // ;
    TOKEN_COMMA,        // ,
    TOKEN_ASSIGN,       // =
    TOKEN_DOT,          // .
    TOKEN_COLON,        // :
    TOKEN_PIPE,         // |（用于 for 循环）
} TokenType;

// Token 结构体
// 字符串值存储在 Arena 中，不分配堆内存
typedef struct Token {
    TokenType type;         // Token 类型
    const char *value;      // Token 值（字符串，存储在 Arena 中，可为 NULL）
    int line;               // 行号
    int column;             // 列号
} Token;

// Lexer 结构体
// 使用固定大小缓冲区，不分配堆内存
#define LEXER_BUFFER_SIZE (1024 * 1024)  // 1MB 缓冲区大小

typedef struct Lexer {
    char buffer[LEXER_BUFFER_SIZE];  // 源代码缓冲区（固定大小数组）
    size_t buffer_size;              // 缓冲区实际大小（字节数）
    size_t position;                 // 当前读取位置
    int line;                        // 当前行号（从1开始）
    int column;                      // 当前列号（从1开始）
    const char *filename;            // 文件名（存储在 Arena 中，可为 NULL）
} Lexer;

// 初始化 Lexer
// 参数：lexer - Lexer 结构体指针（由调用者提供，栈上或静态分配），source - 源代码字符串，source_len - 源代码长度，filename - 文件名（存储在 Arena 中），arena - Arena 分配器
// 返回：成功返回 0，失败返回 -1
// 注意：Lexer 结构体由调用者在栈上或静态分配，此函数只负责初始化
int lexer_init(Lexer *lexer, const char *source, size_t source_len, const char *filename, Arena *arena);

// 获取下一个 Token
// 参数：lexer - Lexer 指针，arena - Arena 分配器（用于存储 Token 和字符串值）
// 返回：下一个 Token 指针（从 Arena 分配），文件结束返回 TOKEN_EOF 类型的 Token
Token *lexer_next_token(Lexer *lexer, Arena *arena);

#endif // LEXER_H

