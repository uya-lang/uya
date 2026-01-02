#include "ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

IRGenerator *irgenerator_new() {
    IRGenerator *gen = malloc(sizeof(IRGenerator));
    if (!gen) {
        return NULL;
    }
    
    gen->instructions = malloc(16 * sizeof(IRInst*));
    if (!gen->instructions) {
        free(gen);
        return NULL;
    }
    
    gen->inst_count = 0;
    gen->inst_capacity = 16;
    gen->current_id = 0;
    
    return gen;
}

void irgenerator_free(IRGenerator *gen) {
    if (gen) {
        if (gen->instructions) {
            for (int i = 0; i < gen->inst_count; i++) {
                irinst_free(gen->instructions[i]);
            }
            free(gen->instructions);
        }
        free(gen);
    }
}

IRInst *irinst_new(IRInstType type) {
    IRInst *inst = malloc(sizeof(IRInst));
    if (!inst) {
        return NULL;
    }
    
    inst->type = type;
    inst->id = -1;  // 未分配ID
    
    // 初始化数据为0
    memset(&inst->data, 0, sizeof(inst->data));
    
    return inst;
}

void irinst_free(IRInst *inst) {
    if (!inst) {
        return;
    }
    
    switch (inst->type) {
        case IR_FUNC_DECL:
        case IR_FUNC_DEF:
            if (inst->data.func.name) {
                free(inst->data.func.name);
            }
            if (inst->data.func.params) {
                for (int i = 0; i < inst->data.func.param_count; i++) {
                    irinst_free(inst->data.func.params[i]);
                }
                free(inst->data.func.params);
            }
            if (inst->data.func.body) {
                for (int i = 0; i < inst->data.func.body_count; i++) {
                    irinst_free(inst->data.func.body[i]);
                }
                free(inst->data.func.body);
            }
            break;
            
        case IR_VAR_DECL:
            if (inst->data.var.name) {
                free(inst->data.var.name);
            }
            if (inst->data.var.original_type_name) {
                free(inst->data.var.original_type_name);
            }
            irinst_free(inst->data.var.init);
            break;
            
        case IR_ASSIGN:
            if (inst->data.assign.dest) {
                free(inst->data.assign.dest);
            }
            irinst_free(inst->data.assign.src);
            break;
            
        case IR_BINARY_OP:
            if (inst->data.binary_op.dest) {
                free(inst->data.binary_op.dest);
            }
            irinst_free(inst->data.binary_op.left);
            irinst_free(inst->data.binary_op.right);
            break;
            
        case IR_UNARY_OP:
            if (inst->data.unary_op.dest) {
                free(inst->data.unary_op.dest);
            }
            irinst_free(inst->data.unary_op.operand);
            break;
            
        case IR_CALL:
            if (inst->data.call.dest) {
                free(inst->data.call.dest);
            }
            if (inst->data.call.func_name) {
                free(inst->data.call.func_name);
            }
            if (inst->data.call.args) {
                for (int i = 0; i < inst->data.call.arg_count; i++) {
                    irinst_free(inst->data.call.args[i]);
                }
                free(inst->data.call.args);
            }
            break;
            
        case IR_RETURN:
            irinst_free(inst->data.ret.value);
            break;
            
        case IR_IF:
            irinst_free(inst->data.if_stmt.condition);
            if (inst->data.if_stmt.then_body) {
                for (int i = 0; i < inst->data.if_stmt.then_count; i++) {
                    irinst_free(inst->data.if_stmt.then_body[i]);
                }
                free(inst->data.if_stmt.then_body);
            }
            if (inst->data.if_stmt.else_body) {
                for (int i = 0; i < inst->data.if_stmt.else_count; i++) {
                    irinst_free(inst->data.if_stmt.else_body[i]);
                }
                free(inst->data.if_stmt.else_body);
            }
            break;
            
        case IR_WHILE:
            irinst_free(inst->data.while_stmt.condition);
            if (inst->data.while_stmt.body) {
                for (int i = 0; i < inst->data.while_stmt.body_count; i++) {
                    irinst_free(inst->data.while_stmt.body[i]);
                }
                free(inst->data.while_stmt.body);
            }
            break;
            
        case IR_BLOCK:
            if (inst->data.block.insts) {
                for (int i = 0; i < inst->data.block.inst_count; i++) {
                    irinst_free(inst->data.block.insts[i]);
                }
                free(inst->data.block.insts);
            }
            break;
            
        case IR_LOAD:
        case IR_STORE:
            if (inst->data.load.dest) {
                free(inst->data.load.dest);
            }
            if (inst->data.load.src) {
                free(inst->data.load.src);
            }
            break;
            
        case IR_CAST:
            if (inst->data.cast.dest) {
                free(inst->data.cast.dest);
            }
            irinst_free(inst->data.cast.src);
            break;
            
        case IR_ERROR_UNION:
            if (inst->data.error_union.dest) {
                free(inst->data.error_union.dest);
            }
            irinst_free(inst->data.error_union.value);
            break;
            
        case IR_TRY_CATCH:
            irinst_free(inst->data.try_catch.try_body);
            if (inst->data.try_catch.error_var) {
                free(inst->data.try_catch.error_var);
            }
            irinst_free(inst->data.try_catch.catch_body);
            break;

        case IR_STRUCT_DECL:
            if (inst->data.struct_decl.name) {
                free(inst->data.struct_decl.name);
            }
            if (inst->data.struct_decl.fields) {
                for (int i = 0; i < inst->data.struct_decl.field_count; i++) {
                    irinst_free(inst->data.struct_decl.fields[i]);
                }
                free(inst->data.struct_decl.fields);
            }
            break;

        case IR_DEFER:
            if (inst->data.defer.body) {
                for (int i = 0; i < inst->data.defer.body_count; i++) {
                    irinst_free(inst->data.defer.body[i]);
                }
                free(inst->data.defer.body);
            }
            break;

        case IR_ERRDEFER:
            if (inst->data.errdefer.body) {
                for (int i = 0; i < inst->data.errdefer.body_count; i++) {
                    irinst_free(inst->data.errdefer.body[i]);
                }
                free(inst->data.errdefer.body);
            }
            break;

        case IR_ERROR_VALUE:
            if (inst->data.error_value.error_name) {
                free(inst->data.error_value.error_name);
            }
            break;

        case IR_STRING_INTERPOLATION:
            // 释放文本段
            if (inst->data.string_interpolation.text_segments) {
                for (int i = 0; i < inst->data.string_interpolation.text_count; i++) {
                    if (inst->data.string_interpolation.text_segments[i]) {
                        free(inst->data.string_interpolation.text_segments[i]);
                    }
                }
                free(inst->data.string_interpolation.text_segments);
            }
            // 释放插值表达式
            if (inst->data.string_interpolation.interp_exprs) {
                for (int i = 0; i < inst->data.string_interpolation.interp_count; i++) {
                    irinst_free(inst->data.string_interpolation.interp_exprs[i]);
                }
                free(inst->data.string_interpolation.interp_exprs);
            }
            // 释放格式字符串
            if (inst->data.string_interpolation.format_strings) {
                for (int i = 0; i < inst->data.string_interpolation.interp_count; i++) {
                    if (inst->data.string_interpolation.format_strings[i]) {
                        free(inst->data.string_interpolation.format_strings[i]);
                    }
                }
                free(inst->data.string_interpolation.format_strings);
            }
            // 释放常量值
            if (inst->data.string_interpolation.const_values) {
                for (int i = 0; i < inst->data.string_interpolation.interp_count; i++) {
                    if (inst->data.string_interpolation.const_values[i]) {
                        free(inst->data.string_interpolation.const_values[i]);
                    }
                }
                free(inst->data.string_interpolation.const_values);
            }
            // 释放常量标记数组
            if (inst->data.string_interpolation.is_const) {
                free(inst->data.string_interpolation.is_const);
            }
            break;

        default:
            break;
    }

    free(inst);
}

