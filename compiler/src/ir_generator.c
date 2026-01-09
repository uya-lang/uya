#include "ir/ir.h"
#include "parser/ast.h"
#include "lexer/lexer.h"
#include "checker/const_eval.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declarations
static IRInst *generate_expr(IRGenerator *ir_gen, struct ASTNode *expr);
static IRInst *generate_stmt(IRGenerator *ir_gen, struct ASTNode *stmt);
static IRInst *generate_function(IRGenerator *ir_gen, struct ASTNode *fn_decl);
static IRInst *generate_test_block(IRGenerator *ir_gen, struct ASTNode *test_block);
static void generate_program(IRGenerator *ir_gen, struct ASTNode *program);
static char *get_type_name_string(struct ASTNode *type_node);
static char *generate_tuple_type_name(struct ASTNode *tuple_type);
static IRInst *ensure_tuple_struct_decl(IRGenerator *ir_gen, struct ASTNode *tuple_type);
static IRInst *find_struct_decl(IRGenerator *ir_gen, const char *struct_name);

static IRType get_ir_type(struct ASTNode *ast_type) {
    if (!ast_type) return IR_TYPE_VOID;

    switch (ast_type->type) {
        case AST_TYPE_NAMED:
            {
                const char *name = ast_type->data.type_named.name;
                if (strcmp(name, "i32") == 0) return IR_TYPE_I32;
                if (strcmp(name, "i64") == 0) return IR_TYPE_I64;
                if (strcmp(name, "i8") == 0) return IR_TYPE_I8;
                if (strcmp(name, "i16") == 0) return IR_TYPE_I16;
                if (strcmp(name, "u32") == 0) return IR_TYPE_U32;
                if (strcmp(name, "u64") == 0) return IR_TYPE_U64;
                if (strcmp(name, "u8") == 0) return IR_TYPE_U8;
                if (strcmp(name, "u16") == 0) return IR_TYPE_U16;
                if (strcmp(name, "f32") == 0) return IR_TYPE_F32;
                if (strcmp(name, "f64") == 0) return IR_TYPE_F64;
                if (strcmp(name, "bool") == 0) return IR_TYPE_BOOL;
                if (strcmp(name, "void") == 0) return IR_TYPE_VOID;
                if (strcmp(name, "byte") == 0) return IR_TYPE_BYTE;

                // Handle generic type parameter T (temporarily treat as i32 until generics are fully implemented)
                if (strcmp(name, "T") == 0) return IR_TYPE_I32;

                // For user-defined types like Point, Vec3, etc., return STRUCT type
                return IR_TYPE_STRUCT;
            }
        case AST_TYPE_ARRAY:
            return IR_TYPE_ARRAY;
        case AST_TYPE_POINTER:
            return IR_TYPE_PTR;
        case AST_TYPE_ERROR_UNION:
            // For error union types, temporarily return the base type
            // Full error handling implementation will be added later
            return get_ir_type(ast_type->data.type_error_union.base_type);
        case AST_TYPE_ATOMIC:
            // For atomic types, return the base type
            // The atomic flag will be set separately
            return get_ir_type(ast_type->data.type_atomic.base_type);
        case AST_TYPE_FN:
            // 函数指针类型：fn(param_types) return_type
            return IR_TYPE_FN;
        case AST_TYPE_TUPLE:
            // 元组类型使用 IR_TYPE_STRUCT 作为占位符
            return IR_TYPE_STRUCT;
        default:
            return IR_TYPE_VOID;
    }
}

// 从表达式节点推断 IR 类型（简化版）
static IRType infer_ir_type_from_expr(struct ASTNode *expr) {
    if (!expr) return IR_TYPE_VOID;
    
    switch (expr->type) {
        case AST_NUMBER: {
            // 检查是否是浮点数字面量
            const char *value = expr->data.number.value;
            if (value && (strchr(value, '.') || strchr(value, 'e') || strchr(value, 'E'))) {
                return IR_TYPE_F64;
            }
            return IR_TYPE_I32;
        }
        case AST_BOOL:
            return IR_TYPE_BOOL;
        case AST_IDENTIFIER:
            // 对于标识符，默认返回 i32（实际类型应该在类型检查阶段确定）
            return IR_TYPE_I32;
        case AST_BINARY_EXPR:
            // 对于二元表达式，返回左操作数的类型
            return infer_ir_type_from_expr(expr->data.binary_expr.left);
        case AST_UNARY_EXPR:
            // 对于一元表达式，返回操作数的类型
            return infer_ir_type_from_expr(expr->data.unary_expr.operand);
        default:
            return IR_TYPE_I32;  // 默认返回 i32
    }
}

// Forward declarations
static IRInst *generate_expr(IRGenerator *ir_gen, struct ASTNode *expr);
static IRInst *generate_function(IRGenerator *ir_gen, struct ASTNode *fn_decl);

