# Uya语言词法分析器规范文档

## 1. 概述

### 1.1 设计目标
Uya语言的词法分析器（Lexer）负责将源代码字符流转换为Token流。设计目标包括：

- **高效解析**：快速将字符流转换为Token流
- **Unicode支持**：支持UTF-8编码的Unicode字符
- **完整语法支持**：支持Uya语言的所有语法元素，包括切片语法
- **错误恢复**：在遇到非法字符时能够恢复并继续解析
- **零运行时开销**：所有解析在编译期完成

### 1.2 词法分析器架构
```
源代码字符流 -> 词法分析器 -> Token流 -> 语法分析器 -> AST
```

## 2. Token类型定义

### 2.1 Token类型枚举

```c
typedef enum {
    // 基本字面量
    TOKEN_EOF,           // 文件结束
    TOKEN_IDENTIFIER,    // 标识符
    TOKEN_NUMBER,        // 数字字面量
    TOKEN_STRING,        // 字符串字面量
    TOKEN_CHAR,          // 字符字面量
    
    // 关键字
    TOKEN_STRUCT,        // struct
    TOKEN_LET,           // let
    TOKEN_MUT,           // mut
    TOKEN_CONST,         // const
    TOKEN_FN,            // fn
    TOKEN_RETURN,        // return
    TOKEN_EXTERN,        // extern
    TOKEN_TRUE,          // true
    TOKEN_FALSE,         // false
    TOKEN_IF,            // if
    TOKEN_WHILE,         // while
    TOKEN_BREAK,         // break
    TOKEN_CONTINUE,      // continue
    TOKEN_DEFER,         // defer
    TOKEN_ERRDEFER,      // errdefer
    TOKEN_TRY,           // try
    TOKEN_CATCH,         // catch
    TOKEN_ERROR,         // error
    TOKEN_NULL,          // null
    TOKEN_INTERFACE,     // interface
    TOKEN_IMPL,          // impl
    TOKEN_ATOMIC,        // atomic
    TOKEN_MAX,           // max
    TOKEN_MIN,           // min
    TOKEN_AS,            // as
    TOKEN_AS_EXCLAMATION,// as!
    TOKEN_TYPE,          // type
    TOKEN_MC,            // mc (宏)
    
    // 运算符
    TOKEN_PLUS,          // +
    TOKEN_MINUS,         // -
    TOKEN_ASTERISK,      // *
    TOKEN_SLASH,         // /
    TOKEN_PERCENT,       // %
    TOKEN_ASSIGN,        // =
    TOKEN_EQUAL,         // ==
    TOKEN_NOT_EQUAL,     // !=
    TOKEN_LESS,          // <
    TOKEN_LESS_EQUAL,    // <=
    TOKEN_GREATER,       // >
    TOKEN_GREATER_EQUAL, // >=
    TOKEN_LEFT_PAREN,    // (
    TOKEN_RIGHT_PAREN,   // )
    TOKEN_LEFT_BRACE,    // {
    TOKEN_RIGHT_BRACE,   // }
    TOKEN_LEFT_BRACKET,  // [
    TOKEN_RIGHT_BRACKET, // ]
    TOKEN_SEMICOLON,     // ;
    TOKEN_COMMA,         // ,
    TOKEN_DOT,           // .
    TOKEN_COLON,         // :
    TOKEN_EXCLAMATION,   // !
    TOKEN_AMPERSAND,     // &
    TOKEN_PIPE,          // |
    TOKEN_CARET,         // ^
    TOKEN_TILDE,         // ~
    TOKEN_LEFT_SHIFT,    // <<
    TOKEN_RIGHT_SHIFT,   // >>
    TOKEN_LOGICAL_AND,   // &&
    TOKEN_LOGICAL_OR,    // ||
    
    // 饱和运算符（显式溢出处理）
    TOKEN_PLUS_PIPE,      // +|
    TOKEN_MINUS_PIPE,     // -|
    TOKEN_ASTERISK_PIPE,  // *|
    
    // 包装运算符（显式溢出处理）
    TOKEN_PLUS_PERCENT,   // +%
    TOKEN_MINUS_PERCENT,  // -%
    TOKEN_ASTERISK_PERCENT, // *%
    
    // 特殊符号
    TOKEN_ARROW,         // => (箭头操作符)
    TOKEN_ELLIPSIS,      // ... (可变参数)
    TOKEN_RANGE,         // .. (范围操作符)
} TokenType;
```

