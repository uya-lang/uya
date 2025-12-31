#ifndef LEXER_H
#define LEXER_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// Token 类型枚举
typedef enum {
    TOKEN_EOF,
    TOKEN_IDENTIFIER,
    TOKEN_NUMBER,
    TOKEN_STRING,
    TOKEN_CHAR,
    
    // 关键字
    TOKEN_STRUCT,
    TOKEN_LET,
    TOKEN_MUT,
    TOKEN_CONST,
    TOKEN_VAR,
    TOKEN_FN,
    TOKEN_RETURN,
    TOKEN_EXTERN,
    TOKEN_TRUE,
    TOKEN_FALSE,
    TOKEN_IF,
    TOKEN_ELSE,
    TOKEN_FOR,
    TOKEN_WHILE,
    TOKEN_BREAK,
    TOKEN_CONTINUE,
    TOKEN_DEFER,
    TOKEN_ERRDEFER,
    TOKEN_TRY,
    TOKEN_CATCH,
    TOKEN_ERROR,
    TOKEN_NULL,
    TOKEN_INTERFACE,
    TOKEN_IMPL,
    TOKEN_ATOMIC,
    TOKEN_MAX,
    TOKEN_MIN,
    TOKEN_AS,
    TOKEN_AS_EXCLAMATION,
    TOKEN_TYPE,
    TOKEN_MC,
    
    // 运算符
    TOKEN_PLUS,
    TOKEN_MINUS,
    TOKEN_ASTERISK,
    TOKEN_SLASH,
    TOKEN_PERCENT,
    TOKEN_ASSIGN,
    TOKEN_EQUAL,
    TOKEN_NOT_EQUAL,
    TOKEN_LESS,
    TOKEN_LESS_EQUAL,
    TOKEN_GREATER,
    TOKEN_GREATER_EQUAL,
    TOKEN_LEFT_PAREN,
    TOKEN_RIGHT_PAREN,
    TOKEN_LEFT_BRACE,
    TOKEN_RIGHT_BRACE,
    TOKEN_LEFT_BRACKET,
    TOKEN_RIGHT_BRACKET,
    TOKEN_SEMICOLON,
    TOKEN_COMMA,
    TOKEN_DOT,
    TOKEN_COLON,
    TOKEN_EXCLAMATION,
    TOKEN_AMPERSAND,
    TOKEN_PIPE,
    TOKEN_CARET,
    TOKEN_TILDE,
    TOKEN_LEFT_SHIFT,
    TOKEN_RIGHT_SHIFT,
    TOKEN_LOGICAL_AND,
    TOKEN_LOGICAL_OR,
    
    // 特殊符号
    TOKEN_ARROW,      // =>
    TOKEN_ELLIPSIS,   // ...
    TOKEN_RANGE,      // ..
} TokenType;

// Token 结构
typedef struct {
    TokenType type;
    char *value;
    int line;
    int column;
    char *filename;
} Token;

// 词法分析器结构
typedef struct Lexer {
    char *buffer;
    size_t buffer_size;
    size_t position;
    int line;
    int column;
    char *filename;
} Lexer;

// 词法分析器函数
Lexer *lexer_new(const char *filename);
void lexer_free(Lexer *lexer);
Token *lexer_next_token(Lexer *lexer);
void token_free(Token *token);

#endif