static IRInst *generate_expr(IRGenerator *ir_gen, struct ASTNode *expr) {
    if (!expr) return NULL;

    switch (expr->type) {
        case AST_NUMBER: {
            // Create a constant for the number
            IRInst *const_inst = irinst_new(IR_CONSTANT);
            if (!const_inst) return NULL;

            // Store the numeric value
            const_inst->data.constant.value = malloc(strlen(expr->data.number.value) + 1);
            if (!const_inst->data.constant.value) {
                irinst_free(const_inst);
                return NULL;
            }
            strcpy(const_inst->data.constant.value, expr->data.number.value);
            const_inst->data.constant.type = IR_TYPE_I32; // Numbers default to i32

            return const_inst;
        }

        case AST_IDENTIFIER: {
            // Create a reference to an existing variable
            IRInst *id_inst = irinst_new(IR_VAR_DECL);
            if (!id_inst) return NULL;

            id_inst->data.var.name = malloc(strlen(expr->data.identifier.name) + 1);
            if (id_inst->data.var.name) {
                strcpy(id_inst->data.var.name, expr->data.identifier.name);
                id_inst->data.var.type = IR_TYPE_I32; // Default type
                id_inst->data.var.init = NULL;
            } else {
                irinst_free(id_inst);
                return NULL;
            }

            return id_inst;
        }

        case AST_CALL_EXPR: {
            // Handle function calls (including slice operations)
            IRInst *call_inst = irinst_new(IR_CALL);
            if (!call_inst) return NULL;

            // Set function name
            if (expr->data.call_expr.callee && expr->data.call_expr.callee->type == AST_IDENTIFIER) {
                call_inst->data.call.func_name = malloc(strlen(expr->data.call_expr.callee->data.identifier.name) + 1);
                if (call_inst->data.call.func_name) {
                    strcpy(call_inst->data.call.func_name, expr->data.call_expr.callee->data.identifier.name);
                } else {
                    irinst_free(call_inst);
                    return NULL;
                }
            } else if (expr->data.call_expr.callee && expr->data.call_expr.callee->type == AST_MEMBER_ACCESS) {
                // Method call: object.method() - generate function name using the field name
                const char *field_name = expr->data.call_expr.callee->data.member_access.field_name;
                call_inst->data.call.func_name = malloc(strlen(field_name) + 1);
                if (call_inst->data.call.func_name) {
                    strcpy(call_inst->data.call.func_name, field_name);
                } else {
                    irinst_free(call_inst);
                    return NULL;
                }
            } else {
                call_inst->data.call.func_name = malloc(8);
                if (call_inst->data.call.func_name) {
                    strcpy(call_inst->data.call.func_name, "unknown");
                } else {
                    irinst_free(call_inst);
                    return NULL;
                }
            }

            // Handle arguments
            // If this is a method call (callee is member_access), prepend the object as first argument
            int is_method_call = (expr->data.call_expr.callee && expr->data.call_expr.callee->type == AST_MEMBER_ACCESS);
            call_inst->data.call.arg_count = expr->data.call_expr.arg_count + (is_method_call ? 1 : 0);
            
            if (call_inst->data.call.arg_count > 0) {
                call_inst->data.call.args = malloc(call_inst->data.call.arg_count * sizeof(IRInst*));
                if (!call_inst->data.call.args) {
                    irinst_free(call_inst);
                    return NULL;
                }
                
                int arg_index = 0;
                
                // If method call, add object as first argument
                // If the method expects a pointer, we need to pass the address of the object
                if (is_method_call) {
                    IRInst *object_expr = generate_expr(ir_gen, expr->data.call_expr.callee->data.member_access.object);
                    if (!object_expr) {
                        irinst_free(call_inst);
                        return NULL;
                    }
                    
                    // For method calls, the first parameter is typically a pointer to the struct
                    // So we need to take the address of the object if it's a value type
                    // Check if object is a value type (not already a pointer)
                    if (object_expr->type == IR_VAR_DECL && object_expr->data.var.type != IR_TYPE_PTR) {
                        // Create address-of operation: &object
                        IRInst *addr_of = irinst_new(IR_UNARY_OP);
                        if (addr_of) {
                            addr_of->data.unary_op.op = IR_OP_ADDR_OF;
                            addr_of->data.unary_op.operand = object_expr;
                            call_inst->data.call.args[arg_index] = addr_of;
                        } else {
                            call_inst->data.call.args[arg_index] = object_expr;
                        }
                    } else {
                        call_inst->data.call.args[arg_index] = object_expr;
                    }
                    arg_index++;
                }
                
                // Add the rest of the arguments
                for (int i = 0; i < expr->data.call_expr.arg_count; i++) {
                    call_inst->data.call.args[arg_index] = generate_expr(ir_gen, expr->data.call_expr.args[i]);
                    if (!call_inst->data.call.args[arg_index]) {
                        irinst_free(call_inst);
                        return NULL;
                    }
                    arg_index++;
                }
            } else {
                call_inst->data.call.args = NULL;
            }

            return call_inst;
        }


        case AST_BINARY_EXPR: {
            // Handle binary expressions like x > 5, a + b, etc.
            IRInst *binary_op = irinst_new(IR_BINARY_OP);
            if (!binary_op) return NULL;

            // Map AST operator to IR operator
            switch (expr->data.binary_expr.op) {
                case TOKEN_PLUS: binary_op->data.binary_op.op = IR_OP_ADD; break;
                case TOKEN_MINUS: binary_op->data.binary_op.op = IR_OP_SUB; break;
                case TOKEN_ASTERISK: binary_op->data.binary_op.op = IR_OP_MUL; break;
                case TOKEN_SLASH: binary_op->data.binary_op.op = IR_OP_DIV; break;
                case TOKEN_PERCENT: binary_op->data.binary_op.op = IR_OP_MOD; break;
                case TOKEN_EQUAL: binary_op->data.binary_op.op = IR_OP_EQ; break;
                case TOKEN_NOT_EQUAL: binary_op->data.binary_op.op = IR_OP_NE; break;
                case TOKEN_LESS: binary_op->data.binary_op.op = IR_OP_LT; break;
                case TOKEN_LESS_EQUAL: binary_op->data.binary_op.op = IR_OP_LE; break;
                case TOKEN_GREATER: binary_op->data.binary_op.op = IR_OP_GT; break;
                case TOKEN_GREATER_EQUAL: binary_op->data.binary_op.op = IR_OP_GE; break;
                default: binary_op->data.binary_op.op = IR_OP_ADD; break; // default
            }

            // Generate left and right operands
            binary_op->data.binary_op.left = generate_expr(ir_gen, expr->data.binary_expr.left);
            binary_op->data.binary_op.right = generate_expr(ir_gen, expr->data.binary_expr.right);

            // Generate a destination variable name
            char temp_name[32];
            snprintf(temp_name, sizeof(temp_name), "temp_%d", ir_gen->current_id++);
            binary_op->data.binary_op.dest = malloc(strlen(temp_name) + 1);
            if (binary_op->data.binary_op.dest) {
                strcpy(binary_op->data.binary_op.dest, temp_name);
            }

            return binary_op;
        }

        case AST_STRING: {
            // Handle string literals
            IRInst *const_str = irinst_new(IR_CONSTANT);
            if (!const_str) return NULL;

            // Store the string value (remove quotes if present)
            if (expr->data.string.value) {
                const char *src = expr->data.string.value;
                size_t len = strlen(src);
                
                // Remove leading and trailing quotes if present
                const char *start = src;
                const char *end = src + len - 1;
                if (len >= 2 && *start == '"' && *end == '"') {
                    start++;  // Skip leading quote
                    len -= 2; // Remove both quotes
                }
                
                // Allocate memory for the string value (without quotes)
                const_str->data.constant.value = malloc(len + 1);
                if (const_str->data.constant.value) {
                    strncpy(const_str->data.constant.value, start, len);
                    const_str->data.constant.value[len] = '\0';
                }
            } else {
                const_str->data.constant.value = NULL;
            }
            // Mark as pointer type (string literals are pointers to char in C)
            const_str->data.constant.type = IR_TYPE_PTR;

            return const_str;
        }

        case AST_STRING_INTERPOLATION: {
            // 创建字符串插值 IR 指令
            IRInst *interp_inst = irinst_new(IR_STRING_INTERPOLATION);
            if (!interp_inst) return NULL;
            
            ASTNode *interp_node = expr;
            int text_count = interp_node->data.string_interpolation.text_count;
            int interp_count = interp_node->data.string_interpolation.interp_count;
            
            // 分配文本段数组
            interp_inst->data.string_interpolation.text_segments = malloc(text_count * sizeof(char*));
            if (!interp_inst->data.string_interpolation.text_segments) {
                irinst_free(interp_inst);
                return NULL;
            }
            interp_inst->data.string_interpolation.text_count = text_count;
            
            // 复制文本段
            for (int i = 0; i < text_count; i++) {
                if (interp_node->data.string_interpolation.text_segments[i]) {
                    size_t len = strlen(interp_node->data.string_interpolation.text_segments[i]);
                    interp_inst->data.string_interpolation.text_segments[i] = malloc(len + 1);
                    if (interp_inst->data.string_interpolation.text_segments[i]) {
                        strcpy(interp_inst->data.string_interpolation.text_segments[i],
                               interp_node->data.string_interpolation.text_segments[i]);
                    }
                } else {
                    interp_inst->data.string_interpolation.text_segments[i] = NULL;
                }
            }
            
            // 分配插值表达式数组、格式字符串数组、常量标记数组和常量值数组
            interp_inst->data.string_interpolation.interp_exprs = malloc(interp_count * sizeof(IRInst*));
            interp_inst->data.string_interpolation.format_strings = malloc(interp_count * sizeof(char*));
            interp_inst->data.string_interpolation.is_const = malloc(interp_count * sizeof(int));
            interp_inst->data.string_interpolation.const_values = malloc(interp_count * sizeof(char*));
            if (!interp_inst->data.string_interpolation.interp_exprs ||
                !interp_inst->data.string_interpolation.format_strings ||
                !interp_inst->data.string_interpolation.is_const ||
                !interp_inst->data.string_interpolation.const_values) {
                // 清理已分配的内存
                for (int i = 0; i < text_count; i++) {
                    if (interp_inst->data.string_interpolation.text_segments[i]) {
                        free(interp_inst->data.string_interpolation.text_segments[i]);
                    }
                }
                free(interp_inst->data.string_interpolation.text_segments);
                if (interp_inst->data.string_interpolation.interp_exprs) {
                    free(interp_inst->data.string_interpolation.interp_exprs);
                }
                if (interp_inst->data.string_interpolation.format_strings) {
                    free(interp_inst->data.string_interpolation.format_strings);
                }
                if (interp_inst->data.string_interpolation.is_const) {
                    free(interp_inst->data.string_interpolation.is_const);
                }
                if (interp_inst->data.string_interpolation.const_values) {
                    free(interp_inst->data.string_interpolation.const_values);
                }
                irinst_free(interp_inst);
                return NULL;
            }
            interp_inst->data.string_interpolation.interp_count = interp_count;
            
            // 初始化常量标记和常量值数组
            for (int i = 0; i < interp_count; i++) {
                interp_inst->data.string_interpolation.is_const[i] = 0;
                interp_inst->data.string_interpolation.const_values[i] = NULL;
            }
            
            // 生成插值表达式的 IR 并构建格式字符串
            for (int i = 0; i < interp_count; i++) {
                // 生成插值表达式的 IR
                ASTNode *expr_node = interp_node->data.string_interpolation.interp_exprs[i];
                IRInst *expr_ir = generate_expr(ir_gen, expr_node);
                if (!expr_ir) {
                    // 清理已分配的内存
                    for (int j = 0; j < i; j++) {
                        irinst_free(interp_inst->data.string_interpolation.interp_exprs[j]);
                        if (interp_inst->data.string_interpolation.format_strings[j]) {
                            free(interp_inst->data.string_interpolation.format_strings[j]);
                        }
                    }
                    for (int j = 0; j < text_count; j++) {
                        if (interp_inst->data.string_interpolation.text_segments[j]) {
                            free(interp_inst->data.string_interpolation.text_segments[j]);
                        }
                    }
                    free(interp_inst->data.string_interpolation.text_segments);
                    free(interp_inst->data.string_interpolation.interp_exprs);
                    free(interp_inst->data.string_interpolation.format_strings);
                    irinst_free(interp_inst);
                    return NULL;
                }
                interp_inst->data.string_interpolation.interp_exprs[i] = expr_ir;
                
                // 构建格式字符串
                FormatSpec *spec = &interp_node->data.string_interpolation.format_specs[i];
                char format_buf[64] = {0};
                int pos = 0;
                
                // 添加 flags
                if (spec->flags) {
                    pos += snprintf(format_buf + pos, sizeof(format_buf) - pos, "%s", spec->flags);
                }
                
                // 添加 width
                if (spec->width >= 0) {
                    pos += snprintf(format_buf + pos, sizeof(format_buf) - pos, "%d", spec->width);
                }
                
                // 添加 precision
                if (spec->precision >= 0) {
                    pos += snprintf(format_buf + pos, sizeof(format_buf) - pos, ".%d", spec->precision);
                }
                
                // 添加 type（如果没有指定，根据表达式类型推断）
                if (spec->type != '\0') {
                    format_buf[pos++] = spec->type;
                } else {
                    // 根据表达式类型推断默认格式
                    IRType expr_type = infer_ir_type_from_expr(expr_node);
                    switch (expr_type) {
                        case IR_TYPE_I32:
                        case IR_TYPE_I64:
                        case IR_TYPE_I8:
                        case IR_TYPE_I16:
                            format_buf[pos++] = 'd';
                            break;
                        case IR_TYPE_U32:
                        case IR_TYPE_U64:
                        case IR_TYPE_U8:
                        case IR_TYPE_U16:
                            format_buf[pos++] = 'u';
                            break;
                        case IR_TYPE_F32:
                        case IR_TYPE_F64:
                            format_buf[pos++] = 'f';
                            break;
                        case IR_TYPE_BOOL:
                            format_buf[pos++] = 'd';  // bool 用 %d 输出
                            break;
                        default:
                            format_buf[pos++] = 'd';  // 默认
                            break;
                    }
                }
                format_buf[pos] = '\0';
                
                // 分配格式字符串
                interp_inst->data.string_interpolation.format_strings[i] = malloc(strlen(format_buf) + 3);  // "%" + format + "\0"
                if (interp_inst->data.string_interpolation.format_strings[i]) {
                    snprintf(interp_inst->data.string_interpolation.format_strings[i],
                            strlen(format_buf) + 3, "%%%s", format_buf);
                } else {
                    interp_inst->data.string_interpolation.format_strings[i] = NULL;
                }
                
                // 检查是否是编译期常量，如果是，在编译期格式化
                ConstValue const_val;
                if (const_eval_expr(expr_node, &const_val)) {
                    // 是编译期常量，在编译期格式化
                    interp_inst->data.string_interpolation.is_const[i] = 1;
                    char formatted_buf[128] = {0};
                    
                    // 构建完整的格式字符串（包含 %）
                    char full_format[128] = {0};
                    snprintf(full_format, sizeof(full_format), "%%%s", format_buf);
                    
                    // 根据常量类型和格式说明符格式化
                    switch (const_val.type) {
                        case CONST_VAL_INT:
                            snprintf(formatted_buf, sizeof(formatted_buf), full_format, const_val.value.int_val);
                            break;
                        case CONST_VAL_FLOAT:
                            snprintf(formatted_buf, sizeof(formatted_buf), full_format, const_val.value.float_val);
                            break;
                        case CONST_VAL_BOOL:
                            snprintf(formatted_buf, sizeof(formatted_buf), full_format, const_val.value.bool_val);
                            break;
                        default:
                            interp_inst->data.string_interpolation.is_const[i] = 0;
                            break;
                    }
                    
                    if (interp_inst->data.string_interpolation.is_const[i]) {
                        // 保存格式化后的字符串
                        size_t formatted_len = strlen(formatted_buf);
                        interp_inst->data.string_interpolation.const_values[i] = malloc(formatted_len + 1);
                        if (interp_inst->data.string_interpolation.const_values[i]) {
                            strcpy(interp_inst->data.string_interpolation.const_values[i], formatted_buf);
                        }
                    }
                } else {
                    // 不是编译期常量，运行时格式化
                    interp_inst->data.string_interpolation.is_const[i] = 0;
                }
            }
            
            // 计算缓冲区大小（根据类型和格式说明符查表）
            int total_size = 0;
            for (int i = 0; i < interp_count; i++) {
                ASTNode *expr_node = interp_node->data.string_interpolation.interp_exprs[i];
                FormatSpec *spec = &interp_node->data.string_interpolation.format_specs[i];
                
                // 推断表达式类型
                IRType expr_type = infer_ir_type_from_expr(expr_node);
                
                // 确定格式类型
                char format_type = spec->type;
                if (format_type == '\0') {
                    // 根据表达式类型推断默认格式
                    switch (expr_type) {
                        case IR_TYPE_I32:
                        case IR_TYPE_I64:
                        case IR_TYPE_I8:
                        case IR_TYPE_I16:
                            format_type = 'd';
                            break;
                        case IR_TYPE_U32:
                        case IR_TYPE_U64:
                        case IR_TYPE_U8:
                        case IR_TYPE_U16:
                            format_type = 'u';
                            break;
                        case IR_TYPE_F32:
                        case IR_TYPE_F64:
                            format_type = 'f';
                            break;
                        case IR_TYPE_BOOL:
                            format_type = 'd';
                            break;
                        default:
                            format_type = 'd';
                            break;
                    }
                }
                
                // 根据类型和格式说明符查表计算最大宽度
                int max_width = 0;
                int is_long = (expr_type == IR_TYPE_I64 || expr_type == IR_TYPE_U64);
                
                switch (format_type) {
                    case 'd':
                    case 'u':
                        if (is_long) {
                            max_width = 21;  // 64位整数最大21字节（含符号和NUL）
                        } else {
                            max_width = 11;  // 32位整数最大11字节（含符号和NUL）
                        }
                        break;
                    case 'x':
                    case 'X':
                        if (is_long) {
                            max_width = 17;  // 64位十六进制最大17字节
                        } else {
                            max_width = 8;   // 32位十六进制最大8字节
                        }
                        // 检查是否有 # 标志（添加 0x 前缀）
                        if (spec->flags && strchr(spec->flags, '#')) {
                            max_width += 2;  // 添加 "0x" 前缀
                        }
                        break;
                    case 'f':
                    case 'F':
                        if (expr_type == IR_TYPE_F64) {
                            max_width = 24;  // f64 最大24字节
                        } else {
                            max_width = 16;  // f32 最大16字节
                        }
                        break;
                    case 'e':
                    case 'E':
                        // 科学计数法格式：[-]d.ddde[+-]dd
                        // f64: 符号(1) + 整数(1) + 小数点(1) + 小数部分(最多15位) + e/E(1) + 符号(1) + 指数(3) + NUL(1) = 最多24字节
                        // f32: 符号(1) + 整数(1) + 小数点(1) + 小数部分(最多6位) + e/E(1) + 符号(1) + 指数(2) + NUL(1) = 最多14字节
                        if (expr_type == IR_TYPE_F64) {
                            max_width = 24;  // f64 最大24字节（与 %f 相同）
                        } else {
                            max_width = 16;  // f32 最大16字节（与 %f 相同）
                        }
                        break;
                    case 'g':
                    case 'G':
                        if (expr_type == IR_TYPE_F64) {
                            max_width = 24;  // f64 最大24字节
                        } else {
                            max_width = 16;  // f32 最大16字节
                        }
                        break;
                    case 'c':
                        max_width = 2;  // 单字符 + NUL
                        break;
                    case 'p':
                        max_width = 18;  // 指针：0x + 16位十六进制（64位平台）
                        break;
                    default:
                        max_width = 11;  // 默认使用32位整数宽度
                        break;
                }
                
                // 如果指定了 width，取较大值
                if (spec->width >= 0 && spec->width + 1 > max_width) {
                    max_width = spec->width + 1;  // +1 for NUL
                }
                
                total_size += max_width;
            }
            
            // 添加文本段的总长度
            for (int i = 0; i < text_count; i++) {
                if (interp_inst->data.string_interpolation.text_segments[i]) {
                    total_size += strlen(interp_inst->data.string_interpolation.text_segments[i]);
                }
            }
            
            // 向上对齐到8的倍数（方便对齐，可选）
            int aligned_size = ((total_size + 7) / 8) * 8;
            interp_inst->data.string_interpolation.buffer_size = aligned_size > 0 ? aligned_size : 8;
            
            return interp_inst;
        }

        case AST_BOOL: {
            // Handle boolean literals
            IRInst *const_bool = irinst_new(IR_CONSTANT);
            if (!const_bool) return NULL;

            // Convert boolean value to string representation
            if (expr->data.bool_literal.value) {
                const_bool->data.constant.value = malloc(5);  // "true" + null terminator
                if (const_bool->data.constant.value) {
                    strcpy(const_bool->data.constant.value, "true");
                }
            } else {
                const_bool->data.constant.value = malloc(6);  // "false" + null terminator
                if (const_bool->data.constant.value) {
                    strcpy(const_bool->data.constant.value, "false");
                }
            }
            const_bool->data.constant.type = IR_TYPE_BOOL;

            return const_bool;
        }

        case AST_UNARY_EXPR: {
            // Handle unary expressions like &variable, -x, !x, try x
            if (expr->data.unary_expr.op == TOKEN_TRY) {
                // Handle try expressions: try expr (error propagation) and try a + b (overflow checking)
                // For now, we'll generate a special error union operation for try expressions
                IRInst *try_op = irinst_new(IR_ERROR_UNION);
                if (!try_op) return NULL;

                // Generate the operand expression
                try_op->data.error_union.value = generate_expr(ir_gen, expr->data.unary_expr.operand);
                try_op->data.error_union.is_error = 0; // Not an error, just a try operation

                // Generate a destination variable name
                char temp_name[32];
                snprintf(temp_name, sizeof(temp_name), "try_%d", ir_gen->current_id++);
                try_op->data.error_union.dest = malloc(strlen(temp_name) + 1);
                if (try_op->data.error_union.dest) {
                    strcpy(try_op->data.error_union.dest, temp_name);
                }

                return try_op;
            } else {
                // Handle other unary expressions
                IRInst *unary_op = irinst_new(IR_UNARY_OP);
                if (!unary_op) return NULL;

                // Map AST operator to IR operator
                switch (expr->data.unary_expr.op) {
                    case TOKEN_AMPERSAND:
                        unary_op->data.unary_op.op = IR_OP_ADDR_OF;
                        break;
                    case TOKEN_MINUS:
                        unary_op->data.unary_op.op = IR_OP_NEG;
                        break;
                    case TOKEN_EXCLAMATION:
                        unary_op->data.unary_op.op = IR_OP_NOT;
                        break;
                    default:
                        unary_op->data.unary_op.op = IR_OP_ADDR_OF;
                        break; // default to address-of
                }

                // Generate operand
                unary_op->data.unary_op.operand = generate_expr(ir_gen, expr->data.unary_expr.operand);

                // Generate a destination variable name
                char temp_name[32];
                snprintf(temp_name, sizeof(temp_name), "temp_%d", ir_gen->current_id++);
                unary_op->data.unary_op.dest = malloc(strlen(temp_name) + 1);
                if (unary_op->data.unary_op.dest) {
                    strcpy(unary_op->data.unary_op.dest, temp_name);
                }

                return unary_op;
            }
        }

        case AST_MEMBER_ACCESS: {
            // Check if this is error.ErrorName (error namespace access)
            if (expr->data.member_access.object && expr->data.member_access.object->type == AST_IDENTIFIER &&
                expr->data.member_access.object->data.identifier.name &&
                strcmp(expr->data.member_access.object->data.identifier.name, "error") == 0 &&
                expr->data.member_access.field_name) {
                // This is error.ErrorName - generate IR_ERROR_VALUE
                IRInst *error_val = irinst_new(IR_ERROR_VALUE);
                if (!error_val) return NULL;

                // Store the error name
                const char *field_name = expr->data.member_access.field_name;
                if (!field_name) {
                    irinst_free(error_val);
                    return NULL;
                }
                
                error_val->data.error_value.error_name = malloc(strlen(field_name) + 1);
                if (error_val->data.error_value.error_name) {
                    strcpy(error_val->data.error_value.error_name, field_name);
                } else {
                    irinst_free(error_val);
                    return NULL;
                }

                return error_val;
            }

            // Handle regular member access like obj.field
            IRInst *member_access = irinst_new(IR_MEMBER_ACCESS);
            if (!member_access) return NULL;

            // Generate the object expression
            member_access->data.member_access.object = generate_expr(ir_gen, expr->data.member_access.object);

            // Copy the field name
            member_access->data.member_access.field_name = malloc(strlen(expr->data.member_access.field_name) + 1);
            if (member_access->data.member_access.field_name) {
                strcpy(member_access->data.member_access.field_name, expr->data.member_access.field_name);
            }

            // Generate a destination variable name
            char temp_name[32];
            snprintf(temp_name, sizeof(temp_name), "temp_%d", ir_gen->current_id++);
            member_access->data.member_access.dest = malloc(strlen(temp_name) + 1);
            if (member_access->data.member_access.dest) {
                strcpy(member_access->data.member_access.dest, temp_name);
            }

            return member_access;
        }

        case AST_STRUCT_INIT: {
            // Handle struct initialization like Point{ x: 10, y: 20 }
            IRInst *struct_init = irinst_new(IR_STRUCT_INIT);
            if (!struct_init) return NULL;

            // Set struct name
            struct_init->data.struct_init.struct_name = malloc(strlen(expr->data.struct_init.struct_name) + 1);
            if (struct_init->data.struct_init.struct_name) {
                strcpy(struct_init->data.struct_init.struct_name, expr->data.struct_init.struct_name);
            }

            // Set up field names and initializations
            struct_init->data.struct_init.field_count = expr->data.struct_init.field_count;
            if (expr->data.struct_init.field_count > 0) {
                struct_init->data.struct_init.field_names = malloc(expr->data.struct_init.field_count * sizeof(char*));
                struct_init->data.struct_init.field_inits = malloc(expr->data.struct_init.field_count * sizeof(IRInst*));

                if (!struct_init->data.struct_init.field_names || !struct_init->data.struct_init.field_inits) {
                    if (struct_init->data.struct_init.field_names) free(struct_init->data.struct_init.field_names);
                    if (struct_init->data.struct_init.field_inits) free(struct_init->data.struct_init.field_inits);
                    irinst_free(struct_init);
                    return NULL;
                }

                for (int i = 0; i < expr->data.struct_init.field_count; i++) {
                    // Copy field name
                    struct_init->data.struct_init.field_names[i] = malloc(strlen(expr->data.struct_init.field_names[i]) + 1);
                    if (struct_init->data.struct_init.field_names[i]) {
                        strcpy(struct_init->data.struct_init.field_names[i], expr->data.struct_init.field_names[i]);
                    }

                    // Generate field initialization expression
                    struct_init->data.struct_init.field_inits[i] = generate_expr(ir_gen, expr->data.struct_init.field_inits[i]);
                }
            } else {
                struct_init->data.struct_init.field_names = NULL;
                struct_init->data.struct_init.field_inits = NULL;
            }

            return struct_init;
        }

        case AST_CATCH_EXPR: {
            // Handle catch expression: expr catch |err| { ... } or expr catch { ... }
            IRInst *try_catch_inst = irinst_new(IR_TRY_CATCH);
            if (!try_catch_inst) return NULL;
            
            // Generate the try body (the expression that returns !T)
            try_catch_inst->data.try_catch.try_body = generate_expr(ir_gen, expr->data.catch_expr.expr);
            if (!try_catch_inst->data.try_catch.try_body) {
                irinst_free(try_catch_inst);
                return NULL;
            }
            
            // Set error variable name (if provided)
            if (expr->data.catch_expr.error_var) {
                try_catch_inst->data.try_catch.error_var = malloc(strlen(expr->data.catch_expr.error_var) + 1);
                if (try_catch_inst->data.try_catch.error_var) {
                    strcpy(try_catch_inst->data.try_catch.error_var, expr->data.catch_expr.error_var);
                }
            } else {
                try_catch_inst->data.try_catch.error_var = NULL;
            }
            
            // Generate catch body
            if (expr->data.catch_expr.catch_body) {
                // Generate IR for catch body (it's a block)
                IRInst *catch_block = irinst_new(IR_BLOCK);
                if (!catch_block) {
                    irinst_free(try_catch_inst);
                    return NULL;
                }
                
                // Convert block statements to IR
                if (expr->data.catch_expr.catch_body->type == AST_BLOCK) {
                    ASTNode *block = expr->data.catch_expr.catch_body;
                    catch_block->data.block.inst_count = block->data.block.stmt_count;
                    if (block->data.block.stmt_count > 0) {
                        catch_block->data.block.insts = malloc(block->data.block.stmt_count * sizeof(IRInst*));
                        if (!catch_block->data.block.insts) {
                            irinst_free(catch_block);
                            irinst_free(try_catch_inst);
                            return NULL;
                        }
                        for (int i = 0; i < block->data.block.stmt_count; i++) {
                            catch_block->data.block.insts[i] = generate_stmt(ir_gen, block->data.block.stmts[i]);
                        }
                    } else {
                        catch_block->data.block.insts = NULL;
                    }
                } else {
                    // Single statement
                    catch_block->data.block.inst_count = 1;
                    catch_block->data.block.insts = malloc(sizeof(IRInst*));
                    if (!catch_block->data.block.insts) {
                        irinst_free(catch_block);
                        irinst_free(try_catch_inst);
                        return NULL;
                    }
                    catch_block->data.block.insts[0] = generate_stmt(ir_gen, expr->data.catch_expr.catch_body);
                }
                
                try_catch_inst->data.try_catch.catch_body = catch_block;
            } else {
                try_catch_inst->data.try_catch.catch_body = NULL;
            }
            
            return try_catch_inst;
        }

        case AST_SUBSCRIPT_EXPR: {
            // Handle array subscript access: arr[index]
            IRInst *subscript = irinst_new(IR_SUBSCRIPT);
            if (!subscript) return NULL;
            
            // Generate the array expression
            IRInst *array_expr = generate_expr(ir_gen, expr->data.subscript_expr.array);
            if (!array_expr) {
                irinst_free(subscript);
                return NULL;
            }
            
            // Generate the index expression
            IRInst *index_expr = generate_expr(ir_gen, expr->data.subscript_expr.index);
            if (!index_expr) {
                irinst_free(subscript);
                return NULL;
            }
            
            // Store in member_access structure (reusing the structure)
            subscript->data.member_access.object = array_expr;
            subscript->data.member_access.index_expr = index_expr;  // Store index expression
            
            // Convert index expression to string for field_name (for constant indices)
            // For non-constant indices, field_name will be NULL and we'll use index_expr in codegen
            if (index_expr->type == IR_CONSTANT && index_expr->data.constant.value) {
                subscript->data.member_access.field_name = malloc(strlen(index_expr->data.constant.value) + 1);
                if (subscript->data.member_access.field_name) {
                    strcpy(subscript->data.member_access.field_name, index_expr->data.constant.value);
                }
            } else {
                // For non-constant indices, field_name is NULL, we'll use index_expr in codegen
                subscript->data.member_access.field_name = NULL;
            }
            
            return subscript;
        }

        case AST_TUPLE_LITERAL: {
            // Handle tuple literals: (expr1, expr2, ...)
            // Tuples are represented as structs in C with field names _0, _1, _2, etc.
            // We generate a struct initialization with field names _0, _1, etc.
            IRInst *struct_init = irinst_new(IR_STRUCT_INIT);
            if (!struct_init) return NULL;

            // Generate a temporary struct name for the tuple type
            // Format: tuple_N where N is the number of elements
            // In a full implementation, we would generate a unique name based on element types
            char temp_struct_name[64];
            snprintf(temp_struct_name, sizeof(temp_struct_name), "tuple_%d", expr->data.tuple_literal.element_count);
            struct_init->data.struct_init.struct_name = malloc(strlen(temp_struct_name) + 1);
            if (!struct_init->data.struct_init.struct_name) {
                irinst_free(struct_init);
                return NULL;
            }
            strcpy(struct_init->data.struct_init.struct_name, temp_struct_name);

            // Set up field names and initializations
            struct_init->data.struct_init.field_count = expr->data.tuple_literal.element_count;
            if (expr->data.tuple_literal.element_count > 0) {
                struct_init->data.struct_init.field_names = malloc(expr->data.tuple_literal.element_count * sizeof(char*));
                struct_init->data.struct_init.field_inits = malloc(expr->data.tuple_literal.element_count * sizeof(IRInst*));

                if (!struct_init->data.struct_init.field_names || !struct_init->data.struct_init.field_inits) {
                    if (struct_init->data.struct_init.field_names) free(struct_init->data.struct_init.field_names);
                    if (struct_init->data.struct_init.field_inits) free(struct_init->data.struct_init.field_inits);
                    free(struct_init->data.struct_init.struct_name);
                    irinst_free(struct_init);
                    return NULL;
                }

                for (int i = 0; i < expr->data.tuple_literal.element_count; i++) {
                    // Generate field name: _0, _1, _2, etc.
                    char field_name[16];
                    snprintf(field_name, sizeof(field_name), "_%d", i);
                    struct_init->data.struct_init.field_names[i] = malloc(strlen(field_name) + 1);
                    if (!struct_init->data.struct_init.field_names[i]) {
                        // Clean up on failure
                        for (int j = 0; j < i; j++) {
                            free(struct_init->data.struct_init.field_names[j]);
                        }
                        free(struct_init->data.struct_init.field_names);
                        free(struct_init->data.struct_init.field_inits);
                        free(struct_init->data.struct_init.struct_name);
                        irinst_free(struct_init);
                        return NULL;
                    }
                    strcpy(struct_init->data.struct_init.field_names[i], field_name);

                    // Generate field initialization expression
                    struct_init->data.struct_init.field_inits[i] = generate_expr(ir_gen, expr->data.tuple_literal.elements[i]);
                    if (!struct_init->data.struct_init.field_inits[i]) {
                        // Clean up on failure
                        for (int j = 0; j <= i; j++) {
                            free(struct_init->data.struct_init.field_names[j]);
                        }
                        free(struct_init->data.struct_init.field_names);
                        free(struct_init->data.struct_init.field_inits);
                        free(struct_init->data.struct_init.struct_name);
                        irinst_free(struct_init);
                        return NULL;
                    }
                }
            } else {
                struct_init->data.struct_init.field_names = NULL;
                struct_init->data.struct_init.field_inits = NULL;
            }

            return struct_init;
        }

        case AST_MATCH_EXPR: {
            // Handle match expressions: match expr { pattern => body, ... }
            // Generate nested if-else chain for pattern matching
            // Note: match expressions return values, so we generate nested IR_IF structures
            // and handle the return value in code generation using GCC compound statement extension
            
            if (!expr->data.match_expr.expr || expr->data.match_expr.pattern_count == 0) {
                return NULL;
            }

            // Build nested if-else chain from patterns (backwards, so last pattern is innermost)
            IRInst *current_if = NULL;

            for (int i = expr->data.match_expr.pattern_count - 1; i >= 0; i--) {
                struct ASTNode *pattern = expr->data.match_expr.patterns[i];
                if (!pattern || !pattern->data.pattern.body) continue;

                // Generate a fresh match_expr_ir for this pattern to avoid double free
                // Each pattern gets its own copy, so there's no shared reference
                IRInst *match_expr_ir = generate_expr(ir_gen, expr->data.match_expr.expr);
                if (!match_expr_ir) {
                    if (current_if) irinst_free(current_if);
                    return NULL;
                }

                IRInst *if_inst = irinst_new(IR_IF);
                if (!if_inst) {
                    irinst_free(match_expr_ir);
                    if (current_if) irinst_free(current_if);
                    return NULL;
                }

                // Generate body expression
                IRInst *body_expr = generate_expr(ir_gen, pattern->data.pattern.body);
                if (!body_expr) {
                    irinst_free(match_expr_ir);
                    irinst_free(if_inst);
                    if (current_if) irinst_free(current_if);
                    return NULL;
                }

                // Check if this is the else pattern
                int is_else = 0;
                if (pattern->data.pattern.pattern_expr) {
                    if (pattern->data.pattern.pattern_expr->type == AST_IDENTIFIER &&
                        pattern->data.pattern.pattern_expr->data.identifier.name &&
                        strcmp(pattern->data.pattern.pattern_expr->data.identifier.name, "else") == 0) {
                        is_else = 1;
                    }
                }

                if (is_else) {
                    // Else branch: use a constant true condition (always matches)
                    // Free match_expr_ir since we don't need it for else pattern
                    irinst_free(match_expr_ir);
                    
                    IRInst *true_const = irinst_new(IR_CONSTANT);
                    if (!true_const) {
                        irinst_free(body_expr);
                        irinst_free(if_inst);
                        if (current_if) irinst_free(current_if);
                        return NULL;
                    }
                    true_const->data.constant.value = malloc(5);
                    if (true_const->data.constant.value) {
                        strcpy(true_const->data.constant.value, "1");
                    }
                    true_const->data.constant.type = IR_TYPE_BOOL;
                    
                    if_inst->data.if_stmt.condition = true_const;
                    if_inst->data.if_stmt.then_count = 1;
                    if_inst->data.if_stmt.then_body = malloc(sizeof(IRInst*));
                    if (!if_inst->data.if_stmt.then_body) {
                        irinst_free(true_const);
                        irinst_free(body_expr);
                        irinst_free(if_inst);
                        if (current_if) irinst_free(current_if);
                        return NULL;
                    }
                    if_inst->data.if_stmt.then_body[0] = body_expr;  // Store expression (will be handled specially in codegen)
                    if_inst->data.if_stmt.else_body = NULL;
                    if_inst->data.if_stmt.else_count = 0;
                } else {
                    // Check if this is a struct pattern (AST_STRUCT_INIT)
                    IRInst *comparison = NULL;
                    if (pattern->data.pattern.pattern_expr && 
                        pattern->data.pattern.pattern_expr->type == AST_STRUCT_INIT) {
                        // Struct pattern: generate field-by-field comparison
                        // For each field: match_expr.field == pattern.field
                        // Combine all field comparisons with AND
                        
                        struct ASTNode *struct_pattern = pattern->data.pattern.pattern_expr;
                        int field_count = struct_pattern->data.struct_init.field_count;
                        
                        if (field_count == 0) {
                            // Empty struct pattern: always matches (use true constant)
                            // Free match_expr_ir since we don't need it
                            irinst_free(match_expr_ir);
                            
                            IRInst *true_const = irinst_new(IR_CONSTANT);
                            if (!true_const) {
                                irinst_free(body_expr);
                                irinst_free(if_inst);
                                if (current_if) irinst_free(current_if);
                                return NULL;
                            }
                            true_const->data.constant.value = malloc(2);
                            if (true_const->data.constant.value) {
                                strcpy(true_const->data.constant.value, "1");
                            }
                            true_const->data.constant.type = IR_TYPE_BOOL;
                            comparison = true_const;
                        } else {
                            // Find struct declaration to get field types
                            const char *struct_name = struct_pattern->data.struct_init.struct_name;
                            IRInst *struct_decl_ir = find_struct_decl(ir_gen, struct_name);
                            
                            // Generate field comparisons and variable bindings
                            IRInst **field_comparisons = malloc(field_count * sizeof(IRInst*));
                            if (!field_comparisons) {
                                irinst_free(match_expr_ir);
                                irinst_free(body_expr);
                                irinst_free(if_inst);
                                if (current_if) irinst_free(current_if);
                                return NULL;
                            }
                            int valid_comparisons = 0;
                            
                            // Collect variable bindings (identifier fields)
                            IRInst **var_bindings = malloc(field_count * sizeof(IRInst*));
                            int var_binding_count = 0;
                            if (!var_bindings) {
                                free(field_comparisons);
                                irinst_free(match_expr_ir);
                                irinst_free(body_expr);
                                irinst_free(if_inst);
                                if (current_if) irinst_free(current_if);
                                return NULL;
                            }
                            
                            for (int j = 0; j < field_count; j++) {
                                const char *field_name = struct_pattern->data.struct_init.field_names[j];
                                ASTNode *pattern_field_value = struct_pattern->data.struct_init.field_inits[j];
                                
                                if (!field_name || !pattern_field_value) continue;
                                
                                // Check if this is a variable binding (identifier) or comparison (constant)
                                if (pattern_field_value->type == AST_IDENTIFIER) {
                                    // Variable binding: generate variable declaration and assignment
                                    const char *bind_var_name = pattern_field_value->data.identifier.name;
                                    
                                    // Get field type from struct declaration
                                    IRType field_type = IR_TYPE_I32;  // Default type
                                    char *field_type_name = NULL;
                                    if (struct_decl_ir) {
                                        for (int k = 0; k < struct_decl_ir->data.struct_decl.field_count; k++) {
                                            IRInst *field = struct_decl_ir->data.struct_decl.fields[k];
                                            if (field && field->data.var.name && 
                                                strcmp(field->data.var.name, field_name) == 0) {
                                                field_type = field->data.var.type;
                                                if (field->data.var.original_type_name) {
                                                    field_type_name = malloc(strlen(field->data.var.original_type_name) + 1);
                                                    if (field_type_name) {
                                                        strcpy(field_type_name, field->data.var.original_type_name);
                                                    }
                                                }
                                                break;
                                            }
                                        }
                                    }
                                    
                                    // Generate member access: match_expr.field
                                    IRInst *field_access = irinst_new(IR_MEMBER_ACCESS);
                                    if (!field_access) {
                                        if (field_type_name) free(field_type_name);
                                        for (int k = 0; k < valid_comparisons; k++) {
                                            irinst_free(field_comparisons[k]);
                                        }
                                        for (int k = 0; k < var_binding_count; k++) {
                                            irinst_free(var_bindings[k]);
                                        }
                                        free(field_comparisons);
                                        free(var_bindings);
                                        irinst_free(match_expr_ir);
                                        irinst_free(body_expr);
                                        irinst_free(if_inst);
                                        if (current_if) irinst_free(current_if);
                                        return NULL;
                                    }
                                    
                                    field_access->data.member_access.object = match_expr_ir;
                                    field_access->data.member_access.field_name = malloc(strlen(field_name) + 1);
                                    if (field_access->data.member_access.field_name) {
                                        strcpy(field_access->data.member_access.field_name, field_name);
                                    }
                                    field_access->data.member_access.dest = NULL;  // Will be set by codegen
                                    
                                    // Create variable declaration for binding
                                    IRInst *var_decl = irinst_new(IR_VAR_DECL);
                                    if (!var_decl) {
                                        irinst_free(field_access);
                                        if (field_type_name) free(field_type_name);
                                        for (int k = 0; k < valid_comparisons; k++) {
                                            irinst_free(field_comparisons[k]);
                                        }
                                        for (int k = 0; k < var_binding_count; k++) {
                                            irinst_free(var_bindings[k]);
                                        }
                                        free(field_comparisons);
                                        free(var_bindings);
                                        irinst_free(match_expr_ir);
                                        irinst_free(body_expr);
                                        irinst_free(if_inst);
                                        if (current_if) irinst_free(current_if);
                                        return NULL;
                                    }
                                    
                                    var_decl->data.var.name = malloc(strlen(bind_var_name) + 1);
                                    if (var_decl->data.var.name) {
                                        strcpy(var_decl->data.var.name, bind_var_name);
                                    }
                                    var_decl->data.var.type = field_type;
                                    var_decl->data.var.original_type_name = field_type_name;
                                    var_decl->data.var.is_mut = 0;
                                    var_decl->data.var.is_atomic = 0;
                                    var_decl->data.var.init = field_access;  // Initialize with field access
                                    var_decl->id = ir_gen->current_id++;
                                    
                                    var_bindings[var_binding_count++] = var_decl;
                                } else {
                                    // Constant comparison: generate comparison as before
                                    // Generate member access: match_expr.field
                                    IRInst *field_access = irinst_new(IR_MEMBER_ACCESS);
                                    if (!field_access) {
                                        for (int k = 0; k < valid_comparisons; k++) {
                                            irinst_free(field_comparisons[k]);
                                        }
                                        for (int k = 0; k < var_binding_count; k++) {
                                            irinst_free(var_bindings[k]);
                                        }
                                        free(field_comparisons);
                                        free(var_bindings);
                                        irinst_free(match_expr_ir);
                                        irinst_free(body_expr);
                                        irinst_free(if_inst);
                                        if (current_if) irinst_free(current_if);
                                        return NULL;
                                    }
                                    
                                    field_access->data.member_access.object = match_expr_ir;
                                    field_access->data.member_access.field_name = malloc(strlen(field_name) + 1);
                                    if (field_access->data.member_access.field_name) {
                                        strcpy(field_access->data.member_access.field_name, field_name);
                                    }
                                    
                                    char temp_field_name[32];
                                    snprintf(temp_field_name, sizeof(temp_field_name), "match_field_%d", ir_gen->current_id++);
                                    field_access->data.member_access.dest = malloc(strlen(temp_field_name) + 1);
                                    if (field_access->data.member_access.dest) {
                                        strcpy(field_access->data.member_access.dest, temp_field_name);
                                    }
                                    
                                    // Generate pattern field value IR
                                    IRInst *pattern_field_ir = generate_expr(ir_gen, pattern_field_value);
                                    if (!pattern_field_ir) {
                                        irinst_free(field_access);
                                        for (int k = 0; k < valid_comparisons; k++) {
                                            irinst_free(field_comparisons[k]);
                                        }
                                        for (int k = 0; k < var_binding_count; k++) {
                                            irinst_free(var_bindings[k]);
                                        }
                                        free(field_comparisons);
                                        free(var_bindings);
                                        irinst_free(match_expr_ir);
                                        irinst_free(body_expr);
                                        irinst_free(if_inst);
                                        if (current_if) irinst_free(current_if);
                                        return NULL;
                                    }
                                    
                                    // Create field comparison: field_access == pattern_field_ir
                                    IRInst *field_comp = irinst_new(IR_BINARY_OP);
                                    if (!field_comp) {
                                        irinst_free(field_access);
                                        irinst_free(pattern_field_ir);
                                        for (int k = 0; k < valid_comparisons; k++) {
                                            irinst_free(field_comparisons[k]);
                                        }
                                        for (int k = 0; k < var_binding_count; k++) {
                                            irinst_free(var_bindings[k]);
                                        }
                                        free(field_comparisons);
                                        free(var_bindings);
                                        irinst_free(match_expr_ir);
                                        irinst_free(body_expr);
                                        irinst_free(if_inst);
                                        if (current_if) irinst_free(current_if);
                                        return NULL;
                                    }
                                    
                                    field_comp->data.binary_op.op = IR_OP_EQ;
                                    field_comp->data.binary_op.left = field_access;
                                    field_comp->data.binary_op.right = pattern_field_ir;
                                    
                                    char temp_comp_name[32];
                                    snprintf(temp_comp_name, sizeof(temp_comp_name), "match_field_comp_%d", ir_gen->current_id++);
                                    field_comp->data.binary_op.dest = malloc(strlen(temp_comp_name) + 1);
                                    if (field_comp->data.binary_op.dest) {
                                        strcpy(field_comp->data.binary_op.dest, temp_comp_name);
                                    }
                                    
                                    field_comparisons[valid_comparisons++] = field_comp;
                                }
                            }
                            
                            // Generate comparison condition
                            if (valid_comparisons == 0) {
                                // No valid comparisons: use true constant (all fields are bindings)
                                free(field_comparisons);
                                if (var_binding_count == 0) {
                                    // No bindings either: empty struct pattern
                                    free(var_bindings);
                                    irinst_free(match_expr_ir);
                                    IRInst *true_const = irinst_new(IR_CONSTANT);
                                    if (!true_const) {
                                        irinst_free(body_expr);
                                        irinst_free(if_inst);
                                        if (current_if) irinst_free(current_if);
                                        return NULL;
                                    }
                                    true_const->data.constant.value = malloc(2);
                                    if (true_const->data.constant.value) {
                                        strcpy(true_const->data.constant.value, "1");
                                    }
                                    true_const->data.constant.type = IR_TYPE_BOOL;
                                    comparison = true_const;
                                } else {
                                    // All fields are bindings: always match
                                    irinst_free(match_expr_ir);
                                    IRInst *true_const = irinst_new(IR_CONSTANT);
                                    if (!true_const) {
                                        for (int k = 0; k < var_binding_count; k++) {
                                            irinst_free(var_bindings[k]);
                                        }
                                        free(var_bindings);
                                        irinst_free(body_expr);
                                        irinst_free(if_inst);
                                        if (current_if) irinst_free(current_if);
                                        return NULL;
                                    }
                                    true_const->data.constant.value = malloc(2);
                                    if (true_const->data.constant.value) {
                                        strcpy(true_const->data.constant.value, "1");
                                    }
                                    true_const->data.constant.type = IR_TYPE_BOOL;
                                    comparison = true_const;
                                }
                            } else if (valid_comparisons == 1) {
                                // Single field comparison: use it directly
                                comparison = field_comparisons[0];
                                free(field_comparisons);
                                // match_expr_ir is now owned by comparison (through field_access)
                            } else {
                                // Multiple field comparisons: combine with AND
                                // Build binary AND tree: ((comp1 && comp2) && comp3) && ...
                                comparison = field_comparisons[0];
                                for (int j = 1; j < valid_comparisons; j++) {
                                    IRInst *and_op = irinst_new(IR_BINARY_OP);
                                    if (!and_op) {
                                        irinst_free(comparison);
                                        for (int k = j; k < valid_comparisons; k++) {
                                            irinst_free(field_comparisons[k]);
                                        }
                                        free(field_comparisons);
                                        for (int k = 0; k < var_binding_count; k++) {
                                            irinst_free(var_bindings[k]);
                                        }
                                        free(var_bindings);
                                        irinst_free(match_expr_ir);
                                        irinst_free(body_expr);
                                        irinst_free(if_inst);
                                        if (current_if) irinst_free(current_if);
                                        return NULL;
                                    }
                                    
                                    and_op->data.binary_op.op = IR_OP_LOGIC_AND;
                                    and_op->data.binary_op.left = comparison;
                                    and_op->data.binary_op.right = field_comparisons[j];
                                    
                                    char temp_and_name[32];
                                    snprintf(temp_and_name, sizeof(temp_and_name), "match_and_%d", ir_gen->current_id++);
                                    and_op->data.binary_op.dest = malloc(strlen(temp_and_name) + 1);
                                    if (and_op->data.binary_op.dest) {
                                        strcpy(and_op->data.binary_op.dest, temp_and_name);
                                    }
                                    
                                    comparison = and_op;
                                }
                                free(field_comparisons);
                                // match_expr_ir is now owned by comparison (through field_access)
                            }
                            
                            // Store variable bindings for later use in then_body
                            if_inst->data.if_stmt.condition = comparison;
                            // then_count will include var_bindings + body_expr
                            if_inst->data.if_stmt.then_count = var_binding_count + 1;
                            if_inst->data.if_stmt.then_body = malloc((var_binding_count + 1) * sizeof(IRInst*));
                            if (!if_inst->data.if_stmt.then_body) {
                                irinst_free(comparison);
                                for (int k = 0; k < var_binding_count; k++) {
                                    irinst_free(var_bindings[k]);
                                }
                                free(var_bindings);
                                irinst_free(body_expr);
                                irinst_free(if_inst);
                                if (current_if) irinst_free(current_if);
                                return NULL;
                            }
                            
                            // Add variable bindings first, then body expression
                            for (int k = 0; k < var_binding_count; k++) {
                                if_inst->data.if_stmt.then_body[k] = var_bindings[k];
                            }
                            if_inst->data.if_stmt.then_body[var_binding_count] = body_expr;
                            free(var_bindings);
                        }
                    } else {
                        // Regular pattern: generate comparison condition (match_expr == pattern_expr)
                        IRInst *pattern_expr_ir = generate_expr(ir_gen, pattern->data.pattern.pattern_expr);
                        if (!pattern_expr_ir) {
                            irinst_free(match_expr_ir);
                            irinst_free(body_expr);
                            irinst_free(if_inst);
                            if (current_if) irinst_free(current_if);
                            return NULL;
                        }

                        // Create comparison: match_expr == pattern_expr
                        comparison = irinst_new(IR_BINARY_OP);
                        if (!comparison) {
                            irinst_free(match_expr_ir);
                            irinst_free(pattern_expr_ir);
                            irinst_free(body_expr);
                            irinst_free(if_inst);
                            if (current_if) irinst_free(current_if);
                            return NULL;
                        }

                        comparison->data.binary_op.op = IR_OP_EQ;
                        comparison->data.binary_op.left = match_expr_ir;
                        comparison->data.binary_op.right = pattern_expr_ir;
                        
                        char temp_name[32];
                        snprintf(temp_name, sizeof(temp_name), "match_cond_%d", ir_gen->current_id++);
                        comparison->data.binary_op.dest = malloc(strlen(temp_name) + 1);
                        if (!comparison->data.binary_op.dest) {
                            irinst_free(comparison);
                            irinst_free(pattern_expr_ir);
                            irinst_free(body_expr);
                            irinst_free(if_inst);
                            if (current_if) irinst_free(current_if);
                            return NULL;
                        }
                        strcpy(comparison->data.binary_op.dest, temp_name);
                    }

                    if (!comparison) {
                        irinst_free(body_expr);
                        irinst_free(if_inst);
                        if (current_if) irinst_free(current_if);
                        return NULL;
                    }

                    // Set condition (for struct patterns, then_body was already set above)
                    if_inst->data.if_stmt.condition = comparison;
                    // Only set then_body for non-struct patterns (struct patterns set it above)
                    if (if_inst->data.if_stmt.then_count == 0) {
                        if_inst->data.if_stmt.then_count = 1;
                        if_inst->data.if_stmt.then_body = malloc(sizeof(IRInst*));
                        if (!if_inst->data.if_stmt.then_body) {
                            irinst_free(comparison);
                            irinst_free(if_inst);
                            if (current_if) irinst_free(current_if);
                            return NULL;
                        }
                        if_inst->data.if_stmt.then_body[0] = body_expr;  // Store expression (will be handled specially in codegen)
                    }

                    // Set else branch to the next if (if exists)
                    if (current_if) {
                        if_inst->data.if_stmt.else_count = 1;
                        if_inst->data.if_stmt.else_body = malloc(sizeof(IRInst*));
                        if (!if_inst->data.if_stmt.else_body) {
                            irinst_free(comparison);
                            irinst_free(if_inst);
                            if (current_if) irinst_free(current_if);
                            return NULL;
                        }
                        if_inst->data.if_stmt.else_body[0] = current_if;
                    } else {
                        if_inst->data.if_stmt.else_body = NULL;
                        if_inst->data.if_stmt.else_count = 0;
                    }
                }

                current_if = if_inst;
            }

            return current_if;  // Return the outermost if (match expression result)
        }

        default:
            // For unsupported expressions, create a placeholder
            return irinst_new(IR_VAR_DECL);
    }
}

