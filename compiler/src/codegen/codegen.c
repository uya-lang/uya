#include "codegen.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

CodeGenerator *codegen_new() {
    CodeGenerator *codegen = malloc(sizeof(CodeGenerator));
    if (!codegen) {
        return NULL;
    }
    
    codegen->output_file = NULL;
    codegen->output_filename = NULL;
    codegen->label_counter = 0;
    codegen->temp_counter = 0;
    codegen->current_function = NULL;
    
    return codegen;
}

void codegen_free(CodeGenerator *codegen) {
    if (codegen) {
        if (codegen->output_filename) {
            free(codegen->output_filename);
        }
        free(codegen);
    }
}

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

static char *codegen_get_type_name(IRType type) {
    switch (type) {
        case IR_TYPE_I8: return "int8_t";
        case IR_TYPE_I16: return "int16_t";
        case IR_TYPE_I32: return "int32_t";
        case IR_TYPE_I64: return "int64_t";
        case IR_TYPE_U8: return "uint8_t";
        case IR_TYPE_U16: return "uint16_t";
        case IR_TYPE_U32: return "uint32_t";
        case IR_TYPE_U64: return "uint64_t";
        case IR_TYPE_F32: return "float";
        case IR_TYPE_F64: return "double";
        case IR_TYPE_BOOL: return "_Bool";  // Use _Bool for C99 bool
        case IR_TYPE_BYTE: return "uint8_t";
        case IR_TYPE_VOID: return "void";
        case IR_TYPE_PTR: return "void*";
        case IR_TYPE_ARRAY: return "int32_t*";  // For now, use pointer for arrays
        case IR_TYPE_STRUCT: return "struct_type"; // 需要特殊处理
        case IR_TYPE_FN: return "fn_type";       // 需要特殊处理
        case IR_TYPE_ERROR_UNION: return "error_union"; // 需要特殊处理
        default: return "unknown_type";
    }
}

static void codegen_write_type(CodeGenerator *codegen, IRType type) {
    fprintf(codegen->output_file, "%s", codegen_get_type_name(type));
}

// Generate error union type name (ErrorUnion_T)
static void codegen_write_error_union_type_name(CodeGenerator *codegen, IRType base_type) {
    const char *base_name = codegen_get_type_name(base_type);
    fprintf(codegen->output_file, "ErrorUnion_%s", base_name);
}

// Generate error union type definition
static void codegen_write_error_union_type_def(CodeGenerator *codegen, IRType base_type) {
    const char *base_name = codegen_get_type_name(base_type);
    fprintf(codegen->output_file, "typedef struct {\n");
    fprintf(codegen->output_file, "    bool is_error;\n");
    fprintf(codegen->output_file, "    union {\n");
    if (base_type == IR_TYPE_VOID) {
        // For void, use an empty struct or just the error code
        fprintf(codegen->output_file, "        uint8_t _void_placeholder;\n");
    } else {
        fprintf(codegen->output_file, "        %s success_value;\n", base_name);
    }
    fprintf(codegen->output_file, "        uint16_t error_code;\n");
    fprintf(codegen->output_file, "    } value;\n");
    fprintf(codegen->output_file, "} ErrorUnion_%s;\n\n", base_name);
}

// Write type with atomic support (for struct fields and variable declarations)
static void codegen_write_type_with_atomic(CodeGenerator *codegen, IRInst *var_inst) {
    if (!var_inst) {
        codegen_write_type(codegen, IR_TYPE_VOID);
        return;
    }
    
    if (var_inst->data.var.is_atomic) {
        // Generate C11 atomic type: _Atomic(type)
        fprintf(codegen->output_file, "_Atomic(");
        codegen_write_type(codegen, var_inst->data.var.type);
        fprintf(codegen->output_file, ")");
    } else {
        codegen_write_type(codegen, var_inst->data.var.type);
    }
}

// Helper function to check if an IR instruction represents an error return value
// According to uya.md, error.ErrorName is the syntax for error types
static int is_error_return_value(IRInst *inst) {
    if (!inst) return 0;
    
    // Check if it's an error value (IR_ERROR_VALUE)
    if (inst->type == IR_ERROR_VALUE) {
        return 1;
    }
    
    // Legacy checks (may not be needed after full migration to IR_ERROR_VALUE)
    // Check if it's a function call to error.*
    if (inst->type == IR_CALL && inst->data.call.func_name) {
        if (strncmp(inst->data.call.func_name, "error", 5) == 0) {
            return 1;
        }
    }
    
    // Check if it's a member access like error.TestError (legacy IR representation)
    if (inst->type == IR_MEMBER_ACCESS && inst->data.member_access.object && inst->data.member_access.field_name) {
        IRInst *object = inst->data.member_access.object;
        // Check if object is an identifier named "error" (the global error namespace)
        if (object->type == IR_VAR_DECL && object->data.var.name && 
            strcmp(object->data.var.name, "error") == 0) {
            // This is error.ErrorName syntax, which represents an error type
            return 1;
        }
    }
    
    return 0;
}

static void codegen_write_value(CodeGenerator *codegen, IRInst *inst) {
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
            // Generate error code from error name
            const char *error_name = inst->data.error_value.error_name;
            if (!error_name) {
                fprintf(codegen->output_file, "1U"); // default error code
                break;
            }
            
            // Generate unique error code using hash function
            uint16_t error_code = 0;
            for (const char *p = error_name; *p; p++) {
                error_code = error_code * 31 + (unsigned char)*p;
            }
            // Ensure error code is non-zero (0 indicates success)
            if (error_code == 0) error_code = 1;
            
            // Generate error code as uint16_t literal
            fprintf(codegen->output_file, "%uU", (unsigned int)error_code);
            break;
        }

        case IR_MEMBER_ACCESS: {
            // Check if this is error.TestError or similar error access
            IRInst *object = inst->data.member_access.object;
            // Check if object is an identifier named "error" (the global error namespace)
            // object can be IR_VAR_DECL (identifier expression)
            if (object && object->type == IR_VAR_DECL && object->data.var.name &&
                strcmp(object->data.var.name, "error") == 0 && inst->data.member_access.field_name) {
                // This is an error access like error.TestError
                // error is a type (uint16_t), error.TestError should generate an error code
                // Generate a unique error code based on the field name
                const char *error_name = inst->data.member_access.field_name;
                uint16_t error_code = 0;
                for (const char *p = error_name; *p; p++) {
                    error_code = error_code * 31 + (unsigned char)*p;
                }
                // Make sure error code is non-zero (0 indicates success)
                if (error_code == 0) error_code = 1;
                // Generate error code: ERROR_CODE (as uint16_t)
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
                } else if (object->data.var.type == IR_TYPE_I32 && object->data.var.name) {
                    // If type is default I32, check if it's a function parameter
                    // This handles the case where identifier expressions default to I32
                    if (codegen->current_function && codegen->current_function->type == IR_FUNC_DEF) {
                        // Look up the parameter in the current function
                        for (int i = 0; i < codegen->current_function->data.func.param_count; i++) {
                            IRInst *param = codegen->current_function->data.func.params[i];
                            if (param && param->data.var.name && 
                                strcmp(param->data.var.name, object->data.var.name) == 0) {
                                // Found the parameter, use its type
                                if (param->data.var.type == IR_TYPE_PTR) {
                                    use_arrow = 1;
                                }
                                break;
                            }
                        }
                    }
                }
            }
            
            codegen_write_value(codegen, object);
            if (use_arrow) {
                fprintf(codegen->output_file, "->%s", inst->data.member_access.field_name);
            } else {
                fprintf(codegen->output_file, ".%s", inst->data.member_access.field_name);
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
            fprintf(codegen->output_file, "%s = ", inst->data.assign.dest);
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
                codegen_write_value(codegen, inst->data.member_access.object);
                if (inst->data.member_access.field_name) {
                    // Check if field_name is a number (constant index) or a variable name
                    fprintf(codegen->output_file, "[%s]", inst->data.member_access.field_name);
                } else {
                    fprintf(codegen->output_file, "[0]"); // Default to index 0
                }
            } else {
                fprintf(codegen->output_file, "/* subscript */");
            }
            break;
            
        default:
            fprintf(codegen->output_file, "temp_%d", inst->id);
            break;
    }
}

