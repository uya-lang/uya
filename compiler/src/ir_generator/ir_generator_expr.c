#include "ir_generator_internal.h"
#include "../checker/const_eval.h"
#include "../lexer/lexer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

IRInst *generate_expr(IRGenerator *ir_gen, struct ASTNode *expr) {
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