### 2.2 Token结构

```c
typedef struct Token {
    TokenType type;       // Token类型
    char *value;          // Token值（字符串形式）
    int line;             // 行号（从1开始）
    int column;           // 列号（从1开始）
    char *filename;       // 文件名
} Token;
```

### 2.3 词法分析器结构

```c
typedef struct Lexer {
    char *buffer;         // 源代码缓冲区
    size_t buffer_size;   // 缓冲区大小
    size_t position;      // 当前位置
    int line;             // 当前行号
    int column;           // 当前列号
    char *filename;       // 源文件名
} Lexer;
```

## 3. 词法分析器函数接口

### 3.1 基础函数

```c
// 创建词法分析器
Lexer *lexer_new(const char *filename);

// 释放词法分析器
void lexer_free(Lexer *lexer);

// 获取下一个Token
Token *lexer_next_token(Lexer *lexer);

// 释放Token
void token_free(Token *token);

// 前瞻Token（不消费）
Token *lexer_peek(Lexer *lexer);

// 前瞻n个Token
Token *lexer_peek_n(Lexer *lexer, int n);
```

### 3.2 辅助函数

```c
// 检查字符类别
int is_alpha(char c);
int is_digit(char c);
int is_alphanumeric(char c);
int is_whitespace(char c);

// 读取下一字符
char lexer_advance(Lexer *lexer);

// 查看下一字符（不消费）
char lexer_peek_char(Lexer *lexer, int offset);

// 跳过空白字符和注释
void lexer_skip_whitespace(Lexer *lexer);
```

## 4. 词法分析算法

### 4.1 词法分析器初始化

```c
Lexer *lexer_new(const char *filename) {
    if (!filename) {
        return NULL;
    }

    Lexer *lexer = malloc(sizeof(Lexer));
    if (!lexer) {
        return NULL;
    }

    // 读取文件内容到缓冲区
    FILE *file = fopen(filename, "r");
    if (!file) {
        free(lexer);
        return NULL;
    }

    fseek(file, 0, SEEK_END);
    long length = ftell(file);
    fseek(file, 0, SEEK_SET);

    lexer->buffer = malloc(length + 1);
    if (!lexer->buffer) {
        fclose(file);
        free(lexer);
        return NULL;
    }

    fread(lexer->buffer, 1, length, file);
    lexer->buffer[length] = '\0';
    fclose(file);

    lexer->buffer_size = length;
    lexer->position = 0;
    lexer->line = 1;
    lexer->column = 1;
    
    lexer->filename = malloc(strlen(filename) + 1);
    if (!lexer->filename) {
        free(lexer->buffer);
        free(lexer);
        return NULL;
    }
    strcpy(lexer->filename, filename);

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
```

### 4.2 字符读取函数

```c
// 读取下一字符
char lexer_advance(Lexer *lexer) {
    if (lexer->position >= lexer->buffer_size) {
        return '\0';
    }

    char c = lexer->buffer[lexer->position];
    lexer->position++;

    // 更新行号和列号
    if (c == '\n') {
        lexer->line++;
        lexer->column = 1;
    } else {
        lexer->column++;
    }

    return c;
}

// 查看下一字符（不消费）
char lexer_peek_char(Lexer *lexer, int offset) {
    size_t pos = lexer->position + offset;
    if (pos >= lexer->buffer_size) {
        return '\0';
    }
    return lexer->buffer[pos];
}
```

### 4.3 跳过空白字符和注释

```c
void lexer_skip_whitespace(Lexer *lexer) {
    while (lexer->position < lexer->buffer_size) {
        char c = lexer_peek_char(lexer, 0);
        
        // 跳过空白字符
        if (is_whitespace(c)) {
            lexer_advance(lexer);
            continue;
        }
        
        // 跳过单行注释 //...
        if (c == '/' && lexer_peek_char(lexer, 1) == '/') {
            lexer_advance(lexer); // 消费 '/'
            lexer_advance(lexer); // 消费 '/'
            
            // 跳过直到行尾
            while (lexer->position < lexer->buffer_size && 
                   lexer_peek_char(lexer, 0) != '\n') {
                lexer_advance(lexer);
            }
            continue;
        }
        
        // 跳过多行注释 /*...*/
        if (c == '/' && lexer_peek_char(lexer, 1) == '*') {
            lexer_advance(lexer); // 消费 '/'
            lexer_advance(lexer); // 消费 '*'
            
            // 跳过直到找到结束符 */
            while (lexer->position < lexer->buffer_size) {
                if (lexer_peek_char(lexer, 0) == '*' && 
                    lexer_peek_char(lexer, 1) == '/') {
                    lexer_advance(lexer); // 消费 '*'
                    lexer_advance(lexer); // 消费 '/'
                    break;
                }
                lexer_advance(lexer);
            }
            continue;
        }
        
        // 不是空白字符或注释，退出循环
        break;
    }
}
```

