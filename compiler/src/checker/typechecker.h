#ifndef TYPECHECKER_H
#define TYPECHECKER_H

#include "../parser/ast.h"
#include "../ir/ir.h"
#include "constraints.h"
#include "const_eval.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// 符号信息
typedef struct Symbol {
    char *name;
    IRType type;
    int is_mut;
    int is_const;
    int is_initialized;
    int is_modified;           // 是否被修改过
    int scope_level;
    int line, column;
    char *filename;
    char *original_type_name;  // 用于用户定义类型
    // 数组类型信息
    int array_size;            // 数组大小（-1表示非数组或未知大小）
    IRType array_element_type; // 数组元素类型（仅当type为IR_TYPE_ARRAY时有效）
} Symbol;

// 函数签名信息
typedef struct FunctionSignature {
    char *name;
    IRType *param_types;       // 参数类型数组
    int param_count;
    IRType return_type;
    int is_extern;             // 是否为extern函数
    int has_varargs;           // 是否有可变参数（...）
    int line, column;
    char *filename;
} FunctionSignature;

// 函数表
typedef struct FunctionTable {
    FunctionSignature **functions;
    int function_count;
    int function_capacity;
} FunctionTable;

// 符号表
typedef struct SymbolTable {
    Symbol **symbols;
    int symbol_count;
    int symbol_capacity;
} SymbolTable;

// 作用域栈
typedef struct ScopeStack {
    int *levels;
    int level_count;
    int level_capacity;
    int current_level;
} ScopeStack;

// 类型检查器结构
typedef struct TypeChecker {
    // 错误管理
    int error_count;
    char **errors;
    int error_capacity;
    
    // 符号表和作用域
    SymbolTable *symbol_table;
    ScopeStack *scopes;
    
    // 函数表（存储所有函数签名，包括extern函数）
    FunctionTable *function_table;
    
    // 约束条件集合（用于路径敏感分析）
    ConstraintSet *constraints;
    
    // 函数作用域计数器（为每个函数分配唯一的作用域级别）
    int function_scope_counter;
    
    // 扫描阶段：1 = 收集函数签名，2 = 检查函数体
    int scan_pass;
    
    // 当前上下文
    int current_line;
    int current_column;
    char *current_file;
} TypeChecker;

// 类型检查器函数
TypeChecker *typechecker_new();
void typechecker_free(TypeChecker *checker);
int typechecker_check(TypeChecker *checker, ASTNode *ast);

// 错误管理
void typechecker_add_error(TypeChecker *checker, const char *fmt, ...);
void typechecker_print_errors(TypeChecker *checker);

// 符号表操作
Symbol *symbol_new(const char *name, IRType type, int is_mut, int is_const, 
                   int scope_level, int line, int column, const char *filename);
void symbol_free(Symbol *symbol);
int typechecker_add_symbol(TypeChecker *checker, Symbol *symbol);
Symbol *typechecker_lookup_symbol(TypeChecker *checker, const char *name);

// 作用域操作
void typechecker_enter_scope(TypeChecker *checker);
void typechecker_exit_scope(TypeChecker *checker);
int typechecker_get_current_scope(TypeChecker *checker);

// 类型推断
IRType typechecker_infer_type(TypeChecker *checker, ASTNode *expr);
int typechecker_type_match(IRType t1, IRType t2);

// 约束操作
void typechecker_add_constraint(TypeChecker *checker, Constraint *constraint);
Constraint *typechecker_find_constraint(TypeChecker *checker, const char *var_name, ConstraintType type);

// 函数表操作
FunctionSignature *function_signature_new(const char *name, IRType *param_types, int param_count, 
                                          IRType return_type, int is_extern, int has_varargs,
                                          int line, int column, const char *filename);
void function_signature_free(FunctionSignature *sig);
int typechecker_add_function(TypeChecker *checker, FunctionSignature *sig);
FunctionSignature *typechecker_lookup_function(TypeChecker *checker, const char *name);

#endif