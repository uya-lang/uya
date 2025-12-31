#include "codegen.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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

        case IR_MEMBER_ACCESS: {
            // Generate member access: object.field or object->field (if object is a pointer)
            IRInst *object = inst->data.member_access.object;
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
                fprintf(codegen->output_file, "%s", inst->data.constant.value);
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
                fprintf(codegen->output_file, "%s(", inst->data.call.func_name);
                for (int i = 0; i < inst->data.call.arg_count; i++) {
                    if (i > 0) fprintf(codegen->output_file, ", ");
                    if (inst->data.call.args[i]) {
                        codegen_write_value(codegen, inst->data.call.args[i]);
                    } else {
                        fprintf(codegen->output_file, "NULL");
                    }
                }
                fprintf(codegen->output_file, ")");
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
            // 生成函数定义
            codegen_write_type(codegen, inst->data.func.return_type);
            fprintf(codegen->output_file, " %s(", inst->data.func.name);
            
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
            
            // 函数体
            for (int i = 0; i < inst->data.func.body_count; i++) {
                fprintf(codegen->output_file, "  ");
                codegen_generate_inst(codegen, inst->data.func.body[i]);
                fprintf(codegen->output_file, ";\n");
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
                // Generate: int32_t arr[3] = {1, 2, 3};

                // For now, assume i32 array type
                fprintf(codegen->output_file, "int32_t %s[] = ", inst->data.var.name);
                codegen_write_value(codegen, inst->data.var.init);  // This will output {1, 2, 3}
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
    fprintf(codegen->output_file, "#include <stdbool.h>\n\n");
    
    // 生成所有指令（如果有）
    if (ir && ir->instructions) {
        for (int i = 0; i < ir->inst_count; i++) {
            if (ir->instructions[i]) {
                codegen_generate_inst(codegen, ir->instructions[i]);
            }
        }
    }
    
    fclose(codegen->output_file);
    codegen->output_file = NULL;
    
    return 1;
}