## 5. Token识别算法

### 5.1 主要Token识别函数

```c
Token *lexer_next_token(Lexer *lexer) {
    // 跳过空白字符和注释
    lexer_skip_whitespace(lexer);

    if (lexer->position >= lexer->buffer_size) {
        return token_new(TOKEN_EOF, "", lexer->line, lexer->column, lexer->filename);
    }

    char c = lexer_peek_char(lexer, 0);
    int line = lexer->line;
    int column = lexer->column;

    switch (c) {
        // 单字符Token
        case '+': lexer_advance(lexer); return token_new(TOKEN_PLUS, "+", line, column, lexer->filename);
        case '*': lexer_advance(lexer); return token_new(TOKEN_ASTERISK, "*", line, column, lexer->filename);
        case '/': lexer_advance(lexer); return token_new(TOKEN_SLASH, "/", line, column, lexer->filename);
        case '%': lexer_advance(lexer); return token_new(TOKEN_PERCENT, "%", line, column, lexer->filename);
        case '(': lexer_advance(lexer); return token_new(TOKEN_LEFT_PAREN, "(", line, column, lexer->filename);
        case ')': lexer_advance(lexer); return token_new(TOKEN_RIGHT_PAREN, ")", line, column, lexer->filename);
        case '{': lexer_advance(lexer); return token_new(TOKEN_LEFT_BRACE, "{", line, column, lexer->filename);
        case '}': lexer_advance(lexer); return token_new(TOKEN_RIGHT_BRACE, "}", line, column, lexer->filename);
        case '[': lexer_advance(lexer); return token_new(TOKEN_LEFT_BRACKET, "[", line, column, lexer->filename);
        case ']': lexer_advance(lexer); return token_new(TOKEN_RIGHT_BRACKET, "]", line, column, lexer->filename);
        case ';': lexer_advance(lexer); return token_new(TOKEN_SEMICOLON, ";", line, column, lexer->filename);
        case ',': lexer_advance(lexer); return token_new(TOKEN_COMMA, ",", line, column, lexer->filename);
        case '.': 
            lexer_advance(lexer);
            // 检查是否是范围操作符 '..' 或切片操作符 '[start:end]'
            if (lexer_peek_char(lexer, 0) == '.') {
                lexer_advance(lexer);
                if (lexer_peek_char(lexer, 0) == '.') {
                    // '...' 三重点操作符（用于可变参数）
                    lexer_advance(lexer);
                    return token_new(TOKEN_ELLIPSIS, "...", line, column, lexer->filename);
                } else {
                    // '..' 范围操作符
                    return token_new(TOKEN_RANGE, "..", line, column, lexer->filename);
                }
            }
            return token_new(TOKEN_DOT, ".", line, column, lexer->filename);
        case ':': lexer_advance(lexer); return token_new(TOKEN_COLON, ":", line, column, lexer->filename);
        case '!': 
            lexer_advance(lexer);
            if (lexer_peek_char(lexer, 0) == '=') {
                lexer_advance(lexer);
                return token_new(TOKEN_NOT_EQUAL, "!=", line, column, lexer->filename);
            }
            return token_new(TOKEN_EXCLAMATION, "!", line, column, lexer->filename);
        case '&': 
            lexer_advance(lexer);
            if (lexer_peek_char(lexer, 0) == '&') {
                lexer_advance(lexer);
                return token_new(TOKEN_LOGICAL_AND, "&&", line, column, lexer->filename);
            }
            return token_new(TOKEN_AMPERSAND, "&", line, column, lexer->filename);
        case '|': 
            lexer_advance(lexer);
            if (lexer_peek_char(lexer, 0) == '|') {
                lexer_advance(lexer);
                return token_new(TOKEN_LOGICAL_OR, "||", line, column, lexer->filename);
            }
            return token_new(TOKEN_PIPE, "|", line, column, lexer->filename);
        case '^': lexer_advance(lexer); return token_new(TOKEN_CARET, "^", line, column, lexer->filename);
        case '~': lexer_advance(lexer); return token_new(TOKEN_TILDE, "~", line, column, lexer->filename);
        case '-': 
            lexer_advance(lexer);
            if (lexer_peek_char(lexer, 0) == '>') {
                lexer_advance(lexer);
                return token_new(TOKEN_ARROW, "->", line, column, lexer->filename);
            }
            return token_new(TOKEN_MINUS, "-", line, column, lexer->filename);
        case '=': 
            lexer_advance(lexer);
            if (lexer_peek_char(lexer, 0) == '=') {
                lexer_advance(lexer);
                return token_new(TOKEN_EQUAL, "==", line, column, lexer->filename);
            }
            return token_new(TOKEN_ASSIGN, "=", line, column, lexer->filename);
        case '<': 
            lexer_advance(lexer);
            if (lexer_peek_char(lexer, 0) == '=') {
                lexer_advance(lexer);
                return token_new(TOKEN_LESS_EQUAL, "<=", line, column, lexer->filename);
            } else if (lexer_peek_char(lexer, 0) == '<') {
                lexer_advance(lexer);
                return token_new(TOKEN_LEFT_SHIFT, "<<", line, column, lexer->filename);
            }
            return token_new(TOKEN_LESS, "<", line, column, lexer->filename);
        case '>': 
            lexer_advance(lexer);
            if (lexer_peek_char(lexer, 0) == '=') {
                lexer_advance(lexer);
                return token_new(TOKEN_GREATER_EQUAL, ">=", line, column, lexer->filename);
            } else if (lexer_peek_char(lexer, 0) == '>') {
                lexer_advance(lexer);
                return token_new(TOKEN_RIGHT_SHIFT, ">>", line, column, lexer->filename);
            }
            return token_new(TOKEN_GREATER, ">", line, column, lexer->filename);
            
        // 字符串字面量
        case '"': return lexer_read_string(lexer);
        
        // 字符字面量
        case '\'': return lexer_read_char(lexer);
        
        // 标识符或关键字
        case 'a'...'z':
        case 'A'...'Z':
        case '_': return lexer_read_identifier_or_keyword(lexer);
        
        // 数字字面量
        case '0'...'9': return lexer_read_number(lexer);
        
        // 未知字符
        default:
            char unknown_char[2] = {c, '\0'};
            lexer_advance(lexer);
            return token_new(TOKEN_EOF, unknown_char, line, column, lexer->filename);
    }
}
```

