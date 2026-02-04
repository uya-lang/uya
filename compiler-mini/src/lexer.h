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
    TOKEN_NUMBER,       // 整数字面量
    TOKEN_FLOAT,        // 浮点字面量
    TOKEN_STRING,       // 字符串字面量（无插值）
    TOKEN_RAW_STRING,   // 原始字符串字面量（反引号，无转义）
    
    // 字符串插值相关（"text${expr}text" 或 "text${expr:spec}text"）
    TOKEN_INTERP_TEXT,   // 插值中的纯文本段，value 为文本内容
    TOKEN_INTERP_OPEN,   // ${ 开始插值表达式
    TOKEN_INTERP_CLOSE,  // } 结束插值表达式
    TOKEN_INTERP_SPEC,   // 可选格式说明符，value 为 spec 字符串（如 ".2f"）
    TOKEN_INTERP_END,    // 插值字符串结束 "
    
    // 关键字
    TOKEN_ENUM,         // enum
    TOKEN_STRUCT,       // struct
    TOKEN_UNION,        // union
    TOKEN_INTERFACE,    // interface
    TOKEN_ATOMIC,       // atomic（原子类型关键字）
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
    TOKEN_TRY,          // try（错误传播/溢出检查）
    TOKEN_CATCH,        // catch（错误捕获）
    TOKEN_ERROR,        // error（错误声明/错误类型前缀）
    TOKEN_DEFER,        // defer（作用域结束执行）
    TOKEN_ERRDEFER,     // errdefer（仅错误返回时执行）
    TOKEN_EXPORT,       // export（模块导出关键字）
    TOKEN_USE,          // use（模块导入关键字）
    TOKEN_AT_IDENTIFIER,// @ 后跟内置函数标识符（@sizeof、@alignof、@len、@max、@min）
    TOKEN_AS,           // as（类型转换关键字）
    TOKEN_AS_BANG,      // as!（强转，返回 !T，规范 uya.md §11.3）
    TOKEN_MATCH,        // match（模式匹配）
    TOKEN_FAT_ARROW,    // =>（match 臂箭头）
    TOKEN_TEST,         // test（测试单元关键字）
    
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
    TOKEN_AMPERSAND,    // &（取地址/按位与）
    TOKEN_PIPE,         // |（for 循环/按位或）
    TOKEN_CARET,        // ^（按位异或）
    TOKEN_TILDE,        // ~（按位取反）
    TOKEN_LSHIFT,       // <<（左移）
    TOKEN_RSHIFT,       // >>（右移）
    // 饱和运算（规范 uya.md §10、§16）
    TOKEN_PLUS_PIPE,    // +|（饱和加法）
    TOKEN_MINUS_PIPE,   // -|（饱和减法）
    TOKEN_ASTERISK_PIPE,// *|（饱和乘法）
    // 包装运算（规范 uya.md §10、§16）
    TOKEN_PLUS_PERCENT, // +%（包装加法）
    TOKEN_MINUS_PERCENT,// -%（包装减法）
    TOKEN_ASTERISK_PERCENT, // *%（包装乘法）
    
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
    TOKEN_DOT_DOT,      // ..（范围，用于 for start..end）
    TOKEN_COLON,        // :
    TOKEN_ELLIPSIS,     // ...（可变参数，用于 extern 函数声明）
    // 复合赋值运算符
    TOKEN_PLUS_ASSIGN,  // +=
    TOKEN_MINUS_ASSIGN, // -=
    TOKEN_ASTERISK_ASSIGN, // *=
    TOKEN_SLASH_ASSIGN, // /=
    TOKEN_PERCENT_ASSIGN, // %=
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

// 字符串插值内部缓冲区大小
#define LEXER_STRING_INTERP_BUFFER_SIZE 4096

typedef struct Lexer {
    char buffer[LEXER_BUFFER_SIZE];  // 源代码缓冲区（固定大小数组）
    size_t buffer_size;              // 缓冲区实际大小（字节数）
    size_t position;                 // 当前读取位置
    int line;                        // 当前行号（从1开始）
    int column;                      // 当前列号（从1开始）
    const char *filename;            // 文件名（存储在 Arena 中，可为 NULL）
    // 字符串插值状态（仅当 string_mode 或 interp_depth 非 0 时有效）
    int string_mode;                 // 1 表示在 "..." 内
    int raw_string_mode;             // 1 表示在 `...` 内（原始字符串）
    int interp_depth;                // 在 ${ } 内时为 1，用于区分 } 是插值结束还是代码
    int pending_interp_open;         // 1 表示已返回 INTERP_TEXT，下一 token 应为 INTERP_OPEN
    int reading_spec;                 // 1 表示正在读取 :spec 直到 }
    int has_seen_interp_in_string;   // 当前字符串中是否出现过 ${
    char string_text_buffer[LEXER_STRING_INTERP_BUFFER_SIZE];  // 当前文本段缓冲
    size_t string_text_len;           // 当前文本段长度
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