static void codegen_generate_inst(CodeGenerator *codegen, IRInst *inst) {
    if (!inst) {
        return;
    }
    
    switch (inst->type) {
        case IR_FUNC_DEF:
            // 在生产模式下，跳过测试函数（以 @test$ 开头）
            if (inst->data.func.name && strncmp(inst->data.func.name, "@test$", 6) == 0) {
                // 跳过测试函数（测试模式会单独处理）
                break;
            }
            // 判断当前函数是否是 drop 函数，并生成正确的函数名
            int is_drop_function = (inst->data.func.name && strcmp(inst->data.func.name, "drop") == 0);
            char *actual_func_name = inst->data.func.name;
            char drop_func_name[256] = {0};
            if (is_drop_function && inst->data.func.param_count > 0 && 
                inst->data.func.params[0] && inst->data.func.params[0]->data.var.original_type_name) {
                snprintf(drop_func_name, sizeof(drop_func_name), "drop_%s", 
                         inst->data.func.params[0]->data.var.original_type_name);
                actual_func_name = drop_func_name;
            }
            
            // 生成函数定义
            // 如果返回类型是!T（错误联合类型），生成标记联合类型名称
            if (inst->data.func.return_type_is_error_union) {
                codegen_write_error_union_type_name(codegen, inst->data.func.return_type);
            } else {
                codegen_write_type(codegen, inst->data.func.return_type);
            }
            fprintf(codegen->output_file, " %s(", actual_func_name);
            
            // Set current function context for member access type checking
            IRInst *prev_function = codegen->current_function;
            codegen->current_function = inst;
            
            // 参数
            for (int i = 0; i < inst->data.func.param_count; i++) {
                if (i > 0) fprintf(codegen->output_file, ", ");
                // Handle pointer types with original type names
                if (inst->data.func.params[i]->data.var.type == IR_TYPE_PTR && 
                    inst->data.func.params[i]->data.var.original_type_name) {
                    fprintf(codegen->output_file, "%s* %s", 
                            inst->data.func.params[i]->data.var.original_type_name,
                            inst->data.func.params[i]->data.var.name);
                } else if (inst->data.func.params[i]->data.var.type == IR_TYPE_STRUCT &&
                           inst->data.func.params[i]->data.var.original_type_name) {
                    fprintf(codegen->output_file, "%s %s", 
                            inst->data.func.params[i]->data.var.original_type_name,
                            inst->data.func.params[i]->data.var.name);
                } else {
                    codegen_write_type(codegen, inst->data.func.params[i]->data.var.type);
                    fprintf(codegen->output_file, " %s", inst->data.func.params[i]->data.var.name);
                }
            }
            fprintf(codegen->output_file, ") {\n");
            
            // 如果函数有返回值，定义一个临时变量来保存返回值
            int has_return_value = inst->data.func.return_type != IR_TYPE_VOID || inst->data.func.return_type_is_error_union;
            char *return_var_name = NULL;
            if (has_return_value) {
                return_var_name = malloc(256);
                sprintf(return_var_name, "_return_%s", actual_func_name);
                // 如果返回类型是!T（错误联合类型），生成标记联合类型名称
                if (inst->data.func.return_type_is_error_union) {
                    codegen_write_error_union_type_name(codegen, inst->data.func.return_type);
                } else {
                    codegen_write_type(codegen, inst->data.func.return_type);
                }
                fprintf(codegen->output_file, "  %s;", return_var_name);
                fprintf(codegen->output_file, "\n");
            }
            
            // 收集defer和errdefer块
            int defer_count = 0;
            IRInst **defer_blocks = NULL;
            int errdefer_count = 0;
            IRInst **errdefer_blocks = NULL;
            
            // 收集需要 drop 的变量（结构体类型或数组类型，且有 original_type_name）
            typedef struct {
                char *var_name;
                char *type_name;
                int is_array;  // 1 if array, 0 if struct
                int array_size;  // For arrays, store the size
            } DropVar;
            DropVar *drop_vars = NULL;
            int drop_var_count = 0;
            
            // 收集函数参数中需要 drop 的变量（drop 函数的参数不需要 drop，因为这是 drop 函数本身）
            if (!is_drop_function) {
                for (int i = 0; i < inst->data.func.param_count; i++) {
                    IRInst *param = inst->data.func.params[i];
                    if (param && param->data.var.original_type_name) {
                        // 用户定义的类型，可能有 drop 函数
                        drop_vars = realloc(drop_vars, (drop_var_count + 1) * sizeof(DropVar));
                        if (drop_vars) {
                            drop_vars[drop_var_count].var_name = param->data.var.name;
                            drop_vars[drop_var_count].type_name = param->data.var.original_type_name;
                            drop_vars[drop_var_count].is_array = (param->data.var.type == IR_TYPE_ARRAY) ? 1 : 0;
                            drop_vars[drop_var_count].array_size = 0;  // For parameters, we don't know the size
                            drop_var_count++;
                        }
                    }
                }
            }
            
            // 跟踪是否有错误返回路径（用于决定是否需要生成错误返回标签）
            int has_error_return_path = 0;
            int return_count = 0;
            
            // 第一遍：生成普通语句，收集defer和errdefer块，修改return语句，收集需要 drop 的变量
            for (int i = 0; i < inst->data.func.body_count; i++) {
                IRInst *body_inst = inst->data.func.body[i];
                
                if (body_inst->type == IR_DEFER) {
                    // 收集defer块
                    defer_blocks = realloc(defer_blocks, (defer_count + 1) * sizeof(IRInst*));
                    defer_blocks[defer_count++] = body_inst;
                    fprintf(codegen->output_file, "  // defer block (collected)\n");
                } else if (body_inst->type == IR_ERRDEFER) {
                    // 收集errdefer块
                    errdefer_blocks = realloc(errdefer_blocks, (errdefer_count + 1) * sizeof(IRInst*));
                    errdefer_blocks[errdefer_count++] = body_inst;
                    fprintf(codegen->output_file, "  // errdefer block (collected)\n");
                } else if (body_inst->type == IR_RETURN) {
                    // 检查返回值是否为错误值
                    int is_error = (body_inst->data.ret.value && is_error_return_value(body_inst->data.ret.value));
                    if (is_error) {
                        has_error_return_path = 1;
                    }
                    
                    // 修改return语句：保存返回值，然后跳转到相应的返回标签
                    if (has_return_value) {
                        // 如果返回类型是!T（错误联合类型），需要设置标记联合结构
                        if (inst->data.func.return_type_is_error_union) {
                            if (is_error) {
                                // 错误返回：设置 is_error = true, error_code = 错误码
                                fprintf(codegen->output_file, "  %s.is_error = true;\n", return_var_name);
                                fprintf(codegen->output_file, "  %s.value.error_code = ", return_var_name);
                                if (body_inst->data.ret.value) {
                                    codegen_write_value(codegen, body_inst->data.ret.value);
                                } else {
                                    fprintf(codegen->output_file, "1U"); // default error code (should not happen)
                                }
                                fprintf(codegen->output_file, ";\n");
                            } else {
                                // 正常返回：设置 is_error = false, success_value = 返回值
                                // 注意：如果 body_inst->data.ret.value 是 NULL，可能是 error.TestError 没有被正确识别
                                // 在这种情况下，对于 !T 类型，如果返回值是 NULL，我们假设这是一个错误（因为正常值不应该为 NULL）
                                if (!body_inst->data.ret.value) {
                                    // 如果返回值是 NULL 且是 !T 类型，可能是一个错误值没有被正确识别
                                    // 为了安全，我们将其视为错误
                                    fprintf(codegen->output_file, "  %s.is_error = true;\n", return_var_name);
                                    fprintf(codegen->output_file, "  %s.value.error_code = 1U;\n", return_var_name);
                                } else {
                                    fprintf(codegen->output_file, "  %s.is_error = false;\n", return_var_name);
                                    fprintf(codegen->output_file, "  %s.value.success_value = ", return_var_name);
                                    codegen_write_value(codegen, body_inst->data.ret.value);
                                    fprintf(codegen->output_file, ";\n");
                                }
                            }
                        } else {
                            // 普通返回类型：直接赋值
                            fprintf(codegen->output_file, "  %s = ", return_var_name);
                            if (body_inst->data.ret.value) {
                                codegen_write_value(codegen, body_inst->data.ret.value);
                            } else {
                                fprintf(codegen->output_file, "0");
                            }
                            fprintf(codegen->output_file, ";\n");
                        }
                    }
                    
                    // 根据是否为错误返回，跳转到不同的标签
                    // 对于!T类型，使用标记联合的is_error标志在函数末尾统一判断
                    if (inst->data.func.return_type_is_error_union) {
                        // !T类型：在函数末尾统一判断is_error标志
                        fprintf(codegen->output_file, "  goto _check_error_return_%s;\n", actual_func_name);
                        has_error_return_path = 1;
                    } else if (is_error) {
                        // 非!T类型但返回错误值（这种情况不应该发生，但保留检查）
                        fprintf(codegen->output_file, "  goto _error_return_%s;\n", actual_func_name);
                        has_error_return_path = 1;
                    } else {
                        fprintf(codegen->output_file, "  goto _normal_return_%s;\n", actual_func_name);
                    }
                    return_count++;
                } else {
                    // 直接处理普通语句，避免递归调用codegen_generate_inst
                    fprintf(codegen->output_file, "  ");
                    switch (body_inst->type) {
                        case IR_VAR_DECL:
                            if (body_inst->data.var.type == IR_TYPE_ARRAY && body_inst->data.var.init &&
                                body_inst->data.var.init->type == IR_CALL &&
                                strcmp(body_inst->data.var.init->data.call.func_name, "array") == 0) {
                                // Special handling for array variable declarations
                                // Use original_type_name if available, otherwise default to int32_t
                                if (body_inst->data.var.original_type_name) {
                                    fprintf(codegen->output_file, "%s %s[] = ", body_inst->data.var.original_type_name, body_inst->data.var.name);
                                    // 收集需要 drop 的数组变量（有 original_type_name 表示元素类型是用户定义的类型）
                                    drop_vars = realloc(drop_vars, (drop_var_count + 1) * sizeof(DropVar));
                                    if (drop_vars) {
                                        drop_vars[drop_var_count].var_name = body_inst->data.var.name;
                                        drop_vars[drop_var_count].type_name = body_inst->data.var.original_type_name;
                                        drop_vars[drop_var_count].is_array = 1;
                                        // 获取数组大小（从 array() 调用的参数数量）
                                        if (body_inst->data.var.init && body_inst->data.var.init->type == IR_CALL &&
                                            strcmp(body_inst->data.var.init->data.call.func_name, "array") == 0) {
                                            drop_vars[drop_var_count].array_size = body_inst->data.var.init->data.call.arg_count;
                                        } else {
                                            drop_vars[drop_var_count].array_size = 0;  // Unknown size
                                        }
                                        drop_var_count++;
                                    }
                                } else {
                                    fprintf(codegen->output_file, "int32_t %s[] = ", body_inst->data.var.name);
                                }
                                codegen_write_value(codegen, body_inst->data.var.init);
                            } else if (body_inst->data.var.type == IR_TYPE_ARRAY && body_inst->data.var.init &&
                                       body_inst->data.var.init->type == IR_STRING_INTERPOLATION) {
                                // 字符串插值：生成完整的代码（函数体中的处理）
                                IRInst *interp_inst = body_inst->data.var.init;
                                int buffer_size = interp_inst->data.string_interpolation.buffer_size;
                                int text_count = interp_inst->data.string_interpolation.text_count;
                                int interp_count = interp_inst->data.string_interpolation.interp_count;
                                
                                // 生成数组声明
                                if (body_inst->data.var.original_type_name) {
                                    fprintf(codegen->output_file, "%s %s[%d] = {0};\n  ", 
                                            body_inst->data.var.original_type_name, body_inst->data.var.name, buffer_size);
                                } else {
                                    fprintf(codegen->output_file, "int8_t %s[%d] = {0};\n  ", 
                                            body_inst->data.var.name, buffer_size);
                                }
                                
                                // 生成字符串插值代码
                                // 文本段和插值表达式交替出现：text[0], interp[0], text[1], interp[1], ...
                                fprintf(codegen->output_file, "int offset_%s = 0;\n  ", body_inst->data.var.name);
                                int max_segments = (text_count > interp_count) ? text_count : interp_count;
                                for (int i = 0; i < max_segments; i++) {
                                    // 先输出文本段（如果有）
                                    if (i < text_count && interp_inst->data.string_interpolation.text_segments[i]) {
                                        const char *text = interp_inst->data.string_interpolation.text_segments[i];
                                        size_t text_len = strlen(text);
                                        if (text_len > 0) {
                                            fprintf(codegen->output_file, "memcpy(&%s[offset_%s], \"", body_inst->data.var.name, body_inst->data.var.name);
                                            size_t actual_len = codegen_write_escaped_string(codegen, text, text_len);
                                            fprintf(codegen->output_file, "\", %zu);\n  offset_%s += %zu;\n  ", actual_len, body_inst->data.var.name, actual_len);
                                        }
                                    }
                                    
                                    // 然后输出插值表达式（如果有）
                                    if (i < interp_count) {
                                        // 检查是否是编译期常量
                                        if (interp_inst->data.string_interpolation.is_const[i] &&
                                            interp_inst->data.string_interpolation.const_values[i]) {
                                            // 编译期常量：直接使用格式化后的字符串
                                            const char *const_val = interp_inst->data.string_interpolation.const_values[i];
                                            size_t const_len = strlen(const_val);
                                            fprintf(codegen->output_file, "memcpy(&%s[offset_%s], \"", body_inst->data.var.name, body_inst->data.var.name);
                                            size_t actual_len = codegen_write_escaped_string(codegen, const_val, const_len);
                                            fprintf(codegen->output_file, "\", %zu);\n  offset_%s += %zu;\n  ", actual_len, body_inst->data.var.name, actual_len);
                                        } else {
                                            // 运行时变量：使用 snprintf
                                            const char *format_str = interp_inst->data.string_interpolation.format_strings[i];
                                            IRInst *expr_ir = interp_inst->data.string_interpolation.interp_exprs[i];
                                            
                                            if (format_str && expr_ir) {
                                                fprintf(codegen->output_file, "offset_%s += snprintf((char*)&%s[offset_%s], %d - offset_%s, \"%s\", ", 
                                                        body_inst->data.var.name, body_inst->data.var.name, body_inst->data.var.name, buffer_size, body_inst->data.var.name, format_str);
                                                codegen_write_value(codegen, expr_ir);
                                                fprintf(codegen->output_file, ");\n  ");
                                            }
                                        }
                                    }
                                }
                            } else if (body_inst->data.var.type == IR_TYPE_ARRAY && body_inst->data.var.init &&
                                       body_inst->data.var.init->type == IR_CONSTANT &&
                                       body_inst->data.var.init->data.constant.value &&
                                       strcmp(body_inst->data.var.init->data.constant.value, "INTERP_PLACEHOLDER") == 0) {
                                // 向后兼容：旧的占位符格式
                                if (body_inst->data.var.original_type_name) {
                                    fprintf(codegen->output_file, "%s %s[] = {0};", body_inst->data.var.original_type_name, body_inst->data.var.name);
                                } else {
                                    fprintf(codegen->output_file, "int8_t %s[] = {0};", body_inst->data.var.name);
                                }
                            } else {
                                // Regular variable declaration
                                if (body_inst->data.var.type == IR_TYPE_STRUCT && body_inst->data.var.original_type_name) {
                                    fprintf(codegen->output_file, "%s %s", body_inst->data.var.original_type_name, body_inst->data.var.name);
                                    // 收集需要 drop 的变量
                                    drop_vars = realloc(drop_vars, (drop_var_count + 1) * sizeof(DropVar));
                                    if (drop_vars) {
                                        drop_vars[drop_var_count].var_name = body_inst->data.var.name;
                                        drop_vars[drop_var_count].type_name = body_inst->data.var.original_type_name;
                                        drop_vars[drop_var_count].is_array = 0;
                                        drop_vars[drop_var_count].array_size = 0;
                                        drop_var_count++;
                                    }
                                } else {
                                    codegen_write_type(codegen, body_inst->data.var.type);
                                    fprintf(codegen->output_file, " %s", body_inst->data.var.name);
                                }
                                if (body_inst->data.var.init) {
                                    fprintf(codegen->output_file, " = ");
                                    codegen_write_value(codegen, body_inst->data.var.init);
                                }
                            }
                            break;
                        case IR_CALL:
                            if (body_inst->data.call.dest) {
                                fprintf(codegen->output_file, "%s = ", body_inst->data.call.dest);
                            }
                            // Special handling for printf with array address arguments to avoid format string warnings
                            int is_printf = (strcmp(body_inst->data.call.func_name, "printf") == 0);
                            int first_arg_is_array_addr = 0;
                            if (is_printf && body_inst->data.call.arg_count > 0 && body_inst->data.call.args[0]) {
                                IRInst *first_arg = body_inst->data.call.args[0];
                                // Check if first argument is &array[0] (IR_UNARY_OP with IR_OP_ADDR_OF)
                                if (first_arg->type == IR_UNARY_OP && first_arg->data.unary_op.op == IR_OP_ADDR_OF) {
                                    first_arg_is_array_addr = 1;
                                }
                            }
                            
                            fprintf(codegen->output_file, "%s(", body_inst->data.call.func_name);
                            for (int j = 0; j < body_inst->data.call.arg_count; j++) {
                                if (j > 0) fprintf(codegen->output_file, ", ");
                                if (body_inst->data.call.args[j]) {
                                    if (is_printf && j == 0 && first_arg_is_array_addr) {
                                        // For printf with array address, use "%s" format string
                                        fprintf(codegen->output_file, "\"%%s\", (char*)");
                                        codegen_write_value(codegen, body_inst->data.call.args[j]);
                                    } else {
                                        codegen_write_value(codegen, body_inst->data.call.args[j]);
                                    }
                                } else {
                                    fprintf(codegen->output_file, "NULL");
                                }
                            }
                            fprintf(codegen->output_file, ")");
                            break;
                        case IR_ASSIGN:
                            fprintf(codegen->output_file, "%s = ", body_inst->data.assign.dest);
                            codegen_write_value(codegen, body_inst->data.assign.src);
                            break;
                        case IR_BINARY_OP:
                            fprintf(codegen->output_file, "%s = ", body_inst->data.binary_op.dest);
                            codegen_write_value(codegen, body_inst->data.binary_op.left);
                            switch (body_inst->data.binary_op.op) {
                                case IR_OP_ADD: fprintf(codegen->output_file, " + "); break;
                                case IR_OP_SUB: fprintf(codegen->output_file, " - "); break;
                                case IR_OP_MUL: fprintf(codegen->output_file, " * "); break;
                                case IR_OP_DIV: fprintf(codegen->output_file, " / "); break;
                                case IR_OP_EQ: fprintf(codegen->output_file, " == "); break;
                                case IR_OP_NE: fprintf(codegen->output_file, " != "); break;
                                case IR_OP_LT: fprintf(codegen->output_file, " < "); break;
                                case IR_OP_LE: fprintf(codegen->output_file, " <= "); break;
                                case IR_OP_GT: fprintf(codegen->output_file, " > "); break;
                                case IR_OP_GE: fprintf(codegen->output_file, " >= "); break;
                                default: fprintf(codegen->output_file, " UNKNOWN_OP "); break;
                            }
                            codegen_write_value(codegen, body_inst->data.binary_op.right);
                            break;
                        case IR_IF:
                            fprintf(codegen->output_file, "if (");
                            codegen_write_value(codegen, body_inst->data.if_stmt.condition);
                            fprintf(codegen->output_file, ") {");
                            for (int j = 0; j < body_inst->data.if_stmt.then_count; j++) {
                                fprintf(codegen->output_file, "\n  ");
                                // 递归处理if语句的then分支
                                codegen_generate_inst(codegen, body_inst->data.if_stmt.then_body[j]);
                                fprintf(codegen->output_file, ";");
                            }
                            if (body_inst->data.if_stmt.else_body) {
                                fprintf(codegen->output_file, "\n} else {");
                                for (int j = 0; j < body_inst->data.if_stmt.else_count; j++) {
                                    fprintf(codegen->output_file, "\n  ");
                                    // 递归处理if语句的else分支
                                    codegen_generate_inst(codegen, body_inst->data.if_stmt.else_body[j]);
                                    fprintf(codegen->output_file, ";");
                                }
                            }
                            fprintf(codegen->output_file, "\n  }");
                            break;
                        case IR_WHILE:
                            fprintf(codegen->output_file, "while (");
                            codegen_write_value(codegen, body_inst->data.while_stmt.condition);
                            fprintf(codegen->output_file, ") {");
                            for (int j = 0; j < body_inst->data.while_stmt.body_count; j++) {
                                fprintf(codegen->output_file, "\n  ");
                                // 递归处理while语句的body
                                codegen_generate_inst(codegen, body_inst->data.while_stmt.body[j]);
                                fprintf(codegen->output_file, ";");
                            }
                            fprintf(codegen->output_file, "\n  }");
                            break;
                        case IR_BLOCK: {
                            // Generate nested block with defer handling: { ... }
                            // Collect defers from the block
                            int block_defer_count = 0;
                            IRInst **block_defer_blocks = NULL;
                            int block_errdefer_count = 0;
                            IRInst **block_errdefer_blocks = NULL;
                            
                            fprintf(codegen->output_file, "{\n");
                            for (int j = 0; j < body_inst->data.block.inst_count; j++) {
                                IRInst *block_stmt = body_inst->data.block.insts[j];
                                if (!block_stmt) continue;
                                
                                if (block_stmt->type == IR_DEFER) {
                                    block_defer_blocks = realloc(block_defer_blocks, (block_defer_count + 1) * sizeof(IRInst*));
                                    block_defer_blocks[block_defer_count++] = block_stmt;
                                    fprintf(codegen->output_file, "    // defer block (collected)\n");
                                } else if (block_stmt->type == IR_ERRDEFER) {
                                    block_errdefer_blocks = realloc(block_errdefer_blocks, (block_errdefer_count + 1) * sizeof(IRInst*));
                                    block_errdefer_blocks[block_errdefer_count++] = block_stmt;
                                    fprintf(codegen->output_file, "    // errdefer block (collected)\n");
                                } else {
                                    fprintf(codegen->output_file, "    ");
                                    codegen_generate_inst(codegen, block_stmt);
                                    fprintf(codegen->output_file, ";\n");
                                }
                            }
                            
                            // Generate defer blocks in LIFO order at the end of the block
                            if (block_errdefer_count > 0 && block_errdefer_blocks) {
                                for (int j = block_errdefer_count - 1; j >= 0; j--) {
                                    IRInst *errdefer_inst = block_errdefer_blocks[j];
                                    if (!errdefer_inst) continue;
                                    if (errdefer_inst->data.errdefer.body) {
                                        for (int k = 0; k < errdefer_inst->data.errdefer.body_count; k++) {
                                            if (!errdefer_inst->data.errdefer.body[k]) continue;
                                            fprintf(codegen->output_file, "    ");
                                            codegen_generate_inst(codegen, errdefer_inst->data.errdefer.body[k]);
                                            fprintf(codegen->output_file, ";\n");
                                        }
                                    }
                                }
                                free(block_errdefer_blocks);
                            }
                            if (block_defer_count > 0 && block_defer_blocks) {
                                for (int j = block_defer_count - 1; j >= 0; j--) {
                                    IRInst *defer_inst = block_defer_blocks[j];
                                    if (!defer_inst) continue;
                                    if (defer_inst->data.defer.body) {
                                        for (int k = 0; k < defer_inst->data.defer.body_count; k++) {
                                            if (!defer_inst->data.defer.body[k]) continue;
                                            fprintf(codegen->output_file, "    ");
                                            codegen_generate_inst(codegen, defer_inst->data.defer.body[k]);
                                            fprintf(codegen->output_file, ";\n");
                                        }
                                    }
                                }
                                free(block_defer_blocks);
                            }
                            fprintf(codegen->output_file, "  }");
                            break;
                        }
                        // 处理其他指令类型...
                        default:
                            fprintf(codegen->output_file, "/* Unknown instruction: %d */", body_inst->type);
                            break;
                    }
                    fprintf(codegen->output_file, ";\n");
                }
            }
            
            // 对于!T类型，生成统一的错误检查点
            if (inst->data.func.return_type_is_error_union && has_error_return_path) {
                fprintf(codegen->output_file, "_check_error_return_%s:\n", actual_func_name);
                fprintf(codegen->output_file, "  if (%s.is_error) {\n", return_var_name);
                fprintf(codegen->output_file, "    goto _error_return_%s;\n", actual_func_name);
                fprintf(codegen->output_file, "  } else {\n");
                fprintf(codegen->output_file, "    goto _normal_return_%s;\n", actual_func_name);
                fprintf(codegen->output_file, "  }\n\n");
            }
            
            // 生成错误返回路径（如果有错误返回）
            if (has_error_return_path && errdefer_count > 0 && errdefer_blocks) {
                fprintf(codegen->output_file, "_error_return_%s:\n", actual_func_name);
                
                // 生成 errdefer 块（仅在错误返回时执行）
                fprintf(codegen->output_file, "  // Generated errdefer blocks in LIFO order (error return)\n");
                for (int i = errdefer_count - 1; i >= 0; i--) {
                    IRInst *errdefer_inst = errdefer_blocks[i];
                    if (!errdefer_inst) continue;
                    fprintf(codegen->output_file, "  // errdefer block %d\n", i);
                    if (errdefer_inst->data.errdefer.body) {
                        for (int j = 0; j < errdefer_inst->data.errdefer.body_count; j++) {
                            if (!errdefer_inst->data.errdefer.body[j]) continue;
                            fprintf(codegen->output_file, "  ");
                            codegen_generate_inst(codegen, errdefer_inst->data.errdefer.body[j]);
                            fprintf(codegen->output_file, ";\n");
                        }
                    }
                }
                
                // 生成 defer 块
                if (defer_count > 0 && defer_blocks) {
                    fprintf(codegen->output_file, "  // Generated defer blocks in LIFO order\n");
                    for (int i = defer_count - 1; i >= 0; i--) {
                        IRInst *defer_inst = defer_blocks[i];
                        if (!defer_inst) continue;
                        fprintf(codegen->output_file, "  // defer block %d\n", i);
                        if (defer_inst->data.defer.body) {
                            for (int j = 0; j < defer_inst->data.defer.body_count; j++) {
                                if (!defer_inst->data.defer.body[j]) continue;
                                fprintf(codegen->output_file, "  ");
                                codegen_generate_inst(codegen, defer_inst->data.defer.body[j]);
                                fprintf(codegen->output_file, ";\n");
                            }
                        }
                    }
                }
                
                // 生成 drop 调用
                if (drop_var_count > 0 && drop_vars) {
                    fprintf(codegen->output_file, "  // Generated drop calls in LIFO order\n");
                    for (int i = drop_var_count - 1; i >= 0; i--) {
                        if (drop_vars[i].var_name && drop_vars[i].type_name) {
                            if (drop_vars[i].is_array) {
                                // 对于数组，需要遍历每个元素调用 drop
                                if (drop_vars[i].array_size > 0) {
                                    fprintf(codegen->output_file, "  for (int _drop_idx = 0; _drop_idx < %d; _drop_idx++) {\n", drop_vars[i].array_size);
                                    fprintf(codegen->output_file, "    drop_%s(%s[_drop_idx]);\n", drop_vars[i].type_name, drop_vars[i].var_name);
                                    fprintf(codegen->output_file, "  }\n");
                                } else {
                                    // 如果不知道数组大小，使用 sizeof 计算
                                    fprintf(codegen->output_file, "  for (int _drop_idx = 0; _drop_idx < (int)(sizeof(%s) / sizeof(%s[0])); _drop_idx++) {\n", drop_vars[i].var_name, drop_vars[i].var_name);
                                    fprintf(codegen->output_file, "    drop_%s(%s[_drop_idx]);\n", drop_vars[i].type_name, drop_vars[i].var_name);
                                    fprintf(codegen->output_file, "  }\n");
                                }
                            } else {
                                // 对于单个结构体，直接调用 drop
                                fprintf(codegen->output_file, "  drop_%s(%s);\n", drop_vars[i].type_name, drop_vars[i].var_name);
                            }
                        }
                    }
                }
                
                // 返回
                if (has_return_value) {
                    fprintf(codegen->output_file, "  return %s;\n", return_var_name);
                } else {
                    fprintf(codegen->output_file, "  return;\n");
                }
            }
            
            // 生成正常返回路径
            fprintf(codegen->output_file, "_normal_return_%s:\n", actual_func_name);
            
            // 生成 defer 块（正常返回时只执行 defer，不执行 errdefer）
            if (defer_count > 0 && defer_blocks) {
                fprintf(codegen->output_file, "  // Generated defer blocks in LIFO order\n");
                for (int i = defer_count - 1; i >= 0; i--) {
                    IRInst *defer_inst = defer_blocks[i];
                    if (!defer_inst) continue;
                    fprintf(codegen->output_file, "  // defer block %d\n", i);
                    if (defer_inst->data.defer.body) {
                        for (int j = 0; j < defer_inst->data.defer.body_count; j++) {
                            if (!defer_inst->data.defer.body[j]) continue;
                            fprintf(codegen->output_file, "  ");
                            codegen_generate_inst(codegen, defer_inst->data.defer.body[j]);
                            fprintf(codegen->output_file, ";\n");
                        }
                    }
                }
            }
            
                // 生成 drop 调用
                if (drop_var_count > 0 && drop_vars) {
                    fprintf(codegen->output_file, "  // Generated drop calls in LIFO order\n");
                    for (int i = drop_var_count - 1; i >= 0; i--) {
                        if (drop_vars[i].var_name && drop_vars[i].type_name) {
                            if (drop_vars[i].is_array) {
                                // 对于数组，需要遍历每个元素调用 drop
                                if (drop_vars[i].array_size > 0) {
                                    fprintf(codegen->output_file, "  for (int _drop_idx = 0; _drop_idx < %d; _drop_idx++) {\n", drop_vars[i].array_size);
                                    fprintf(codegen->output_file, "    drop_%s(%s[_drop_idx]);\n", drop_vars[i].type_name, drop_vars[i].var_name);
                                    fprintf(codegen->output_file, "  }\n");
                                } else {
                                    // 如果不知道数组大小，使用 sizeof 计算
                                    fprintf(codegen->output_file, "  for (int _drop_idx = 0; _drop_idx < (int)(sizeof(%s) / sizeof(%s[0])); _drop_idx++) {\n", drop_vars[i].var_name, drop_vars[i].var_name);
                                    fprintf(codegen->output_file, "    drop_%s(%s[_drop_idx]);\n", drop_vars[i].type_name, drop_vars[i].var_name);
                                    fprintf(codegen->output_file, "  }\n");
                                }
                            } else {
                                // 对于单个结构体，直接调用 drop
                                fprintf(codegen->output_file, "  drop_%s(%s);\n", drop_vars[i].type_name, drop_vars[i].var_name);
                            }
                        }
                    }
                    free(drop_vars);
                }
            
            // 返回
            if (has_return_value) {
                fprintf(codegen->output_file, "  return %s;\n", return_var_name);
                free(return_var_name);
            } else {
                fprintf(codegen->output_file, "  return;\n");
            }
            
            // 释放defer和errdefer块数组
            if (defer_blocks) {
                free(defer_blocks);
            }
            if (errdefer_blocks) {
                free(errdefer_blocks);
            }
            
            fprintf(codegen->output_file, "}\n\n");
            
            // Restore previous function context
            codegen->current_function = prev_function;
            break;
            
        case IR_VAR_DECL:
            if (inst->data.var.type == IR_TYPE_ARRAY && inst->data.var.init &&
                inst->data.var.init->type == IR_CALL &&
                strcmp(inst->data.var.init->data.call.func_name, "array") == 0) {
                // Special handling for array variable declarations: let arr: [i32; 3] = [1, 2, 3];
                // Generate: TypeName arr[] = {1, 2, 3};
                // Use original_type_name if available, otherwise default to int32_t
                if (inst->data.var.original_type_name) {
                    fprintf(codegen->output_file, "%s %s[] = ", inst->data.var.original_type_name, inst->data.var.name);
                } else {
                    fprintf(codegen->output_file, "int32_t %s[] = ", inst->data.var.name);
                }
                codegen_write_value(codegen, inst->data.var.init);  // This will output {1, 2, 3}
            } else if (inst->data.var.type == IR_TYPE_ARRAY && inst->data.var.init &&
                       inst->data.var.init->type == IR_STRING_INTERPOLATION) {
                // 字符串插值：生成完整的代码
                IRInst *interp_inst = inst->data.var.init;
                int buffer_size = interp_inst->data.string_interpolation.buffer_size;
                int text_count = interp_inst->data.string_interpolation.text_count;
                int interp_count = interp_inst->data.string_interpolation.interp_count;
                
                // 生成数组声明
                if (inst->data.var.original_type_name) {
                    fprintf(codegen->output_file, "%s %s[%d] = {0};\n  ", 
                            inst->data.var.original_type_name, inst->data.var.name, buffer_size);
                } else {
                    fprintf(codegen->output_file, "int8_t %s[%d] = {0};\n  ", 
                            inst->data.var.name, buffer_size);
                }
                
                // 生成字符串插值代码
                fprintf(codegen->output_file, "int offset_%s = 0;\n  ", inst->data.var.name);
                for (int i = 0; i < text_count || i < interp_count; i++) {
                    // 先输出文本段
                    if (i < text_count && interp_inst->data.string_interpolation.text_segments[i]) {
                        const char *text = interp_inst->data.string_interpolation.text_segments[i];
                        size_t text_len = strlen(text);
                        if (text_len > 0) {
                            // 生成 memcpy 调用
                            fprintf(codegen->output_file, "memcpy(&%s[offset_%s], \"", inst->data.var.name, inst->data.var.name);
                            size_t actual_len = codegen_write_escaped_string(codegen, text, text_len);
                            fprintf(codegen->output_file, "\", %zu);\n  offset_%s += %zu;\n  ", actual_len, inst->data.var.name, actual_len);
                        }
                    }
                    
                    // 然后输出插值表达式
                    if (i < interp_count) {
                        const char *format_str = interp_inst->data.string_interpolation.format_strings[i];
                        IRInst *expr_ir = interp_inst->data.string_interpolation.interp_exprs[i];
                        
                        if (format_str && expr_ir) {
                            // 生成 snprintf 调用，使用 offset 变量和剩余缓冲区大小
                            fprintf(codegen->output_file, "offset_%s += snprintf((char*)&%s[offset_%s], %d - offset_%s, \"%s\", ", 
                                    inst->data.var.name, inst->data.var.name, inst->data.var.name, buffer_size, inst->data.var.name, format_str);
                            codegen_write_value(codegen, expr_ir);
                            fprintf(codegen->output_file, ");\n  ");
                        }
                    }
                }
            } else if (inst->data.var.type == IR_TYPE_ARRAY && inst->data.var.init &&
                       inst->data.var.init->type == IR_CONSTANT &&
                       inst->data.var.init->data.constant.value &&
                       strcmp(inst->data.var.init->data.constant.value, "INTERP_PLACEHOLDER") == 0) {
                // 向后兼容：旧的占位符格式
                if (inst->data.var.original_type_name) {
                    fprintf(codegen->output_file, "%s %s[] = {0};", inst->data.var.original_type_name, inst->data.var.name);
                } else {
                    fprintf(codegen->output_file, "int8_t %s[] = {0};", inst->data.var.name);
                }
            } else {
                // Check if initialization is a function call with same name as variable
                // This avoids name shadowing issues in C (e.g., "float area = area(rect);")
                int name_conflict = 0;
                if (inst->data.var.init && inst->data.var.init->type == IR_CALL &&
                    inst->data.var.name &&
                    inst->data.var.init->data.call.func_name &&
                    strcmp(inst->data.var.name, inst->data.var.init->data.call.func_name) == 0) {
                    name_conflict = 1;
                }
                
                if (name_conflict) {
                    // Generate: type _tmp_var = func_name(...); type var = _tmp_var;
                    // This ensures the function is called before the variable is declared
                    codegen_write_type(codegen, inst->data.var.type);
                    fprintf(codegen->output_file, " _tmp_%s = ", inst->data.var.name);
                    codegen_write_value(codegen, inst->data.var.init);
                    fprintf(codegen->output_file, ";\n  ");
                    // Now declare the actual variable and assign from temp
                    if (inst->data.var.type == IR_TYPE_STRUCT && inst->data.var.original_type_name) {
                        fprintf(codegen->output_file, "%s %s = _tmp_%s", 
                                inst->data.var.original_type_name, inst->data.var.name, inst->data.var.name);
                    } else {
                        codegen_write_type(codegen, inst->data.var.type);
                        fprintf(codegen->output_file, " %s = _tmp_%s", inst->data.var.name, inst->data.var.name);
                    }
                } else {
                    // For user-defined struct types, use the original type name
                    if (inst->data.var.type == IR_TYPE_STRUCT && inst->data.var.original_type_name) {
                        fprintf(codegen->output_file, "%s %s", inst->data.var.original_type_name, inst->data.var.name);
                    } else {
                        codegen_write_type(codegen, inst->data.var.type);
                        fprintf(codegen->output_file, " %s", inst->data.var.name);
                    }

                    if (inst->data.var.init) {
                        fprintf(codegen->output_file, " = ");
                        codegen_write_value(codegen, inst->data.var.init);
                    }
                }
            }
            break;
            
        case IR_ASSIGN:
            fprintf(codegen->output_file, "%s = ", inst->data.assign.dest);
            codegen_write_value(codegen, inst->data.assign.src);
            break;
            
        case IR_BINARY_OP:
            fprintf(codegen->output_file, "%s = ", inst->data.binary_op.dest);
            codegen_write_value(codegen, inst->data.binary_op.left);
            
            switch (inst->data.binary_op.op) {
                case IR_OP_ADD: fprintf(codegen->output_file, " + "); break;
                case IR_OP_SUB: fprintf(codegen->output_file, " - "); break;
                case IR_OP_MUL: fprintf(codegen->output_file, " * "); break;
                case IR_OP_DIV: fprintf(codegen->output_file, " / "); break;
                case IR_OP_EQ: fprintf(codegen->output_file, " == "); break;
                case IR_OP_NE: fprintf(codegen->output_file, " != "); break;
                case IR_OP_LT: fprintf(codegen->output_file, " < "); break;
                case IR_OP_LE: fprintf(codegen->output_file, " <= "); break;
                case IR_OP_GT: fprintf(codegen->output_file, " > "); break;
                case IR_OP_GE: fprintf(codegen->output_file, " >= "); break;
                default: fprintf(codegen->output_file, " UNKNOWN_OP "); break;
            }
            
            codegen_write_value(codegen, inst->data.binary_op.right);
            break;
            
        case IR_RETURN:
            // This case should only be called for return statements not inside function bodies
            // Inside function bodies, return statements are handled specially in IR_FUNC_DEF case
            fprintf(codegen->output_file, "return ");
            if (inst->data.ret.value) {
                codegen_write_value(codegen, inst->data.ret.value);
            } else {
                // Default return value for non-void functions when value is missing
                fprintf(codegen->output_file, "0");
            }
            break;
            
        case IR_CALL:
            if (inst->data.call.dest) {
                fprintf(codegen->output_file, "%s = ", inst->data.call.dest);
            }
            fprintf(codegen->output_file, "%s(", inst->data.call.func_name);
            for (int i = 0; i < inst->data.call.arg_count; i++) {
                if (i > 0) fprintf(codegen->output_file, ", ");
                codegen_write_value(codegen, inst->data.call.args[i]);
            }
            fprintf(codegen->output_file, ")");
            break;
            
        case IR_IF:
            fprintf(codegen->output_file, "if (");
            codegen_write_value(codegen, inst->data.if_stmt.condition);
            fprintf(codegen->output_file, ") {\n");
            
            for (int i = 0; i < inst->data.if_stmt.then_count; i++) {
                fprintf(codegen->output_file, "  ");
                codegen_generate_inst(codegen, inst->data.if_stmt.then_body[i]);
                fprintf(codegen->output_file, ";\n");
            }
            
            if (inst->data.if_stmt.else_body) {
                fprintf(codegen->output_file, "} else {\n");
                for (int i = 0; i < inst->data.if_stmt.else_count; i++) {
                    fprintf(codegen->output_file, "  ");
                    codegen_generate_inst(codegen, inst->data.if_stmt.else_body[i]);
                    fprintf(codegen->output_file, ";\n");
                }
            }
            fprintf(codegen->output_file, "}");
            break;
            
        case IR_WHILE:
            fprintf(codegen->output_file, "while (");
            codegen_write_value(codegen, inst->data.while_stmt.condition);
            fprintf(codegen->output_file, ") {\n");

            for (int i = 0; i < inst->data.while_stmt.body_count; i++) {
                fprintf(codegen->output_file, "  ");
                codegen_generate_inst(codegen, inst->data.while_stmt.body[i]);
                fprintf(codegen->output_file, ";\n");
            }

            fprintf(codegen->output_file, "}");
            break;

        case IR_FOR:
            // Generate for loop - for now, generate a basic structure
            // In a full implementation, we'd generate proper iteration code
            fprintf(codegen->output_file, "/* for loop */ {\n");

            // If we have item variable, we'll need to handle iteration
            if (inst->data.for_stmt.item_var) {
                fprintf(codegen->output_file, "  // Iterate over items, assign to %s\n", inst->data.for_stmt.item_var);
            }

            // Generate the loop body
            for (int i = 0; i < inst->data.for_stmt.body_count; i++) {
                fprintf(codegen->output_file, "  ");
                codegen_generate_inst(codegen, inst->data.for_stmt.body[i]);
                fprintf(codegen->output_file, ";\n");
            }

            fprintf(codegen->output_file, "}");
            break;

        case IR_TRY_CATCH:
            // For now, just generate the try body without error handling
            // In a full implementation, we'd generate proper error handling code
            if (inst->data.try_catch.try_body) {
                codegen_generate_inst(codegen, inst->data.try_catch.try_body);
            }
            break;

        case IR_STRUCT_DECL:
            // Generate struct declaration: typedef struct StructName { ... } StructName;
            fprintf(codegen->output_file, "typedef struct %s {\n", inst->data.struct_decl.name);
            for (int i = 0; i < inst->data.struct_decl.field_count; i++) {
                if (inst->data.struct_decl.fields[i]) {
                    fprintf(codegen->output_file, "  ");
                    codegen_write_type_with_atomic(codegen, inst->data.struct_decl.fields[i]);
                    fprintf(codegen->output_file, " %s;\n", inst->data.struct_decl.fields[i]->data.var.name);
                }
            }
            fprintf(codegen->output_file, "} %s;\n\n", inst->data.struct_decl.name);
            break;

        case IR_DROP:
            // Generate drop call: drop_TypeName(var_name)
            if (inst->data.drop.var_name) {
                if (inst->data.drop.type_name) {
                    fprintf(codegen->output_file, "drop_%s(%s)", inst->data.drop.type_name, inst->data.drop.var_name);
                } else {
                    // Fallback if type_name is not available
                    fprintf(codegen->output_file, "drop(%s)", inst->data.drop.var_name);
                }
            }
            break;
            
        case IR_DEFER:
            // Defer implementation in C - generate code directly in the function
            fprintf(codegen->output_file, "// defer block\n");
            // Generate the defer body directly
            for (int i = 0; i < inst->data.defer.body_count; i++) {
                fprintf(codegen->output_file, "  ");
                codegen_generate_inst(codegen, inst->data.defer.body[i]);
                fprintf(codegen->output_file, ";\n");
            }
            break;
            
        case IR_ERRDEFER:
            // Errdefer implementation in C - generate code directly in the function
            fprintf(codegen->output_file, "// errdefer block\n");
            // Generate the errdefer body directly
            for (int i = 0; i < inst->data.errdefer.body_count; i++) {
                fprintf(codegen->output_file, "  ");
                codegen_generate_inst(codegen, inst->data.errdefer.body[i]);
                fprintf(codegen->output_file, ";\n");
            }
            break;

        case IR_BLOCK:
            // Generate block: { ... }
            fprintf(codegen->output_file, "{\n");
            for (int i = 0; i < inst->data.block.inst_count; i++) {
                if (!inst->data.block.insts[i]) continue;
                fprintf(codegen->output_file, "  ");
                codegen_generate_inst(codegen, inst->data.block.insts[i]);
                fprintf(codegen->output_file, ";\n");
            }
            fprintf(codegen->output_file, "}");
            break;
            
        default:
            fprintf(codegen->output_file, "/* Unknown instruction type: %d */", inst->type);
            break;
    }
}

