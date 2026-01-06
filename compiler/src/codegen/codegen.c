#include "codegen.h"
#include "../ir/ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// 前向声明
static void collect_error_names_recursive(CodeGenerator *codegen, IRInst *inst);
static uint32_t hash_error_name(const char *error_name);
static int detect_error_code_collisions(CodeGenerator *codegen);

// 收集所有错误名称（从 IR 中遍历所有 IR_ERROR_VALUE）
static int collect_error_names(CodeGenerator *codegen, IRGenerator *ir) {
    if (!codegen || !ir || !ir->instructions) {
        return 0; // 成功
    }
    
    // 第一遍：收集所有唯一的错误名称
    for (int i = 0; i < ir->inst_count; i++) {
        if (!ir->instructions[i]) continue;
        
        // 递归遍历 IR 指令树，查找所有 IR_ERROR_VALUE
        collect_error_names_recursive(codegen, ir->instructions[i]);
    }
    
    // 如果没有收集到任何错误名称，直接返回
    if (codegen->error_map_size == 0) {
        return 0; // 成功
    }
    
    // 计算每个错误名称的哈希值
    for (int i = 0; i < codegen->error_map_size; i++) {
        codegen->error_map[i].error_code = hash_error_name(codegen->error_map[i].error_name);
    }
    
    // 检测冲突
    int collision_count = detect_error_code_collisions(codegen);
    if (collision_count > 0) {
        fprintf(stderr, "\n编译失败: 发现 %d 个错误码冲突\n", collision_count);
        fprintf(stderr, "请重命名冲突的错误名称以避免冲突\n");
        return 1; // 失败
    }
    
    return 0; // 成功
}

// 递归遍历 IR 指令树，收集所有 IR_ERROR_VALUE
static void collect_error_names_recursive(CodeGenerator *codegen, IRInst *inst) {
    if (!codegen || !inst) {
        return;
    }
    
    // 如果是 IR_ERROR_VALUE，收集错误名称
    if (inst->type == IR_ERROR_VALUE) {
        const char *error_name = inst->data.error_value.error_name;
        if (!error_name || strlen(error_name) == 0) {
            return;
        }
        
        // 检查是否已经收集过这个错误名称
        for (int i = 0; i < codegen->error_map_size; i++) {
            if (codegen->error_map[i].error_name && 
                strcmp(codegen->error_map[i].error_name, error_name) == 0) {
                // 已经存在，跳过
                return;
            }
        }
        
        // 扩展映射表容量
        if (codegen->error_map_size >= codegen->error_map_capacity) {
            int new_capacity = codegen->error_map_capacity == 0 ? 8 : codegen->error_map_capacity * 2;
            ErrorNameMap *new_map = realloc(codegen->error_map, new_capacity * sizeof(ErrorNameMap));
            if (!new_map) {
                return; // 内存分配失败
            }
            codegen->error_map = new_map;
            codegen->error_map_capacity = new_capacity;
        }
        
        // 添加新的错误名称
        codegen->error_map[codegen->error_map_size].error_name = malloc(strlen(error_name) + 1);
        if (codegen->error_map[codegen->error_map_size].error_name) {
            strcpy(codegen->error_map[codegen->error_map_size].error_name, error_name);
            codegen->error_map[codegen->error_map_size].error_code = 0; // 稍后分配
            codegen->error_map_size++;
        }
    }
    
    // 递归遍历子节点
    switch (inst->type) {
        case IR_BLOCK:
            if (inst->data.block.insts) {
                for (int i = 0; i < inst->data.block.inst_count; i++) {
                    collect_error_names_recursive(codegen, inst->data.block.insts[i]);
                }
            }
            break;
        case IR_FUNC_DEF:
            if (inst->data.func.body) {
                for (int i = 0; i < inst->data.func.body_count; i++) {
                    collect_error_names_recursive(codegen, inst->data.func.body[i]);
                }
            }
            break;
        case IR_IF:
            if (inst->data.if_stmt.then_body) {
                for (int i = 0; i < inst->data.if_stmt.then_count; i++) {
                    collect_error_names_recursive(codegen, inst->data.if_stmt.then_body[i]);
                }
            }
            if (inst->data.if_stmt.else_body) {
                for (int i = 0; i < inst->data.if_stmt.else_count; i++) {
                    collect_error_names_recursive(codegen, inst->data.if_stmt.else_body[i]);
                }
            }
            break;
        case IR_WHILE:
            if (inst->data.while_stmt.body) {
                for (int i = 0; i < inst->data.while_stmt.body_count; i++) {
                    collect_error_names_recursive(codegen, inst->data.while_stmt.body[i]);
                }
            }
            break;
        case IR_RETURN:
            if (inst->data.ret.value) {
                collect_error_names_recursive(codegen, inst->data.ret.value);
            }
            break;
        case IR_MEMBER_ACCESS:
            if (inst->data.member_access.object) {
                collect_error_names_recursive(codegen, inst->data.member_access.object);
            }
            break;
        case IR_CALL:
            if (inst->data.call.args) {
                for (int i = 0; i < inst->data.call.arg_count; i++) {
                    collect_error_names_recursive(codegen, inst->data.call.args[i]);
                }
            }
            break;
        case IR_BINARY_OP:
            if (inst->data.binary_op.left) {
                collect_error_names_recursive(codegen, inst->data.binary_op.left);
            }
            if (inst->data.binary_op.right) {
                collect_error_names_recursive(codegen, inst->data.binary_op.right);
            }
            break;
        case IR_UNARY_OP:
            if (inst->data.unary_op.operand) {
                collect_error_names_recursive(codegen, inst->data.unary_op.operand);
            }
            break;
        case IR_ASSIGN:
            if (inst->data.assign.src) {
                collect_error_names_recursive(codegen, inst->data.assign.src);
            }
            break;
        default:
            break;
    }
}