static IRInst *generate_function(IRGenerator *ir_gen, struct ASTNode *fn_decl) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL) return NULL;

    IRInst *func = irinst_new(IR_FUNC_DEF);
    if (!func) return NULL;

    // Set function name
    func->data.func.name = malloc(strlen(fn_decl->data.fn_decl.name) + 1);
    if (!func->data.func.name) {
        irinst_free(func);
        return NULL;
    }
    strcpy(func->data.func.name, fn_decl->data.fn_decl.name);

    // Set return type
    func->data.func.return_type = get_ir_type(fn_decl->data.fn_decl.return_type);
    func->data.func.is_extern = fn_decl->data.fn_decl.is_extern;
    
    // Check if return type is error union (!T)
    func->data.func.return_type_is_error_union = (fn_decl->data.fn_decl.return_type && 
                                                   fn_decl->data.fn_decl.return_type->type == AST_TYPE_ERROR_UNION) ? 1 : 0;
    
    // Extract return type name for struct types
    func->data.func.return_type_original_name = NULL;
    if (fn_decl->data.fn_decl.return_type && 
        fn_decl->data.fn_decl.return_type->type == AST_TYPE_NAMED &&
        func->data.func.return_type == IR_TYPE_STRUCT) {
        const char *type_name = fn_decl->data.fn_decl.return_type->data.type_named.name;
        if (type_name) {
            func->data.func.return_type_original_name = malloc(strlen(type_name) + 1);
            if (func->data.func.return_type_original_name) {
                strcpy(func->data.func.return_type_original_name, type_name);
            }
        }
    }

    // Handle parameters
    func->data.func.param_count = fn_decl->data.fn_decl.param_count;
    if (fn_decl->data.fn_decl.param_count > 0) {
        func->data.func.params = malloc(fn_decl->data.fn_decl.param_count * sizeof(IRInst*));
        if (!func->data.func.params) {
            irinst_free(func);
            return NULL;
        }

        for (int i = 0; i < fn_decl->data.fn_decl.param_count; i++) {
            // Create parameter as variable declaration
            IRInst *param = irinst_new(IR_VAR_DECL);
            if (!param) {
                irinst_free(func);
                return NULL;
            }

            param->data.var.name = malloc(strlen(fn_decl->data.fn_decl.params[i]->data.var_decl.name) + 1);
            if (!param->data.var.name) {
                irinst_free(param);
                irinst_free(func);
                return NULL;
            }
            strcpy(param->data.var.name, fn_decl->data.fn_decl.params[i]->data.var_decl.name);
            param->data.var.type = get_ir_type(fn_decl->data.fn_decl.params[i]->data.var_decl.type);
            param->data.var.init = NULL;

            // Store original type name for pointer types and struct types
            struct ASTNode *param_type = fn_decl->data.fn_decl.params[i]->data.var_decl.type;
            if (param_type) {
                if (param_type->type == AST_TYPE_POINTER && param_type->data.type_pointer.pointee_type) {
                    // For pointer types, extract the pointee type name
                    struct ASTNode *pointee_type = param_type->data.type_pointer.pointee_type;
                    if (pointee_type->type == AST_TYPE_NAMED) {
                        const char *type_name = pointee_type->data.type_named.name;
                        // Replace "Self" with struct name if we're in an impl context (passed via global state)
                        // For now, we'll check if it's "Self" and replace it later if needed
                        // Check if it's a user-defined type (not a built-in type) or "Self"
                        if (strcmp(type_name, "Self") == 0 || 
                            (strcmp(type_name, "i32") != 0 && strcmp(type_name, "i64") != 0 &&
                             strcmp(type_name, "i8") != 0 && strcmp(type_name, "i16") != 0 &&
                             strcmp(type_name, "u32") != 0 && strcmp(type_name, "u64") != 0 &&
                             strcmp(type_name, "u8") != 0 && strcmp(type_name, "u16") != 0 &&
                             strcmp(type_name, "f32") != 0 && strcmp(type_name, "f64") != 0 &&
                             strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0 &&
                             strcmp(type_name, "byte") != 0)) {
                            param->data.var.original_type_name = malloc(strlen(type_name) + 1);
                            if (param->data.var.original_type_name) {
                                strcpy(param->data.var.original_type_name, type_name);
                            }
                        } else {
                            param->data.var.original_type_name = NULL;
                        }
                    } else {
                        param->data.var.original_type_name = NULL;
                    }
                } else if (param_type->type == AST_TYPE_NAMED) {
                    const char *type_name = param_type->data.type_named.name;
                    // Check if it's a user-defined type (not a built-in type)
                    if (strcmp(type_name, "i32") != 0 && strcmp(type_name, "i64") != 0 &&
                        strcmp(type_name, "i8") != 0 && strcmp(type_name, "i16") != 0 &&
                        strcmp(type_name, "u32") != 0 && strcmp(type_name, "u64") != 0 &&
                        strcmp(type_name, "u8") != 0 && strcmp(type_name, "u16") != 0 &&
                        strcmp(type_name, "f32") != 0 && strcmp(type_name, "f64") != 0 &&
                        strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0 &&
                        strcmp(type_name, "byte") != 0) {
                        param->data.var.original_type_name = malloc(strlen(type_name) + 1);
                        if (param->data.var.original_type_name) {
                            strcpy(param->data.var.original_type_name, type_name);
                        }
                    } else {
                        param->data.var.original_type_name = NULL;
                    }
                } else {
                    param->data.var.original_type_name = NULL;
                }
            } else {
                param->data.var.original_type_name = NULL;
            }

            func->data.func.params[i] = param;
        }
    } else {
        func->data.func.params = NULL;
    }

    // Handle function body - convert AST statements to IR instructions
    if (fn_decl->data.fn_decl.body) {
        if (fn_decl->data.fn_decl.body->type == AST_BLOCK) {
            func->data.func.body_count = fn_decl->data.fn_decl.body->data.block.stmt_count;
            // Debug: print function name and statement count
            if (fn_decl->data.fn_decl.name && strcmp(fn_decl->data.fn_decl.name, "main") == 0) {
                fprintf(stderr, "[DEBUG IR] Function '%s' has %d statements in AST\n", 
                        fn_decl->data.fn_decl.name, func->data.func.body_count);
            }
            func->data.func.body = malloc(func->data.func.body_count * sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }

            int null_count = 0;
            for (int i = 0; i < func->data.func.body_count; i++) {
                // Set up the IR instruction based on the AST statement type
                struct ASTNode *ast_stmt = fn_decl->data.fn_decl.body->data.block.stmts[i];
                IRInst *stmt_ir = generate_stmt(ir_gen, ast_stmt);
                if (!stmt_ir && fn_decl->data.fn_decl.name && strcmp(fn_decl->data.fn_decl.name, "main") == 0) {
                    fprintf(stderr, "[DEBUG IR] Statement %d in 'main' generated NULL IR (AST type: %d)\n", 
                            i, ast_stmt ? ast_stmt->type : -1);
                    null_count++;
                }
                func->data.func.body[i] = stmt_ir;
            }
            if (fn_decl->data.fn_decl.name && strcmp(fn_decl->data.fn_decl.name, "main") == 0 && null_count > 0) {
                fprintf(stderr, "[DEBUG IR] Function 'main' has %d NULL statements out of %d total\n", 
                        null_count, func->data.func.body_count);
            }
        } else {
            // Single statement body
            func->data.func.body_count = 1;
            func->data.func.body = malloc(sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }

            // Handle single statement
            struct ASTNode *ast_stmt = fn_decl->data.fn_decl.body;
            IRInst *stmt_ir = NULL;

            if (ast_stmt->type == AST_VAR_DECL) {
                stmt_ir = irinst_new(IR_VAR_DECL);
                if (stmt_ir) {
                    stmt_ir->data.var.name = malloc(strlen(ast_stmt->data.var_decl.name) + 1);
                    if (stmt_ir->data.var.name) {
                        strcpy(stmt_ir->data.var.name, ast_stmt->data.var_decl.name);
                        stmt_ir->data.var.type = get_ir_type(ast_stmt->data.var_decl.type);
                        stmt_ir->data.var.is_mut = ast_stmt->data.var_decl.is_mut;

                        // Ensure tuple struct declaration exists if type is tuple
                        if (ast_stmt->data.var_decl.type && ast_stmt->data.var_decl.type->type == AST_TYPE_TUPLE) {
                            IRInst *tuple_struct = ensure_tuple_struct_decl(ir_gen, ast_stmt->data.var_decl.type);
                            if (!tuple_struct) {
                                free(stmt_ir->data.var.name);
                                irinst_free(stmt_ir);
                                stmt_ir = NULL;
                            } else {
                                // Store the tuple type name as original_type_name
                                char *tuple_type_name = generate_tuple_type_name(ast_stmt->data.var_decl.type);
                                if (tuple_type_name) {
                                    stmt_ir->data.var.original_type_name = tuple_type_name;
                                } else {
                                    stmt_ir->data.var.original_type_name = NULL;
                                }
                            }
                        } else {
                            stmt_ir->data.var.original_type_name = NULL;
                        }

                        // Handle initialization
                        if (ast_stmt->data.var_decl.init && stmt_ir) {
                            stmt_ir->data.var.init = generate_expr(ir_gen, ast_stmt->data.var_decl.init);
                        }
                    }
                }
            } else if (ast_stmt->type == AST_RETURN_STMT) {
                stmt_ir = irinst_new(IR_RETURN);
                if (stmt_ir && ast_stmt->data.return_stmt.expr) {
                    stmt_ir->data.ret.value = generate_expr(ir_gen, ast_stmt->data.return_stmt.expr);
                }
            } else if (ast_stmt->type == AST_IF_STMT) {
                stmt_ir = irinst_new(IR_IF);
                if (stmt_ir) {
                    // Generate condition
                    stmt_ir->data.if_stmt.condition = generate_expr(ir_gen, ast_stmt->data.if_stmt.condition);

                    // Generate then body
                    if (ast_stmt->data.if_stmt.then_branch) {
                        if (ast_stmt->data.if_stmt.then_branch->type == AST_BLOCK) {
                            stmt_ir->data.if_stmt.then_count = ast_stmt->data.if_stmt.then_branch->data.block.stmt_count;
                            stmt_ir->data.if_stmt.then_body = malloc(stmt_ir->data.if_stmt.then_count * sizeof(IRInst*));
                            if (stmt_ir->data.if_stmt.then_body) {
                                for (int j = 0; j < stmt_ir->data.if_stmt.then_count; j++) {
                                    stmt_ir->data.if_stmt.then_body[j] = generate_stmt(ir_gen, ast_stmt->data.if_stmt.then_branch->data.block.stmts[j]);
                                }
                            }
                        } else {
                            stmt_ir->data.if_stmt.then_count = 1;
                            stmt_ir->data.if_stmt.then_body = malloc(sizeof(IRInst*));
                            if (stmt_ir->data.if_stmt.then_body) {
                                stmt_ir->data.if_stmt.then_body[0] = generate_stmt(ir_gen, ast_stmt->data.if_stmt.then_branch);
                            }
                        }
                    } else {
                        stmt_ir->data.if_stmt.then_count = 0;
                        stmt_ir->data.if_stmt.then_body = NULL;
                    }

                    // Generate else body
                    if (ast_stmt->data.if_stmt.else_branch) {
                        if (ast_stmt->data.if_stmt.else_branch->type == AST_BLOCK) {
                            stmt_ir->data.if_stmt.else_count = ast_stmt->data.if_stmt.else_branch->data.block.stmt_count;
                            stmt_ir->data.if_stmt.else_body = malloc(stmt_ir->data.if_stmt.else_count * sizeof(IRInst*));
                            if (stmt_ir->data.if_stmt.else_body) {
                                for (int j = 0; j < stmt_ir->data.if_stmt.else_count; j++) {
                                    stmt_ir->data.if_stmt.else_body[j] = generate_stmt(ir_gen, ast_stmt->data.if_stmt.else_branch->data.block.stmts[j]);
                                }
                            }
                        } else {
                            stmt_ir->data.if_stmt.else_count = 1;
                            stmt_ir->data.if_stmt.else_body = malloc(sizeof(IRInst*));
                            if (stmt_ir->data.if_stmt.else_body) {
                                stmt_ir->data.if_stmt.else_body[0] = generate_stmt(ir_gen, ast_stmt->data.if_stmt.else_branch);
                            }
                        }
                    } else {
                        stmt_ir->data.if_stmt.else_count = 0;
                        stmt_ir->data.if_stmt.else_body = NULL;
                    }
                }
            } else if (ast_stmt->type == AST_WHILE_STMT) {
                stmt_ir = irinst_new(IR_WHILE);
                if (stmt_ir) {
                    // Generate condition
                    stmt_ir->data.while_stmt.condition = generate_expr(ir_gen, ast_stmt->data.while_stmt.condition);

                    // Generate body
                    if (ast_stmt->data.while_stmt.body) {
                        if (ast_stmt->data.while_stmt.body->type == AST_BLOCK) {
                            stmt_ir->data.while_stmt.body_count = ast_stmt->data.while_stmt.body->data.block.stmt_count;
                            stmt_ir->data.while_stmt.body = malloc(stmt_ir->data.while_stmt.body_count * sizeof(IRInst*));
                            if (stmt_ir->data.while_stmt.body) {
                                for (int j = 0; j < stmt_ir->data.while_stmt.body_count; j++) {
                                    stmt_ir->data.while_stmt.body[j] = generate_stmt(ir_gen, ast_stmt->data.while_stmt.body->data.block.stmts[j]);
                                }
                            }
                        } else {
                            stmt_ir->data.while_stmt.body_count = 1;
                            stmt_ir->data.while_stmt.body = malloc(sizeof(IRInst*));
                            if (stmt_ir->data.while_stmt.body) {
                                stmt_ir->data.while_stmt.body[0] = generate_stmt(ir_gen, ast_stmt->data.while_stmt.body);
                            }
                        }
                    } else {
                        stmt_ir->data.while_stmt.body_count = 0;
                        stmt_ir->data.while_stmt.body = NULL;
                    }
                }
            }

            func->data.func.body[0] = stmt_ir;
        }
    } else {
        func->data.func.body_count = 0;
        func->data.func.body = NULL;
    }

    // Add function to instructions array
    if (ir_gen->inst_count >= ir_gen->inst_capacity) {
        size_t new_capacity = ir_gen->inst_capacity * 2;
        IRInst **new_instructions = realloc(ir_gen->instructions,
                                           new_capacity * sizeof(IRInst*));
        if (!new_instructions) {
            irinst_free(func);
            return NULL;
        }
        ir_gen->instructions = new_instructions;
        ir_gen->inst_capacity = new_capacity;
    }
    ir_gen->instructions[ir_gen->inst_count++] = func;

    return func;
}

