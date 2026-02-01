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
    
    // 字符串插值状态初始化
    lexer->string_mode = 0;
    lexer->interp_depth = 0;
    lexer->pending_interp_open = 0;
    lexer->reading_spec = 0;
    lexer->string_text_len = 0;
    lexer->has_seen_interp_in_string = 0;
    
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
    if (strcmp(str, "interface") == 0) return TOKEN_INTERFACE;
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
    if (strcmp(str, "try") == 0) return TOKEN_TRY;
    if (strcmp(str, "catch") == 0) return TOKEN_CATCH;
    if (strcmp(str, "error") == 0) return TOKEN_ERROR;
    if (strcmp(str, "defer") == 0) return TOKEN_DEFER;
    if (strcmp(str, "errdefer") == 0) return TOKEN_ERRDEFER;
    if (strcmp(str, "as") == 0) return TOKEN_AS;
    if (strcmp(str, "match") == 0) return TOKEN_MATCH;
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
    
    // 检查标识符长度是否合法
    if (len <= 0 || len > 256) {
        fprintf(stderr, "错误: 标识符长度无效 (%zu)\n", len);
        return NULL;
    }
    
    const char *value = arena_strdup(arena, start, len);
    if (value == NULL) {
        fprintf(stderr, "错误: 无法为标识符分配内存\n");
        return NULL;
    }
    
    // 检查是否为关键字
    TokenType type = is_keyword(value);
    
    return make_token(arena, type, value, line, column);
}

// 读取数字字面量（整数或浮点数）
static Token *read_number(Lexer *lexer, Arena *arena) {
    const char *start = lexer->buffer + lexer->position;
    int line = lexer->line;
    int column = lexer->column;
    int is_float = 0;
    
    // 读取整数部分
    while (lexer->position < lexer->buffer_size) {
        char c = peek_char(lexer, 0);
        if (isdigit((unsigned char)c)) {
            advance_char(lexer);
        } else {
            break;
        }
    }
    
    // 检查小数点（若下一个是 '.' 则为范围 ..，不当作小数点）
    if (peek_char(lexer, 0) == '.' && peek_char(lexer, 1) != '.') {
        advance_char(lexer);
        is_float = 1;
        while (lexer->position < lexer->buffer_size) {
            char c = peek_char(lexer, 0);
            if (isdigit((unsigned char)c)) {
                advance_char(lexer);
            } else {
                break;
            }
        }
    }
    
    // 检查指数部分 (e/E [+-]? digits)
    if (!is_float && (peek_char(lexer, 0) == 'e' || peek_char(lexer, 0) == 'E')) {
        is_float = 1;
    }
    if (peek_char(lexer, 0) == 'e' || peek_char(lexer, 0) == 'E') {
        advance_char(lexer);
        is_float = 1;
        if (peek_char(lexer, 0) == '+' || peek_char(lexer, 0) == '-') {
            advance_char(lexer);
        }
        if (!isdigit((unsigned char)peek_char(lexer, 0))) {
            return NULL;  /* 指数后必须有数字 */
        }
        while (lexer->position < lexer->buffer_size) {
            char c = peek_char(lexer, 0);
            if (isdigit((unsigned char)c)) {
                advance_char(lexer);
            } else {
                break;
            }
        }
    }
    
    size_t len = (lexer->buffer + lexer->position) - start;
    const char *value = arena_strdup(arena, start, len);
    if (value == NULL) {
        return NULL;
    }
    
    return make_token(arena, is_float ? TOKEN_FLOAT : TOKEN_NUMBER, value, line, column);
}

// 在字符串插值模式下读取一个逻辑字符（处理转义），追加到 string_text_buffer，成功返回 0，失败返回 -1
static int read_string_char_into_buffer(Lexer *lexer) {
    if (lexer->position >= lexer->buffer_size) {
        return -1;
    }
    char c = peek_char(lexer, 0);
    if (c == '\\') {
        advance_char(lexer);
        if (lexer->position >= lexer->buffer_size) {
            return -1;
        }
        char e = peek_char(lexer, 0);
        char escaped;
        switch (e) {
            case 'n': escaped = '\n'; break;
            case 't': escaped = '\t'; break;
            case '\\': escaped = '\\'; break;
            case '"': escaped = '"'; break;
            case '0': escaped = '\0'; break;
            default: return -1;
        }
        if (lexer->string_text_len >= LEXER_STRING_INTERP_BUFFER_SIZE - 1) {
            return -1;
        }
        lexer->string_text_buffer[lexer->string_text_len++] = escaped;
        advance_char(lexer);
        return 0;
    }
    if (lexer->string_text_len >= LEXER_STRING_INTERP_BUFFER_SIZE - 1) {
        return -1;
    }
    lexer->string_text_buffer[lexer->string_text_len++] = c;
    advance_char(lexer);
    return 0;
}

