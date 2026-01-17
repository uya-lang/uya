#ifndef AST_H
#define AST_H

#include "arena.h"
#include <stddef.h>

// 枚举变体结构
typedef struct EnumVariant {
    const char *name;      // 变体名称（字符串存储在 Arena 中）
    const char *value;     // 显式值（字符串形式，如果指定了 = NUM，否则为 NULL，存储在 Arena 中）
} EnumVariant;

// AST 节点类型枚举
// Uya Mini 仅包含最小子集所需的节点类型
typedef enum {
    // 声明节点
    AST_PROGRAM,        // 程序节点（根节点）
    AST_ENUM_DECL,      // 枚举声明
    AST_STRUCT_DECL,    // 结构体声明
    AST_FN_DECL,        // 函数声明
    AST_VAR_DECL,       // 变量声明（const/var）
    
    // 语句节点
    AST_IF_STMT,        // if 语句
    AST_WHILE_STMT,     // while 语句
    AST_FOR_STMT,       // for 语句（数组遍历）
    AST_BREAK_STMT,     // break 语句
    AST_CONTINUE_STMT,  // continue 语句
    AST_RETURN_STMT,    // return 语句
    AST_ASSIGN,         // 赋值语句
    AST_EXPR_STMT,      // 表达式语句
    AST_BLOCK,          // 代码块
    
    // 表达式节点
    AST_BINARY_EXPR,    // 二元表达式
    AST_UNARY_EXPR,     // 一元表达式
    AST_CALL_EXPR,      // 函数调用
    AST_MEMBER_ACCESS,  // 字段访问（obj.field）
    AST_ARRAY_ACCESS,   // 数组访问（arr[index]）
    AST_STRUCT_INIT,    // 结构体字面量（StructName{ field: value, ... }）
    AST_ARRAY_LITERAL,  // 数组字面量（[expr1, expr2, ..., exprN]）
    AST_SIZEOF,         // sizeof 表达式（sizeof(Type) 或 sizeof(expr)）
    AST_LEN,            // len 表达式（len(array)）
    AST_ALIGNOF,        // alignof 表达式（alignof(Type) 或 alignof(expr)）
    AST_CAST_EXPR,      // 类型转换表达式（expr as type）
    AST_IDENTIFIER,     // 标识符
    AST_NUMBER,         // 数字字面量
    AST_BOOL,           // 布尔字面量（true/false）
    AST_STRING,         // 字符串字面量
    
    // 类型节点
    AST_TYPE_NAMED,     // 命名类型（i32, bool, void, 或 struct Name）
    AST_TYPE_POINTER,   // 指针类型（&T 或 *T）
    AST_TYPE_ARRAY,     // 数组类型（[T: N]）
} ASTNodeType;

// 基础 AST 节点结构
// 使用 union 存储不同类型节点的数据，使用 Arena 分配器管理内存
struct ASTNode {
    ASTNodeType type;   // 节点类型
    int line;           // 行号
    int column;         // 列号
    const char *filename; // 文件名（从 Lexer 中获取，用于错误报告）
    
    union {
        // 程序节点
        struct {
            struct ASTNode **decls;      // 声明数组（从 Arena 分配）
            int decl_count;       // 声明数量
        } program;
        
        // 枚举声明
        struct {
            const char *name;              // 枚举名称（字符串存储在 Arena 中）
            EnumVariant *variants;         // 变体数组（从 Arena 分配）
            int variant_count;             // 变体数量
        } enum_decl;
        
        // 结构体声明
        struct {
            const char *name;         // 结构体名称（字符串存储在 Arena 中）
            struct ASTNode **fields;         // 字段数组（字段是 AST_VAR_DECL 节点）
            int field_count;          // 字段数量
        } struct_decl;
        
        // 函数声明
        struct {
            const char *name;         // 函数名称
            struct ASTNode **params;         // 参数数组（参数是 AST_VAR_DECL 节点）
            int param_count;          // 参数数量
            struct ASTNode *return_type;     // 返回类型（类型节点）
            struct ASTNode *body;            // 函数体（AST_BLOCK 节点）
            int is_varargs;           // 是否为可变参数函数（1 表示是，0 表示否，仅用于 extern 函数）
        } fn_decl;
        
        // 变量声明（用于变量声明、函数参数、结构体字段）
        struct {
            const char *name;         // 变量名称
            struct ASTNode *type;            // 类型节点
            struct ASTNode *init;            // 初始值表达式（可为 NULL）
            int is_const;             // 1 表示 const，0 表示 var
        } var_decl;
        
        // 二元表达式
        struct {
            struct ASTNode *left;            // 左操作数
            int op;                   // 运算符（Token 类型，暂用 int 表示）
            struct ASTNode *right;           // 右操作数
        } binary_expr;
        
        // 一元表达式
        struct {
            int op;                   // 运算符（Token 类型）
            struct ASTNode *operand;         // 操作数
        } unary_expr;
        
        // 函数调用
        struct {
            struct ASTNode *callee;          // 被调用的函数（标识符节点）
            struct ASTNode **args;           // 参数表达式数组
            int arg_count;            // 参数数量
        } call_expr;
        