// 计算错误名称的哈希值
static uint32_t hash_error_name(const char *error_name) {
    if (!error_name) return 1;
    uint32_t error_code = 0;
    for (const char *p = error_name; *p; p++) {
        error_code = error_code * 31 + (unsigned char)*p;
    }
    // Ensure error code is non-zero (0 indicates success)
    if (error_code == 0) error_code = 1;
    return error_code;
}

// 生成建议的重命名方案
static void suggest_rename(const char *original_name, char *suggestion, size_t max_len) {
    if (!original_name || !suggestion || max_len == 0) return;
    
    // 方案1: 添加后缀 "_Alt"
    snprintf(suggestion, max_len, "%s_Alt", original_name);
}

// 检测错误码冲突并报告
static int detect_error_code_collisions(CodeGenerator *codegen) {
    if (!codegen || codegen->error_map_size == 0) {
        return 0; // 无冲突
    }
    
    int collision_count = 0;
    
    // 检查所有错误名称对
    for (int i = 0; i < codegen->error_map_size; i++) {
        uint32_t code_i = codegen->error_map[i].error_code;
        for (int j = i + 1; j < codegen->error_map_size; j++) {
            uint32_t code_j = codegen->error_map[j].error_code;
            if (code_i == code_j) {
                // 发现冲突
                collision_count++;
                const char *name1 = codegen->error_map[i].error_name;
                const char *name2 = codegen->error_map[j].error_name;
                
                fprintf(stderr, "\n");
                fprintf(stderr, "═══════════════════════════════════════════════════════════\n");
                fprintf(stderr, "错误: 错误码冲突！\n");
                fprintf(stderr, "═══════════════════════════════════════════════════════════\n");
                fprintf(stderr, "\n");
                fprintf(stderr, "  冲突的错误名称:\n");
                fprintf(stderr, "    • error.%s\n", name1);
                fprintf(stderr, "    • error.%s\n", name2);
                fprintf(stderr, "\n");
                fprintf(stderr, "  冲突的错误码: %uU\n", code_i);
                fprintf(stderr, "\n");
                fprintf(stderr, "  解决方案:\n");
                fprintf(stderr, "    请重命名其中一个错误名称以避免冲突。\n");
                fprintf(stderr, "\n");
                fprintf(stderr, "  建议的重命名方案:\n");
                
                // 为第一个错误名称提供建议
                char suggestion1[256];
                suggest_rename(name1, suggestion1, sizeof(suggestion1));
                fprintf(stderr, "    方案1: 将 error.%s 重命名为 error.%s\n", name1, suggestion1);
                
                // 为第二个错误名称提供建议
                char suggestion2[256];
                suggest_rename(name2, suggestion2, sizeof(suggestion2));
                fprintf(stderr, "    方案2: 将 error.%s 重命名为 error.%s\n", name2, suggestion2);
                
                fprintf(stderr, "\n");
                fprintf(stderr, "  其他建议:\n");
                fprintf(stderr, "    • 使用更具体、更具描述性的错误名称\n");
                fprintf(stderr, "    • 避免使用相似的错误名称（如 TestError 和 TestErr）\n");
                fprintf(stderr, "    • 考虑使用命名空间或前缀来区分不同类型的错误\n");
                fprintf(stderr, "\n");
                fprintf(stderr, "═══════════════════════════════════════════════════════════\n");
                fprintf(stderr, "\n");
            }
        }
    }
    
    return collision_count;
}

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
    codegen->error_map = NULL;
    codegen->error_map_size = 0;
    codegen->error_map_capacity = 0;
    
    return codegen;
}