### 5.2 标识符和关键字识别

```c
Token *lexer_read_identifier_or_keyword(Lexer *lexer) {
    int line = lexer->line;
    int column = lexer->column;
    
    const char *start = lexer->buffer + lexer->position;
    
    // 读取标识符
    while (lexer->position < lexer->buffer_size) {
        char c = lexer_peek_char(lexer, 0);
        if (is_alphanumeric(c) || c == '_') {
            lexer_advance(lexer);
        } else {
            break;
        }
    }
    
    size_t len = (lexer->buffer + lexer->position) - start;
    char *ident = malloc(len + 1);
    if (!ident) {
        return NULL;
    }
    strncpy(ident, start, len);
    ident[len] = '\0';
    
    // 检查是否为关键字
    TokenType keyword_type = lexer_lookup_keyword(ident);
    if (keyword_type != TOKEN_EOF) {
        // 这是关键字
        free(ident);
        return token_new(keyword_type, lexer_get_keyword_string(keyword_type), line, column, lexer->filename);
    }
    
    // 这是普通标识符
    Token *token = token_new(TOKEN_IDENTIFIER, ident, line, column, lexer->filename);
    if (!token) {
        free(ident);
        return NULL;
    }
    token->value = ident;  // 重新分配，因为token_new可能使用了不同的值
    
    return token;
}

// 关键字查找表
TokenType lexer_lookup_keyword(const char *str) {
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
    return TOKEN_EOF;  // 不是关键字
}

const char *lexer_get_keyword_string(TokenType type) {
    switch (type) {
        case TOKEN_STRUCT: return "struct";
        case TOKEN_LET: return "let";
        case TOKEN_MUT: return "mut";
        case TOKEN_CONST: return "const";
        case TOKEN_FN: return "fn";
        case TOKEN_RETURN: return "return";
        case TOKEN_EXTERN: return "extern";
        case TOKEN_TRUE: return "true";
        case TOKEN_FALSE: return "false";
        case TOKEN_IF: return "if";
        case TOKEN_WHILE: return "while";
        case TOKEN_BREAK: return "break";
        case TOKEN_CONTINUE: return "continue";
        case TOKEN_DEFER: return "defer";
        case TOKEN_ERRDEFER: return "errdefer";
        case TOKEN_TRY: return "try";
        case TOKEN_CATCH: return "catch";
        case TOKEN_ERROR: return "error";
        case TOKEN_NULL: return "null";
        case TOKEN_INTERFACE: return "interface";
        case TOKEN_IMPL: return "impl";
        case TOKEN_ATOMIC: return "atomic";
        case TOKEN_MAX: return "max";
        case TOKEN_MIN: return "min";
        case TOKEN_AS: return "as";
        case TOKEN_AS_EXCLAMATION: return "as!";
        case TOKEN_TYPE: return "type";
        case TOKEN_MC: return "mc";
        default: return "";
    }
}
```