// Generate test block as a function (returns !void, no parameters)
static IRInst *generate_test_block(IRGenerator *ir_gen, struct ASTNode *test_block) {
    if (!test_block || test_block->type != AST_TEST_BLOCK) return NULL;

    IRInst *func = irinst_new(IR_FUNC_DEF);
    if (!func) return NULL;

    // Generate function name from test name (use @test$<name> format, sanitize name)
    // For now, use a simple approach: @test$ followed by a hash of the name
    char test_func_name[256];
    snprintf(test_func_name, sizeof(test_func_name), "@test$%s", test_block->data.test_block.name);
    // Replace spaces and special chars with underscores for valid C identifier
    for (char *p = test_func_name; *p; p++) {
        if (*p == ' ' || *p == '-' || *p == '.') *p = '_';
    }

    func->data.func.name = malloc(strlen(test_func_name) + 1);
    if (!func->data.func.name) {
        irinst_free(func);
        return NULL;
    }
    strcpy(func->data.func.name, test_func_name);

    // Test functions return !void (error union with void base)
    func->data.func.return_type = IR_TYPE_VOID;  // Will be handled as error union in codegen
    func->data.func.is_extern = 0;

    // No parameters for test blocks
    func->data.func.param_count = 0;
    func->data.func.params = NULL;

    // Handle test body - convert AST statements to IR instructions
    if (test_block->data.test_block.body) {
        if (test_block->data.test_block.body->type == AST_BLOCK) {
            func->data.func.body_count = test_block->data.test_block.body->data.block.stmt_count;
            func->data.func.body = malloc(func->data.func.body_count * sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }

            for (int i = 0; i < func->data.func.body_count; i++) {
                struct ASTNode *ast_stmt = test_block->data.test_block.body->data.block.stmts[i];
                IRInst *stmt_ir = generate_stmt(ir_gen, ast_stmt);
                func->data.func.body[i] = stmt_ir;
            }
        } else {
            // Single statement body
            func->data.func.body_count = 1;
            func->data.func.body = malloc(sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }
            func->data.func.body[0] = generate_stmt(ir_gen, test_block->data.test_block.body);
        }
    } else {
        func->data.func.body_count = 0;
        func->data.func.body = NULL;
    }

    // Add function to instructions array
    if (ir_gen->inst_count >= ir_gen->inst_capacity) {
        size_t new_capacity = ir_gen->inst_capacity * 2;
        IRInst **new_instructions = realloc(ir_gen->instructions,
                                           new_capacity * sizeof(IRInst*));
        if (!new_instructions) {
            irinst_free(func);
            return NULL;
        }
        ir_gen->instructions = new_instructions;
        ir_gen->inst_capacity = new_capacity;
    }
    ir_gen->instructions[ir_gen->inst_count++] = func;

    return func;
}

