#include "lexer.h"
#include <stdio.h>
#include <string.h>
#include <ctype.h>
#include <stddef.h>

// 初始化 Lexer
int lexer_init(Lexer *lexer, const char *source, size_t source_len, const char *filename, Arena *arena) {
    if (lexer == NULL || source == NULL || arena == NULL) {
        return -1;
    }
    
    // 检查源代码长度是否超过缓冲区大小
    if (source_len >= LEXER_BUFFER_SIZE) {
        return -1;  // 源代码太长
    }
    
    // 复制源代码到缓冲区
    memcpy(lexer->buffer, source, source_len);
    lexer->buffer[source_len] = '\0';
    lexer->buffer_size = source_len;
    
    // 初始化位置信息
    lexer->position = 0;
    lexer->line = 1;
    lexer->column = 1;
    
    // 复制文件名到 Arena
    if (filename != NULL) {
        size_t filename_len = strlen(filename) + 1;
        char *filename_copy = (char *)arena_alloc(arena, filename_len);
        if (filename_copy == NULL) {
            return -1;
        }
        memcpy(filename_copy, filename, filename_len);
        lexer->filename = filename_copy;
    } else {
        lexer->filename = NULL;
    }
    
    return 0;
}

// 辅助函数：查看指定偏移的字符
static char peek_char(const Lexer *lexer, size_t offset) {
    size_t pos = lexer->position + offset;
    if (pos >= lexer->buffer_size) {
        return '\0';
    }
    return lexer->buffer[pos];
}

// 辅助函数：前进一个字符，更新位置信息
static char advance_char(Lexer *lexer) {
    if (lexer->position >= lexer->buffer_size) {
        return '\0';
    }
    
    char c = lexer->buffer[lexer->position];
    lexer->position++;
    
    if (c == '\n') {
        lexer->line++;
        lexer->column = 1;
    } else {
        lexer->column++;
    }
    
    return c;
}

// 跳过空白字符和注释
static void skip_whitespace_and_comments(Lexer *lexer) {
    while (lexer->position < lexer->buffer_size) {
        char c = peek_char(lexer, 0);
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            advance_char(lexer);
        } else if (c == '/' && peek_char(lexer, 1) == '/') {
            // 单行注释：跳过到行尾
            while (lexer->position < lexer->buffer_size && peek_char(lexer, 0) != '\n') {
                advance_char(lexer);
            }
        } else {
            break;
        }
    }
}

// 检查是否为关键字
static TokenType is_keyword(const char *str) {
    if (strcmp(str, "enum") == 0) return TOKEN_ENUM;
    if (strcmp(str, "struct") == 0) return TOKEN_STRUCT;
    if (strcmp(str, "const") == 0) return TOKEN_CONST;
    if (strcmp(str, "var") == 0) return TOKEN_VAR;
    if (strcmp(str, "fn") == 0) return TOKEN_FN;
    if (strcmp(str, "extern") == 0) return TOKEN_EXTERN;
    if (strcmp(str, "return") == 0) return TOKEN_RETURN;
    if (strcmp(str, "if") == 0) return TOKEN_IF;
    if (strcmp(str, "else") == 0) return TOKEN_ELSE;
    if (strcmp(str, "while") == 0) return TOKEN_WHILE;
    if (strcmp(str, "for") == 0) return TOKEN_FOR;
    if (strcmp(str, "break") == 0) return TOKEN_BREAK;
    if (strcmp(str, "continue") == 0) return TOKEN_CONTINUE;
    if (strcmp(str, "true") == 0) return TOKEN_TRUE;
    if (strcmp(str, "false") == 0) return TOKEN_FALSE;
    if (strcmp(str, "null") == 0) return TOKEN_NULL;
    if (strcmp(str, "sizeof") == 0) return TOKEN_SIZEOF;
    if (strcmp(str, "len") == 0) return TOKEN_LEN;
    if (strcmp(str, "alignof") == 0) return TOKEN_ALIGNOF;
    if (strcmp(str, "as") == 0) return TOKEN_AS;
    return TOKEN_IDENTIFIER;  // 不是关键字，是标识符
}

// 从 Arena 复制字符串
static const char *arena_strdup(Arena *arena, const char *start, size_t len) {
    if (arena == NULL || start == NULL) {
        return NULL;
    }
    
    char *result = (char *)arena_alloc(arena, len + 1);
    if (result == NULL) {
        return NULL;
    }
    
    memcpy(result, start, len);
    result[len] = '\0';
    return result;
}

