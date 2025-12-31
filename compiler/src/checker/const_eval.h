#ifndef CONST_EVAL_H
#define CONST_EVAL_H

#include "../parser/ast.h"

// 常量值类型
typedef enum {
    CONST_VAL_INT,
    CONST_VAL_FLOAT,
    CONST_VAL_BOOL,
    CONST_VAL_NONE  // 不是常量
} ConstValueType;

// 常量值
typedef struct ConstValue {
    ConstValueType type;
    union {
        long long int_val;
        double float_val;
        int bool_val;
    } value;
} ConstValue;

// 常量表达式求值
// 返回1表示是常量，0表示不是常量
// 如果返回1，结果存储在result中
int const_eval_expr(ASTNode *expr, ConstValue *result);

// 检查表达式是否为常量
int const_is_constant(ASTNode *expr);

// 获取常量整数值（如果不是常量或不是整数，返回0）
long long const_get_int_value(ASTNode *expr);

#endif // CONST_EVAL_H