// Generate statement for function body (doesn't add to main array)
static IRInst *generate_stmt_for_body(IRGenerator *ir_gen, struct ASTNode *stmt) {
    if (!stmt) return NULL;

    switch (stmt->type) {
        case AST_VAR_DECL: {
            IRInst *var_decl = irinst_new(IR_VAR_DECL);
            if (!var_decl) return NULL;

            var_decl->data.var.name = malloc(strlen(stmt->data.var_decl.name) + 1);
            if (!var_decl->data.var.name) {
                irinst_free(var_decl);
                return NULL;
            }
            strcpy(var_decl->data.var.name, stmt->data.var_decl.name);
            
            // Check if the type is atomic
            var_decl->data.var.is_atomic = (stmt->data.var_decl.type && stmt->data.var_decl.type->type == AST_TYPE_ATOMIC) ? 1 : 0;
            
            var_decl->data.var.type = get_ir_type(stmt->data.var_decl.type);
            var_decl->data.var.is_mut = stmt->data.var_decl.is_mut;

            // Ensure tuple struct declaration exists if type is tuple
            if (stmt->data.var_decl.type && stmt->data.var_decl.type->type == AST_TYPE_TUPLE) {
                IRInst *tuple_struct = ensure_tuple_struct_decl(ir_gen, stmt->data.var_decl.type);
                if (!tuple_struct) {
                    irinst_free(var_decl);
                    return NULL;
                }
                // Store the tuple type name as original_type_name
                char *tuple_type_name = generate_tuple_type_name(stmt->data.var_decl.type);
                if (tuple_type_name) {
                    var_decl->data.var.original_type_name = tuple_type_name;
                }
            }

            // Store original type name for user-defined types
            if (stmt->data.var_decl.type) {
                if (stmt->data.var_decl.type->type == AST_TYPE_TUPLE) {
                    // Already handled above, skip
                } else if (stmt->data.var_decl.type->type == AST_TYPE_POINTER && stmt->data.var_decl.type->data.type_pointer.pointee_type) {
                    // For pointer types, extract the pointee type name
                    struct ASTNode *pointee_type = stmt->data.var_decl.type->data.type_pointer.pointee_type;
                    if (pointee_type->type == AST_TYPE_NAMED) {
                        const char *type_name = pointee_type->data.type_named.name;
                        // For pointer types, store the pointee type name (including built-in types like i32)
                        // This is needed for code generation to generate the correct type (e.g., int32_t* instead of void*)
                        var_decl->data.var.original_type_name = malloc(strlen(type_name) + 1);
                        if (var_decl->data.var.original_type_name) {
                            strcpy(var_decl->data.var.original_type_name, type_name);
                        }
                    } else {
                        var_decl->data.var.original_type_name = NULL;
                    }
                } else if (stmt->data.var_decl.type->type == AST_TYPE_ARRAY) {
                    // For array types, extract element type name
                    struct ASTNode *element_type = stmt->data.var_decl.type->data.type_array.element_type;
                    if (element_type && element_type->type == AST_TYPE_NAMED) {
                        const char *type_name = element_type->data.type_named.name;
                        // Check if it's a user-defined type (not a built-in type)
                        if (strcmp(type_name, "i32") != 0 && strcmp(type_name, "i64") != 0 &&
                            strcmp(type_name, "i8") != 0 && strcmp(type_name, "i16") != 0 &&
                            strcmp(type_name, "u32") != 0 && strcmp(type_name, "u64") != 0 &&
                            strcmp(type_name, "u8") != 0 && strcmp(type_name, "u16") != 0 &&
                            strcmp(type_name, "f32") != 0 && strcmp(type_name, "f64") != 0 &&
                            strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0 &&
                            strcmp(type_name, "byte") != 0) {
                            // This is a user-defined type, store the original name
                            var_decl->data.var.original_type_name = malloc(strlen(type_name) + 1);
                            if (var_decl->data.var.original_type_name) {
                                strcpy(var_decl->data.var.original_type_name, type_name);
                            }
                        } else {
                            var_decl->data.var.original_type_name = NULL;
                        }
                    } else {
                        var_decl->data.var.original_type_name = NULL;
                    }
                } else if (stmt->data.var_decl.type->type == AST_TYPE_NAMED) {
                    const char *type_name = stmt->data.var_decl.type->data.type_named.name;
                    // Check if it's a user-defined type (not a built-in type)
                    if (strcmp(type_name, "i32") != 0 && strcmp(type_name, "i64") != 0 &&
                        strcmp(type_name, "i8") != 0 && strcmp(type_name, "i16") != 0 &&
                        strcmp(type_name, "u32") != 0 && strcmp(type_name, "u64") != 0 &&
                        strcmp(type_name, "u8") != 0 && strcmp(type_name, "u16") != 0 &&
                        strcmp(type_name, "f32") != 0 && strcmp(type_name, "f64") != 0 &&
                        strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0 &&
                        strcmp(type_name, "byte") != 0) {
                        // This is a user-defined type, store the original name
                        var_decl->data.var.original_type_name = malloc(strlen(type_name) + 1);
                        if (var_decl->data.var.original_type_name) {
                            strcpy(var_decl->data.var.original_type_name, type_name);
                        }
                    } else {
                        var_decl->data.var.original_type_name = NULL;
                    }
                } else if (stmt->data.var_decl.type->type == AST_TYPE_TUPLE) {
                    // Already handled above, skip (tuple type name is already set)
                } else {
                    var_decl->data.var.original_type_name = NULL;
                }
            } else {
                var_decl->data.var.original_type_name = NULL;
            }

            if (stmt->data.var_decl.init) {
                var_decl->data.var.init = generate_expr(ir_gen, stmt->data.var_decl.init);
                
                // If variable type is tuple and init is tuple literal (IR_STRUCT_INIT with tuple_N name),
                // update the struct_name to use the correct tuple type name
                if (stmt->data.var_decl.type && stmt->data.var_decl.type->type == AST_TYPE_TUPLE &&
                    var_decl->data.var.init && var_decl->data.var.init->type == IR_STRUCT_INIT &&
                    var_decl->data.var.original_type_name) {
                    // Check if struct_name is in tuple_N format
                    const char *struct_name = var_decl->data.var.init->data.struct_init.struct_name;
                    if (struct_name && strncmp(struct_name, "tuple_", 6) == 0) {
                        // Check if it's the old format (tuple_N where N is just a number)
                        int is_old_format = 1;
                        for (int i = 6; struct_name[i] != '\0'; i++) {
                            if (struct_name[i] < '0' || struct_name[i] > '9') {
                                is_old_format = 0;
                                break;
                            }
                        }
                        if (is_old_format) {
                            // Update struct_name to use the correct tuple type name
                            free(var_decl->data.var.init->data.struct_init.struct_name);
                            var_decl->data.var.init->data.struct_init.struct_name = malloc(strlen(var_decl->data.var.original_type_name) + 1);
                            if (var_decl->data.var.init->data.struct_init.struct_name) {
                                strcpy(var_decl->data.var.init->data.struct_init.struct_name, var_decl->data.var.original_type_name);
                            }
                        }
                    }
                }
            } else {
                var_decl->data.var.init = NULL;
            }

            return var_decl;
        }

        case AST_RETURN_STMT: {
            IRInst *ret = irinst_new(IR_RETURN);
            if (!ret) return NULL;

            if (stmt->data.return_stmt.expr) {
                ret->data.ret.value = generate_expr(ir_gen, stmt->data.return_stmt.expr);
            } else {
                ret->data.ret.value = NULL; // void return
            }

            return ret;
        }

        case AST_IF_STMT: {
            IRInst *if_inst = irinst_new(IR_IF);
            if (!if_inst) return NULL;

            // Generate condition
            if_inst->data.if_stmt.condition = generate_expr(ir_gen, stmt->data.if_stmt.condition);

            // Generate then body
            if (stmt->data.if_stmt.then_branch) {
                if (stmt->data.if_stmt.then_branch->type == AST_BLOCK) {
                    if_inst->data.if_stmt.then_count = stmt->data.if_stmt.then_branch->data.block.stmt_count;
                    if_inst->data.if_stmt.then_body = malloc(if_inst->data.if_stmt.then_count * sizeof(IRInst*));
                    if (!if_inst->data.if_stmt.then_body) {
                        irinst_free(if_inst);
                        return NULL;
                    }

                    for (int i = 0; i < if_inst->data.if_stmt.then_count; i++) {
                        if_inst->data.if_stmt.then_body[i] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.then_branch->data.block.stmts[i]);
                    }
                } else {
                    if_inst->data.if_stmt.then_count = 1;
                    if_inst->data.if_stmt.then_body = malloc(sizeof(IRInst*));
                    if (if_inst->data.if_stmt.then_body) {
                        if_inst->data.if_stmt.then_body[0] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.then_branch);
                    }
                }
            } else {
                if_inst->data.if_stmt.then_count = 0;
                if_inst->data.if_stmt.then_body = NULL;
            }

            // Generate else body
            if (stmt->data.if_stmt.else_branch) {
                if (stmt->data.if_stmt.else_branch->type == AST_BLOCK) {
                    if_inst->data.if_stmt.else_count = stmt->data.if_stmt.else_branch->data.block.stmt_count;
                    if_inst->data.if_stmt.else_body = malloc(if_inst->data.if_stmt.else_count * sizeof(IRInst*));
                    if (!if_inst->data.if_stmt.else_body) {
                        // Clean up then body
                        if (if_inst->data.if_stmt.then_body) {
                            free(if_inst->data.if_stmt.then_body);
                        }
                        irinst_free(if_inst);
                        return NULL;
                    }

                    for (int i = 0; i < if_inst->data.if_stmt.else_count; i++) {
                        if_inst->data.if_stmt.else_body[i] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.else_branch->data.block.stmts[i]);
                    }
                } else {
                    if_inst->data.if_stmt.else_count = 1;
                    if_inst->data.if_stmt.else_body = malloc(sizeof(IRInst*));
                    if (if_inst->data.if_stmt.else_body) {
                        if_inst->data.if_stmt.else_body[0] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.else_branch);
                    }
                }
            } else {
                if_inst->data.if_stmt.else_count = 0;
                if_inst->data.if_stmt.else_body = NULL;
            }

            return if_inst;
        }

        case AST_WHILE_STMT: {
            IRInst *while_inst = irinst_new(IR_WHILE);
            if (!while_inst) return NULL;

            // Generate condition
            while_inst->data.while_stmt.condition = generate_expr(ir_gen, stmt->data.while_stmt.condition);

            // Generate body
            if (stmt->data.while_stmt.body) {
                if (stmt->data.while_stmt.body->type == AST_BLOCK) {
                    while_inst->data.while_stmt.body_count = stmt->data.while_stmt.body->data.block.stmt_count;
                    while_inst->data.while_stmt.body = malloc(while_inst->data.while_stmt.body_count * sizeof(IRInst*));
                    if (!while_inst->data.while_stmt.body) {
                        irinst_free(while_inst);
                        return NULL;
                    }

                    for (int i = 0; i < while_inst->data.while_stmt.body_count; i++) {
                        while_inst->data.while_stmt.body[i] = generate_stmt_for_body(ir_gen, stmt->data.while_stmt.body->data.block.stmts[i]);
                    }
                } else {
                    while_inst->data.while_stmt.body_count = 1;
                    while_inst->data.while_stmt.body = malloc(sizeof(IRInst*));
                    if (while_inst->data.while_stmt.body) {
                        while_inst->data.while_stmt.body[0] = generate_stmt_for_body(ir_gen, stmt->data.while_stmt.body);
                    }
                }
            } else {
                while_inst->data.while_stmt.body_count = 0;
                while_inst->data.while_stmt.body = NULL;
            }

            return while_inst;
        }

        case AST_FOR_STMT: {
            IRInst *for_inst = irinst_new(IR_FOR);
            if (!for_inst) return NULL;

            // Generate iterable expression
            for_inst->data.for_stmt.iterable = generate_expr(ir_gen, stmt->data.for_stmt.iterable);

            // Generate index range (if present)
            if (stmt->data.for_stmt.index_range) {
                for_inst->data.for_stmt.index_range = generate_expr(ir_gen, stmt->data.for_stmt.index_range);
            } else {
                for_inst->data.for_stmt.index_range = NULL;
            }

            // Copy variable names
            if (stmt->data.for_stmt.item_var) {
                for_inst->data.for_stmt.item_var = malloc(strlen(stmt->data.for_stmt.item_var) + 1);
                if (for_inst->data.for_stmt.item_var) {
                    strcpy(for_inst->data.for_stmt.item_var, stmt->data.for_stmt.item_var);
                }
            } else {
                for_inst->data.for_stmt.item_var = NULL;
            }

            if (stmt->data.for_stmt.index_var) {
                for_inst->data.for_stmt.index_var = malloc(strlen(stmt->data.for_stmt.index_var) + 1);
                if (for_inst->data.for_stmt.index_var) {
                    strcpy(for_inst->data.for_stmt.index_var, stmt->data.for_stmt.index_var);
                }
            } else {
                for_inst->data.for_stmt.index_var = NULL;
            }

            // Generate body
            if (stmt->data.for_stmt.body) {
                if (stmt->data.for_stmt.body->type == AST_BLOCK) {
                    for_inst->data.for_stmt.body_count = stmt->data.for_stmt.body->data.block.stmt_count;
                    for_inst->data.for_stmt.body = malloc(for_inst->data.for_stmt.body_count * sizeof(IRInst*));
                    if (!for_inst->data.for_stmt.body) {
                        irinst_free(for_inst);
                        return NULL;
                    }

                    for (int i = 0; i < for_inst->data.for_stmt.body_count; i++) {
                        for_inst->data.for_stmt.body[i] = generate_stmt_for_body(ir_gen, stmt->data.for_stmt.body->data.block.stmts[i]);
                    }
                } else {
                    for_inst->data.for_stmt.body_count = 1;
                    for_inst->data.for_stmt.body = malloc(sizeof(IRInst*));
                    if (for_inst->data.for_stmt.body) {
                        for_inst->data.for_stmt.body[0] = generate_stmt_for_body(ir_gen, stmt->data.for_stmt.body);
                    }
                }
            } else {
                for_inst->data.for_stmt.body_count = 0;
                for_inst->data.for_stmt.body = NULL;
            }

            return for_inst;
        }

        case AST_ASSIGN: {
            IRInst *assign = irinst_new(IR_ASSIGN);
            if (!assign) return NULL;

            // 检查目标是否是表达式（如 arr[0]）还是简单变量
            if (stmt->data.assign.dest_expr) {
                // 表达式赋值：arr[0] = value
                assign->data.assign.dest = NULL;
                assign->data.assign.dest_expr = generate_expr(ir_gen, stmt->data.assign.dest_expr);
            } else if (stmt->data.assign.dest) {
                // 简单变量赋值：var = value
                assign->data.assign.dest = malloc(strlen(stmt->data.assign.dest) + 1);
                if (assign->data.assign.dest) {
                    strcpy(assign->data.assign.dest, stmt->data.assign.dest);
                }
                assign->data.assign.dest_expr = NULL;
            } else {
                assign->data.assign.dest = NULL;
                assign->data.assign.dest_expr = NULL;
            }

            // Set source (right-hand side expression)
            if (stmt->data.assign.src) {
                assign->data.assign.src = generate_expr(ir_gen, stmt->data.assign.src);
            } else {
                assign->data.assign.src = NULL;
            }

            return assign;
        }

        case AST_DEFER_STMT: {
            IRInst *defer_inst = irinst_new(IR_DEFER);
            if (!defer_inst) return NULL;

            // Generate defer body
            if (stmt->data.defer_stmt.body) {
                if (stmt->data.defer_stmt.body->type == AST_BLOCK) {
                    defer_inst->data.defer.body_count = stmt->data.defer_stmt.body->data.block.stmt_count;
                    defer_inst->data.defer.body = malloc(defer_inst->data.defer.body_count * sizeof(IRInst*));
                    if (!defer_inst->data.defer.body) {
                        irinst_free(defer_inst);
                        return NULL;
                    }

                    for (int i = 0; i < defer_inst->data.defer.body_count; i++) {
                        defer_inst->data.defer.body[i] = generate_stmt_for_body(ir_gen, stmt->data.defer_stmt.body->data.block.stmts[i]);
                    }
                } else {
                    defer_inst->data.defer.body_count = 1;
                    defer_inst->data.defer.body = malloc(sizeof(IRInst*));
                    if (defer_inst->data.defer.body) {
                        defer_inst->data.defer.body[0] = generate_stmt_for_body(ir_gen, stmt->data.defer_stmt.body);
                    }
                }
            } else {
                defer_inst->data.defer.body_count = 0;
                defer_inst->data.defer.body = NULL;
            }

            return defer_inst;
        }

        case AST_ERRDEFER_STMT: {
            IRInst *errdefer_inst = irinst_new(IR_ERRDEFER);
            if (!errdefer_inst) return NULL;

            // Generate errdefer body
            if (stmt->data.errdefer_stmt.body) {
                if (stmt->data.errdefer_stmt.body->type == AST_BLOCK) {
                    errdefer_inst->data.errdefer.body_count = stmt->data.errdefer_stmt.body->data.block.stmt_count;
                    errdefer_inst->data.errdefer.body = malloc(errdefer_inst->data.errdefer.body_count * sizeof(IRInst*));
                    if (!errdefer_inst->data.errdefer.body) {
                        irinst_free(errdefer_inst);
                        return NULL;
                    }

                    for (int i = 0; i < errdefer_inst->data.errdefer.body_count; i++) {
                        errdefer_inst->data.errdefer.body[i] = generate_stmt_for_body(ir_gen, stmt->data.errdefer_stmt.body->data.block.stmts[i]);
                    }
                } else {
                    errdefer_inst->data.errdefer.body_count = 1;
                    errdefer_inst->data.errdefer.body = malloc(sizeof(IRInst*));
                    if (errdefer_inst->data.errdefer.body) {
                        errdefer_inst->data.errdefer.body[0] = generate_stmt_for_body(ir_gen, stmt->data.errdefer_stmt.body);
                    }
                }
            } else {
                errdefer_inst->data.errdefer.body_count = 0;
                errdefer_inst->data.errdefer.body = NULL;
            }

            return errdefer_inst;
        }

        case AST_BLOCK: {
            // Handle nested blocks - generate IR_BLOCK instruction
            IRInst *block_inst = irinst_new(IR_BLOCK);
            if (!block_inst) return NULL;

            block_inst->data.block.inst_count = stmt->data.block.stmt_count;
            block_inst->data.block.insts = malloc(block_inst->data.block.inst_count * sizeof(IRInst*));
            if (!block_inst->data.block.insts) {
                irinst_free(block_inst);
                return NULL;
            }

            for (int i = 0; i < block_inst->data.block.inst_count; i++) {
                block_inst->data.block.insts[i] = generate_stmt_for_body(ir_gen, stmt->data.block.stmts[i]);
            }

            return block_inst;
        }

        case AST_CALL_EXPR:
            // Expression statement: function call as a statement
            // Convert the call expression directly to IR_CALL
            return generate_expr(ir_gen, stmt);

        case AST_CATCH_EXPR:
            // Catch expression statement: expr catch |err| { ... }
            // Convert catch expression to IR_TRY_CATCH
            return generate_expr(ir_gen, stmt);

        case AST_MATCH_EXPR:
            // Match expression statement: match expr { pattern => body, ... }
            // Convert match expression to IR_IF (nested if-else chain)
            return generate_expr(ir_gen, stmt);

        case AST_BINARY_EXPR:
        case AST_UNARY_EXPR:
        case AST_IDENTIFIER:
        case AST_NUMBER:
        case AST_STRING:
        case AST_STRING_INTERPOLATION:
        case AST_BOOL:
        case AST_NULL:
        case AST_MEMBER_ACCESS:
        case AST_SUBSCRIPT_EXPR:
            // Other expression types used as statements
            // Convert expression to IR (discard result for statement form)
            return generate_expr(ir_gen, stmt);

        default:
            return NULL;
    }
}