// 创建 Token
static Token *make_token(Arena *arena, TokenType type, const char *value, int line, int column) {
    if (arena == NULL) {
        return NULL;
    }
    
    Token *token = (Token *)arena_alloc(arena, sizeof(Token));
    if (token == NULL) {
        return NULL;
    }
    
    token->type = type;
    token->value = value;  // value 已经在 Arena 中
    token->line = line;
    token->column = column;
    
    return token;
}

// 读取标识符或关键字
static Token *read_identifier_or_keyword(Lexer *lexer, Arena *arena) {
    const char *start = lexer->buffer + lexer->position;
    int line = lexer->line;
    int column = lexer->column;
    
    // 读取标识符字符
    while (lexer->position < lexer->buffer_size) {
        char c = peek_char(lexer, 0);
        if (isalnum((unsigned char)c) || c == '_') {
            advance_char(lexer);
        } else {
            break;
        }
    }
    
    size_t len = (lexer->buffer + lexer->position) - start;
    const char *value = arena_strdup(arena, start, len);
    if (value == NULL) {
        return NULL;
    }
    
    // 检查是否为关键字
    TokenType type = is_keyword(value);
    
    return make_token(arena, type, value, line, column);
}

// 读取数字字面量
static Token *read_number(Lexer *lexer, Arena *arena) {
    const char *start = lexer->buffer + lexer->position;
    int line = lexer->line;
    int column = lexer->column;
    
    // 读取数字（仅支持整数）
    while (lexer->position < lexer->buffer_size) {
        char c = peek_char(lexer, 0);
        if (isdigit((unsigned char)c)) {
            advance_char(lexer);
        } else {
            break;
        }
    }
    
    size_t len = (lexer->buffer + lexer->position) - start;
    const char *value = arena_strdup(arena, start, len);
    if (value == NULL) {
        return NULL;
    }
    
    return make_token(arena, TOKEN_NUMBER, value, line, column);
}

// 读取字符串字面量
// 参数：lexer - Lexer 指针，arena - Arena 分配器
// 返回：字符串字面量 Token，失败返回 NULL
// 注意：Uya Mini 字符串字面量不支持转义序列，仅支持普通字符
static Token *read_string(Lexer *lexer, Arena *arena) {
    int line = lexer->line;
    int column = lexer->column;
    
    // 消费开始的引号
    advance_char(lexer);
    
    const char *start = lexer->buffer + lexer->position;
    
    // 读取字符串内容（直到遇到结束引号）
    while (lexer->position < lexer->buffer_size) {
        char c = peek_char(lexer, 0);
        if (c == '\0') {
            // 文件结束，字符串未闭合
            return NULL;
        }
        if (c == '"') {
            // 遇到结束引号
            break;
        }
        if (c == '\n') {
            // 字符串字面量不能跨行（Uya Mini 不支持转义序列）
            return NULL;
        }
        advance_char(lexer);
    }
    
    // 检查是否找到了结束引号
    if (lexer->position >= lexer->buffer_size || peek_char(lexer, 0) != '"') {
        // 字符串未闭合
        return NULL;
    }
    
    // 计算字符串长度（不包括引号）
    size_t len = (lexer->buffer + lexer->position) - start;
    
    // 复制字符串内容到 Arena（包括 null 终止符）
    const char *value = arena_strdup(arena, start, len);
    if (value == NULL) {
        return NULL;
    }
    
    // 消费结束引号
    advance_char(lexer);
    
    return make_token(arena, TOKEN_STRING, value, line, column);
}

