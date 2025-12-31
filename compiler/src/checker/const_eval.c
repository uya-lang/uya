#include "const_eval.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <limits.h>

// 检查表达式是否为常量
int const_is_constant(ASTNode *expr) {
    if (!expr) return 0;
    
    switch (expr->type) {
        case AST_NUMBER:
        case AST_BOOL:
        case AST_STRING:
            return 1;
        case AST_IDENTIFIER:
            // 变量引用不是常量（除非是const变量，但需要符号表信息）
            return 0;
        case AST_BINARY_EXPR: {
            // 递归检查左右操作数
            int left_const = const_is_constant(expr->data.binary_expr.left);
            int right_const = const_is_constant(expr->data.binary_expr.right);
            return left_const && right_const;
        }
        case AST_UNARY_EXPR: {
            // 递归检查操作数
            return const_is_constant(expr->data.unary_expr.operand);
        }
        default:
            return 0;
    }
}

// 获取常量整数值
long long const_get_int_value(ASTNode *expr) {
    if (!expr) return 0;
    
    if (expr->type == AST_NUMBER) {
        char *endptr;
        long long val = strtoll(expr->data.number.value, &endptr, 10);
        if (*endptr == '\0' && errno != ERANGE) {
            return val;
        }
    } else if (expr->type == AST_BOOL) {
        return expr->data.bool_literal.value ? 1 : 0;
    }
    
    return 0;
}

// 常量表达式求值
int const_eval_expr(ASTNode *expr, ConstValue *result) {
    if (!expr || !result) return 0;
    
    result->type = CONST_VAL_NONE;
    
    switch (expr->type) {
        case AST_NUMBER: {
            char *endptr;
            errno = 0;
            long long int_val = strtoll(expr->data.number.value, &endptr, 10);
            
            // 检查是否是整数
            if (*endptr == '\0' && errno != ERANGE) {
                result->type = CONST_VAL_INT;
                result->value.int_val = int_val;
                return 1;
            }
            
            // 尝试作为浮点数解析
            errno = 0;
            double float_val = strtod(expr->data.number.value, &endptr);
            if (*endptr == '\0' && errno != ERANGE) {
                result->type = CONST_VAL_FLOAT;
                result->value.float_val = float_val;
                return 1;
            }
            
            return 0;
        }
        
        case AST_BOOL: {
            result->type = CONST_VAL_BOOL;
            result->value.bool_val = expr->data.bool_literal.value;
            return 1;
        }
        
        case AST_BINARY_EXPR: {
            ConstValue left_val, right_val;
            int left_const = const_eval_expr(expr->data.binary_expr.left, &left_val);
            int right_const = const_eval_expr(expr->data.binary_expr.right, &right_val);
            
            if (!left_const || !right_const) {
                return 0;  // 不是常量表达式
            }
            
            // 根据操作符类型进行运算
            int op = expr->data.binary_expr.op;
            
            // 整数运算
            if (left_val.type == CONST_VAL_INT && right_val.type == CONST_VAL_INT) {
                long long a = left_val.value.int_val;
                long long b = right_val.value.int_val;
                long long result_val;
                int overflow = 0;
                
                switch (op) {
                    case 36: // TOKEN_PLUS
                        result_val = a + b;
                        // 检查溢出（简化版）
                        if ((a > 0 && b > 0 && result_val < a) ||
                            (a < 0 && b < 0 && result_val > a)) {
                            overflow = 1;
                        }
                        break;
                    case 37: // TOKEN_MINUS
                        result_val = a - b;
                        if ((a > 0 && b < 0 && result_val < a) ||
                            (a < 0 && b > 0 && result_val > a)) {
                            overflow = 1;
                        }
                        break;
                    case 38: // TOKEN_ASTERISK
                        result_val = a * b;
                        // 简化的溢出检查
                        if (a != 0 && result_val / a != b) {
                            overflow = 1;
                        }
                        break;
                    case 39: // TOKEN_SLASH
                        if (b == 0) {
                            return 0;  // 除零错误
                        }
                        result_val = a / b;
                        break;
                    case 40: // TOKEN_PERCENT
                        if (b == 0) {
                            return 0;  // 除零错误
                        }
                        result_val = a % b;
                        break;
                    case 57: // TOKEN_EQUAL
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a == b);
                        return 1;
                    case 58: // TOKEN_NOT_EQUAL
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a != b);
                        return 1;
                    case 59: // TOKEN_LESS
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a < b);
                        return 1;
                    case 60: // TOKEN_LESS_EQUAL
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a <= b);
                        return 1;
                    case 61: // TOKEN_GREATER
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a > b);
                        return 1;
                    case 62: // TOKEN_GREATER_EQUAL
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a >= b);
                        return 1;
                    default:
                        return 0;  // 不支持的操作符
                }
                
                if (overflow) {
                    return 0;  // 溢出，不是有效常量
                }
                
                result->type = CONST_VAL_INT;
                result->value.int_val = result_val;
                return 1;
            }
            
            // 浮点数运算
            if (left_val.type == CONST_VAL_FLOAT || right_val.type == CONST_VAL_FLOAT) {
                double a = (left_val.type == CONST_VAL_FLOAT) ? left_val.value.float_val : (double)left_val.value.int_val;
                double b = (right_val.type == CONST_VAL_FLOAT) ? right_val.value.float_val : (double)right_val.value.int_val;
                double result_val;
                
                switch (op) {
                    case 36: // TOKEN_PLUS
                        result_val = a + b;
                        break;
                    case 37: // TOKEN_MINUS
                        result_val = a - b;
                        break;
                    case 38: // TOKEN_ASTERISK
                        result_val = a * b;
                        break;
                    case 39: // TOKEN_SLASH
                        if (b == 0.0) {
                            return 0;  // 除零错误
                        }
                        result_val = a / b;
                        break;
                    case 57: // TOKEN_EQUAL
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a == b);
                        return 1;
                    case 58: // TOKEN_NOT_EQUAL
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a != b);
                        return 1;
                    case 59: // TOKEN_LESS
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a < b);
                        return 1;
                    case 60: // TOKEN_LESS_EQUAL
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a <= b);
                        return 1;
                    case 61: // TOKEN_GREATER
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a > b);
                        return 1;
                    case 62: // TOKEN_GREATER_EQUAL
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = (a >= b);
                        return 1;
                    default:
                        return 0;
                }
                
                result->type = CONST_VAL_FLOAT;
                result->value.float_val = result_val;
                return 1;
            }
            
            return 0;
        }
        
        case AST_UNARY_EXPR: {
            ConstValue operand_val;
            int operand_const = const_eval_expr(expr->data.unary_expr.operand, &operand_val);
            
            if (!operand_const) {
                return 0;
            }
            
            int op = expr->data.unary_expr.op;
            
            switch (op) {
                case 37: // TOKEN_MINUS (负号)
                    if (operand_val.type == CONST_VAL_INT) {
                        result->type = CONST_VAL_INT;
                        result->value.int_val = -operand_val.value.int_val;
                        return 1;
                    } else if (operand_val.type == CONST_VAL_FLOAT) {
                        result->type = CONST_VAL_FLOAT;
                        result->value.float_val = -operand_val.value.float_val;
                        return 1;
                    }
                    break;
                case 73: // TOKEN_EXCLAMATION (逻辑非)
                    if (operand_val.type == CONST_VAL_BOOL) {
                        result->type = CONST_VAL_BOOL;
                        result->value.bool_val = !operand_val.value.bool_val;
                        return 1;
                    }
                    break;
                default:
                    return 0;
            }
            
            return 0;
        }
        
        default:
            return 0;  // 不是常量表达式
    }
}

