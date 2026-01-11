#ifndef CHECKER_H
#define CHECKER_H

#include "ast.h"
#include "arena.h"
#include <stddef.h>

// 类型枚举（Uya Mini 支持的类型）
typedef enum {
    TYPE_I32,      // 32位有符号整数
    TYPE_BOOL,     // 布尔类型
    TYPE_VOID,     // void 类型（仅用于函数返回类型）
    TYPE_STRUCT,   // 结构体类型（通过名称引用）
} TypeKind;

// 类型结构
// 使用 union 存储不同类型的数据
typedef struct Type {
    TypeKind kind;              // 类型种类
    const char *struct_name;    // 结构体名称（仅当 kind == TYPE_STRUCT 时有效）
} Type;

// 符号信息（变量、函数参数等）
typedef struct Symbol {
    const char *name;           // 符号名称（存储在 Arena 中）
    Type type;                  // 符号类型
    int is_const;               // 1 表示 const，0 表示 var
    int scope_level;            // 作用域级别
    int line;                   // 行号
    int column;                 // 列号
} Symbol;

// 函数签名信息
typedef struct FunctionSignature {
    const char *name;           // 函数名称（存储在 Arena 中）
    Type *param_types;          // 参数类型数组（从 Arena 分配）
    int param_count;            // 参数数量
    Type return_type;           // 返回类型
    int is_extern;              // 是否为 extern 函数
    int line;                   // 行号
    int column;                 // 列号
} FunctionSignature;

// 符号表（固定大小哈希表，使用开放寻址）
#define SYMBOL_TABLE_SIZE 256   // 固定大小（必须是2的幂）

typedef struct SymbolTable {
    Symbol *slots[SYMBOL_TABLE_SIZE];  // 符号槽位数组（固定大小）
    int count;                          // 当前符号数量
} SymbolTable;

// 函数表（固定大小哈希表，使用开放寻址）
#define FUNCTION_TABLE_SIZE 64  // 固定大小（必须是2的幂）

typedef struct FunctionTable {
    FunctionSignature *slots[FUNCTION_TABLE_SIZE];  // 函数槽位数组（固定大小）
    int count;                                       // 当前函数数量
} FunctionTable;

// 类型检查器结构
typedef struct TypeChecker {
    Arena *arena;               // Arena 分配器（用于分配类型、符号等）
    SymbolTable symbol_table;   // 符号表
    FunctionTable function_table; // 函数表
    int scope_level;            // 当前作用域级别
    ASTNode *program_node;      // 程序节点（用于查找结构体声明等）
    int error_count;            // 错误计数（简化版本，暂不存储错误消息）
} TypeChecker;

// 初始化 TypeChecker
// 参数：checker - TypeChecker 结构体指针（由调用者提供），arena - Arena 分配器
// 返回：成功返回 0，失败返回 -1
// 注意：TypeChecker 结构体由调用者在栈上或静态分配，此函数只负责初始化
int checker_init(TypeChecker *checker, Arena *arena);

// 类型检查主函数
// 参数：checker - TypeChecker 指针，ast - AST 根节点
// 返回：成功返回 0，失败返回 -1
int checker_check(TypeChecker *checker, ASTNode *ast);

// 获取错误计数
// 参数：checker - TypeChecker 指针
// 返回：错误数量
int checker_get_error_count(TypeChecker *checker);

#endif // CHECKER_H