static void ir_print_indent(int indent) {
    for (int i = 0; i < indent; i++) {
        printf("  ");
    }
}

void ir_print(IRInst *inst, int indent) {
    if (!inst) {
        return;
    }
    
    ir_print_indent(indent);
    
    switch (inst->type) {
        case IR_FUNC_DECL:
            printf("FUNC_DECL: %s\n", inst->data.func.name);
            break;
            
        case IR_FUNC_DEF:
            printf("FUNC_DEF: %s\n", inst->data.func.name);
            for (int i = 0; i < inst->data.func.body_count; i++) {
                ir_print(inst->data.func.body[i], indent + 1);
            }
            break;
            
        case IR_VAR_DECL:
            printf("VAR_DECL: %s : ", inst->data.var.name);
            switch (inst->data.var.type) {
                case IR_TYPE_I32: printf("i32"); break;
                case IR_TYPE_F64: printf("f64"); break;
                case IR_TYPE_BOOL: printf("bool"); break;
                case IR_TYPE_VOID: printf("void"); break;
                default: printf("unknown"); break;
            }
            if (inst->data.var.init) {
                printf(" = ");
                ir_print(inst->data.var.init, 0);
            }
            printf("\n");
            break;
            
        case IR_ASSIGN:
            printf("ASSIGN: %s = ", inst->data.assign.dest);
            ir_print(inst->data.assign.src, 0);
            break;
            
        case IR_BINARY_OP:
            printf("BINARY_OP: ");
            switch (inst->data.binary_op.op) {
                case IR_OP_ADD: printf("+"); break;
                case IR_OP_SUB: printf("-"); break;
                case IR_OP_MUL: printf("*"); break;
                case IR_OP_DIV: printf("/"); break;
                case IR_OP_EQ: printf("=="); break;
                case IR_OP_LT: printf("<"); break;
                default: printf("op_%d", inst->data.binary_op.op); break;
            }
            printf("\n");
            ir_print_indent(indent + 1);
            printf("Left: ");
            ir_print(inst->data.binary_op.left, 0);
            ir_print_indent(indent + 1);
            printf("Right: ");
            ir_print(inst->data.binary_op.right, 0);
            break;
            
        case IR_CALL:
            printf("CALL: %s", inst->data.call.func_name);
            if (inst->data.call.args) {
                printf("(");
                for (int i = 0; i < inst->data.call.arg_count; i++) {
                    if (i > 0) printf(", ");
                    ir_print(inst->data.call.args[i], 0);
                }
                printf(")");
            }
            printf("\n");
            break;
            
        case IR_RETURN:
            printf("RETURN: ");
            if (inst->data.ret.value) {
                ir_print(inst->data.ret.value, 0);
            } else {
                printf("void");
            }
            printf("\n");
            break;
            
        case IR_IF:
            printf("IF:\n");
            ir_print_indent(indent + 1);
            printf("Condition: ");
            ir_print(inst->data.if_stmt.condition, 0);
            ir_print_indent(indent + 1);
            printf("Then:\n");
            for (int i = 0; i < inst->data.if_stmt.then_count; i++) {
                ir_print(inst->data.if_stmt.then_body[i], indent + 2);
            }
            if (inst->data.if_stmt.else_body) {
                ir_print_indent(indent + 1);
                printf("Else:\n");
                for (int i = 0; i < inst->data.if_stmt.else_count; i++) {
                    ir_print(inst->data.if_stmt.else_body[i], indent + 2);
                }
            }
            break;
            
        case IR_WHILE:
            printf("WHILE:\n");
            ir_print_indent(indent + 1);
            printf("Condition: ");
            ir_print(inst->data.while_stmt.condition, 0);
            ir_print_indent(indent + 1);
            printf("Body:\n");
            for (int i = 0; i < inst->data.while_stmt.body_count; i++) {
                ir_print(inst->data.while_stmt.body[i], indent + 2);
            }
            break;
            
        case IR_STRUCT_DECL:
            printf("STRUCT_DECL: %s {\n", inst->data.struct_decl.name);
            for (int i = 0; i < inst->data.struct_decl.field_count; i++) {
                if (inst->data.struct_decl.fields[i]) {
                    ir_print_indent(indent + 1);
                    printf("  FIELD: ");
                    if (inst->data.struct_decl.fields[i]->data.var.name) {
                        printf("%s : ", inst->data.struct_decl.fields[i]->data.var.name);
                    }
                    // Print field type info
                    printf("type_%d\n", inst->data.struct_decl.fields[i]->data.var.type);
                }
            }
            ir_print_indent(indent);
            printf("}\n");
            break;

        case IR_BLOCK:
            printf("BLOCK:\n");
            for (int i = 0; i < inst->data.block.inst_count; i++) {
                ir_print(inst->data.block.insts[i], indent + 1);
            }
            break;

        default:
            printf("IR_INST: type=%d\n", inst->type);
            break;
    }
}