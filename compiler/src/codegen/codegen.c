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
        case IR_TYPE_BOOL: return "uint8_t";  // C99中用uint8_t表示bool
        case IR_TYPE_BYTE: return "uint8_t";
        case IR_TYPE_VOID: return "void";
        case IR_TYPE_PTR: return "void*";
        case IR_TYPE_ARRAY: return "array_type";  // 需要特殊处理
        case IR_TYPE_STRUCT: return "struct_type"; // 需要特殊处理
        case IR_TYPE_FN: return "fn_type";       // 需要特殊处理
        case IR_TYPE_ERROR_UNION: return "error_union"; // 需要特殊处理
        default: return "unknown_type";
    }
}

static void codegen_write_type(CodeGenerator *codegen, IRType type) {
    fprintf(codegen->output_file, "%s", codegen_get_type_name(type));
}

static void codegen_write_value(CodeGenerator *codegen, IRInst *inst) {
    if (!inst) {
        fprintf(codegen->output_file, "0");
        return;
    }

    switch (inst->type) {
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
                default: fprintf(codegen->output_file, " UNKNOWN_OP "); break;
            }

            codegen_write_value(codegen, inst->data.binary_op.right);
            fprintf(codegen->output_file, ")");
            break;

        case IR_CALL:
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
            // 生成函数定义
            codegen_write_type(codegen, inst->data.func.return_type);
            fprintf(codegen->output_file, " %s(", inst->data.func.name);
            
            // 参数
            for (int i = 0; i < inst->data.func.param_count; i++) {
                if (i > 0) fprintf(codegen->output_file, ", ");
                codegen_write_type(codegen, inst->data.func.params[i]->data.var.type);
                fprintf(codegen->output_file, " %s", inst->data.func.params[i]->data.var.name);
            }
            fprintf(codegen->output_file, ") {\n");
            
            // 函数体
            for (int i = 0; i < inst->data.func.body_count; i++) {
                fprintf(codegen->output_file, "  ");
                codegen_generate_inst(codegen, inst->data.func.body[i]);
                fprintf(codegen->output_file, ";\n");
            }
            
            fprintf(codegen->output_file, "}\n\n");
            break;
            
        case IR_VAR_DECL:
            codegen_write_type(codegen, inst->data.var.type);
            fprintf(codegen->output_file, " %s", inst->data.var.name);
            if (inst->data.var.init) {
                fprintf(codegen->output_file, " = ");
                codegen_write_value(codegen, inst->data.var.init);
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
            // For loops are transformed to while loops in the IR
            // The actual transformation happens during IR generation
            // Here we generate the appropriate C code for the for loop
            fprintf(codegen->output_file, "for (");

            // For now, we'll generate a simplified version
            // In a full implementation, we'd generate the proper iterator code
            if (inst->data.for_stmt.iterable) {
                // This would be more complex in a real implementation
                // For now, just show a placeholder
                fprintf(codegen->output_file, "/* for loop */");
            }

            fprintf(codegen->output_file, ") {\n");

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
    fprintf(codegen->output_file, "#include <stddef.h>\n\n");
    
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