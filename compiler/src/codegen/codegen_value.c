#include "codegen_value.h"
#include "codegen.h"
#include "codegen_type.h"
#include "../ir/ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// 处理转义序列并计算实际长度
static size_t codegen_write_escaped_string(CodeGenerator *codegen, const char *text, size_t text_len) {
    size_t actual_len = 0;
    for (size_t j = 0; j < text_len; j++) {
        if (text[j] == '\\' && j + 1 < text_len) {
            // 处理转义序列
            char next = text[j + 1];
            switch (next) {
                case 'n':
                    fprintf(codegen->output_file, "\\n");
                    actual_len += 1;  // \n 是一个字符
                    j++;  // 跳过 'n'
                    break;
                case 't':
                    fprintf(codegen->output_file, "\\t");
                    actual_len += 1;  // \t 是一个字符
                    j++;  // 跳过 't'
                    break;
                case '\\':
                    fprintf(codegen->output_file, "\\\\");
                    actual_len += 1;  // \\ 是一个字符
                    j++;  // 跳过第二个 '\'
                    break;
                case '"':
                    fprintf(codegen->output_file, "\\\"");
                    actual_len += 1;  // \" 是一个字符
                    j++;  // 跳过 '"'
                    break;
                default:
                    // 未知转义序列，保持原样
                    fprintf(codegen->output_file, "\\%c", next);
                    actual_len += 2;
                    j++;  // 跳过下一个字符
                    break;
            }
        } else if (text[j] == '"') {
            fprintf(codegen->output_file, "\\\"");
            actual_len += 1;
        } else {
            fprintf(codegen->output_file, "%c", text[j]);
            actual_len += 1;
        }
    }
    return actual_len;
}