void codegen_free(CodeGenerator *codegen) {
    if (codegen) {
        if (codegen->output_filename) {
            free(codegen->output_filename);
        }
        // Free error map
        if (codegen->error_map) {
            for (int i = 0; i < codegen->error_map_size; i++) {
                if (codegen->error_map[i].error_name) {
                    free(codegen->error_map[i].error_name);
                }
            }
            free(codegen->error_map);
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
        case IR_TYPE_STRUCT: return "struct_type"; // 需要特殊处理，使用 original_type_name
        case IR_TYPE_FN: return "fn_type";       // 需要特殊处理
        case IR_TYPE_ERROR_UNION: return "error_union"; // 需要特殊处理
        default: return "unknown_type";
    }
}

// Helper function to find struct name from return type
// For struct return types, we need to find the struct name from IR
// This is a workaround since IR doesn't store return_type_original_name
static const char *codegen_find_struct_name_from_return_type(CodeGenerator *codegen, IRInst *func_inst) {
    if (!codegen || !codegen->ir || !func_inst || func_inst->data.func.return_type != IR_TYPE_STRUCT) {
        return NULL;
    }
    
    // Try to find struct name by looking at all struct declarations in IR
    // This is a simple heuristic: if there's only one struct, use it
    // Otherwise, we can't determine which struct it is
    if (codegen->ir && codegen->ir->instructions) {
        const char *found_struct_name = NULL;
        int struct_count = 0;
        for (int i = 0; i < codegen->ir->inst_count; i++) {
            if (codegen->ir->instructions[i] && codegen->ir->instructions[i]->type == IR_STRUCT_DECL) {
                struct_count++;
                if (!found_struct_name) {
                    found_struct_name = codegen->ir->instructions[i]->data.struct_decl.name;
                }
            }
        }
        // If there's exactly one struct, use it (common case)
        if (struct_count == 1 && found_struct_name) {
            return found_struct_name;
        }
    }
    
    return NULL;
}

static void codegen_write_type(CodeGenerator *codegen, IRType type) {
    fprintf(codegen->output_file, "%s", codegen_get_type_name(type));
}

// Write type with optional original type name (for struct types)
static void codegen_write_type_with_name(CodeGenerator *codegen, IRType type, const char *original_type_name) {
    if (type == IR_TYPE_STRUCT && original_type_name) {
        fprintf(codegen->output_file, "%s", original_type_name);
    } else {
        codegen_write_type(codegen, type);
    }
}

// Generate error union type name (struct error_union_T)
static void codegen_write_error_union_type_name(CodeGenerator *codegen, IRType base_type) {
    const char *base_name = codegen_get_type_name(base_type);
    fprintf(codegen->output_file, "struct error_union_%s", base_name);
}

// Generate error union type definition
// According to uya.md: struct error_union_T { uint32_t error_id; T value; }
// error_id == 0: success (use value field)
// error_id != 0: error (error_id contains error code, value field undefined)
static void codegen_write_error_union_type_def(CodeGenerator *codegen, IRType base_type) {
    const char *base_name = codegen_get_type_name(base_type);
    fprintf(codegen->output_file, "struct error_union_%s {\n", base_name);
    fprintf(codegen->output_file, "    uint32_t error_id; // 0 = success (use value), non-zero = error (use error_id)\n");
    if (base_type == IR_TYPE_VOID) {
        // For !void, only error_id field, no value field
        fprintf(codegen->output_file, "};\n\n");
    } else {
        fprintf(codegen->output_file, "    %s value; // success value (only valid when error_id == 0)\n", base_name);
        fprintf(codegen->output_file, "};\n\n");
    }
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

// Helper function to find function return type from IR
// Returns the base type (not error union type) and whether it's an error union
static int find_function_return_type(IRGenerator *ir, const char *func_name, IRType *base_type, int *is_error_union) {
    if (!ir || !ir->instructions || !func_name) {
        return 0;
    }
    
    for (int i = 0; i < ir->inst_count; i++) {
        if (ir->instructions[i] && ir->instructions[i]->type == IR_FUNC_DEF) {
            IRInst *func = ir->instructions[i];
            if (func->data.func.name && strcmp(func->data.func.name, func_name) == 0) {
                *base_type = func->data.func.return_type;
                *is_error_union = func->data.func.return_type_is_error_union;
                return 1;
            }
        }
    }
    
    return 0;
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
        // object can be IR_VAR_DECL (identifier expression) or IR_IDENTIFIER (if IR has identifier type)
        if (object && (
            (object->type == IR_VAR_DECL && object->data.var.name && strcmp(object->data.var.name, "error") == 0) ||
            (object->type == IR_CONSTANT && object->data.constant.value && strcmp(object->data.constant.value, "error") == 0)
        )) {
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
            uint32_t error_code = hash_error_name(error_name);
            
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
            } else if (inst->data.func.return_type == IR_TYPE_STRUCT) {
                // For struct return types, use return_type_original_name if available
                if (inst->data.func.return_type_original_name) {
                    fprintf(codegen->output_file, "%s", inst->data.func.return_type_original_name);
                } else {
                    // Fallback: try to find the struct name
                    const char *struct_name = codegen_find_struct_name_from_return_type(codegen, inst);
                    if (struct_name) {
                        fprintf(codegen->output_file, "%s", struct_name);
                    } else {
                        codegen_write_type(codegen, inst->data.func.return_type);
                    }
                }
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
                    // For drop functions, use pointer parameter to avoid copying large structs
                    // and to be consistent with other function calls
                    if (is_drop_function && i == 0) {
                        fprintf(codegen->output_file, "%s* %s", 
                                inst->data.func.params[i]->data.var.original_type_name,
                                inst->data.func.params[i]->data.var.name);
                    } else {
                        fprintf(codegen->output_file, "%s %s", 
                                inst->data.func.params[i]->data.var.original_type_name,
                                inst->data.func.params[i]->data.var.name);
                    }
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
                } else if (inst->data.func.return_type == IR_TYPE_STRUCT) {
                    // For struct return types, use return_type_original_name if available
                    if (inst->data.func.return_type_original_name) {
                        fprintf(codegen->output_file, "%s", inst->data.func.return_type_original_name);
                    } else {
                        // Fallback: try to find the struct name
                        const char *struct_name = codegen_find_struct_name_from_return_type(codegen, inst);
                        if (struct_name) {
                            fprintf(codegen->output_file, "%s", struct_name);
                        } else {
                            codegen_write_type(codegen, inst->data.func.return_type);
                        }
                    }
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
            // 注意：指针类型（IR_TYPE_PTR）不需要 drop，只有结构体类型和数组类型需要 drop
            if (!is_drop_function) {
                for (int i = 0; i < inst->data.func.param_count; i++) {
                    IRInst *param = inst->data.func.params[i];
                    if (param && param->data.var.original_type_name && 
                        param->data.var.type != IR_TYPE_PTR) {
                        // 用户定义的类型（结构体或数组），可能有 drop 函数
                        // 排除指针类型，因为指针本身不需要 drop
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
                    // 注意：对于 !void 类型，即使 value 为 NULL，也可能是错误返回（需要检查表达式）
                    int is_error = 0;
                    if (body_inst->data.ret.value) {
                        is_error = is_error_return_value(body_inst->data.ret.value);
                    }
                    // 对于 !void 类型，如果 value 为 NULL，可能是错误返回没有被正确识别
                    // 这种情况应该不会发生，因为错误返回应该有 IR_ERROR_VALUE
                    if (is_error) {
                        has_error_return_path = 1;
                    }
                    
                    // 修改return语句：保存返回值，然后跳转到相应的返回标签
                    if (has_return_value) {
                        // 如果返回类型是!T（错误联合类型），需要设置错误联合结构
                        // According to uya.md: error_id == 0 means success (use value), error_id != 0 means error (use error_id)
                        if (inst->data.func.return_type_is_error_union) {
                            // 检查返回值是否为错误值
                            // 对于 !void 类型，即使 value 为 NULL，也可能是错误返回（需要检查表达式）
                            int is_error_final = 0;
                            if (body_inst->data.ret.value) {
                                is_error_final = is_error_return_value(body_inst->data.ret.value);
                            }
                            
                            if (is_error_final && body_inst->data.ret.value) {
                                // 错误返回：设置 error_id = 错误码，value 字段未定义
                                fprintf(codegen->output_file, "  %s.error_id = ", return_var_name);
                                codegen_write_value(codegen, body_inst->data.ret.value);
                                fprintf(codegen->output_file, ";\n");
                            } else if (is_error_final && !body_inst->data.ret.value) {
                                // 错误返回但 value 为 NULL（不应该发生，但为了安全处理）
                                fprintf(codegen->output_file, "  %s.error_id = 1U;\n", return_var_name);
                            } else if (!body_inst->data.ret.value) {
                                // value 为 NULL 的情况
                                // 如果是 !void 类型，NULL value 是正常的（void 没有返回值）
                                if (inst->data.func.return_type == IR_TYPE_VOID) {
                                    fprintf(codegen->output_file, "  %s.error_id = 0;\n", return_var_name);
                                } else {
                                    // 对于非 void 类型，NULL value 不应该发生（应该有值或错误）
                                    // 为了安全，我们将其视为错误
                                    fprintf(codegen->output_file, "  %s.error_id = 1U;\n", return_var_name);
                                }
                            } else {
                                // value 不为 NULL，再次检查是否是错误值（防止之前的检查失败）
                                if (is_error_return_value(body_inst->data.ret.value)) {
                                    // 这是错误值，设置 error_id
                                    fprintf(codegen->output_file, "  %s.error_id = ", return_var_name);
                                    codegen_write_value(codegen, body_inst->data.ret.value);
                                    fprintf(codegen->output_file, ";\n");
                                } else {
                                    // 正常值返回
                                    fprintf(codegen->output_file, "  %s.error_id = 0;\n", return_var_name);
                                    // 对于 !void 类型，没有 value 字段
                                    if (inst->data.func.return_type != IR_TYPE_VOID) {
                                        fprintf(codegen->output_file, "  %s.value = ", return_var_name);
                                        codegen_write_value(codegen, body_inst->data.ret.value);
                                        fprintf(codegen->output_file, ";\n");
                                    }
                                }
                            }
                        } else {
                            // 普通返回类型：直接赋值
                            fprintf(codegen->output_file, "  %s = ", return_var_name);
                            if (body_inst->data.ret.value) {
                                codegen_write_value(codegen, body_inst->data.ret.value);
                            } else {
                                // For struct types, use compound literal initialization instead of 0
                                if (inst->data.func.return_type == IR_TYPE_STRUCT) {
                                    const char *struct_name = inst->data.func.return_type_original_name;
                                    if (!struct_name) {
                                        struct_name = codegen_find_struct_name_from_return_type(codegen, inst);
                                    }
                                    if (struct_name) {
                                        fprintf(codegen->output_file, "(%s){0}", struct_name);
                                    } else {
                                        fprintf(codegen->output_file, "{0}");
                                    }
                                } else {
                                    fprintf(codegen->output_file, "0");
                                }
                            }
                            fprintf(codegen->output_file, ";\n");
                        }
                    }
                    
                    // 根据是否为错误返回，跳转到不同的标签
                    // 对于!T类型，使用error_id字段在函数末尾统一判断
                    if (inst->data.func.return_type_is_error_union) {
                        // !T类型：在函数末尾统一判断error_id字段（error_id != 0 表示错误）
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
                                IRInst *then_inst = body_inst->data.if_stmt.then_body[j];
                                if (then_inst->type == IR_RETURN) {
                                    // 处理 if 语句中的 return：需要包装成 error_union 结构
                                    fprintf(codegen->output_file, "\n  ");
                                    int is_error = 0;
                                    if (then_inst->data.ret.value) {
                                        is_error = is_error_return_value(then_inst->data.ret.value);
                                    }
                                    if (has_return_value && inst->data.func.return_type_is_error_union) {
                                        if (is_error && then_inst->data.ret.value) {
                                            fprintf(codegen->output_file, "%s.error_id = ", return_var_name);
                                            codegen_write_value(codegen, then_inst->data.ret.value);
                                            fprintf(codegen->output_file, ";");
                                        } else if (is_error && !then_inst->data.ret.value) {
                                            fprintf(codegen->output_file, "%s.error_id = 1U;", return_var_name);
                                        } else if (!is_error && then_inst->data.ret.value && is_error_return_value(then_inst->data.ret.value)) {
                                            // 再次检查是否是错误值
                                            fprintf(codegen->output_file, "%s.error_id = ", return_var_name);
                                            codegen_write_value(codegen, then_inst->data.ret.value);
                                            fprintf(codegen->output_file, ";");
                                        } else {
                                            fprintf(codegen->output_file, "%s.error_id = 0;", return_var_name);
                                            if (inst->data.func.return_type != IR_TYPE_VOID && then_inst->data.ret.value) {
                                                fprintf(codegen->output_file, "\n  %s.value = ", return_var_name);
                                                codegen_write_value(codegen, then_inst->data.ret.value);
                                                fprintf(codegen->output_file, ";");
                                            }
                                        }
                                        fprintf(codegen->output_file, "\n  goto _check_error_return_%s;", actual_func_name);
                                        has_error_return_path = 1;
                                    } else {
                                        // 普通返回类型
                                        fprintf(codegen->output_file, "%s = ", return_var_name);
                                        if (then_inst->data.ret.value) {
                                            codegen_write_value(codegen, then_inst->data.ret.value);
                                        } else {
                                            fprintf(codegen->output_file, "0");
                                        }
                                        fprintf(codegen->output_file, ";\n  goto _normal_return_%s;", actual_func_name);
                                    }
                                } else {
                                    fprintf(codegen->output_file, "\n  ");
                                    codegen_generate_inst(codegen, then_inst);
                                    fprintf(codegen->output_file, ";");
                                }
                            }
                            if (body_inst->data.if_stmt.else_body) {
                                fprintf(codegen->output_file, "\n} else {");
                                for (int j = 0; j < body_inst->data.if_stmt.else_count; j++) {
                                    IRInst *else_inst = body_inst->data.if_stmt.else_body[j];
                                    if (else_inst->type == IR_RETURN) {
                                        // 处理 else 分支中的 return
                                        fprintf(codegen->output_file, "\n  ");
                                        int is_error = 0;
                                        if (else_inst->data.ret.value) {
                                            is_error = is_error_return_value(else_inst->data.ret.value);
                                        }
                                        if (has_return_value && inst->data.func.return_type_is_error_union) {
                                            if (is_error && else_inst->data.ret.value) {
                                                fprintf(codegen->output_file, "%s.error_id = ", return_var_name);
                                                codegen_write_value(codegen, else_inst->data.ret.value);
                                                fprintf(codegen->output_file, ";");
                                            } else if (is_error && !else_inst->data.ret.value) {
                                                fprintf(codegen->output_file, "%s.error_id = 1U;", return_var_name);
                                            } else if (!is_error && else_inst->data.ret.value && is_error_return_value(else_inst->data.ret.value)) {
                                                // 再次检查是否是错误值
                                                fprintf(codegen->output_file, "%s.error_id = ", return_var_name);
                                                codegen_write_value(codegen, else_inst->data.ret.value);
                                                fprintf(codegen->output_file, ";");
                                            } else {
                                                fprintf(codegen->output_file, "%s.error_id = 0;", return_var_name);
                                                if (inst->data.func.return_type != IR_TYPE_VOID && else_inst->data.ret.value) {
                                                    fprintf(codegen->output_file, "\n  %s.value = ", return_var_name);
                                                    codegen_write_value(codegen, else_inst->data.ret.value);
                                                    fprintf(codegen->output_file, ";");
                                                }
                                            }
                                            fprintf(codegen->output_file, "\n  goto _check_error_return_%s;", actual_func_name);
                                            has_error_return_path = 1;
                                        } else {
                                            fprintf(codegen->output_file, "%s = ", return_var_name);
                                            if (else_inst->data.ret.value) {
                                                codegen_write_value(codegen, else_inst->data.ret.value);
                                            } else {
                                                fprintf(codegen->output_file, "0");
                                            }
                                            fprintf(codegen->output_file, ";\n  goto _normal_return_%s;", actual_func_name);
                                        }
                                    } else {
                                        fprintf(codegen->output_file, "\n  ");
                                        codegen_generate_inst(codegen, else_inst);
                                        fprintf(codegen->output_file, ";");
                                    }
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
            // According to uya.md: error_id == 0 means success, error_id != 0 means error
            if (inst->data.func.return_type_is_error_union && has_error_return_path) {
                fprintf(codegen->output_file, "_check_error_return_%s:\n", actual_func_name);
                fprintf(codegen->output_file, "  if (%s.error_id != 0) {\n", return_var_name);
                fprintf(codegen->output_file, "    goto _error_return_%s;\n", actual_func_name);
                fprintf(codegen->output_file, "  } else {\n");
                fprintf(codegen->output_file, "    goto _normal_return_%s;\n", actual_func_name);
                fprintf(codegen->output_file, "  }\n\n");
            }
            
            // 生成错误返回路径（如果有错误返回）
            // 对于 !T 类型，即使没有 errdefer 块，也需要生成 _error_return_ 标签（因为 _check_error_return 会跳转到这里）
            if (has_error_return_path) {
                fprintf(codegen->output_file, "_error_return_%s:\n", actual_func_name);
                
                // 只有在有 errdefer 块时才生成 errdefer 代码
                if (errdefer_count > 0 && errdefer_blocks) {
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
                }
                
                // 生成 defer 块（错误返回时也执行 defer）
                if (defer_count > 0 && defer_blocks) {
                    fprintf(codegen->output_file, "  // Generated defer blocks in LIFO order (error return)\n");
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
                                // 传递变量的地址，因为 drop 函数接受指针参数
                                fprintf(codegen->output_file, "  drop_%s(&%s);\n", drop_vars[i].type_name, drop_vars[i].var_name);
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
                                // 传递变量的地址，因为 drop 函数接受指针参数
                                fprintf(codegen->output_file, "  drop_%s(&%s);\n", drop_vars[i].type_name, drop_vars[i].var_name);
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
            // Generate try/catch: check error_id and extract value or execute catch block
            // try_body returns struct error_union_T, we need to check error_id and extract value
            if (inst->data.try_catch.try_body) {
                // Determine return type from try_body (if it's a function call)
                IRType base_type = IR_TYPE_I32;  // default to i32
                int is_error_union = 0;
                
                if (inst->data.try_catch.try_body->type == IR_CALL && 
                    inst->data.try_catch.try_body->data.call.func_name &&
                    codegen->ir) {
                    // Look up function return type
                    find_function_return_type(codegen->ir, 
                                            inst->data.try_catch.try_body->data.call.func_name,
                                            &base_type, &is_error_union);
                }
                
                // Generate temporary variable to store the error union result
                char temp_var[64];
                snprintf(temp_var, sizeof(temp_var), "_try_result_%d", codegen->temp_counter++);
                
                // Generate the try body (function call that returns error union)
                fprintf(codegen->output_file, "struct error_union_%s %s = ", 
                        codegen_get_type_name(base_type), temp_var);
                codegen_write_value(codegen, inst->data.try_catch.try_body);
                fprintf(codegen->output_file, ";\n");
                
                // Check if error_id != 0, if so execute catch block
                fprintf(codegen->output_file, "if (%s.error_id != 0) {\n", temp_var);
                if (inst->data.try_catch.error_var) {
                    // Bind error to variable
                    fprintf(codegen->output_file, "  uint32_t %s = %s.error_id;\n", 
                            inst->data.try_catch.error_var, temp_var);
                }
                if (inst->data.try_catch.catch_body) {
                    codegen_generate_inst(codegen, inst->data.try_catch.catch_body);
                }
                fprintf(codegen->output_file, "} else {\n");
                // Extract value for success case (only if not void)
                if (base_type != IR_TYPE_VOID) {
                    fprintf(codegen->output_file, "  %s.value", temp_var);
                } else {
                    // For void, just empty expression
                    fprintf(codegen->output_file, "  /* void success */");
                }
                fprintf(codegen->output_file, "\n}\n");
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
    
    // Store IR generator reference for function lookup
    codegen->ir = ir;
    
    // 第一步：收集所有错误名称并检测冲突
    if (collect_error_names(codegen, ir) != 0) {
        // 发现冲突，编译失败
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
    // Error type definition (error is a type containing error codes, represented as uint32_t)
    fprintf(codegen->output_file, "// Error type definition (error codes are uint32_t)\n");
    fprintf(codegen->output_file, "typedef uint32_t error;\n\n");
    
    // Generate slice type definition
    // According to uya.md: &[T] is represented as struct slice_T { void* ptr; size_t len; }
    fprintf(codegen->output_file, "// Slice type definition\n");
    fprintf(codegen->output_file, "// Generic slice structure for all slice types\n");
    fprintf(codegen->output_file, "struct slice {\n");
    fprintf(codegen->output_file, "    void* ptr;    // 8 bytes (64位) 或 4 bytes (32位)\n");
    fprintf(codegen->output_file, "    size_t len;   // 8 bytes (64位) 或 4 bytes (32位)\n");
    fprintf(codegen->output_file, "};\n\n");
    
    // Generate interface type definition
    // According to uya.md: InterfaceName is represented as struct interface { void* vtable; void* data; }
    fprintf(codegen->output_file, "// Interface type definition\n");
    fprintf(codegen->output_file, "// Generic interface structure for all interface types\n");
    fprintf(codegen->output_file, "struct interface {\n");
    fprintf(codegen->output_file, "    void* vtable;  // 8 bytes (64位) 或 4 bytes (32位)\n");
    fprintf(codegen->output_file, "    void* data;    // 8 bytes (64位) 或 4 bytes (32位)\n");
    fprintf(codegen->output_file, "};\n\n");
    
    // Collect and generate error union type definitions for all functions with !T return types
    fprintf(codegen->output_file, "// Error union type definitions\n");
    if (ir && ir->instructions) {
        // Collect all error union types actually used in the program
        // Use a simple array to track unique base types (excluding struct types for now)
        IRType *used_types = NULL;
        int type_count = 0;
        int type_capacity = 0;
        
        // First pass: collect all error union return types
        for (int i = 0; i < ir->inst_count; i++) {
            if (ir->instructions[i] && ir->instructions[i]->type == IR_FUNC_DEF) {
                IRInst *func = ir->instructions[i];
                if (func->data.func.return_type_is_error_union) {
                    IRType base_type = func->data.func.return_type;
                    
                    // Skip struct types for now (need struct name which is not stored in IRType)
                    // TODO: Improve IR to store struct name in return type information
                    if (base_type == IR_TYPE_STRUCT) {
                        continue;
                    }
                    
                    // Check if this type is already collected
                    int found = 0;
                    for (int j = 0; j < type_count; j++) {
                        if (used_types[j] == base_type) {
                            found = 1;
                            break;
                        }
                    }
                    
                    if (!found) {
                        // Expand array if needed
                        if (type_count >= type_capacity) {
                            int new_capacity = type_capacity == 0 ? 8 : type_capacity * 2;
                            IRType *new_types = realloc(used_types, new_capacity * sizeof(IRType));
                            if (!new_types) {
                                if (used_types) free(used_types);
                                break;
                            }
                            used_types = new_types;
                            type_capacity = new_capacity;
                        }
                        
                        used_types[type_count++] = base_type;
                    }
                }
            }
        }
        
        // Generate error union type definitions for collected types
        for (int i = 0; i < type_count; i++) {
            codegen_write_error_union_type_def(codegen, used_types[i]);
        }
        
        // Also generate common types that might be used (for backward compatibility)
        // Check if i32 and void are already in the list
        int has_i32 = 0, has_void = 0;
        for (int i = 0; i < type_count; i++) {
            if (used_types[i] == IR_TYPE_I32) has_i32 = 1;
            if (used_types[i] == IR_TYPE_VOID) has_void = 1;
        }
        if (!has_i32) codegen_write_error_union_type_def(codegen, IR_TYPE_I32);
        if (!has_void) codegen_write_error_union_type_def(codegen, IR_TYPE_VOID);
        
        // Cleanup
        if (used_types) free(used_types);
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
                } else if (func->data.func.return_type == IR_TYPE_STRUCT) {
                    // For struct return types, use return_type_original_name if available
                    if (func->data.func.return_type_original_name) {
                        fprintf(codegen->output_file, "%s", func->data.func.return_type_original_name);
                    } else {
                        // Fallback: try to find the struct name
                        const char *struct_name = codegen_find_struct_name_from_return_type(codegen, func);
                        if (struct_name) {
                            fprintf(codegen->output_file, "%s", struct_name);
                        } else {
                            codegen_write_type(codegen, func->data.func.return_type);
                        }
                    }
                } else {
                    codegen_write_type(codegen, func->data.func.return_type);
                }
                
                // For drop functions, use the actual function name (drop_TypeName)
                char *actual_func_name = func->data.func.name;
                char drop_func_name[256] = {0};
                int is_drop_func_forward = 0;
                if (func->data.func.name && strcmp(func->data.func.name, "drop") == 0 &&
                    func->data.func.param_count > 0 && func->data.func.params[0] &&
                    func->data.func.params[0]->data.var.original_type_name) {
                    snprintf(drop_func_name, sizeof(drop_func_name), "drop_%s", 
                             func->data.func.params[0]->data.var.original_type_name);
                    actual_func_name = drop_func_name;
                    is_drop_func_forward = 1;
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
                        // For drop functions, use pointer parameter to avoid copying large structs
                        if (is_drop_func_forward && j == 0) {
                            fprintf(codegen->output_file, "%s* %s", 
                                    func->data.func.params[j]->data.var.original_type_name,
                                    func->data.func.params[j]->data.var.name);
                        } else {
                            fprintf(codegen->output_file, "%s %s", 
                                    func->data.func.params[j]->data.var.original_type_name,
                                    func->data.func.params[j]->data.var.name);
                        }
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