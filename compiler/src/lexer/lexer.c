#include "lexer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

// 读取整个文件到缓冲区
static char *read_file(const char *filename) {
    FILE *file = fopen(filename, "r");
    if (!file) {
        return NULL;
    }
    
    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);
    
    char *buffer = malloc(length + 1);
    if (!buffer) {
        fclose(file);
        return NULL;
    }
    
    fread(buffer, 1, length, file);
    buffer[length] = '\0';
    
    fclose(file);
    return buffer;
}

Lexer *lexer_new(const char *filename) {
    Lexer *lexer = malloc(sizeof(Lexer));
    if (!lexer) {
        return NULL;
    }
    
    lexer->filename = malloc(strlen(filename) + 1);
    if (!lexer->filename) {
        free(lexer);
        return NULL;
    }
    strcpy(lexer->filename, filename);
    
    lexer->buffer = read_file(filename);
    if (!lexer->buffer) {
        free(lexer->filename);
        free(lexer);
        return NULL;
    }
    
    lexer->buffer_size = strlen(lexer->buffer);
    lexer->position = 0;
    lexer->line = 1;
    lexer->column = 1;
    
    return lexer;
}

void lexer_free(Lexer *lexer) {
    if (lexer) {
        if (lexer->buffer) {
            free(lexer->buffer);
        }
        if (lexer->filename) {
            free(lexer->filename);
        }
        free(lexer);
    }
}

static char peek(Lexer *lexer, int offset) {
    size_t pos = lexer->position + offset;
    if (pos >= lexer->buffer_size) {
        return '\0';
    }
    return lexer->buffer[pos];
}

