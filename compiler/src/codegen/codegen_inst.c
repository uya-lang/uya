#include "codegen_inst.h"
#include "codegen.h"
#include "codegen_type.h"
#include "codegen_value.h"
#include "codegen_error.h"
#include "../ir/ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// IR_FUNC_DEF implementation
void codegen_gen_func_def(CodeGenerator *codegen, IRInst *inst) {
    // 在生产模式下，跳过测试函数（以 @test$ 开头）
    if (inst->data.func.name && strncmp(inst->data.func.name, "@test$", 6) == 0) {
        // 跳过测试函数（测试模式会单独处理）
        return;
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
                    codegen_gen_var_decl(codegen, body_inst);
                    break;
                case IR_CALL:
                    codegen_gen_call(codegen, body_inst);
                    break;
                case IR_ASSIGN:
                    codegen_gen_assign(codegen, body_inst);
                    break;
                case IR_BINARY_OP:
                    codegen_gen_binary_op(codegen, body_inst);
                    break;
                case IR_IF:
                    codegen_gen_if(codegen, body_inst);
                    break;
                case IR_WHILE:
                    codegen_gen_while(codegen, body_inst);
                    break;
                case IR_BLOCK:
                    codegen_gen_block(codegen, body_inst);
                    break;
                case IR_TRY_CATCH:
                    codegen_gen_try_catch(codegen, body_inst);
                    break;
                default:
                    // Fallback: use codegen_generate_inst for other statement types
                    codegen_generate_inst(codegen, body_inst);
                    break;
            }
            fprintf(codegen->output_file, ";\n");
        }
    }

    // 对于!T类型，生成统一的错误检查点
    // According to uya.md: error_id == 0 means success, error_id != 0 means error
    // 对于错误联合返回类型，这个标签应该总是被生成（因为codegen_gen_return会跳转到这里）
    if (inst->data.func.return_type_is_error_union) {
        fprintf(codegen->output_file, "_check_error_return_%s:\n", actual_func_name);
        fprintf(codegen->output_file, "  if (%s.error_id != 0) {\n", return_var_name);
        fprintf(codegen->output_file, "    goto _error_return_%s;\n", actual_func_name);
        fprintf(codegen->output_file, "  } else {\n");
        fprintf(codegen->output_file, "    goto _normal_return_%s;\n", actual_func_name);
        fprintf(codegen->output_file, "  }\n\n");
        // 如果还没有设置has_error_return_path，现在设置它（因为需要生成_error_return标签）
        if (!has_error_return_path) {
            has_error_return_path = 1;
        }
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

        // 生成 drop 调用（错误返回时也执行 drop）
        if (drop_var_count > 0 && drop_vars) {
            fprintf(codegen->output_file, "  // Generated drop calls in LIFO order (error return)\n");
            for (int i = drop_var_count - 1; i >= 0; i--) {
                if (drop_vars[i].var_name && drop_vars[i].type_name) {
                    if (drop_vars[i].is_array) {
                        // 对于数组，需要遍历每个元素调用 drop
                        if (drop_vars[i].array_size > 0) {
                            fprintf(codegen->output_file, "  for (int _drop_idx = 0; _drop_idx < %d; _drop_idx++) {\n", drop_vars[i].array_size);
                            fprintf(codegen->output_file, "    drop_%s(&%s[_drop_idx]);\n", drop_vars[i].type_name, drop_vars[i].var_name);
                            fprintf(codegen->output_file, "  }\n");
                        } else {
                            // 如果不知道数组大小，使用 sizeof 计算
                            fprintf(codegen->output_file, "  for (int _drop_idx = 0; _drop_idx < (int)(sizeof(%s) / sizeof(%s[0])); _drop_idx++) {\n", drop_vars[i].var_name, drop_vars[i].var_name);
                            fprintf(codegen->output_file, "    drop_%s(&%s[_drop_idx]);\n", drop_vars[i].type_name, drop_vars[i].var_name);
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

        // 返回错误值
        if (has_return_value) {
            fprintf(codegen->output_file, "  return %s;\n", return_var_name);
        } else {
            fprintf(codegen->output_file, "  return;\n");
        }
    }

    // 生成正常返回路径
    fprintf(codegen->output_file, "_normal_return_%s:\n", actual_func_name);

    // 生成 defer 块（正常返回时执行）
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
                        fprintf(codegen->output_file, "    drop_%s(&%s[_drop_idx]);\n", drop_vars[i].type_name, drop_vars[i].var_name);
                        fprintf(codegen->output_file, "  }\n");
                    } else {
                        // 如果不知道数组大小，使用 sizeof 计算
                        fprintf(codegen->output_file, "  for (int _drop_idx = 0; _drop_idx < (int)(sizeof(%s) / sizeof(%s[0])); _drop_idx++) {\n", drop_vars[i].var_name, drop_vars[i].var_name);
                        fprintf(codegen->output_file, "    drop_%s(&%s[_drop_idx]);\n", drop_vars[i].type_name, drop_vars[i].var_name);
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

    // 释放所有分配的资源（只释放一次，在函数末尾）
    if (return_var_name) {
        free(return_var_name);
    }
    if (defer_blocks) {
        free(defer_blocks);
    }
    if (errdefer_blocks) {
        free(errdefer_blocks);
    }
    if (drop_vars) {
        free(drop_vars);
    }

    fprintf(codegen->output_file, "}\n\n");

    // Restore previous function context
    codegen->current_function = prev_function;
}

// IR_VAR_DECL implementation
void codegen_gen_var_decl(CodeGenerator *codegen, IRInst *inst) {
    // 生成变量类型和名称
    if (inst->data.var.type == IR_TYPE_STRUCT) {
        // For struct types, use original_type_name if available
        if (inst->data.var.original_type_name) {
            fprintf(codegen->output_file, "%s", inst->data.var.original_type_name);
        } else {
            codegen_write_type(codegen, inst->data.var.type);
        }
    } else if (inst->data.var.type == IR_TYPE_PTR) {
        // Handle pointer types with original type names
        if (inst->data.var.original_type_name) {
            fprintf(codegen->output_file, "%s*", inst->data.var.original_type_name);
        } else {
            codegen_write_type(codegen, inst->data.var.type);
        }
    } else if (inst->data.var.type == IR_TYPE_ARRAY) {
        // Handle array types with original type names
        if (inst->data.var.original_type_name) {
            fprintf(codegen->output_file, "%s*", inst->data.var.original_type_name);
        } else {
            codegen_write_type(codegen, inst->data.var.type);
        }
    } else {
        codegen_write_type(codegen, inst->data.var.type);
    }
    fprintf(codegen->output_file, " %s", inst->data.var.name);

    // 生成变量初始化
    if (inst->data.var.init) {
        fprintf(codegen->output_file, " = ");
        codegen_write_value(codegen, inst->data.var.init);
    }
}

// IR_ASSIGN implementation
void codegen_gen_assign(CodeGenerator *codegen, IRInst *inst) {
    // 生成赋值语句
    if (inst->data.assign.dest_expr) {
        // 使用目标表达式（支持 arr[0] 等复杂赋值）
        codegen_write_value(codegen, inst->data.assign.dest_expr);
        fprintf(codegen->output_file, " = ");
        codegen_write_value(codegen, inst->data.assign.src);
    } else if (inst->data.assign.dest) {
        // 普通赋值
        fprintf(codegen->output_file, "%s = ", inst->data.assign.dest);
        codegen_write_value(codegen, inst->data.assign.src);
    } else {
        // 没有目标，直接生成源表达式（可能是函数调用或其他）
        codegen_write_value(codegen, inst->data.assign.src);
    }
}

// IR_BINARY_OP implementation
void codegen_gen_binary_op(CodeGenerator *codegen, IRInst *inst) {
    // 生成二元运算
    codegen_write_value(codegen, inst->data.binary_op.left);
    fprintf(codegen->output_file, " ");
    switch (inst->data.binary_op.op) {
        case IR_OP_ADD: fprintf(codegen->output_file, "+"); break;
        case IR_OP_SUB: fprintf(codegen->output_file, "-"); break;
        case IR_OP_MUL: fprintf(codegen->output_file, "*"); break;
        case IR_OP_DIV: fprintf(codegen->output_file, "/"); break;
        case IR_OP_MOD: fprintf(codegen->output_file, "%%"); break;
        case IR_OP_EQ: fprintf(codegen->output_file, "=="); break;
        case IR_OP_NE: fprintf(codegen->output_file, "!="); break;
        case IR_OP_LT: fprintf(codegen->output_file, "<"); break;
        case IR_OP_LE: fprintf(codegen->output_file, "<="); break;
        case IR_OP_GT: fprintf(codegen->output_file, ">"); break;
        case IR_OP_GE: fprintf(codegen->output_file, ">="); break;
        case IR_OP_LOGIC_AND: fprintf(codegen->output_file, "&&"); break;
        case IR_OP_LOGIC_OR: fprintf(codegen->output_file, "||"); break;
        case IR_OP_BIT_AND: fprintf(codegen->output_file, "&"); break;
        case IR_OP_BIT_OR: fprintf(codegen->output_file, "|"); break;
        case IR_OP_BIT_XOR: fprintf(codegen->output_file, "^"); break;
        case IR_OP_LEFT_SHIFT: fprintf(codegen->output_file, "<<"); break;
        case IR_OP_RIGHT_SHIFT: fprintf(codegen->output_file, ">>"); break;
        default: fprintf(codegen->output_file, "?"); break;
    }
    fprintf(codegen->output_file, " ");
    codegen_write_value(codegen, inst->data.binary_op.right);
}

// IR_RETURN implementation
void codegen_gen_return(CodeGenerator *codegen, IRInst *inst) {
    // Check if we're in a function context and if it returns an error union type
    if (codegen->current_function && 
        codegen->current_function->type == IR_FUNC_DEF &&
        codegen->current_function->data.func.return_type_is_error_union) {
        
        // Generate return variable name and function name for goto labels
        // Handle drop functions: for drop functions, actual function name is drop_TypeName
        const char *func_name = codegen->current_function->data.func.name;
        char return_var_name[256];
        char actual_func_name[256];
        
        int is_drop_function = (func_name && strcmp(func_name, "drop") == 0);
        if (is_drop_function && codegen->current_function->data.func.param_count > 0 &&
            codegen->current_function->data.func.params[0] &&
            codegen->current_function->data.func.params[0]->data.var.original_type_name) {
            snprintf(actual_func_name, sizeof(actual_func_name), "drop_%s",
                     codegen->current_function->data.func.params[0]->data.var.original_type_name);
        } else {
            strncpy(actual_func_name, func_name ? func_name : "", sizeof(actual_func_name) - 1);
            actual_func_name[sizeof(actual_func_name) - 1] = '\0';
        }
        
        snprintf(return_var_name, sizeof(return_var_name), "_return_%s", actual_func_name);
        
        // Check if return value is an error value
        int is_error = 0;
        if (inst->data.ret.value) {
            is_error = is_error_return_value(inst->data.ret.value);
        }
        
        if (is_error && inst->data.ret.value) {
            // Error return: set error_id
            fprintf(codegen->output_file, "%s.error_id = ", return_var_name);
            codegen_write_value(codegen, inst->data.ret.value);
            fprintf(codegen->output_file, ";\ngoto _check_error_return_%s", actual_func_name);
        } else if (inst->data.ret.value) {
            // Normal value return
            IRType return_type = codegen->current_function->data.func.return_type;
            fprintf(codegen->output_file, "%s.error_id = 0", return_var_name);
            if (return_type != IR_TYPE_VOID) {
                fprintf(codegen->output_file, ";\n%s.value = ", return_var_name);
                codegen_write_value(codegen, inst->data.ret.value);
            }
            fprintf(codegen->output_file, ";\ngoto _check_error_return_%s", actual_func_name);
        } else {
            // No value (void return type)
            fprintf(codegen->output_file, "%s.error_id = 0;\ngoto _check_error_return_%s", return_var_name, actual_func_name);
        }
    } else {
        // Normal return (not error union type)
        fprintf(codegen->output_file, "return");
        if (inst->data.ret.value) {
            fprintf(codegen->output_file, " ");
            codegen_write_value(codegen, inst->data.ret.value);
        }
    }
}

// IR_CALL implementation
void codegen_gen_call(CodeGenerator *codegen, IRInst *inst) {
    // 生成函数调用
    fprintf(codegen->output_file, "%s(", inst->data.call.func_name);
    for (int i = 0; i < inst->data.call.arg_count; i++) {
        if (i > 0) fprintf(codegen->output_file, ", ");
        codegen_write_value(codegen, inst->data.call.args[i]);
    }
    fprintf(codegen->output_file, ")");
}

// IR_IF implementation
void codegen_gen_if(CodeGenerator *codegen, IRInst *inst) {
    // 生成if语句
    // 根据uya.md: 需要将else if视为嵌套的if语句
    // 生成条件
    fprintf(codegen->output_file, "if (");
    codegen_write_value(codegen, inst->data.if_stmt.condition);
    fprintf(codegen->output_file, ") {");
    
    // 生成then分支
    for (int i = 0; i < inst->data.if_stmt.then_count; i++) {
        IRInst *then_inst = inst->data.if_stmt.then_body[i];
        if (!then_inst) continue;
        
        // 检查then_body[i]是否是一个block
        if (then_inst->type == IR_BLOCK) {
            // 如果是block，直接生成block内的指令
            for (int j = 0; j < then_inst->data.block.inst_count; j++) {
                IRInst *nested_then_inst = then_inst->data.block.insts[j];
                if (!nested_then_inst) continue;
                fprintf(codegen->output_file, "\n    ");
                codegen_generate_inst(codegen, nested_then_inst);
                fprintf(codegen->output_file, ";");
            }
        } else {
            // 否则直接生成指令
            fprintf(codegen->output_file, "\n    ");
            codegen_generate_inst(codegen, then_inst);
            fprintf(codegen->output_file, ";");
        }
    }
    fprintf(codegen->output_file, "\n");
    
    // 生成else分支
    if (inst->data.if_stmt.else_count > 0 && inst->data.if_stmt.else_body) {
        fprintf(codegen->output_file, "} else {");
        
        // 处理else分支中的指令
        for (int i = 0; i < inst->data.if_stmt.else_count; i++) {
            IRInst *else_inst = inst->data.if_stmt.else_body[i];
            if (!else_inst) continue;
            
            // 检查else_inst是否是一个if语句（即else if模式）
            if (else_inst->type == IR_IF) {
                // 对于else if，直接生成if语句
                fprintf(codegen->output_file, "\n  ");
                codegen_generate_inst(codegen, else_inst);
            } else if (else_inst->type == IR_BLOCK) {
                // 如果是block，生成block内的指令
                for (int j = 0; j < else_inst->data.block.inst_count; j++) {
                    IRInst *nested_else_inst = else_inst->data.block.insts[j];
                    if (!nested_else_inst) continue;
                    fprintf(codegen->output_file, "\n    ");
                    codegen_generate_inst(codegen, nested_else_inst);
                    fprintf(codegen->output_file, ";");
                }
            } else {
                // 否则直接生成指令
                fprintf(codegen->output_file, "\n    ");
                codegen_generate_inst(codegen, else_inst);
                fprintf(codegen->output_file, ";");
            }
        }
        fprintf(codegen->output_file, "\n");
    }
    fprintf(codegen->output_file, "}");
}

// IR_WHILE implementation
void codegen_gen_while(CodeGenerator *codegen, IRInst *inst) {
    // 生成while循环
    fprintf(codegen->output_file, "while (");
    codegen_write_value(codegen, inst->data.while_stmt.condition);
    fprintf(codegen->output_file, ") {");
    
    // 生成循环体
    for (int i = 0; i < inst->data.while_stmt.body_count; i++) {
        IRInst *body_inst = inst->data.while_stmt.body[i];
        if (!body_inst) continue;
        
        // 检查body_inst是否是一个block
        if (body_inst->type == IR_BLOCK) {
            // 如果是block，生成block内的指令
            for (int j = 0; j < body_inst->data.block.inst_count; j++) {
                IRInst *nested_body_inst = body_inst->data.block.insts[j];
                if (!nested_body_inst) continue;
                fprintf(codegen->output_file, "\n    ");
                codegen_generate_inst(codegen, nested_body_inst);
                fprintf(codegen->output_file, ";");
            }
        } else {
            // 否则直接生成指令
            fprintf(codegen->output_file, "\n    ");
            codegen_generate_inst(codegen, body_inst);
            fprintf(codegen->output_file, ";");
        }
    }
    fprintf(codegen->output_file, "\n}");
}

// IR_FOR implementation
void codegen_gen_for(CodeGenerator *codegen, IRInst *inst) {
    // 生成for循环
    // 注意：这里只处理for-in循环，不处理C风格的for循环
    // 根据uya.md: for (var item in iterable) {
    if (inst->data.for_stmt.item_var && inst->data.for_stmt.iterable) {
        fprintf(codegen->output_file, "for (var %s in ", inst->data.for_stmt.item_var);
        
        // 生成iterable
        codegen_write_value(codegen, inst->data.for_stmt.iterable);
        fprintf(codegen->output_file, ") {");
        
        // 生成循环体
        for (int i = 0; i < inst->data.for_stmt.body_count; i++) {
            IRInst *body_inst = inst->data.for_stmt.body[i];
            if (!body_inst) continue;
            
            // 检查body_inst是否是一个block
            if (body_inst->type == IR_BLOCK) {
                // 如果是block，生成block内的指令
                for (int j = 0; j < body_inst->data.block.inst_count; j++) {
                    IRInst *nested_body_inst = body_inst->data.block.insts[j];
                    if (!nested_body_inst) continue;
                    fprintf(codegen->output_file, "\n    ");
                    codegen_generate_inst(codegen, nested_body_inst);
                    fprintf(codegen->output_file, ";");
                }
            } else {
                // 否则直接生成指令
                fprintf(codegen->output_file, "\n    ");
                codegen_generate_inst(codegen, body_inst);
                fprintf(codegen->output_file, ";");
            }
        }
        fprintf(codegen->output_file, "\n}");
    }
}

// IR_TRY_CATCH implementation
void codegen_gen_try_catch(CodeGenerator *codegen, IRInst *inst) {
    // 生成try-catch语句
    // 根据uya.md: try { ... } catch (error) { ... }
    fprintf(codegen->output_file, "try {");
    
    // 生成try块
    if (inst->data.try_catch.try_body) {
        if (inst->data.try_catch.try_body->type == IR_BLOCK) {
            // 如果是block，生成block内的指令
            for (int j = 0; j < inst->data.try_catch.try_body->data.block.inst_count; j++) {
                IRInst *nested_try_inst = inst->data.try_catch.try_body->data.block.insts[j];
                if (!nested_try_inst) continue;
                fprintf(codegen->output_file, "\n    ");
                codegen_generate_inst(codegen, nested_try_inst);
                fprintf(codegen->output_file, ";");
            }
        } else {
            // 否则直接生成指令
            fprintf(codegen->output_file, "\n    ");
            codegen_generate_inst(codegen, inst->data.try_catch.try_body);
            fprintf(codegen->output_file, ";");
        }
    }
    fprintf(codegen->output_file, "\n}");
    
    // 生成catch块
    if (inst->data.try_catch.catch_body) {
        fprintf(codegen->output_file, " catch (");
        
        // 生成error变量（如果有）
        if (inst->data.try_catch.error_var) {
            // error_var is just a string name, not an IRInst
            fprintf(codegen->output_file, "var %s", inst->data.try_catch.error_var);
        }
        fprintf(codegen->output_file, ") {");
        
        // 生成catch块体
        if (inst->data.try_catch.catch_body->type == IR_BLOCK) {
            // 如果是block，生成block内的指令
            for (int i = 0; i < inst->data.try_catch.catch_body->data.block.inst_count; i++) {
                IRInst *catch_inst = inst->data.try_catch.catch_body->data.block.insts[i];
                if (!catch_inst) continue;
                fprintf(codegen->output_file, "\n    ");
                codegen_generate_inst(codegen, catch_inst);
                fprintf(codegen->output_file, ";");
            }
        } else {
            // 否则直接生成指令
            fprintf(codegen->output_file, "\n    ");
            codegen_generate_inst(codegen, inst->data.try_catch.catch_body);
            fprintf(codegen->output_file, ";");
        }
        fprintf(codegen->output_file, "\n}");
    }
}

// IR_STRUCT_DECL implementation
void codegen_gen_struct_decl(CodeGenerator *codegen, IRInst *inst) {
    // 生成struct声明
    fprintf(codegen->output_file, "struct %s {", inst->data.struct_decl.name);
    
    // 生成struct字段
    for (int i = 0; i < inst->data.struct_decl.field_count; i++) {
        IRInst *field = inst->data.struct_decl.fields[i];
        if (!field) continue;
        
        // 字段应该是VAR_DECL类型
        if (field->type == IR_VAR_DECL) {
            fprintf(codegen->output_file, "\n    ");
            
            // 生成字段类型
            if (field->data.var.type == IR_TYPE_STRUCT && field->data.var.original_type_name) {
                fprintf(codegen->output_file, "%s", field->data.var.original_type_name);
            } else if (field->data.var.type == IR_TYPE_PTR) {
                fprintf(codegen->output_file, "void*");
            } else {
                codegen_write_type(codegen, field->data.var.type);
            }
            
            // 生成字段名称
            fprintf(codegen->output_file, " %s;", field->data.var.name);
        }
    }
    fprintf(codegen->output_file, "\n} %s;", inst->data.struct_decl.name);
}

// IR_ENUM_DECL implementation
void codegen_gen_enum_decl(CodeGenerator *codegen, IRInst *inst) {
    // 生成enum声明
    fprintf(codegen->output_file, "enum %s {", inst->data.enum_decl.name);
    
    // 生成enum变体
    for (int i = 0; i < inst->data.enum_decl.variant_count; i++) {
        fprintf(codegen->output_file, "\n    %s", inst->data.enum_decl.variant_names[i]);
        
        // 添加变体值（如果有）
        if (inst->data.enum_decl.variant_values[i]) {
            fprintf(codegen->output_file, " = %s", inst->data.enum_decl.variant_values[i]);
        }
        
        // 添加逗号（除了最后一个变体）
        if (i < inst->data.enum_decl.variant_count - 1) {
            fprintf(codegen->output_file, ",");
        }
    }
    fprintf(codegen->output_file, "\n} %s;", inst->data.enum_decl.name);
}

// IR_DROP implementation
void codegen_gen_drop(CodeGenerator *codegen, IRInst *inst) {
    // 生成drop调用
    // 根据uya.md: 每个结构体类型都有一个自动生成的drop函数
    // drop函数的名称是drop_结构体名称
    // drop函数的参数是结构体的指针
    if (inst->data.drop.type_name) {
        // 使用生成的type_name（如drop_Person）
        fprintf(codegen->output_file, "drop_%s(%s)", inst->data.drop.type_name, inst->data.drop.var_name);
    } else {
        // Fallback if type_name is not available
        fprintf(codegen->output_file, "drop(%s)", inst->data.drop.var_name);
    }
}

// IR_DEFER implementation
void codegen_gen_defer(CodeGenerator *codegen, IRInst *inst) {
    // Defer implementation in C - generate code directly in the function
    fprintf(codegen->output_file, "// defer block\n");
    // Generate the defer body directly
    for (int i = 0; i < inst->data.defer.body_count; i++) {
        fprintf(codegen->output_file, "  ");
        codegen_generate_inst(codegen, inst->data.defer.body[i]);
        fprintf(codegen->output_file, ";\n");
    }
}

// IR_ERRDEFER implementation
void codegen_gen_errdefer(CodeGenerator *codegen, IRInst *inst) {
    // Errdefer implementation in C - generate code directly in the function
    fprintf(codegen->output_file, "// errdefer block\n");
    // Generate the errdefer body directly
    for (int i = 0; i < inst->data.errdefer.body_count; i++) {
        fprintf(codegen->output_file, "  ");
        codegen_generate_inst(codegen, inst->data.errdefer.body[i]);
        fprintf(codegen->output_file, ";\n");
    }
}

// IR_BLOCK implementation
void codegen_gen_block(CodeGenerator *codegen, IRInst *inst) {
    // Generate block: { ... }
    fprintf(codegen->output_file, "{\n");
    for (int i = 0; i < inst->data.block.inst_count; i++) {
        if (!inst->data.block.insts[i]) continue;
        fprintf(codegen->output_file, "  ");
        codegen_generate_inst(codegen, inst->data.block.insts[i]);
        fprintf(codegen->output_file, ";\n");
    }
    fprintf(codegen->output_file, "}");
}

// Main instruction generation function
void codegen_generate_inst(CodeGenerator *codegen, IRInst *inst) {
    if (!inst) {
        return;
    }

    switch (inst->type) {
        case IR_FUNC_DEF:
            codegen_gen_func_def(codegen, inst);
            break;
        case IR_VAR_DECL:
            codegen_gen_var_decl(codegen, inst);
            break;
        case IR_ASSIGN:
            codegen_gen_assign(codegen, inst);
            break;
        case IR_BINARY_OP:
            codegen_gen_binary_op(codegen, inst);
            break;
        case IR_RETURN:
            codegen_gen_return(codegen, inst);
            break;
        case IR_CALL:
            codegen_gen_call(codegen, inst);
            break;
        case IR_IF:
            codegen_gen_if(codegen, inst);
            break;
        case IR_WHILE:
            codegen_gen_while(codegen, inst);
            break;
        case IR_FOR:
            codegen_gen_for(codegen, inst);
            break;
        case IR_TRY_CATCH:
            codegen_gen_try_catch(codegen, inst);
            break;
        case IR_STRUCT_DECL:
            codegen_gen_struct_decl(codegen, inst);
            break;
        case IR_ENUM_DECL:
            codegen_gen_enum_decl(codegen, inst);
            break;
        case IR_DROP:
            codegen_gen_drop(codegen, inst);
            break;
        case IR_DEFER:
            codegen_gen_defer(codegen, inst);
            break;
        case IR_ERRDEFER:
            codegen_gen_errdefer(codegen, inst);
            break;
        case IR_BLOCK:
            codegen_gen_block(codegen, inst);
            break;
        default:
            break;
    }
}