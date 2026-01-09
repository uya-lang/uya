#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// 格式说明符结构（用于字符串插值）
typedef struct FormatSpec {
    char *flags;        // 格式标志字符串（如 "#", "0", "-", "+", " "）
    int width;          // 字段宽度（-1 表示未指定）
    int precision;      // 精度（-1 表示未指定）
    char type;          // 格式类型字符（'d', 'u', 'x', 'X', 'f', 'e', 'g', 'c', 'p' 等）
} FormatSpec;

// AST 节点类型枚举
typedef enum {
    AST_PROGRAM,
    AST_STRUCT_DECL,
    AST_FN_DECL,
    AST_EXTERN_DECL,
    AST_VAR_DECL,
    AST_IF_STMT,
    AST_WHILE_STMT,
    AST_RETURN_STMT,
    AST_ASSIGN,
    AST_EXPR_STMT,
    AST_BLOCK,
    AST_BREAK_STMT,
    AST_CONTINUE_STMT,
    AST_DEFER_STMT,
    AST_ERRDEFER_STMT,
    AST_FOR_STMT,
    AST_STRUCT_INIT,  // 结构体初始化表达式

    // 表达式类型
    AST_BINARY_EXPR,
    AST_UNARY_EXPR,
    AST_CALL_EXPR,
    AST_MEMBER_ACCESS,
    AST_SUBSCRIPT_EXPR,
    AST_IDENTIFIER,
    AST_NUMBER,
    AST_STRING,
    AST_STRING_INTERPOLATION,
    AST_BOOL,
    AST_NULL,
    AST_ERROR_EXPR,
    AST_CATCH_EXPR,  // catch expression: expr catch |err| { ... } or expr catch { ... }

    // 类型相关
    AST_TYPE_NAMED,
    AST_TYPE_POINTER,
    AST_TYPE_ARRAY,
    AST_TYPE_FN,
    AST_TYPE_ERROR_UNION,
    AST_TYPE_BOOL,
    AST_TYPE_ATOMIC,

    // 接口相关
    AST_INTERFACE_DECL,
    AST_IMPL_DECL,

    // 宏相关
    AST_MACRO_DECL,

    // 测试相关
    AST_TEST_BLOCK,
} ASTNodeType;

// 基础 AST 节点结构
typedef struct ASTNode {
    ASTNodeType type;
    int line;
    int column;
    char *filename;

    union {
        // 程序节点
        struct {
            struct ASTNode **decls;
            int decl_count;
        } program;

        // 结构体声明
        struct {
            char *name;
            struct ASTNode **fields;
            int field_count;
        } struct_decl;

        // 函数声明
        struct {
            char *name;
            struct ASTNode **params;
            int param_count;
            struct ASTNode *return_type;
            struct ASTNode *body;
            int is_extern;
        } fn_decl;

        // 变量声明
        struct {
            char *name;
            struct ASTNode *type;
            struct ASTNode *init;
            int is_mut;
            int is_const;
        } var_decl;

        // 二元表达式
        struct {
            struct ASTNode *left;
            int op;  // Token 类型
            struct ASTNode *right;
        } binary_expr;

        // 一元表达式
        struct {
            int op;  // Token 类型
            struct ASTNode *operand;
        } unary_expr;

        // 函数调用
        struct {
            struct ASTNode *callee;
            struct ASTNode **args;
            int arg_count;
        } call_expr;

        // catch 表达式 (expr catch |err| { ... } or expr catch { ... })
        struct {
            struct ASTNode *expr;      // 被 catch 的表达式（返回 !T 类型）
            char *error_var;           // 错误变量名（可为 NULL，如果没有 |err|）
            struct ASTNode *catch_body; // catch 块
        } catch_expr;

        // 标识符
        struct {
            char *name;
        } identifier;

        // 数字字面量
        struct {
            char *value;
        } number;

        // 字符串字面量
        struct {
            char *value;
        } string;

        // 字符串插值
        struct {
            char **text_segments;      // 文本段数组
            struct ASTNode **interp_exprs;  // 插值表达式数组
            FormatSpec *format_specs;  // 格式说明符数组（与 interp_exprs 对应，可为 NULL）
            int segment_count;         // 文本段和插值段的总数（交替出现：text, interp, text, interp, ...）
            int text_count;            // 文本段数量
            int interp_count;          // 插值段数量
        } string_interpolation;

        // 布尔字面量
        struct {
            int value;
        } bool_literal;

        // if 语句
        struct {
            struct ASTNode *condition;
            struct ASTNode *then_branch;
            struct ASTNode *else_branch;
        } if_stmt;

        // while 语句
        struct {
            struct ASTNode *condition;
            struct ASTNode *body;
        } while_stmt;

        // return 语句
        struct {
            struct ASTNode *expr;
        } return_stmt;

        // assignment 语句
        struct {
            char *dest;              // 简单变量名（向后兼容）
            struct ASTNode *dest_expr;  // 目标表达式（支持 arr[0] 等）
            struct ASTNode *src;
        } assign;

        // 代码块
        struct {
            struct ASTNode **stmts;
            int stmt_count;
        } block;

        // 类型节点
        struct {
            char *name;
        } type_named;

        // 数组类型
        struct {
            struct ASTNode *element_type;
            int size;
        } type_array;

        // 指针类型
        struct {
            struct ASTNode *pointee_type;
        } type_pointer;

        // 错误联合类型
        struct {
            struct ASTNode *base_type;
        } type_error_union;

        // 原子类型
        struct {
            struct ASTNode *base_type;
        } type_atomic;

        // for 语句
        struct {
            struct ASTNode *iterable;
            struct ASTNode *index_range;  // May be NULL for basic form
            char *item_var;
            char *index_var;              // May be NULL for basic form
            struct ASTNode *body;
        } for_stmt;

        // defer 语句
        struct {
            struct ASTNode *body;        // defer 块
        } defer_stmt;

        // errdefer 语句
        struct {
            struct ASTNode *body;        // errdefer 块
        } errdefer_stmt;

        // 结构体初始化表达式
        struct {
            char *struct_name;
            struct ASTNode **field_inits;
            char **field_names;
            int field_count;
        } struct_init;

        // 成员访问表达式 (obj.field)
        struct {
            struct ASTNode *object;      // 对象表达式
            char *field_name;           // 字段名称
        } member_access;

        // 数组下标访问表达式 (arr[index])
        struct {
            struct ASTNode *array;      // 数组表达式
            struct ASTNode *index;      // 索引表达式
        } subscript_expr;

        // 接口声明
        struct {
            char *name;
            struct ASTNode **methods;    // 方法声明列表（函数声明）
            int method_count;
        } interface_decl;

        // 接口实现声明 (StructName : InterfaceName { ... })
        // 新语法（0.24版本）：移除了 impl 关键字
        struct {
            char *struct_name;           // 结构体名称
            char *interface_name;        // 接口名称
            struct ASTNode **methods;    // 方法实现列表（函数声明）
            int method_count;
        } impl_decl;

        // 测试块 (test "说明文字" { ... })
        struct {
            char *name;                  // 测试名称（说明文字）
            struct ASTNode *body;        // 测试体
        } test_block;
    } data;
} ASTNode;

// AST 操作函数
ASTNode *ast_new_node(ASTNodeType type, int line, int column, const char *filename);
void ast_free(ASTNode *node);
void ast_print(ASTNode *node, int indent);

#endif