static char advance(Lexer *lexer) {
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

static void skip_whitespace(Lexer *lexer) {
    while (lexer->position < lexer->buffer_size) {
        char c = peek(lexer, 0);
        if (c == ' ' || c == '\t' || c == '\r' || c == '\n') {
            advance(lexer);
        } else if (c == '/' && peek(lexer, 1) == '/') {
            // 单行注释
            while (lexer->position < lexer->buffer_size && peek(lexer, 0) != '\n') {
                advance(lexer);
            }
        } else if (c == '/' && peek(lexer, 1) == '*') {
            // 多行注释
            advance(lexer); // '/'
            advance(lexer); // '*'
            while (lexer->position < lexer->buffer_size) {
                if (peek(lexer, 0) == '*' && peek(lexer, 1) == '/') {
                    advance(lexer); // '*'
                    advance(lexer); // '/'
                    break;
                }
                advance(lexer);
            }
        } else {
            break;
        }
    }
}

static char *make_token_value(const char *start, size_t len) {
    char *value = malloc(len + 1);
    if (!value) {
        return NULL;
    }
    strncpy(value, start, len);
    value[len] = '\0';
    return value;
}

static Token *create_token(TokenType type, const char *value, int line, int column, const char *filename) {
    Token *token = malloc(sizeof(Token));
    if (!token) {
        return NULL;
    }
    
    token->type = type;
    token->value = malloc(strlen(value) + 1);
    if (!token->value) {
        free(token);
        return NULL;
    }
    strcpy(token->value, value);
    token->line = line;
    token->column = column;
    token->filename = malloc(strlen(filename) + 1);
    if (!token->filename) {
        free(token->value);
        free(token);
        return NULL;
    }
    strcpy(token->filename, filename);
    
    return token;
}

static Token *make_token(Lexer *lexer, TokenType type, const char *value) {
    return create_token(type, value, lexer->line, lexer->column, lexer->filename);
}

static int is_keyword(const char *str) {
    if (strcmp(str, "struct") == 0) return TOKEN_STRUCT;
    if (strcmp(str, "let") == 0) return TOKEN_LET;
    if (strcmp(str, "mut") == 0) return TOKEN_MUT;
    if (strcmp(str, "const") == 0) return TOKEN_CONST;
    if (strcmp(str, "fn") == 0) return TOKEN_FN;
    if (strcmp(str, "return") == 0) return TOKEN_RETURN;
    if (strcmp(str, "extern") == 0) return TOKEN_EXTERN;
    if (strcmp(str, "true") == 0) return TOKEN_TRUE;
    if (strcmp(str, "false") == 0) return TOKEN_FALSE;
    if (strcmp(str, "if") == 0) return TOKEN_IF;
    if (strcmp(str, "else") == 0) return TOKEN_ELSE;
    if (strcmp(str, "for") == 0) return TOKEN_FOR;
    if (strcmp(str, "while") == 0) return TOKEN_WHILE;
    if (strcmp(str, "break") == 0) return TOKEN_BREAK;
    if (strcmp(str, "continue") == 0) return TOKEN_CONTINUE;
    if (strcmp(str, "defer") == 0) return TOKEN_DEFER;
    if (strcmp(str, "errdefer") == 0) return TOKEN_ERRDEFER;
    if (strcmp(str, "try") == 0) return TOKEN_TRY;
    if (strcmp(str, "catch") == 0) return TOKEN_CATCH;
    if (strcmp(str, "error") == 0) return TOKEN_ERROR;
    if (strcmp(str, "null") == 0) return TOKEN_NULL;
    if (strcmp(str, "interface") == 0) return TOKEN_INTERFACE;
    if (strcmp(str, "impl") == 0) return TOKEN_IMPL;
    if (strcmp(str, "atomic") == 0) return TOKEN_ATOMIC;
    if (strcmp(str, "max") == 0) return TOKEN_MAX;
    if (strcmp(str, "min") == 0) return TOKEN_MIN;
    if (strcmp(str, "as") == 0) return TOKEN_AS;
    if (strcmp(str, "as!") == 0) return TOKEN_AS_EXCLAMATION;
    if (strcmp(str, "type") == 0) return TOKEN_TYPE;
    if (strcmp(str, "mc") == 0) return TOKEN_MC;
    return 0;
}

static Token *read_identifier_or_keyword(Lexer *lexer) {
    const char *start = lexer->buffer + lexer->position;
    int line = lexer->line;
    int column = lexer->column;
    
    // 读取标识符
    while (lexer->position < lexer->buffer_size) {
        char c = peek(lexer, 0);
        if (isalnum(c) || c == '_') {
            advance(lexer);
        } else {
            break;
        }
    }
    
    size_t len = (lexer->buffer + lexer->position) - start;
    char *ident = make_token_value(start, len);
    if (!ident) {
        return NULL;
    }
    
    // 检查是否为关键字
    int keyword_type = is_keyword(ident);
    if (keyword_type) {
        Token *token = make_token(lexer, keyword_type, ident);
        free(ident);
        return token;
    }
    
    Token *token = make_token(lexer, TOKEN_IDENTIFIER, ident);
    free(ident);
    return token;
}

static Token *read_number(Lexer *lexer) {
    const char *start = lexer->buffer + lexer->position;
    int line = lexer->line;
    int column = lexer->column;
    
    // 读取数字（整数或浮点数）
    while (lexer->position < lexer->buffer_size) {
        char c = peek(lexer, 0);
        if (isdigit(c) || c == '.') {
            advance(lexer);
        } else {
            break;
        }
    }
    
    size_t len = (lexer->buffer + lexer->position) - start;
    char *num = make_token_value(start, len);
    if (!num) {
        return NULL;
    }
    
    Token *token = make_token(lexer, TOKEN_NUMBER, num);
    free(num);
    return token;
}

static Token *read_string(Lexer *lexer) {
    const char *start = lexer->buffer + lexer->position;
    int line = lexer->line;
    int column = lexer->column;
    
    advance(lexer); // 跳过开始的引号
    
    while (lexer->position < lexer->buffer_size) {
        char c = advance(lexer);
        if (c == '"') {
            break;
        } else if (c == '\\') {
            advance(lexer); // 跳过转义字符
        }
    }
    
    size_t len = (lexer->buffer + lexer->position) - start;
    char *str = make_token_value(start, len);
    if (!str) {
        return NULL;
    }
    
    Token *token = make_token(lexer, TOKEN_STRING, str);
    free(str);
    return token;
}

Token *lexer_next_token(Lexer *lexer) {
    skip_whitespace(lexer);
    
    if (lexer->position >= lexer->buffer_size) {
        return make_token(lexer, TOKEN_EOF, "");
    }
    
    char c = peek(lexer, 0);
    int line = lexer->line;
    int column = lexer->column;
    
    switch (c) {
        case '+':
            advance(lexer);
            return make_token(lexer, TOKEN_PLUS, "+");
        case '-':
            advance(lexer);
            if (peek(lexer, 0) == '>') {
                advance(lexer);
                return make_token(lexer, TOKEN_ARROW, "=>");
            }
            return make_token(lexer, TOKEN_MINUS, "-");
        case '*':
            advance(lexer);
            return make_token(lexer, TOKEN_ASTERISK, "*");
        case '/':
            advance(lexer);
            return make_token(lexer, TOKEN_SLASH, "/");
        case '%':
            advance(lexer);
            return make_token(lexer, TOKEN_PERCENT, "%");
        case '=':
            advance(lexer);
            if (peek(lexer, 0) == '=') {
                advance(lexer);
                return make_token(lexer, TOKEN_EQUAL, "==");
            }
            return make_token(lexer, TOKEN_ASSIGN, "=");
        case '!':
            advance(lexer);
            if (peek(lexer, 0) == '=') {
                advance(lexer);
                return make_token(lexer, TOKEN_NOT_EQUAL, "!=");
            }
            return make_token(lexer, TOKEN_EXCLAMATION, "!");
        case '<':
            advance(lexer);
            if (peek(lexer, 0) == '=') {
                advance(lexer);
                return make_token(lexer, TOKEN_LESS_EQUAL, "<=");
            } else if (peek(lexer, 0) == '<') {
                advance(lexer);
                return make_token(lexer, TOKEN_LEFT_SHIFT, "<<");
            }
            return make_token(lexer, TOKEN_LESS, "<");
        case '>':
            advance(lexer);
            if (peek(lexer, 0) == '=') {
                advance(lexer);
                return make_token(lexer, TOKEN_GREATER_EQUAL, ">=");
            } else if (peek(lexer, 0) == '>') {
                advance(lexer);
                return make_token(lexer, TOKEN_RIGHT_SHIFT, ">>");
            }
            return make_token(lexer, TOKEN_GREATER, ">");
        case '&':
            advance(lexer);
            if (peek(lexer, 0) == '&') {
                advance(lexer);
                return make_token(lexer, TOKEN_LOGICAL_AND, "&&");
            }
            return make_token(lexer, TOKEN_AMPERSAND, "&");
        case '|':
            advance(lexer);
            if (peek(lexer, 0) == '|') {
                advance(lexer);
                return make_token(lexer, TOKEN_LOGICAL_OR, "||");
            }
            return make_token(lexer, TOKEN_PIPE, "|");
        case '^':
            advance(lexer);
            return make_token(lexer, TOKEN_CARET, "^");
        case '~':
            advance(lexer);
            return make_token(lexer, TOKEN_TILDE, "~");
        case '(':
            advance(lexer);
            return make_token(lexer, TOKEN_LEFT_PAREN, "(");
        case ')':
            advance(lexer);
            return make_token(lexer, TOKEN_RIGHT_PAREN, ")");
        case '{':
            advance(lexer);
            return make_token(lexer, TOKEN_LEFT_BRACE, "{");
        case '}':
            advance(lexer);
            return make_token(lexer, TOKEN_RIGHT_BRACE, "}");
        case '[':
            advance(lexer);
            return make_token(lexer, TOKEN_LEFT_BRACKET, "[");
        case ']':
            advance(lexer);
            return make_token(lexer, TOKEN_RIGHT_BRACKET, "]");
        case ';':
            advance(lexer);
            return make_token(lexer, TOKEN_SEMICOLON, ";");
        case ',':
            advance(lexer);
            return make_token(lexer, TOKEN_COMMA, ",");
        case '.':
            advance(lexer);
            if (peek(lexer, 0) == '.') {
                advance(lexer);
                if (peek(lexer, 0) == '.') {
                    advance(lexer);
                    return make_token(lexer, TOKEN_ELLIPSIS, "...");
                }
                return make_token(lexer, TOKEN_RANGE, "..");
            }
            return make_token(lexer, TOKEN_DOT, ".");
        case ':':
            advance(lexer);
            return make_token(lexer, TOKEN_COLON, ":");
        case '"':
            return read_string(lexer);
        default:
            if (isalpha(c) || c == '_') {
                return read_identifier_or_keyword(lexer);
            } else if (isdigit(c)) {
                return read_number(lexer);
            } else {
                advance(lexer);
                char temp[2] = {c, '\0'};
                return make_token(lexer, TOKEN_EOF, temp); // 错误处理
            }
    }
}

void token_free(Token *token) {
    if (token) {
        if (token->value) {
            free(token->value);
        }
        if (token->filename) {
            free(token->filename);
        }
        free(token);
    }
}