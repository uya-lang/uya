#ifndef AST_H
#define AST_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

    // 表达式类型
    AST_BINARY_EXPR,
    AST_UNARY_EXPR,
    AST_CALL_EXPR,
    AST_MEMBER_ACCESS,
    AST_SUBSCRIPT_EXPR,
    AST_IDENTIFIER,
    AST_NUMBER,
    AST_STRING,
    AST_BOOL,
    AST_NULL,
    AST_ERROR_EXPR,

    // 类型相关
    AST_TYPE_NAMED,
    AST_TYPE_POINTER,
    AST_TYPE_ARRAY,
    AST_TYPE_FN,
    AST_TYPE_ERROR_UNION,
    AST_TYPE_BOOL,

    // 接口相关
    AST_INTERFACE_DECL,
    AST_IMPL_DECL,

    // 宏相关
    AST_MACRO_DECL,
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
            char *dest;
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

        // for 语句
        struct {
            struct ASTNode *iterable;
            struct ASTNode *index_range;  // May be NULL for basic form
            char *item_var;
            char *index_var;              // May be NULL for basic form
            struct ASTNode *body;
        } for_stmt;
    } data;
} ASTNode;

// AST 操作函数
ASTNode *ast_new_node(ASTNodeType type, int line, int column, const char *filename);
void ast_free(ASTNode *node);
void ast_print(ASTNode *node, int indent);

#endif