        // 字段访问（obj.field）
        struct {
            struct ASTNode *object;          // 对象表达式
            const char *field_name;   // 字段名称
        } member_access;
        
        // 数组访问（arr[index]）
        struct {
            struct ASTNode *array;           // 数组表达式
            struct ASTNode *index;           // 索引表达式
        } array_access;
        
        // 结构体字面量（StructName{ field1: value1, field2: value2 }）
        struct {
            const char *struct_name;  // 结构体名称
            const char **field_names; // 字段名称数组
            struct ASTNode **field_values;   // 字段值表达式数组
            int field_count;          // 字段数量
        } struct_init;
        
        // 数组字面量（[expr1, expr2, ..., exprN]）
        struct {
            struct ASTNode **elements;  // 元素表达式数组
            int element_count;          // 元素数量
        } array_literal;
        
        // sizeof 表达式（sizeof(Type) 或 sizeof(expr)）
        struct {
            struct ASTNode *target;   // 目标节点（类型节点或表达式节点）
            int is_type;              // 1 表示 target 是类型节点，0 表示 target 是表达式节点
        } sizeof_expr;
        
        // len 表达式（len(array)）
        struct {
            struct ASTNode *array;    // 数组表达式节点
        } len_expr;
        
        // alignof 表达式（alignof(Type) 或 alignof(expr)）
        struct {
            struct ASTNode *target;   // 目标节点（类型节点或表达式节点）
            int is_type;              // 1 表示 target 是类型节点，0 表示 target 是表达式节点
        } alignof_expr;
        
        // 类型转换表达式（expr as type）
        struct {
            struct ASTNode *expr;     // 源表达式
            struct ASTNode *target_type;  // 目标类型节点
        } cast_expr;
        
        // 标识符
        struct {
            const char *name;         // 标识符名称
        } identifier;
        
        // 数字字面量
        struct {
            int value;                // 数值（i32）
        } number;
        
        // 布尔字面量
        struct {
            int value;                // 1 表示 true，0 表示 false
        } bool_literal;
        
        // 字符串字面量
        struct {
            const char *value;        // 字符串内容（存储在 Arena 中，不包括引号，包括 null 终止符）
        } string_literal;
        
        // if 语句
        struct {
            struct ASTNode *condition;       // 条件表达式
            struct ASTNode *then_branch;     // then 分支（AST_BLOCK 节点）
            struct ASTNode *else_branch;     // else 分支（AST_BLOCK 节点，可为 NULL）
        } if_stmt;
        
        // while 语句
        struct {
            struct ASTNode *condition;       // 条件表达式
            struct ASTNode *body;            // 循环体（AST_BLOCK 节点）
        } while_stmt;
        
        // for 语句（数组遍历）
        struct {
            struct ASTNode *array;           // 数组表达式
            const char *var_name;            // 循环变量名称（存储在 Arena 中）
            int is_ref;                      // 是否为引用迭代（1 表示引用迭代，0 表示值迭代）
            struct ASTNode *body;            // 循环体（AST_BLOCK 节点）
        } for_stmt;
        
        // return 语句
        struct {
            struct ASTNode *expr;            // 返回值表达式（可为 NULL，用于 void 函数）
        } return_stmt;
        
        // 赋值语句
        struct {
            struct ASTNode *dest;            // 目标表达式（标识符节点）
            struct ASTNode *src;             // 源表达式
        } assign;
        
        // 代码块
        struct {
            struct ASTNode **stmts;          // 语句数组
            int stmt_count;           // 语句数量
        } block;
        
        // 类型节点（命名类型：i32, bool, void, struct Name）
        struct {
            const char *name;         // 类型名称（"i32", "bool", "void", 或结构体名称）
        } type_named;
        
        // 指针类型节点（&T 或 *T）
        struct {
            struct ASTNode *pointed_type;  // 指向的类型节点（从 Arena 分配）
            int is_ffi_pointer;            // 是否为 FFI 指针（1 表示 *T，0 表示 &T）
        } type_pointer;
        
        // 数组类型节点（[T: N]）
        struct {
            struct ASTNode *element_type;  // 元素类型节点（从 Arena 分配）
            struct ASTNode *size_expr;     // 数组大小表达式节点（必须是编译期常量，从 Arena 分配）
        } type_array;
    } data;
};

// 类型别名
typedef struct ASTNode ASTNode;

// AST 节点创建函数
// 参数：type - 节点类型，line - 行号，column - 列号，arena - Arena 分配器
// 返回：新创建的 AST 节点指针，失败返回 NULL
ASTNode *ast_new_node(ASTNodeType type, int line, int column, Arena *arena, const char *filename);

// 合并多个 AST_PROGRAM 节点为一个程序节点
// 参数：programs - AST_PROGRAM 节点数组
//       count - 程序节点数量
//       arena - Arena 分配器
// 返回：合并后的 AST_PROGRAM 节点，失败返回 NULL
ASTNode *ast_merge_programs(ASTNode **programs, int count, Arena *arena);

#endif // AST_H