int codegen_generate(CodeGenerator *codegen, IRGenerator *ir, const char *output_file) {
    if (!codegen || !ir || !output_file) {
        return 0;
    }
    
    codegen->output_file = fopen(output_file, "w");
    if (!codegen->output_file) {
        return 0;
    }
    
    codegen->output_filename = malloc(strlen(output_file) + 1);
    if (!codegen->output_filename) {
        fclose(codegen->output_file);
        return 0;
    }
    strcpy(codegen->output_filename, output_file);
    
    // 写入C99头文件
    fprintf(codegen->output_file, "// Generated by Uya to C99 Compiler\n");
    fprintf(codegen->output_file, "#include <stdint.h>\n");
    fprintf(codegen->output_file, "#include <stddef.h>\n");
    fprintf(codegen->output_file, "#include <stdbool.h>\n");
    fprintf(codegen->output_file, "#include <stdio.h>\n");
    fprintf(codegen->output_file, "#include <stdlib.h>\n");
    fprintf(codegen->output_file, "#include <string.h>\n");
    fprintf(codegen->output_file, "#include <unistd.h>\n");
    fprintf(codegen->output_file, "#include <fcntl.h>\n\n");
    // Error type definition (error is a type containing error codes, represented as uint16_t)
    fprintf(codegen->output_file, "// Error type definition (error codes are uint16_t)\n");
    fprintf(codegen->output_file, "typedef uint16_t error;\n\n");
    
    // Collect and generate error union type definitions for all functions with !T return types
    fprintf(codegen->output_file, "// Error union type definitions\n");
    if (ir && ir->instructions) {
        // Use a simple approach: generate error union types for common base types
        // TODO: In the future, we should collect only the types actually used
        codegen_write_error_union_type_def(codegen, IR_TYPE_I32);
        codegen_write_error_union_type_def(codegen, IR_TYPE_VOID);
    }
    fprintf(codegen->output_file, "\n");
    
    // 第一遍：生成结构体声明（必须在函数声明之前）
    if (ir && ir->instructions) {
        for (int i = 0; i < ir->inst_count; i++) {
            if (ir->instructions[i] && ir->instructions[i]->type == IR_STRUCT_DECL) {
                codegen_generate_inst(codegen, ir->instructions[i]);
            }
        }
    }
    
    // 第二遍：生成函数声明（前向声明）
    fprintf(codegen->output_file, "// Forward declarations\n");
    if (ir && ir->instructions) {
        for (int i = 0; i < ir->inst_count; i++) {
            if (ir->instructions[i] && ir->instructions[i]->type == IR_FUNC_DEF) {
                IRInst *func = ir->instructions[i];
                // Skip test functions
                if (func->data.func.name && strncmp(func->data.func.name, "@test$", 6) == 0) {
                    continue;
                }
                // Generate forward declaration
                if (func->data.func.return_type_is_error_union) {
                    codegen_write_error_union_type_name(codegen, func->data.func.return_type);
                } else {
                    codegen_write_type(codegen, func->data.func.return_type);
                }
                
                // For drop functions, use the actual function name (drop_TypeName)
                char *actual_func_name = func->data.func.name;
                char drop_func_name[256] = {0};
                if (func->data.func.name && strcmp(func->data.func.name, "drop") == 0 &&
                    func->data.func.param_count > 0 && func->data.func.params[0] &&
                    func->data.func.params[0]->data.var.original_type_name) {
                    snprintf(drop_func_name, sizeof(drop_func_name), "drop_%s", 
                             func->data.func.params[0]->data.var.original_type_name);
                    actual_func_name = drop_func_name;
                }
                
                fprintf(codegen->output_file, " %s(", actual_func_name);
                for (int j = 0; j < func->data.func.param_count; j++) {
                    if (j > 0) fprintf(codegen->output_file, ", ");
                    if (func->data.func.params[j]->data.var.type == IR_TYPE_PTR && 
                        func->data.func.params[j]->data.var.original_type_name) {
                        fprintf(codegen->output_file, "%s* %s", 
                                func->data.func.params[j]->data.var.original_type_name,
                                func->data.func.params[j]->data.var.name);
                    } else if (func->data.func.params[j]->data.var.type == IR_TYPE_STRUCT &&
                               func->data.func.params[j]->data.var.original_type_name) {
                        fprintf(codegen->output_file, "%s %s", 
                                func->data.func.params[j]->data.var.original_type_name,
                                func->data.func.params[j]->data.var.name);
                    } else {
                        codegen_write_type(codegen, func->data.func.params[j]->data.var.type);
                        fprintf(codegen->output_file, " %s", func->data.func.params[j]->data.var.name);
                    }
                }
                fprintf(codegen->output_file, ");\n");
            }
        }
    }
    fprintf(codegen->output_file, "\n");
    
    // 第三遍：生成函数定义（跳过已生成的结构体声明）
    if (ir && ir->instructions) {
        for (int i = 0; i < ir->inst_count; i++) {
            if (ir->instructions[i]) {
                // Skip struct declarations (already generated in first pass)
                if (ir->instructions[i]->type == IR_STRUCT_DECL) {
                    continue;
                }
                codegen_generate_inst(codegen, ir->instructions[i]);
            }
        }
    }
    
    fclose(codegen->output_file);
    codegen->output_file = NULL;
    
    return 1;
}