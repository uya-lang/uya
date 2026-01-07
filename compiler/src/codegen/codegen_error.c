#include "codegen_error.h"
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
int collect_error_names(CodeGenerator *codegen, IRGenerator *ir) {
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
            if (inst->data.assign.dest_expr) {
                collect_error_names_recursive(codegen, inst->data.assign.dest_expr);
            }
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

// Helper function to check if an IR instruction represents an error return value
// According to uya.md, error.ErrorName is the syntax for error types
int is_error_return_value(IRInst *inst) {
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