static IRInst *generate_stmt(IRGenerator *ir_gen, struct ASTNode *stmt) {
    // Top-level statements (like function declarations) should be added to main array
    // Function body statements should only be stored in the function's body array
    IRInst *result = generate_stmt_for_body(ir_gen, stmt);

    return result;
}

static void generate_program(IRGenerator *ir_gen, struct ASTNode *program) {
    if (!program || program->type != AST_PROGRAM) return;

    for (int i = 0; i < program->data.program.decl_count; i++) {
        struct ASTNode *decl = program->data.program.decls[i];
        if (decl->type == AST_FN_DECL) {
            generate_function(ir_gen, decl);
        } else if (decl->type == AST_TEST_BLOCK) {
            generate_test_block(ir_gen, decl);
        } else if (decl->type == AST_IMPL_DECL) {
            // Handle impl declarations: convert each method to a regular function
            // Replace "Self" type names with the struct name in method parameters
            const char *struct_name = decl->data.impl_decl.struct_name;
            for (int j = 0; j < decl->data.impl_decl.method_count; j++) {
                struct ASTNode *method = decl->data.impl_decl.methods[j];
                if (method && method->type == AST_FN_DECL) {
                    // Replace "Self" in parameter types with struct_name
                    for (int k = 0; k < method->data.fn_decl.param_count; k++) {
                        struct ASTNode *param_type = method->data.fn_decl.params[k]->data.var_decl.type;
                        if (param_type && param_type->type == AST_TYPE_POINTER && 
                            param_type->data.type_pointer.pointee_type &&
                            param_type->data.type_pointer.pointee_type->type == AST_TYPE_NAMED &&
                            strcmp(param_type->data.type_pointer.pointee_type->data.type_named.name, "Self") == 0) {
                            // Replace "Self" with struct_name
                            free(param_type->data.type_pointer.pointee_type->data.type_named.name);
                            param_type->data.type_pointer.pointee_type->data.type_named.name = malloc(strlen(struct_name) + 1);
                            if (param_type->data.type_pointer.pointee_type->data.type_named.name) {
                                strcpy(param_type->data.type_pointer.pointee_type->data.type_named.name, struct_name);
                            }
                        }
                    }
                    generate_function(ir_gen, method);
                }
            }
        } else if (decl->type == AST_ENUM_DECL) {
            // Handle enum declarations
            IRInst *enum_ir = irinst_new(IR_ENUM_DECL);
            if (enum_ir) {
                // Set enum name
                enum_ir->data.enum_decl.name = malloc(strlen(decl->data.enum_decl.name) + 1);
                if (enum_ir->data.enum_decl.name) {
                    strcpy(enum_ir->data.enum_decl.name, decl->data.enum_decl.name);
                }

                // Set underlying type (default to i32 if not specified)
                if (decl->data.enum_decl.underlying_type) {
                    enum_ir->data.enum_decl.underlying_type = get_ir_type(decl->data.enum_decl.underlying_type);
                } else {
                    enum_ir->data.enum_decl.underlying_type = IR_TYPE_I32;  // Default underlying type
                }

                // Handle variants
                enum_ir->data.enum_decl.variant_count = decl->data.enum_decl.variant_count;
                if (decl->data.enum_decl.variant_count > 0) {
                    enum_ir->data.enum_decl.variant_names = malloc(decl->data.enum_decl.variant_count * sizeof(char*));
                    enum_ir->data.enum_decl.variant_values = malloc(decl->data.enum_decl.variant_count * sizeof(char*));
                    if (enum_ir->data.enum_decl.variant_names && enum_ir->data.enum_decl.variant_values) {
                        for (int j = 0; j < decl->data.enum_decl.variant_count; j++) {
                            // Copy variant name
                            enum_ir->data.enum_decl.variant_names[j] = malloc(strlen(decl->data.enum_decl.variants[j].name) + 1);
                            if (enum_ir->data.enum_decl.variant_names[j]) {
                                strcpy(enum_ir->data.enum_decl.variant_names[j], decl->data.enum_decl.variants[j].name);
                            }

                            // Copy variant value (if specified)
                            if (decl->data.enum_decl.variants[j].value) {
                                enum_ir->data.enum_decl.variant_values[j] = malloc(strlen(decl->data.enum_decl.variants[j].value) + 1);
                                if (enum_ir->data.enum_decl.variant_values[j]) {
                                    strcpy(enum_ir->data.enum_decl.variant_values[j], decl->data.enum_decl.variants[j].value);
                                }
                            } else {
                                enum_ir->data.enum_decl.variant_values[j] = NULL;  // No explicit value
                            }
                        }
                    }
                } else {
                    enum_ir->data.enum_decl.variant_names = NULL;
                    enum_ir->data.enum_decl.variant_values = NULL;
                }

                enum_ir->id = ir_gen->current_id++;

                // Add to instructions array
                if (ir_gen->inst_count >= ir_gen->inst_capacity) {
                    size_t new_capacity = ir_gen->inst_capacity * 2;
                    IRInst **new_instructions = realloc(ir_gen->instructions,
                                                       new_capacity * sizeof(IRInst*));
                    if (new_instructions) {
                        ir_gen->instructions = new_instructions;
                        ir_gen->inst_capacity = new_capacity;
                    }
                }
                if (ir_gen->inst_count < ir_gen->inst_capacity) {
                    ir_gen->instructions[ir_gen->inst_count++] = enum_ir;
                }
            }
        } else if (decl->type == AST_TYPE_TUPLE) {
            // Handle tuple type declarations - tuples don't need separate IR instructions
            // They are handled inline during expression processing
            // TODO: Generate IR_STRUCT_DECL for tuple types
        } else if (decl->type == AST_TUPLE_LITERAL) {
            // Handle tuple literals - these are processed as expressions
            // This shouldn't happen here since tuple literals are expressions, not declarations
            // But we'll add it for completeness
        } else if (decl->type == AST_STRUCT_DECL) {
            // Handle struct declarations
            IRInst *struct_ir = irinst_new(IR_STRUCT_DECL);
            if (struct_ir) {
                // Set struct name
                struct_ir->data.struct_decl.name = malloc(strlen(decl->data.struct_decl.name) + 1);
                if (struct_ir->data.struct_decl.name) {
                    strcpy(struct_ir->data.struct_decl.name, decl->data.struct_decl.name);
                }

                // Handle fields
                struct_ir->data.struct_decl.field_count = decl->data.struct_decl.field_count;
                if (decl->data.struct_decl.field_count > 0) {
                    struct_ir->data.struct_decl.fields = malloc(decl->data.struct_decl.field_count * sizeof(IRInst*));
                    if (struct_ir->data.struct_decl.fields) {
                        for (int j = 0; j < decl->data.struct_decl.field_count; j++) {
                            // Create field as variable declaration
                            IRInst *field = irinst_new(IR_VAR_DECL);
                            if (field) {
                                field->data.var.name = malloc(strlen(decl->data.struct_decl.fields[j]->data.var_decl.name) + 1);
                                if (field->data.var.name) {
                                    strcpy(field->data.var.name, decl->data.struct_decl.fields[j]->data.var_decl.name);
                                    
                                    // Check if the type is atomic
                                    struct ASTNode *field_type = decl->data.struct_decl.fields[j]->data.var_decl.type;
                                    field->data.var.is_atomic = (field_type && field_type->type == AST_TYPE_ATOMIC) ? 1 : 0;
                                    
                                    field->data.var.type = get_ir_type(field_type);
                                    field->data.var.is_mut = decl->data.struct_decl.fields[j]->data.var_decl.is_mut;
                                    field->data.var.init = NULL;
                                    field->id = ir_gen->current_id++;
                                    struct_ir->data.struct_decl.fields[j] = field;
                                }
                            }
                        }
                    }
                } else {
                    struct_ir->data.struct_decl.fields = NULL;
                }

                struct_ir->id = ir_gen->current_id++;

                // Add to instructions array
                if (ir_gen->inst_count >= ir_gen->inst_capacity) {
                    size_t new_capacity = ir_gen->inst_capacity * 2;
                    IRInst **new_instructions = realloc(ir_gen->instructions,
                                                       new_capacity * sizeof(IRInst*));
                    if (new_instructions) {
                        ir_gen->instructions = new_instructions;
                        ir_gen->inst_capacity = new_capacity;
                    }
                }
                if (ir_gen->inst_count < ir_gen->inst_capacity) {
                    ir_gen->instructions[ir_gen->inst_count++] = struct_ir;
                }
            }
        }
    }
}