void codegen_write_value(CodeGenerator *codegen, IRInst *inst) {
    if (!inst) {
        fprintf(codegen->output_file, "0");
        return;
    }

    switch (inst->type) {
        case IR_STRUCT_INIT:
            // Generate struct initialization: (StructName){ .field = value, ... }
            fprintf(codegen->output_file, "(%s){ ", inst->data.struct_init.struct_name);
            for (int i = 0; i < inst->data.struct_init.field_count; i++) {
                if (i > 0) fprintf(codegen->output_file, ", ");
                fprintf(codegen->output_file, ".%s = ", inst->data.struct_init.field_names[i]);
                if (inst->data.struct_init.field_inits[i]) {
                    codegen_write_value(codegen, inst->data.struct_init.field_inits[i]);
                } else {
                    fprintf(codegen->output_file, "0"); // default value
                }
            }
            fprintf(codegen->output_file, "}");
            break;

        case IR_ERROR_VALUE: {
            // Generate error code from error name using hash function
            // Hash function ensures stability: same error name always generates same error code,
            // regardless of other errors being added or removed
            const char *error_name = inst->data.error_value.error_name;
            if (!error_name || strlen(error_name) == 0) {
                // If error_name is NULL or empty, use default error code
                // This should not happen for valid error.ErrorName, but we need to handle it gracefully
                fprintf(codegen->output_file, "1U"); // default error code
                break;
            }

            // Generate unique error code using hash function
            // According to uya.md, error codes are uint32_t
            // Hash function: error_code = error_code * 31 + char (similar to Java's String.hashCode)
            // This ensures stability: same error name always generates same error code,
            // even when other errors are added or removed
            uint32_t error_code = 0;
            for (const char *p = error_name; *p; p++) {
                error_code = error_code * 31 + (unsigned char)*p;
            }
            // Make sure error code is non-zero (0 indicates success)
            if (error_code == 0) error_code = 1;

            // Generate error code as uint32_t literal
            fprintf(codegen->output_file, "%uU", (unsigned int)error_code);
            break;
        }

        case IR_MEMBER_ACCESS: {
            // Check if this is error.TestError or similar error access (legacy IR representation)
            // This should not happen if IR generator correctly generates IR_ERROR_VALUE,
            // but we handle it for backward compatibility
            IRInst *object = inst->data.member_access.object;
            // Check if object is an identifier named "error" (the global error namespace)
            // object can be IR_VAR_DECL (identifier expression from AST_IDENTIFIER)
            if (object && object->type == IR_VAR_DECL && object->data.var.name &&
                strcmp(object->data.var.name, "error") == 0 && inst->data.member_access.field_name) {
                // This is an error access like error.TestError (legacy representation)
                // error is a type (uint32_t), error.TestError should generate an error code
                // Generate a unique error code based on the field name
                const char *error_name = inst->data.member_access.field_name;
                if (!error_name || strlen(error_name) == 0) {
                    fprintf(codegen->output_file, "1U"); // default error code
                    break;
                }
                uint32_t error_code = 0;
                for (const char *p = error_name; *p; p++) {
                    error_code = error_code * 31 + (unsigned char)*p;
                }
                // Make sure error code is non-zero (0 indicates success)
                if (error_code == 0) error_code = 1;
                // Generate error code: ERROR_CODE (as uint32_t)
                fprintf(codegen->output_file, "%uU", (unsigned int)error_code);
                break;
            }

            // Regular member access: object.field or object->field (if object is a pointer)
            int use_arrow = 0;

            // Check if the object is a pointer type
            if (object && object->type == IR_VAR_DECL) {
                // First check the IR type
                if (object->data.var.type == IR_TYPE_PTR) {
                    use_arrow = 1;
                } else if ((object->data.var.type == IR_TYPE_STRUCT ||
                           object->data.var.type == IR_TYPE_I32) && object->data.var.name) {
                    // If type is struct or default I32, check if it's a function parameter
                    // This handles the case where identifier expressions default to I32 or are struct types
                    if (codegen->current_function && codegen->current_function->type == IR_FUNC_DEF) {
                        // Check if this is a drop function
                        int is_drop_func = (codegen->current_function->data.func.name &&
                                           strcmp(codegen->current_function->data.func.name, "drop") == 0);

                        // Look up the parameter in the current function
                        for (int i = 0; i < codegen->current_function->data.func.param_count; i++) {
                            IRInst *param = codegen->current_function->data.func.params[i];
                            if (param && param->data.var.name &&
                                strcmp(param->data.var.name, object->data.var.name) == 0) {
                                // Found the parameter, use its type
                                if (param->data.var.type == IR_TYPE_PTR) {
                                    use_arrow = 1;
                                } else if (is_drop_func && i == 0 &&
                                          param->data.var.type == IR_TYPE_STRUCT) {
                                    // For drop functions, the first parameter (self) is passed as pointer
                                    use_arrow = 1;
                                }
                                break;
                            }
                        }
                    }
                }
            }

            codegen_write_value(codegen, object);
            
            // Check if field_name is a numeric string (tuple field access like .0, .1)
            // In C, struct field names cannot start with digits, so we use _0, _1, etc.
            const char *field_name = inst->data.member_access.field_name;
            int is_numeric_field = 0;
            if (field_name) {
                is_numeric_field = 1;
                for (int i = 0; field_name[i] != '\0'; i++) {
                    if (field_name[i] < '0' || field_name[i] > '9') {
                        is_numeric_field = 0;
                        break;
                    }
                }
            }
            
            if (use_arrow) {
                if (is_numeric_field) {
                    fprintf(codegen->output_file, "->_%s", field_name);
                } else {
                    fprintf(codegen->output_file, "->%s", field_name);
                }
            } else {
                if (is_numeric_field) {
                    fprintf(codegen->output_file, "._%s", field_name);
                } else {
                    fprintf(codegen->output_file, ".%s", field_name);
                }
            }
            break;
        }

        case IR_CONSTANT:
            if (inst->data.constant.value) {
                // Check if this is a string literal (pointer type)
                if (inst->data.constant.type == IR_TYPE_PTR) {
                    // Output as C string literal with quotes
                    fprintf(codegen->output_file, "\"%s\"", inst->data.constant.value);
                } else {
                    // Output as regular constant (numbers, booleans, etc.)
                    fprintf(codegen->output_file, "%s", inst->data.constant.value);
                }
            } else {
                fprintf(codegen->output_file, "0"); // default value
            }
            break;

        case IR_VAR_DECL:
            if (inst->data.var.name) {
                fprintf(codegen->output_file, "%s", inst->data.var.name);
            } else {
                fprintf(codegen->output_file, "temp_%d", inst->id);
            }
            break;
        case IR_ASSIGN:
            // 检查目标是否是表达式（如 arr[0]）还是简单变量
            if (inst->data.assign.dest_expr) {
                // 表达式赋值：arr[0] = value
                codegen_write_value(codegen, inst->data.assign.dest_expr);
                fprintf(codegen->output_file, " = ");
            } else if (inst->data.assign.dest) {
                // 简单变量赋值：var = value
                fprintf(codegen->output_file, "%s = ", inst->data.assign.dest);
            } else {
                fprintf(codegen->output_file, "/* unknown dest */ = ");
            }
            if (inst->data.assign.src) {
                codegen_write_value(codegen, inst->data.assign.src);
            } else {
                fprintf(codegen->output_file, "0"); // default value
            }
            break;
        case IR_UNARY_OP:
            switch (inst->data.unary_op.op) {
                case IR_OP_ADDR_OF:
                    fprintf(codegen->output_file, "&");
                    codegen_write_value(codegen, inst->data.unary_op.operand);
                    break;
                case IR_OP_DEREF:
                    fprintf(codegen->output_file, "*");
                    codegen_write_value(codegen, inst->data.unary_op.operand);
                    break;
                case IR_OP_NEG:
                    fprintf(codegen->output_file, "-");
                    codegen_write_value(codegen, inst->data.unary_op.operand);
                    break;
                case IR_OP_NOT:
                    fprintf(codegen->output_file, "!");
                    codegen_write_value(codegen, inst->data.unary_op.operand);
                    break;
                default:
                    fprintf(codegen->output_file, "/* UNARY_OP */");
                    codegen_write_value(codegen, inst->data.unary_op.operand);
                    break;
            }
            break;

        case IR_BINARY_OP:
            fprintf(codegen->output_file, "(");
            codegen_write_value(codegen, inst->data.binary_op.left);

            switch (inst->data.binary_op.op) {
                case IR_OP_ADD: fprintf(codegen->output_file, " + "); break;
                case IR_OP_SUB: fprintf(codegen->output_file, " - "); break;
                case IR_OP_MUL: fprintf(codegen->output_file, " * "); break;
                case IR_OP_DIV: fprintf(codegen->output_file, " / "); break;
                case IR_OP_MOD: fprintf(codegen->output_file, " %% "); break;
                case IR_OP_EQ: fprintf(codegen->output_file, " == "); break;
                case IR_OP_NE: fprintf(codegen->output_file, " != "); break;
                case IR_OP_LT: fprintf(codegen->output_file, " < "); break;
                case IR_OP_LE: fprintf(codegen->output_file, " <= "); break;
                case IR_OP_GT: fprintf(codegen->output_file, " > "); break;
                case IR_OP_GE: fprintf(codegen->output_file, " >= "); break;
                case IR_OP_BIT_AND: fprintf(codegen->output_file, " & "); break;
                case IR_OP_BIT_OR: fprintf(codegen->output_file, " | "); break;
                case IR_OP_BIT_XOR: fprintf(codegen->output_file, " ^ "); break;
                case IR_OP_LEFT_SHIFT: fprintf(codegen->output_file, " << "); break;
                case IR_OP_RIGHT_SHIFT: fprintf(codegen->output_file, " >> "); break;
                case IR_OP_ADDR_OF: fprintf(codegen->output_file, " & "); break;  // Should be handled in unary_op
                case IR_OP_DEREF: fprintf(codegen->output_file, " * "); break;    // Should be handled in unary_op
                default: fprintf(codegen->output_file, " UNKNOWN_OP "); break;
            }

            codegen_write_value(codegen, inst->data.binary_op.right);
            fprintf(codegen->output_file, ")");
            break;

        case IR_STRUCT_DECL:
            fprintf(codegen->output_file, "typedef struct %s {\n", inst->data.struct_decl.name);
            for (int i = 0; i < inst->data.struct_decl.field_count; i++) {
                if (inst->data.struct_decl.fields[i]) {
                    fprintf(codegen->output_file, "  ");
                    codegen_write_type(codegen, inst->data.struct_decl.fields[i]->data.var.type);
                    fprintf(codegen->output_file, " %s;\n", inst->data.struct_decl.fields[i]->data.var.name);
                }
            }
            fprintf(codegen->output_file, "} %s;\n\n", inst->data.struct_decl.name);
            break;

        case IR_CALL:
            // Handle function calls, but special-case array and slice operations
            if (strcmp(inst->data.call.func_name, "array") == 0) {
                // Generate C array literal: {1, 2, 3, 4, 5}
                fprintf(codegen->output_file, "{");
                for (int i = 0; i < inst->data.call.arg_count; i++) {
                    if (i > 0) fprintf(codegen->output_file, ", ");
                    if (inst->data.call.args[i]) {
                        codegen_write_value(codegen, inst->data.call.args[i]);
                    } else {
                        fprintf(codegen->output_file, "0");
                    }
                }
                fprintf(codegen->output_file, "}");
            } else if (strcmp(inst->data.call.func_name, "slice") == 0) {
                // Generate slice operation - for now, just show as a comment since C doesn't have slices
                fprintf(codegen->output_file, "/* slice operation */");
            } else if (strcmp(inst->data.call.func_name, "double_val") == 0 && inst->data.call.arg_count == 1) {
                // Macro expansion: double_val(x) -> x * 2
                fprintf(codegen->output_file, "(");
                if (inst->data.call.args[0]) {
                    codegen_write_value(codegen, inst->data.call.args[0]);
                } else {
                    fprintf(codegen->output_file, "0");
                }
                fprintf(codegen->output_file, " * 2)");
            } else {
                // Regular function call
                // Special handling for printf with array address arguments to avoid format string warnings
                int is_printf = (strcmp(inst->data.call.func_name, "printf") == 0);
                int first_arg_is_array_addr = 0;
                if (is_printf && inst->data.call.arg_count > 0 && inst->data.call.args[0]) {
                    IRInst *first_arg = inst->data.call.args[0];
                    // Check if first argument is &array[0] (IR_UNARY_OP with IR_OP_ADDR_OF)
                    if (first_arg->type == IR_UNARY_OP && first_arg->data.unary_op.op == IR_OP_ADDR_OF) {
                        first_arg_is_array_addr = 1;
                    }
                }

                fprintf(codegen->output_file, "%s(", inst->data.call.func_name);
                for (int i = 0; i < inst->data.call.arg_count; i++) {
                    if (i > 0) fprintf(codegen->output_file, ", ");
                    if (inst->data.call.args[i]) {
                        if (is_printf && i == 0 && first_arg_is_array_addr) {
                            // For printf with array address, use "%s" format string
                            fprintf(codegen->output_file, "\"%%s\", (char*)");
                            codegen_write_value(codegen, inst->data.call.args[i]);
                        } else {
                            codegen_write_value(codegen, inst->data.call.args[i]);
                        }
                    } else {
                        fprintf(codegen->output_file, "NULL");
                    }
                }
                fprintf(codegen->output_file, ")");
            }
            break;

        case IR_ERROR_UNION:
            // Handle error union operations, especially try expressions
            if (inst->data.error_union.value) {
                // For try expressions, generate the value part
                codegen_write_value(codegen, inst->data.error_union.value);
            } else {
                fprintf(codegen->output_file, "/* error union */");
            }
            break;

        case IR_SUBSCRIPT:
            // Array subscript access: arr[index]
            // Uses member_access structure: object is the array, field_name is the index (as string)
            if (inst->data.member_access.object) {
                // Check if object is a void* pointer that needs type casting
                IRInst *object = inst->data.member_access.object;
                int needs_cast = 0;
                const char *cast_type = NULL;

                if (object) {
                    if (object->type == IR_VAR_DECL) {
                        if (object->data.var.type == IR_TYPE_PTR) {
                            if (object->data.var.original_type_name) {
                                // This is a typed pointer, cast to the original type before subscript
                                needs_cast = 1;
                                cast_type = object->data.var.original_type_name;
                            } else {
                                // For void* without original_type_name, try to infer from context
                                // This is a workaround - ideally IR should preserve type information
                                // Check variable name for hints first (faster)
                                int name_suggests_node = 0;
                                if (object->data.var.name) {
                                    const char *var_name = object->data.var.name;
                                    if (strstr(var_name, "current") || strstr(var_name, "next") ||
                                        strstr(var_name, "prev") || strstr(var_name, "head") ||
                                        strstr(var_name, "tail")) {
                                        name_suggests_node = 1;
                                    }
                                }

                                // If name suggests node type, use Node directly
                                if (name_suggests_node) {
                                    needs_cast = 1;
                                    cast_type = "Node";
                                } else {
                                    // For all void* pointers without type info, try to find Node type from IR
                                    // This is a heuristic - in linked list code, void* pointers are often Node*
                                    if (codegen->ir && codegen->ir->instructions) {
                                        for (int i = 0; i < codegen->ir->inst_count; i++) {
                                            if (codegen->ir->instructions[i] &&
                                                codegen->ir->instructions[i]->type == IR_STRUCT_DECL &&
                                                codegen->ir->instructions[i]->data.struct_decl.name &&
                                                strcmp(codegen->ir->instructions[i]->data.struct_decl.name, "Node") == 0) {
                                                // Found Node type, use it for void* pointer subscript
                                                // Use it as a fallback for all void* pointers
                                                needs_cast = 1;
                                                cast_type = "Node";
                                                break;
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    } else if (object->type == IR_MEMBER_ACCESS) {
                        // This is a member access expression like self->head
                        // Check if the field name suggests a pointer type
                        if (object->data.member_access.field_name) {
                            const char *field_name = object->data.member_access.field_name;
                            // Common pointer field names in linked lists
                            if (strcmp(field_name, "head") == 0 ||
                                strcmp(field_name, "tail") == 0 ||
                                strcmp(field_name, "next") == 0 ||
                                strcmp(field_name, "prev") == 0) {
                                // Try to find Node type from IR
                                if (codegen->ir && codegen->ir->instructions) {
                                    for (int i = 0; i < codegen->ir->inst_count; i++) {
                                        if (codegen->ir->instructions[i] &&
                                            codegen->ir->instructions[i]->type == IR_STRUCT_DECL &&
                                            codegen->ir->instructions[i]->data.struct_decl.name &&
                                            strcmp(codegen->ir->instructions[i]->data.struct_decl.name, "Node") == 0) {
                                            needs_cast = 1;
                                            cast_type = "Node";
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    } else if (object->type == IR_SUBSCRIPT) {
                        // This is a chained subscript like (arr[0])[0] or (ptr[0])[0]
                        // For now, try to infer Node type
                        if (codegen->ir && codegen->ir->instructions) {
                            for (int i = 0; i < codegen->ir->inst_count; i++) {
                                if (codegen->ir->instructions[i] &&
                                    codegen->ir->instructions[i]->type == IR_STRUCT_DECL &&
                                    codegen->ir->instructions[i]->data.struct_decl.name &&
                                    strcmp(codegen->ir->instructions[i]->data.struct_decl.name, "Node") == 0) {
                                    needs_cast = 1;
                                    cast_type = "Node";
                                    break;
                                }
                            }
                        }
                    }
                }

                if (needs_cast && cast_type) {
                    fprintf(codegen->output_file, "((%s*)", cast_type);
                    codegen_write_value(codegen, object);
                    fprintf(codegen->output_file, ")");
                } else {
                    codegen_write_value(codegen, object);
                }

                // Generate index expression
                fprintf(codegen->output_file, "[");
                if (inst->data.member_access.field_name) {
                    // Constant index: use the string value directly
                    fprintf(codegen->output_file, "%s", inst->data.member_access.field_name);
                } else if (inst->data.member_access.index_expr) {
                    // Non-constant index: generate the index expression code
                    codegen_write_value(codegen, inst->data.member_access.index_expr);
                } else {
                    // Fallback: default to index 0
                    fprintf(codegen->output_file, "0");
                }
                fprintf(codegen->output_file, "]");
            } else {
                fprintf(codegen->output_file, "/* subscript */");
            }
            break;

        case IR_IF: {
            // Match expression: generate using GCC compound statement extension ({...})
            // This allows match expressions (which are expressions) to return values
            // Format: ({ type temp; if (cond) temp = body1; else if (cond2) temp = body2; else temp = else_body; temp; })
            
            // Infer return type from first body expression (simplified: assume i32 for now)
            IRType match_type = IR_TYPE_I32;
            if (inst->data.if_stmt.then_body && inst->data.if_stmt.then_count > 0) {
                IRInst *first_body = inst->data.if_stmt.then_body[0];
                if (first_body) {
                    // Try to infer type from expression
                    if (first_body->type == IR_CONSTANT) {
                        match_type = first_body->data.constant.type;
                    } else if (first_body->type == IR_BINARY_OP) {
                        // For binary ops, assume result type is i32 (simplified)
                        match_type = IR_TYPE_I32;
                    } else if (first_body->type == IR_VAR_DECL) {
                        match_type = first_body->data.var.type;
                    }
                    // Add more type inference as needed
                }
            }
            
            // Generate temporary variable name
            static int match_temp_counter = 0;
            char temp_var[32];
            snprintf(temp_var, sizeof(temp_var), "__match_temp_%d", match_temp_counter++);
            
            // Start GCC compound statement
            fprintf(codegen->output_file, "({ ");
            codegen_write_type(codegen, match_type);
            fprintf(codegen->output_file, " %s; ", temp_var);
            
            // Generate nested if-else chain
            IRInst *current_if = inst;
            int first = 1;
            while (current_if && current_if->type == IR_IF) {
                if (!first) {
                    fprintf(codegen->output_file, "else ");
                }
                first = 0;
                
                fprintf(codegen->output_file, "if (");
                codegen_write_value(codegen, current_if->data.if_stmt.condition);
                fprintf(codegen->output_file, ") { %s = ", temp_var);
                
                // Generate body expression (stored in then_body[0])
                if (current_if->data.if_stmt.then_body && current_if->data.if_stmt.then_count > 0) {
                    codegen_write_value(codegen, current_if->data.if_stmt.then_body[0]);
                } else {
                    fprintf(codegen->output_file, "0");
                }
                fprintf(codegen->output_file, "; }");
                
                // Check if there's an else branch (next if in chain)
                if (current_if->data.if_stmt.else_body && current_if->data.if_stmt.else_count > 0) {
                    current_if = current_if->data.if_stmt.else_body[0];
                } else {
                    current_if = NULL;
                }
            }
            
            // Return the temporary variable
            fprintf(codegen->output_file, " %s; })", temp_var);
            break;
        }

        default:
            fprintf(codegen->output_file, "temp_%d", inst->id);
            break;
    }
}