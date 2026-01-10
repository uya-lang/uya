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
    
    // 初始化所有指令指针为NULL，防止释放未初始化的指针
    for (int i = 0; i < 16; i++) {
        gen->instructions[i] = NULL;
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
    
    // 初始化数据为0
    memset(&inst->data, 0, sizeof(inst->data));
    
    inst->type = type;
    inst->id = -1;  // 未分配ID
    
    return inst;
}

void irinst_free(IRInst *inst) {
    if (!inst) {
        return;
    }
    
    // 防止重复释放：如果type为0，说明已经被释放过
    if (inst->type == 0) {
        return;
    }
    
    // 保存原始类型，因为我们需要在最后设置type为0
    IRInstType original_type = inst->type;
    
    // 先将type设置为0，防止重复释放
    inst->type = 0;
    
    switch (original_type) {
        case IR_FUNC_DECL:
        case IR_FUNC_DEF:
            if (inst->data.func.name) {
                free(inst->data.func.name);
                inst->data.func.name = NULL;
            }
            if (inst->data.func.return_type_original_name) {
                free(inst->data.func.return_type_original_name);
                inst->data.func.return_type_original_name = NULL;
            }
            if (inst->data.func.params) {
                for (int i = 0; i < inst->data.func.param_count; i++) {
                    if (inst->data.func.params[i]) {
                        irinst_free(inst->data.func.params[i]);
                        inst->data.func.params[i] = NULL;
                    }
                }
                free(inst->data.func.params);
                inst->data.func.params = NULL;
            }
            if (inst->data.func.body) {
                for (int i = 0; i < inst->data.func.body_count; i++) {
                    if (inst->data.func.body[i]) {
                        irinst_free(inst->data.func.body[i]);
                        inst->data.func.body[i] = NULL;
                    }
                }
                free(inst->data.func.body);
                inst->data.func.body = NULL;
            }
            break;
            
        case IR_VAR_DECL:
            if (inst->data.var.name) {
                free(inst->data.var.name);
                inst->data.var.name = NULL;
            }
            if (inst->data.var.original_type_name) {
                free(inst->data.var.original_type_name);
                inst->data.var.original_type_name = NULL;
            }
            if (inst->data.var.init) {
                irinst_free(inst->data.var.init);
                inst->data.var.init = NULL;
            }
            break;
            
        case IR_ASSIGN:
            if (inst->data.assign.dest) {
                free(inst->data.assign.dest);
                inst->data.assign.dest = NULL;
            }
            if (inst->data.assign.dest_expr) {
                irinst_free(inst->data.assign.dest_expr);
                inst->data.assign.dest_expr = NULL;
            }
            if (inst->data.assign.src) {
                irinst_free(inst->data.assign.src);
                inst->data.assign.src = NULL;
            }
            break;
            
        case IR_BINARY_OP:
            if (inst->data.binary_op.dest) {
                free(inst->data.binary_op.dest);
                inst->data.binary_op.dest = NULL;
            }
            if (inst->data.binary_op.left) {
                irinst_free(inst->data.binary_op.left);
                inst->data.binary_op.left = NULL;
            }
            if (inst->data.binary_op.right) {
                irinst_free(inst->data.binary_op.right);
                inst->data.binary_op.right = NULL;
            }
            break;
            
        case IR_UNARY_OP:
            if (inst->data.unary_op.dest) {
                free(inst->data.unary_op.dest);
                inst->data.unary_op.dest = NULL;
            }
            if (inst->data.unary_op.operand) {
                irinst_free(inst->data.unary_op.operand);
                inst->data.unary_op.operand = NULL;
            }
            break;
            
        case IR_CALL:
            if (inst->data.call.dest) {
                free(inst->data.call.dest);
                inst->data.call.dest = NULL;
            }
            if (inst->data.call.func_name) {
                free(inst->data.call.func_name);
                inst->data.call.func_name = NULL;
            }
            if (inst->data.call.args) {
                for (int i = 0; i < inst->data.call.arg_count; i++) {
                    if (inst->data.call.args[i]) {
                        irinst_free(inst->data.call.args[i]);
                        inst->data.call.args[i] = NULL;
                    }
                }
                free(inst->data.call.args);
                inst->data.call.args = NULL;
            }
            break;
            
        case IR_RETURN:
            if (inst->data.ret.value) {
                irinst_free(inst->data.ret.value);
                inst->data.ret.value = NULL;
            }
            break;
            
        case IR_IF:
            if (inst->data.if_stmt.condition) {
                irinst_free(inst->data.if_stmt.condition);
                inst->data.if_stmt.condition = NULL;
            }
            if (inst->data.if_stmt.then_body) {
                for (int i = 0; i < inst->data.if_stmt.then_count; i++) {
                    if (inst->data.if_stmt.then_body[i]) {
                        irinst_free(inst->data.if_stmt.then_body[i]);
                        inst->data.if_stmt.then_body[i] = NULL;
                    }
                }
                free(inst->data.if_stmt.then_body);
                inst->data.if_stmt.then_body = NULL;
            }
            if (inst->data.if_stmt.else_body) {
                for (int i = 0; i < inst->data.if_stmt.else_count; i++) {
                    if (inst->data.if_stmt.else_body[i]) {
                        irinst_free(inst->data.if_stmt.else_body[i]);
                        inst->data.if_stmt.else_body[i] = NULL;
                    }
                }
                free(inst->data.if_stmt.else_body);
                inst->data.if_stmt.else_body = NULL;
            }
            break;
            
        case IR_WHILE:
            if (inst->data.while_stmt.condition) {
                irinst_free(inst->data.while_stmt.condition);
                inst->data.while_stmt.condition = NULL;
            }
            if (inst->data.while_stmt.body) {
                for (int i = 0; i < inst->data.while_stmt.body_count; i++) {
                    if (inst->data.while_stmt.body[i]) {
                        irinst_free(inst->data.while_stmt.body[i]);
                        inst->data.while_stmt.body[i] = NULL;
                    }
                }
                free(inst->data.while_stmt.body);
                inst->data.while_stmt.body = NULL;
            }
            break;
            
        case IR_BLOCK:
            if (inst->data.block.insts) {
                for (int i = 0; i < inst->data.block.inst_count; i++) {
                    if (inst->data.block.insts[i]) {
                        irinst_free(inst->data.block.insts[i]);
                        inst->data.block.insts[i] = NULL;
                    }
                }
                free(inst->data.block.insts);
                inst->data.block.insts = NULL;
            }
            break;
            
        case IR_LOAD:
        case IR_STORE:
            if (inst->data.load.dest) {
                free(inst->data.load.dest);
                inst->data.load.dest = NULL;
            }
            if (inst->data.load.src) {
                free(inst->data.load.src);
                inst->data.load.src = NULL;
            }
            break;
            
        case IR_CAST:
            if (inst->data.cast.dest) {
                free(inst->data.cast.dest);
                inst->data.cast.dest = NULL;
            }
            if (inst->data.cast.src) {
                irinst_free(inst->data.cast.src);
                inst->data.cast.src = NULL;
            }
            break;
            
        case IR_ERROR_UNION:
            if (inst->data.error_union.dest) {
                free(inst->data.error_union.dest);
                inst->data.error_union.dest = NULL;
            }
            if (inst->data.error_union.value) {
                irinst_free(inst->data.error_union.value);
                inst->data.error_union.value = NULL;
            }
            break;
            
        case IR_TRY_CATCH:;
            // 保存指针到临时变量，防止重复释放
            IRInst *try_body = inst->data.try_catch.try_body;
            char *error_var = inst->data.try_catch.error_var;
            IRInst *catch_body = inst->data.try_catch.catch_body;
            
            // 立即将原指针设置为NULL，防止重复释放
            inst->data.try_catch.try_body = NULL;
            inst->data.try_catch.error_var = NULL;
            inst->data.try_catch.catch_body = NULL;
            
            // 释放资源
            if (try_body) irinst_free(try_body);
            if (error_var) free(error_var);
            if (catch_body) irinst_free(catch_body);
            break;

        case IR_STRUCT_DECL:
            if (inst->data.struct_decl.name) {
                free(inst->data.struct_decl.name);
                inst->data.struct_decl.name = NULL;
            }
            if (inst->data.struct_decl.fields) {
                for (int i = 0; i < inst->data.struct_decl.field_count; i++) {
                    if (inst->data.struct_decl.fields[i]) {
                        irinst_free(inst->data.struct_decl.fields[i]);
                        inst->data.struct_decl.fields[i] = NULL;
                    }
                }
                free(inst->data.struct_decl.fields);
                inst->data.struct_decl.fields = NULL;
            }
            break;

        case IR_ENUM_DECL:
            if (inst->data.enum_decl.name) {
                free(inst->data.enum_decl.name);
                inst->data.enum_decl.name = NULL;
            }
            if (inst->data.enum_decl.variant_names) {
                for (int i = 0; i < inst->data.enum_decl.variant_count; i++) {
                    if (inst->data.enum_decl.variant_names[i]) {
                        free(inst->data.enum_decl.variant_names[i]);
                        inst->data.enum_decl.variant_names[i] = NULL;
                    }
                }
                free(inst->data.enum_decl.variant_names);
                inst->data.enum_decl.variant_names = NULL;
            }
            if (inst->data.enum_decl.variant_values) {
                for (int i = 0; i < inst->data.enum_decl.variant_count; i++) {
                    if (inst->data.enum_decl.variant_values[i]) {
                        free(inst->data.enum_decl.variant_values[i]);
                        inst->data.enum_decl.variant_values[i] = NULL;
                    }
                }
                free(inst->data.enum_decl.variant_values);
                inst->data.enum_decl.variant_values = NULL;
            }
            break;

        case IR_DEFER:
            if (inst->data.defer.body) {
                for (int i = 0; i < inst->data.defer.body_count; i++) {
                    if (inst->data.defer.body[i]) {
                        irinst_free(inst->data.defer.body[i]);
                        inst->data.defer.body[i] = NULL;
                    }
                }
                free(inst->data.defer.body);
                inst->data.defer.body = NULL;
            }
            break;

        case IR_ERRDEFER:
            if (inst->data.errdefer.body) {
                for (int i = 0; i < inst->data.errdefer.body_count; i++) {
                    if (inst->data.errdefer.body[i]) {
                        irinst_free(inst->data.errdefer.body[i]);
                        inst->data.errdefer.body[i] = NULL;
                    }
                }
                free(inst->data.errdefer.body);
                inst->data.errdefer.body = NULL;
            }
            break;

        case IR_ERROR_VALUE:
            if (inst->data.error_value.error_name) {
                free(inst->data.error_value.error_name);
                // 防止双重释放：将指针置为 NULL
                inst->data.error_value.error_name = NULL;
            }
            break;

        case IR_CONSTANT:
            if (inst->data.constant.value) {
                free(inst->data.constant.value);
                // 防止双重释放：将指针置为 NULL
                inst->data.constant.value = NULL;
            }
            break;

        case IR_MEMBER_ACCESS:
        case IR_SUBSCRIPT: {
            // 对于 IR_SUBSCRIPT，field_name 可能指向 index_expr->data.constant.value 的副本
            // 所以先保存 field_name，避免在释放 index_expr 后变成悬垂指针
            char *field_name_to_free = inst->data.member_access.field_name;
            
            // 检查 object 是否为 NULL，避免双重释放
            if (inst->data.member_access.object) {
                irinst_free(inst->data.member_access.object);
                inst->data.member_access.object = NULL;
            }
            
            // 先释放 index_expr，因为它可能包含 field_name 指向的数据
            if (inst->data.member_access.index_expr) {
                irinst_free(inst->data.member_access.index_expr);
                inst->data.member_access.index_expr = NULL;
            }
            
            // 现在可以安全释放 field_name
            if (field_name_to_free) {
                free(field_name_to_free);
                inst->data.member_access.field_name = NULL;
            }
            
            if (inst->data.member_access.dest) {
                free(inst->data.member_access.dest);
                inst->data.member_access.dest = NULL;
            }
            break;
        }

        case IR_STRUCT_INIT:
            if (inst->data.struct_init.struct_name) {
                free(inst->data.struct_init.struct_name);
                inst->data.struct_init.struct_name = NULL;
            }
            if (inst->data.struct_init.field_names) {
                for (int i = 0; i < inst->data.struct_init.field_count; i++) {
                    if (inst->data.struct_init.field_names[i]) {
                        free(inst->data.struct_init.field_names[i]);
                        inst->data.struct_init.field_names[i] = NULL;
                    }
                }
                free(inst->data.struct_init.field_names);
                inst->data.struct_init.field_names = NULL;
            }
            if (inst->data.struct_init.field_inits) {
                for (int i = 0; i < inst->data.struct_init.field_count; i++) {
                    if (inst->data.struct_init.field_inits[i]) {
                        irinst_free(inst->data.struct_init.field_inits[i]);
                        inst->data.struct_init.field_inits[i] = NULL;
                    }
                }
                free(inst->data.struct_init.field_inits);
                inst->data.struct_init.field_inits = NULL;
            }
            break;

        case IR_STRING_INTERPOLATION:
            // 释放文本段
            if (inst->data.string_interpolation.text_segments) {
                for (int i = 0; i < inst->data.string_interpolation.text_count; i++) {
                    if (inst->data.string_interpolation.text_segments[i]) {
                        free(inst->data.string_interpolation.text_segments[i]);
                        inst->data.string_interpolation.text_segments[i] = NULL;
                    }
                }
                free(inst->data.string_interpolation.text_segments);
                inst->data.string_interpolation.text_segments = NULL;
            }
            // 释放插值表达式
            if (inst->data.string_interpolation.interp_exprs) {
                for (int i = 0; i < inst->data.string_interpolation.interp_count; i++) {
                    if (inst->data.string_interpolation.interp_exprs[i]) {
                        irinst_free(inst->data.string_interpolation.interp_exprs[i]);
                        inst->data.string_interpolation.interp_exprs[i] = NULL;
                    }
                }
                free(inst->data.string_interpolation.interp_exprs);
                inst->data.string_interpolation.interp_exprs = NULL;
            }
            // 释放格式字符串
            if (inst->data.string_interpolation.format_strings) {
                for (int i = 0; i < inst->data.string_interpolation.interp_count; i++) {
                    if (inst->data.string_interpolation.format_strings[i]) {
                        free(inst->data.string_interpolation.format_strings[i]);
                        inst->data.string_interpolation.format_strings[i] = NULL;
                    }
                }
                free(inst->data.string_interpolation.format_strings);
                inst->data.string_interpolation.format_strings = NULL;
            }
            // 释放常量值
            if (inst->data.string_interpolation.const_values) {
                for (int i = 0; i < inst->data.string_interpolation.interp_count; i++) {
                    if (inst->data.string_interpolation.const_values[i]) {
                        free(inst->data.string_interpolation.const_values[i]);
                        inst->data.string_interpolation.const_values[i] = NULL;
                    }
                }
                free(inst->data.string_interpolation.const_values);
                inst->data.string_interpolation.const_values = NULL;
            }
            // 释放常量标记数组
            if (inst->data.string_interpolation.is_const) {
                free(inst->data.string_interpolation.is_const);
                inst->data.string_interpolation.is_const = NULL;
            }
            break;

        default:
            break;
    }

    // 标记为已释放，防止重复释放
    inst->type = 0;
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