void *irgenerator_generate(IRGenerator *ir_gen, struct ASTNode *ast) {
    if (!ir_gen || !ast) {
        return NULL;
    }

    printf("生成中间表示...\n");

    // Reset counters
    ir_gen->current_id = 0;
    ir_gen->inst_count = 0;

    // Generate IR from AST
    generate_program(ir_gen, ast);

    printf("生成了 %d 条IR指令\n", ir_gen->inst_count);

    return ir_gen;
}

// Helper function to get type name string from AST type node
static char *get_type_name_string(struct ASTNode *type_node) {
    if (!type_node) {
        return NULL;
    }
    
    switch (type_node->type) {
        case AST_TYPE_NAMED:
            {
                const char *name = type_node->data.type_named.name;
                char *result = malloc(strlen(name) + 1);
                if (result) {
                    strcpy(result, name);
                }
                return result;
            }
        case AST_TYPE_ARRAY:
            {
                // For arrays: array_ElementType
                struct ASTNode *elem_type = type_node->data.type_array.element_type;
                char *elem_name = get_type_name_string(elem_type);
                if (!elem_name) {
                    return NULL;
                }
                char *result = malloc(strlen(elem_name) + 16);
                if (result) {
                    snprintf(result, strlen(elem_name) + 16, "array_%s", elem_name);
                }
                free(elem_name);
                return result;
            }
        case AST_TYPE_POINTER:
            {
                // For pointers: ptr_PointeeType
                struct ASTNode *pointee_type = type_node->data.type_pointer.pointee_type;
                char *elem_name = get_type_name_string(pointee_type);
                if (!elem_name) {
                    return NULL;
                }
                char *result = malloc(strlen(elem_name) + 16);
                if (result) {
                    snprintf(result, strlen(elem_name) + 16, "ptr_%s", elem_name);
                }
                free(elem_name);
                return result;
            }
        case AST_TYPE_TUPLE:
            {
                // For tuples: tuple_T1_T2_...
                char *result = malloc(256);  // Allocate enough space
                if (!result) {
                    return NULL;
                }
                strcpy(result, "tuple");
                for (int i = 0; i < type_node->data.type_tuple.element_count; i++) {
                    char *elem_name = get_type_name_string(type_node->data.type_tuple.element_types[i]);
                    if (!elem_name) {
                        free(result);
                        return NULL;
                    }
                    // Append underscore and element type name
                    size_t new_len = strlen(result) + strlen(elem_name) + 2;
                    char *new_result = realloc(result, new_len);
                    if (!new_result) {
                        free(result);
                        free(elem_name);
                        return NULL;
                    }
                    result = new_result;
                    strcat(result, "_");
                    strcat(result, elem_name);
                    free(elem_name);
                }
                return result;
            }
        case AST_TYPE_ERROR_UNION:
            {
                // For error unions: error_union_BaseType
                struct ASTNode *base_type = type_node->data.type_error_union.base_type;
                char *base_name = get_type_name_string(base_type);
                if (!base_name) {
                    return NULL;
                }
                char *result = malloc(strlen(base_name) + 32);
                if (result) {
                    snprintf(result, strlen(base_name) + 32, "error_union_%s", base_name);
                }
                free(base_name);
                return result;
            }
        case AST_TYPE_ATOMIC:
            {
                // For atomic: atomic_BaseType
                struct ASTNode *base_type = type_node->data.type_atomic.base_type;
                char *base_name = get_type_name_string(base_type);
                if (!base_name) {
                    return NULL;
                }
                char *result = malloc(strlen(base_name) + 32);
                if (result) {
                    snprintf(result, strlen(base_name) + 32, "atomic_%s", base_name);
                }
                free(base_name);
                return result;
            }
        case AST_TYPE_FN:
            {
                // For function pointers: fn_... (simplified)
                char *result = malloc(16);
                if (result) {
                    strcpy(result, "fn");
                }
                return result;
            }
        default:
            return NULL;
    }
}