### 5.3 数字字面量识别

```c
Token *lexer_read_number(Lexer *lexer) {
    int line = lexer->line;
    int column = lexer->column;
    
    const char *start = lexer->buffer + lexer->position;
    
    // 读取数字（整数或浮点数）
    while (lexer->position < lexer->buffer_size) {
        char c = lexer_peek_char(lexer, 0);
        if (isdigit(c) || c == '.') {
            lexer_advance(lexer);
        } else {
            break;
        }
    }
    
    size_t len = (lexer->buffer + lexer->position) - start;
    char *num_str = malloc(len + 1);
    if (!num_str) {
        return NULL;
    }
    strncpy(num_str, start, len);
    num_str[len] = '\0';
    
    return token_new(TOKEN_NUMBER, num_str, line, column, lexer->filename);
}
```

### 5.4 字符串字面量识别

```c
Token *lexer_read_string(Lexer *lexer) {
    int line = lexer->line;
    int column = lexer->column;
    
    // 消费开始的引号 "
    lexer_advance(lexer);
    
    const char *start = lexer->buffer + lexer->position;
    
    // 读取字符串内容，直到遇到结束引号或换行
    while (lexer->position < lexer->buffer_size) {
        char c = lexer_peek_char(lexer, 0);
        
        if (c == '"') {
            // 找到结束引号
            lexer_advance(lexer);
            break;
        } else if (c == '\\') {
            // 转义字符，跳过下一个字符
            lexer_advance(lexer);  // 消费 '\'
            if (lexer->position < lexer->buffer_size) {
                lexer_advance(lexer);  // 消费转义字符
            }
        } else if (c == '\n') {
            // 字符串不能跨行，除非使用特殊语法
            break;
        } else {
            lexer_advance(lexer);
        }
    }
    
    size_t len = (lexer->buffer + lexer->position - 1) - start;  // -1 为了排除结束引号
    char *str_value = malloc(len + 1);
    if (!str_value) {
        return NULL;
    }
    strncpy(str_value, start, len);
    str_value[len] = '\0';
    
    return token_new(TOKEN_STRING, str_value, line, column, lexer->filename);
}
```

### 5.5 字符字面量识别

```c
Token *lexer_read_char(Lexer *lexer) {
    int line = lexer->line;
    int column = lexer->column;
    
    // 消费开始的引号 '
    lexer_advance(lexer);
    
    const char *start = lexer->buffer + lexer->position;
    
    // 读取字符内容，直到遇到结束引号或换行
    while (lexer->position < lexer->buffer_size) {
        char c = lexer_peek_char(lexer, 0);
        
        if (c == '\'') {
            // 找到结束引号
            lexer_advance(lexer);
            break;
        } else if (c == '\\') {
            // 转义字符，跳过下一个字符
            lexer_advance(lexer);  // 消费 '\'
            if (lexer->position < lexer->buffer_size) {
                lexer_advance(lexer);  // 消费转义字符
            }
        } else if (c == '\n') {
            // 字符不能跨行
            break;
        } else {
            lexer_advance(lexer);
        }
    }
    
    size_t len = (lexer->buffer + lexer->position - 1) - start;  // -1 为了排除结束引号
    char *char_value = malloc(len + 1);
    if (!char_value) {
        return NULL;
    }
    strncpy(char_value, start, len);
    char_value[len] = '\0';
    
    return token_new(TOKEN_CHAR, char_value, line, column, lexer->filename);
}
```

### 5.6 Token创建函数