// 获取下一个 Token
Token *lexer_next_token(Lexer *lexer, Arena *arena) {
    if (lexer == NULL || arena == NULL) {
        return NULL;
    }
    
    int line = lexer->line;
    int column = lexer->column;
    
top_of_token:
    // ----- 字符串插值 / 插值内部状态：优先于空白与普通 switch -----
    if (lexer->reading_spec) {
        lexer->string_text_len = 0;
        while (lexer->position < lexer->buffer_size && peek_char(lexer, 0) != '}') {
            if (lexer->string_text_len >= LEXER_STRING_INTERP_BUFFER_SIZE - 1) {
                return NULL;
            }
            lexer->string_text_buffer[lexer->string_text_len++] = peek_char(lexer, 0);
            advance_char(lexer);
        }
        if (lexer->position >= lexer->buffer_size || peek_char(lexer, 0) != '}') {
            return NULL;
        }
        lexer->string_text_buffer[lexer->string_text_len] = '\0';
        const char *spec_value = arena_strdup(arena, lexer->string_text_buffer, lexer->string_text_len);
        if (spec_value == NULL) {
            return NULL;
        }
        advance_char(lexer);  /* 消费 } */
        lexer->interp_depth = 0;
        lexer->reading_spec = 0;
        lexer->pending_interp_open = 0;  /* 插值段结束，避免下一 token 误走 pending_interp_open */
        return make_token(arena, TOKEN_INTERP_SPEC, spec_value, line, column);
    }
    
    if (lexer->pending_interp_open) {
        if (lexer->position + 2 > lexer->buffer_size ||
            peek_char(lexer, 0) != '$' || peek_char(lexer, 1) != '{') {
            return NULL;
        }
        advance_char(lexer);
        advance_char(lexer);
        lexer->pending_interp_open = 0;
        lexer->interp_depth = 1;
        return make_token(arena, TOKEN_INTERP_OPEN, NULL, line, column);
    }
    
    if (lexer->interp_depth > 0) {
        char p = peek_char(lexer, 0);
        if (p == '}') {
            advance_char(lexer);
            lexer->interp_depth = 0;
            return make_token(arena, TOKEN_INTERP_CLOSE, NULL, lexer->line, lexer->column);
        }
        if (p == ':') {
            advance_char(lexer);
            lexer->reading_spec = 1;
            lexer->string_text_len = 0;
            while (lexer->position < lexer->buffer_size && peek_char(lexer, 0) != '}') {
                if (lexer->string_text_len >= LEXER_STRING_INTERP_BUFFER_SIZE - 1) {
                    return NULL;
                }
                lexer->string_text_buffer[lexer->string_text_len++] = peek_char(lexer, 0);
                advance_char(lexer);
            }
            if (lexer->position >= lexer->buffer_size || peek_char(lexer, 0) != '}') {
                return NULL;
            }
            lexer->string_text_buffer[lexer->string_text_len] = '\0';
            const char *spec_value = arena_strdup(arena, lexer->string_text_buffer, lexer->string_text_len);
            if (spec_value == NULL) {
                return NULL;
            }
            advance_char(lexer);
            lexer->interp_depth = 0;
            lexer->pending_interp_open = 0;  /* 同上 */
            lexer->reading_spec = 0;  /* 避免下次 next_token 误入 reading_spec 分支再返回错误 INTERP_SPEC */
            return make_token(arena, TOKEN_INTERP_SPEC, spec_value, line, column);
        }
    }
    
    if (lexer->string_mode && lexer->interp_depth == 0) {
        /* 每段新文本开始时清空缓冲，避免 INTERP_SPEC/INTERP_CLOSE 后的残留 */
        lexer->string_text_len = 0;
        while (lexer->position < lexer->buffer_size) {
            char p = peek_char(lexer, 0);
            if (p == '"') {
                if (!lexer->has_seen_interp_in_string) {
                    lexer->string_text_buffer[lexer->string_text_len] = '\0';
                    const char *value = arena_strdup(arena, lexer->string_text_buffer, lexer->string_text_len);
                    if (value == NULL) {
                        return NULL;
                    }
                    advance_char(lexer);
                    lexer->string_mode = 0;
                    return make_token(arena, TOKEN_STRING, value, line, column);
                }
                if (lexer->string_text_len > 0) {
                    lexer->string_text_buffer[lexer->string_text_len] = '\0';
                    const char *value = arena_strdup(arena, lexer->string_text_buffer, lexer->string_text_len);
                    if (value == NULL) {
                        return NULL;
                    }
                    lexer->string_text_len = 0;
                    return make_token(arena, TOKEN_INTERP_TEXT, value, line, column);
                }
                advance_char(lexer);
                lexer->string_mode = 0;
                lexer->has_seen_interp_in_string = 0;
                return make_token(arena, TOKEN_INTERP_END, NULL, lexer->line, lexer->column);
            }
            if (p == '$' && peek_char(lexer, 1) == '{') {
                lexer->has_seen_interp_in_string = 1;
                lexer->pending_interp_open = 1;
                lexer->string_text_buffer[lexer->string_text_len] = '\0';
                const char *value = arena_strdup(arena, lexer->string_text_buffer, lexer->string_text_len);
                if (value == NULL) {
                    return NULL;
                }
                lexer->string_text_len = 0;
                return make_token(arena, TOKEN_INTERP_TEXT, value, line, column);
            }
            if (read_string_char_into_buffer(lexer) != 0) {
                return NULL;
            }
        }
        return NULL;  /* 字符串未闭合 */
    }
    
    // 跳过空白字符和注释
    skip_whitespace_and_comments(lexer);
    
    // 检查是否到达文件末尾
    if (lexer->position >= lexer->buffer_size) {
        return make_token(arena, TOKEN_EOF, NULL, lexer->line, lexer->column);
    }
    
    char c = peek_char(lexer, 0);
    line = lexer->line;
    column = lexer->column;
    
    /* 在插值外部，} 为普通 TOKEN_RIGHT_BRACE；在 interp_depth>0 时已在上面处理 */
    
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
            if (peek_char(lexer, 0) == '>') {
                advance_char(lexer);
                return make_token(arena, TOKEN_FAT_ARROW, "=>", line, column);
            }
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
            if (peek_char(lexer, 0) == '<') {
                advance_char(lexer);
                return make_token(arena, TOKEN_LSHIFT, "<<", line, column);
            }
            if (peek_char(lexer, 0) == '=') {
                advance_char(lexer);
                return make_token(arena, TOKEN_LESS_EQUAL, "<=", line, column);
            }
            return make_token(arena, TOKEN_LESS, "<", line, column);
        case '>':
            advance_char(lexer);
            if (peek_char(lexer, 0) == '>') {
                advance_char(lexer);
                return make_token(arena, TOKEN_RSHIFT, ">>", line, column);
            }
            if (peek_char(lexer, 0) == '=') {
                advance_char(lexer);
                return make_token(arena, TOKEN_GREATER_EQUAL, ">=", line, column);
            }
            return make_token(arena, TOKEN_GREATER, ">", line, column);
        case '^':
            advance_char(lexer);
            return make_token(arena, TOKEN_CARET, "^", line, column);
        case '~':
            advance_char(lexer);
            return make_token(arena, TOKEN_TILDE, "~", line, column);
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
            // 检查是否为 ..（范围，用于 for start..end）
            if (peek_char(lexer, 0) == '.') {
                advance_char(lexer);
                return make_token(arena, TOKEN_DOT_DOT, "..", line, column);
            }
            return make_token(arena, TOKEN_DOT, ".", line, column);
        case ':':
            advance_char(lexer);
            return make_token(arena, TOKEN_COLON, ":", line, column);
        case '@':
            advance_char(lexer);
            // @ 后必须是标识符（内置函数名）
            if (isalpha((unsigned char)peek_char(lexer, 0)) || peek_char(lexer, 0) == '_') {
                const char *start = lexer->buffer + lexer->position;
                while (lexer->position < lexer->buffer_size) {
                    char c = peek_char(lexer, 0);
                    if (isalnum((unsigned char)c) || c == '_') {
                        advance_char(lexer);
                    } else {
                        break;
                    }
                }
                size_t len = (lexer->buffer + lexer->position) - start;
                if (len <= 0 || len > 256) {
                    fprintf(stderr, "错误: @ 后标识符长度无效 (%zu)\n", len);
                    return NULL;
                }
                const char *value = arena_strdup(arena, start, len);
                if (value == NULL) {
                    fprintf(stderr, "错误: 无法为 @ 标识符分配内存\n");
                    return NULL;
                }
                // 仅接受已知内置函数与内置变量
                if (strcmp(value, "sizeof") == 0 || strcmp(value, "alignof") == 0 ||
                    strcmp(value, "len") == 0 || strcmp(value, "max") == 0 || strcmp(value, "min") == 0 ||
                    strcmp(value, "params") == 0) {
                    return make_token(arena, TOKEN_AT_IDENTIFIER, value, line, column);
                }
                fprintf(stderr, "错误: 未知内置 @%s，支持：@sizeof、@alignof、@len、@max、@min、@params\n", value);
                return NULL;
            }
            fprintf(stderr, "错误: @ 后必须是标识符\n");
            return NULL;
        case '"': {
            advance_char(lexer);
            lexer->string_mode = 1;
            lexer->has_seen_interp_in_string = 0;
            lexer->string_text_len = 0;
            goto top_of_token;
        }
        default:
            if (isalpha((unsigned char)c) || c == '_') {
                return read_identifier_or_keyword(lexer, arena);
            } else if (isdigit((unsigned char)c)) {
                return read_number(lexer, arena);
            } else {
                // 未知字符，输出错误信息并返回 EOF 作为错误标记
                const char *filename = lexer->filename ? lexer->filename : "<unknown>";
                fprintf(stderr, "错误: 词法分析失败 (%s:%d:%d): 未知字符 '", filename, line, column);
                if (isprint((unsigned char)c)) {
                    fprintf(stderr, "%c", c);
                } else {
                    fprintf(stderr, "\\x%02x", (unsigned char)c);
                }
                fprintf(stderr, "' (ASCII %d)\n", (unsigned char)c);
                fprintf(stderr, "提示: Uya Mini 不支持此字符。如果是三元运算符 '?'，请使用 if-else 语句替代。\n");
                advance_char(lexer);
                return make_token(arena, TOKEN_EOF, NULL, line, column);
            }
    }
}