// Generate tuple type name from AST_TYPE_TUPLE node
// Returns a unique name based on element types (e.g., "tuple_i32_bool")
static char *generate_tuple_type_name(struct ASTNode *tuple_type) {
    if (!tuple_type || tuple_type->type != AST_TYPE_TUPLE) {
        return NULL;
    }
    
    return get_type_name_string(tuple_type);
}

// Ensure tuple struct declaration exists in IR
// Returns the struct declaration IR instruction if it already exists or was created
static IRInst *ensure_tuple_struct_decl(IRGenerator *ir_gen, struct ASTNode *tuple_type) {
    if (!ir_gen || !tuple_type || tuple_type->type != AST_TYPE_TUPLE) {
        return NULL;
    }
    
    // Generate tuple type name
    char *tuple_type_name = generate_tuple_type_name(tuple_type);
    if (!tuple_type_name) {
        return NULL;
    }
    
    // Check if struct declaration already exists
    for (int i = 0; i < ir_gen->inst_count; i++) {
        if (ir_gen->instructions[i] && ir_gen->instructions[i]->type == IR_STRUCT_DECL) {
            if (ir_gen->instructions[i]->data.struct_decl.name &&
                strcmp(ir_gen->instructions[i]->data.struct_decl.name, tuple_type_name) == 0) {
                // Found existing struct declaration
                free(tuple_type_name);
                return ir_gen->instructions[i];
            }
        }
    }
    
    // Struct declaration doesn't exist, create it
    IRInst *struct_ir = irinst_new(IR_STRUCT_DECL);
    if (!struct_ir) {
        free(tuple_type_name);
        return NULL;
    }
    
    // Set struct name
    struct_ir->data.struct_decl.name = tuple_type_name;
    
    // Handle fields
    struct_ir->data.struct_decl.field_count = tuple_type->data.type_tuple.element_count;
    if (tuple_type->data.type_tuple.element_count > 0) {
        struct_ir->data.struct_decl.fields = malloc(tuple_type->data.type_tuple.element_count * sizeof(IRInst*));
        if (!struct_ir->data.struct_decl.fields) {
            free(tuple_type_name);
            irinst_free(struct_ir);
            return NULL;
        }
        
        for (int i = 0; i < tuple_type->data.type_tuple.element_count; i++) {
            // Create field as variable declaration
            IRInst *field = irinst_new(IR_VAR_DECL);
            if (!field) {
                // Clean up on failure
                for (int j = 0; j < i; j++) {
                    if (struct_ir->data.struct_decl.fields[j]) {
                        irinst_free(struct_ir->data.struct_decl.fields[j]);
                    }
                }
                free(struct_ir->data.struct_decl.fields);
                free(tuple_type_name);
                irinst_free(struct_ir);
                return NULL;
            }
            
            // Field name: _0, _1, _2, etc.
            char field_name[16];
            snprintf(field_name, sizeof(field_name), "_%d", i);
            field->data.var.name = malloc(strlen(field_name) + 1);
            if (!field->data.var.name) {
                irinst_free(field);
                // Clean up on failure
                for (int j = 0; j < i; j++) {
                    if (struct_ir->data.struct_decl.fields[j]) {
                        irinst_free(struct_ir->data.struct_decl.fields[j]);
                    }
                }
                free(struct_ir->data.struct_decl.fields);
                free(tuple_type_name);
                irinst_free(struct_ir);
                return NULL;
            }
            strcpy(field->data.var.name, field_name);
            
            // Get field type from tuple element type
            struct ASTNode *element_type = tuple_type->data.type_tuple.element_types[i];
            if (!element_type) {
                irinst_free(field);
                // Clean up on failure
                for (int j = 0; j < i; j++) {
                    if (struct_ir->data.struct_decl.fields[j]) {
                        irinst_free(struct_ir->data.struct_decl.fields[j]);
                    }
                }
                free(struct_ir->data.struct_decl.fields);
                free(tuple_type_name);
                irinst_free(struct_ir);
                return NULL;
            }
            
            // Check if the type is atomic
            field->data.var.is_atomic = (element_type->type == AST_TYPE_ATOMIC) ? 1 : 0;
            
            // Handle nested tuple types: ensure their struct declarations exist
            if (element_type->type == AST_TYPE_TUPLE) {
                IRInst *nested_struct = ensure_tuple_struct_decl(ir_gen, element_type);
                if (!nested_struct) {
                    irinst_free(field);
                    // Clean up on failure
                    for (int j = 0; j < i; j++) {
                        if (struct_ir->data.struct_decl.fields[j]) {
                            irinst_free(struct_ir->data.struct_decl.fields[j]);
                        }
                    }
                    free(struct_ir->data.struct_decl.fields);
                    free(tuple_type_name);
                    irinst_free(struct_ir);
                    return NULL;
                }
            }
            
            field->data.var.type = get_ir_type(element_type);
            field->data.var.is_mut = 0;  // Tuple fields are immutable
            field->data.var.init = NULL;
            field->id = ir_gen->current_id++;
            
            // Store original type name for struct/enum types
            if (field->data.var.type == IR_TYPE_STRUCT || field->data.var.type == IR_TYPE_ENUM) {
                char *type_name = get_type_name_string(element_type);
                if (type_name) {
                    field->data.var.original_type_name = type_name;
                }
            }
            
            struct_ir->data.struct_decl.fields[i] = field;
        }
    } else {
        struct_ir->data.struct_decl.fields = NULL;
    }
    
    struct_ir->id = ir_gen->current_id++;
    
    // Add to instructions array
    if (ir_gen->inst_count >= ir_gen->inst_capacity) {
        size_t new_capacity = ir_gen->inst_capacity * 2;
        IRInst **new_instructions = realloc(ir_gen->instructions,
                                           new_capacity * sizeof(IRInst*));
        if (!new_instructions) {
            // Clean up on failure
            if (struct_ir->data.struct_decl.fields) {
                for (int i = 0; i < struct_ir->data.struct_decl.field_count; i++) {
                    if (struct_ir->data.struct_decl.fields[i]) {
                        irinst_free(struct_ir->data.struct_decl.fields[i]);
                    }
                }
                free(struct_ir->data.struct_decl.fields);
            }
            free(tuple_type_name);
            irinst_free(struct_ir);
            return NULL;
        }
        ir_gen->instructions = new_instructions;
        ir_gen->inst_capacity = new_capacity;
    }
    if (ir_gen->inst_count < ir_gen->inst_capacity) {
        ir_gen->instructions[ir_gen->inst_count++] = struct_ir;
    }
    
    return struct_ir;
}

// Find struct declaration by name in IR
static IRInst *find_struct_decl(IRGenerator *ir_gen, const char *struct_name) {
    if (!ir_gen || !struct_name) {
        return NULL;
    }
    
    for (int i = 0; i < ir_gen->inst_count; i++) {
        if (ir_gen->instructions[i] && ir_gen->instructions[i]->type == IR_STRUCT_DECL) {
            if (ir_gen->instructions[i]->data.struct_decl.name &&
                strcmp(ir_gen->instructions[i]->data.struct_decl.name, struct_name) == 0) {
                return ir_gen->instructions[i];
            }
        }
    }
    
    return NULL;
}

void ir_free(void *ir) {
    // IR的清理函数
    printf("清理IR资源...\n");
    if (ir) {
        IRGenerator *ir_gen = (IRGenerator *)ir;
        irgenerator_free(ir_gen);
    }
}