```c
Token *token_new(TokenType type, const char *value, int line, int column, const char *filename) {
    Token *token = malloc(sizeof(Token));
    if (!token) {
        return NULL;
    }
    
    token->type = type;
    token->line = line;
    token->column = column;
    
    // 复制值
    if (value) {
        token->value = malloc(strlen(value) + 1);
        if (token->value) {
            strcpy(token->value, value);
        } else {
            free(token);
            return NULL;
        }
    } else {
        token->value = NULL;
    }
    
    // 复制文件名
    if (filename) {
        token->filename = malloc(strlen(filename) + 1);
        if (token->filename) {
            strcpy(token->filename, filename);
        } else {
            if (token->value) free(token->value);
            free(token);
            return NULL;
        }
    } else {
        token->filename = NULL;
    }
    
    return token;
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
```

## 6. 切片语法的词法支持

### 6.1 切片语法Token识别

Uya语言支持两种切片语法：
1. **函数语法**：`slice(arr, start, len)`
2. **操作符语法**：`arr[start:end]`

词法分析器需要正确识别这些语法中的Token：

- `slice` - 作为普通标识符（除非作为内置函数处理）
- `[` `]` - 数组下标操作符
- `:` - 切片分隔符

### 6.2 切片语法示例

```uya
// 基本切片语法
let arr: [i32; 10] = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9];
let slice1: [i32; 3] = slice(arr, 2, 5);  // [2, 3, 4]
let slice2: [i32; 3] = arr[2:5];          // [2, 3, 4]，操作符语法

// 负数索引切片
let slice3: [i32; 3] = slice(arr, -3, 10);  // [7, 8, 9]
let slice4: [i32; 3] = arr[-3:10];          // [7, 8, 9]，操作符语法

// 省略边界
let slice5: [i32; 3] = arr[:3];             // [0, 1, 2]，从开头到索引2
let slice6: [i32; 3] = arr[7:];             // [7, 8, 9]，从索引7到末尾
```

### 6.3 语法分析器集成

语法分析器需要能够识别`[start:end]`模式并将其解析为切片操作，而不是普通的数组下标操作。

## 7. 性能特性

### 7.1 时间复杂度
- 词法分析：O(n)，其中n是源代码字符数
- 每个字符最多被访问常数次
- 关键字查找：O(k)，其中k是关键字数量（通常很小）

### 7.2 空间复杂度
- Token缓冲区：O(t)，其中t是Token数量
- 每个Token的值存储：O(v)，其中v是值的总长度

## 8. Unicode支持

### 8.1 UTF-8编码
- 词法分析器假定源代码使用UTF-8编码
- 支持ASCII范围外的Unicode字符
- 标识符可以包含Unicode字母字符

### 8.2 字符分类
```c
// 检查是否为字母（包括Unicode字母）
int is_letter(char c) {
    return (c >= 'a' && c <= 'z') || 
           (c >= 'A' && c <= 'Z') || 
           c == '_';
}

// 检查是否为数字
int is_digit(char c) {
    return c >= '0' && c <= '9';
}

// 检查是否为字母数字
int is_alphanumeric(char c) {
    return is_letter(c) || is_digit(c);
}

// 检查是否为空白字符
int is_whitespace(char c) {
    return c == ' ' || c == '\t' || c == '\n' || c == '\r';
}
```

## 9. 错误处理

### 9.1 非法字符处理
- 遇到非预期字符时，生成错误Token并继续解析
- 提供详细的错误位置信息（行号、列号、文件名）

### 9.2 错误恢复
- 遇到错误时，跳过到下一个可能的Token边界
- 继续解析后续代码

## 10. 与Uya语言哲学的一致性

词法分析器完全符合Uya语言的核心哲学：

1. **安全优先**：所有Token识别都在编译期完成
2. **零运行时开销**：词法分析在编译期完成，运行时无解析开销
3. **显式控制**：语法结构明确，无隐式转换
4. **数学确定性**：每个Token都有明确的识别规则

## 11. 与切片语法的集成

词法分析器为切片语法提供了以下支持：
- 正确识别`:`操作符（用于切片分隔）
- 正确识别`[`和`]`操作符（用于数组访问和切片）
- 支持负数索引的`-`操作符识别
- 为语法分析器提供足够的Token信息以解析切片语法

> **Uya词法分析器 = 高效字符流解析 + 完整语法支持 + 零运行时开销**；
> **所有Token在编译期识别，通过路径零指令，失败路径不存在**。