// 获取下一个 Token
Token *lexer_next_token(Lexer *lexer, Arena *arena) {
    if (lexer == NULL || arena == NULL) {
        return NULL;
    }
    
    // 跳过空白字符和注释
    skip_whitespace_and_comments(lexer);
    
    // 检查是否到达文件末尾
    if (lexer->position >= lexer->buffer_size) {
        return make_token(arena, TOKEN_EOF, NULL, lexer->line, lexer->column);
    }
    
    char c = peek_char(lexer, 0);
    int line = lexer->line;
    int column = lexer->column;
    
    // 根据第一个字符判断 Token 类型
    switch (c) {
        case '+':
            advance_char(lexer);
            return make_token(arena, TOKEN_PLUS, "+", line, column);
        case '-':
            advance_char(lexer);
            return make_token(arena, TOKEN_MINUS, "-", line, column);
        case '*':
            advance_char(lexer);
            return make_token(arena, TOKEN_ASTERISK, "*", line, column);
        case '/':
            advance_char(lexer);
            return make_token(arena, TOKEN_SLASH, "/", line, column);
        case '%':
            advance_char(lexer);
            return make_token(arena, TOKEN_PERCENT, "%", line, column);
        case '=':
            advance_char(lexer);
            if (peek_char(lexer, 0) == '=') {
                advance_char(lexer);
                return make_token(arena, TOKEN_EQUAL, "==", line, column);
            }
            return make_token(arena, TOKEN_ASSIGN, "=", line, column);
        case '!':
            advance_char(lexer);
            if (peek_char(lexer, 0) == '=') {
                advance_char(lexer);
                return make_token(arena, TOKEN_NOT_EQUAL, "!=", line, column);
            }
            return make_token(arena, TOKEN_EXCLAMATION, "!", line, column);
        case '<':
            advance_char(lexer);
            if (peek_char(lexer, 0) == '=') {
                advance_char(lexer);
                return make_token(arena, TOKEN_LESS_EQUAL, "<=", line, column);
            }
            return make_token(arena, TOKEN_LESS, "<", line, column);
        case '>':
            advance_char(lexer);
            if (peek_char(lexer, 0) == '=') {
                advance_char(lexer);
                return make_token(arena, TOKEN_GREATER_EQUAL, ">=", line, column);
            }
            return make_token(arena, TOKEN_GREATER, ">", line, column);
        case '&':
            advance_char(lexer);
            if (peek_char(lexer, 0) == '&') {
                advance_char(lexer);
                return make_token(arena, TOKEN_LOGICAL_AND, "&&", line, column);
            }
            // 单个 & 是取地址运算符
            return make_token(arena, TOKEN_AMPERSAND, "&", line, column);
        case '|':
            advance_char(lexer);
            if (peek_char(lexer, 0) == '|') {
                advance_char(lexer);
                return make_token(arena, TOKEN_LOGICAL_OR, "||", line, column);
            }
            // 单个 | 用于 for 循环（for expr | ID | { ... }）
            return make_token(arena, TOKEN_PIPE, "|", line, column);
        case '(':
            advance_char(lexer);
            return make_token(arena, TOKEN_LEFT_PAREN, "(", line, column);
        case ')':
            advance_char(lexer);
            return make_token(arena, TOKEN_RIGHT_PAREN, ")", line, column);
        case '{':
            advance_char(lexer);
            return make_token(arena, TOKEN_LEFT_BRACE, "{", line, column);
        case '}':
            advance_char(lexer);
            return make_token(arena, TOKEN_RIGHT_BRACE, "}", line, column);
        case '[':
            advance_char(lexer);
            return make_token(arena, TOKEN_LEFT_BRACKET, "[", line, column);
        case ']':
            advance_char(lexer);
            return make_token(arena, TOKEN_RIGHT_BRACKET, "]", line, column);
        case ';':
            advance_char(lexer);
            return make_token(arena, TOKEN_SEMICOLON, ";", line, column);
        case ',':
            advance_char(lexer);
            return make_token(arena, TOKEN_COMMA, ",", line, column);
        case '.':
            advance_char(lexer);
            // 检查是否为 ...（可变参数）
            if (peek_char(lexer, 0) == '.' && peek_char(lexer, 1) == '.') {
                advance_char(lexer);  // 消费第二个 .
                advance_char(lexer);  // 消费第三个 .
                return make_token(arena, TOKEN_ELLIPSIS, "...", line, column);
            }
            return make_token(arena, TOKEN_DOT, ".", line, column);
        case ':':
            advance_char(lexer);
            return make_token(arena, TOKEN_COLON, ":", line, column);
        case '"':
            // 字符串字面量
            return read_string(lexer, arena);
        default:
            if (isalpha((unsigned char)c) || c == '_') {
                return read_identifier_or_keyword(lexer, arena);
            } else if (isdigit((unsigned char)c)) {
                return read_number(lexer, arena);
            } else {
                // 未知字符，跳过并返回错误（这里返回 EOF 作为错误标记）
                advance_char(lexer);
                return make_token(arena, TOKEN_EOF, NULL, line, column);
            }
    }
}

