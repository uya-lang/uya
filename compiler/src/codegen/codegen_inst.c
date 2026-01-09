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

void codegen_generate_inst(CodeGenerator *codegen, IRInst *inst) {
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
                                            size_t actual_len = 0; // We'll need to implement this function in the value module
                                            // For now, we'll just call the function directly here
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
                                            size_t actual_len = 0; // We'll need to implement this function in the value module
                                            // For now, we'll just call the function directly here
                                            for (size_t j = 0; j < const_len; j++) {
                                                if (const_val[j] == '\\' && j + 1 < const_len) {
                                                    // 处理转义序列
                                                    char next = const_val[j + 1];
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
                                                } else if (const_val[j] == '"') {
                                                    fprintf(codegen->output_file, "\\\"");
                                                    actual_len += 1;
                                                } else {
                                                    fprintf(codegen->output_file, "%c", const_val[j]);
                                                    actual_len += 1;
                                                }
                                            }
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
                            } else if (body_inst->data.var.type == IR_TYPE_ARRAY && !body_inst->data.var.init) {
                                // 未初始化的数组：var arr: [i32 : 5];
                                // 需要从符号表中获取数组大小，或者从 original_type_name 推断
                                // 暂时使用固定大小（需要从 AST 中获取）
                                // TODO: 从 IR 中获取数组大小
                                if (body_inst->data.var.original_type_name) {
                                    fprintf(codegen->output_file, "%s %s[5]", body_inst->data.var.original_type_name, body_inst->data.var.name);
                                } else {
                                    fprintf(codegen->output_file, "int32_t %s[5]", body_inst->data.var.name);
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
                                } else if (body_inst->data.var.type == IR_TYPE_PTR && body_inst->data.var.original_type_name) {
                                    // Pointer type with original type name: *i32 -> int32_t*
                                    const char *c_type_name = codegen_convert_uya_type_to_c(body_inst->data.var.original_type_name);
                                    fprintf(codegen->output_file, "%s* %s", c_type_name ? c_type_name : body_inst->data.var.original_type_name, body_inst->data.var.name);
                                } else {
                                    codegen_write_type(codegen, body_inst->data.var.type);
                                    fprintf(codegen->output_file, " %s", body_inst->data.var.name);
                                }
                                if (body_inst->data.var.init) {
                                    // Special handling for catch expressions (IR_TRY_CATCH)
                                    if (body_inst->data.var.init->type == IR_TRY_CATCH) {
                                        // For catch expressions, we need to generate code that assigns the result to the variable
                                        // First declare the variable without initialization
                                        fprintf(codegen->output_file, ";\n  ");
                                        // Generate try-catch code with variable assignment
                                        IRInst *try_catch_inst = body_inst->data.var.init;
                                        if (try_catch_inst->data.try_catch.try_body) {
                                            // Determine return type from try_body
                                            IRType base_type = IR_TYPE_I32;
                                            int is_error_union = 0;
                                            if (try_catch_inst->data.try_catch.try_body->type == IR_CALL &&
                                                try_catch_inst->data.try_catch.try_body->data.call.func_name &&
                                                codegen->ir) {
                                                find_function_return_type(codegen->ir,
                                                                        try_catch_inst->data.try_catch.try_body->data.call.func_name,
                                                                        &base_type, &is_error_union);
                                            }
                                            // Generate temporary variable to store the error union result
                                            char temp_var[64];
                                            snprintf(temp_var, sizeof(temp_var), "_try_result_%d", codegen->temp_counter++);
                                            // Generate the try body
                                            fprintf(codegen->output_file, "struct error_union_%s %s = ",
                                                    codegen_get_type_name(base_type), temp_var);
                                            codegen_write_value(codegen, try_catch_inst->data.try_catch.try_body);
                                            fprintf(codegen->output_file, ";\n  ");
                                            // Check if error_id != 0, if so execute catch block and assign catch result
                                            fprintf(codegen->output_file, "if (%s.error_id != 0) {\n  ", temp_var);
                                            if (try_catch_inst->data.try_catch.error_var) {
                                                fprintf(codegen->output_file, "uint32_t %s = %s.error_id;\n  ",
                                                        try_catch_inst->data.try_catch.error_var, temp_var);
                                            }
                                            if (try_catch_inst->data.try_catch.catch_body) {
                                                // Generate catch body and extract the last expression as the result
                                                if (try_catch_inst->data.try_catch.catch_body->type == IR_BLOCK) {
                                                    // For blocks, we need to extract the value from the last statement
                                                    // This is complex - for now, generate the block and assume it returns a value
                                                    // Actually, the catch block should end with an expression statement
                                                    for (int i = 0; i < try_catch_inst->data.try_catch.catch_body->data.block.inst_count; i++) {
                                                        if (!try_catch_inst->data.try_catch.catch_body->data.block.insts[i]) continue;
                                                        if (i == try_catch_inst->data.try_catch.catch_body->data.block.inst_count - 1) {
                                                            // Last statement: should be an expression, assign to variable
                                                            fprintf(codegen->output_file, "%s = ", body_inst->data.var.name);
                                                            codegen_write_value(codegen, try_catch_inst->data.try_catch.catch_body->data.block.insts[i]);
                                                            fprintf(codegen->output_file, ";\n  ");
                                                        } else {
                                                            // Non-last statements: generate normally
                                                            codegen_generate_inst(codegen, try_catch_inst->data.try_catch.catch_body->data.block.insts[i]);
                                                            fprintf(codegen->output_file, ";\n  ");
                                                        }
                                                    }
                                                } else {
                                                    // Single statement: assign to variable
                                                    fprintf(codegen->output_file, "%s = ", body_inst->data.var.name);
                                                    codegen_write_value(codegen, try_catch_inst->data.try_catch.catch_body);
                                                    fprintf(codegen->output_file, ";\n  ");
                                                }
                                            }
                                            fprintf(codegen->output_file, "} else {\n  ");
                                            // Success case: assign value from error union
                                            if (base_type != IR_TYPE_VOID) {
                                                fprintf(codegen->output_file, "%s = %s.value;\n  ", body_inst->data.var.name, temp_var);
                                            }
                                            fprintf(codegen->output_file, "}\n");
                                        }
                                    } else {
                                        fprintf(codegen->output_file, " = ");
                                        codegen_write_value(codegen, body_inst->data.var.init);
                                    }
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
                            // 检查目标是否是表达式（如 arr[0]）还是简单变量
                            if (body_inst->data.assign.dest_expr) {
                                // 表达式赋值：arr[0] = value
                                codegen_write_value(codegen, body_inst->data.assign.dest_expr);
                                fprintf(codegen->output_file, " = ");
                            } else if (body_inst->data.assign.dest) {
                                // 简单变量赋值：var = value
                                fprintf(codegen->output_file, "%s = ", body_inst->data.assign.dest);
                            } else {
                                fprintf(codegen->output_file, "/* unknown dest */ = ");
                            }
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
                        case IR_TRY_CATCH:
                            // Generate try/catch expression - delegate to top-level handler
                            // Note: This generates multi-line code (complete statement), so we don't add semicolon here
                            // The codegen_generate_inst will handle the full try/catch structure
                            codegen_generate_inst(codegen, body_inst);
                            fprintf(codegen->output_file, "\n");
                            break;
                        // 处理其他指令类型...
                        default:
                            fprintf(codegen->output_file, "/* Unknown instruction: %d */", body_inst->type);
                            break;
                    }
                    // Only add semicolon if not IR_TRY_CATCH (which generates complete statement)
                    if (body_inst->type != IR_TRY_CATCH) {
                        fprintf(codegen->output_file, ";\n");
                    }
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
                // Special handling for array variable declarations: let arr: [i32 : 3] = [1, 2, 3];
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
                            size_t actual_len = 0; // We'll need to implement this function in the value module
                            // For now, we'll just call the function directly here
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
                    } else if (inst->data.var.type == IR_TYPE_PTR && inst->data.var.original_type_name) {
                        const char *c_type_name = codegen_convert_uya_type_to_c(inst->data.var.original_type_name);
                        fprintf(codegen->output_file, "%s* %s = _tmp_%s",
                                c_type_name ? c_type_name : inst->data.var.original_type_name, inst->data.var.name, inst->data.var.name);
                    } else {
                        codegen_write_type(codegen, inst->data.var.type);
                        fprintf(codegen->output_file, " %s = _tmp_%s", inst->data.var.name, inst->data.var.name);
                    }
                } else {
                    if (inst->data.var.type == IR_TYPE_STRUCT && inst->data.var.original_type_name) {
                        fprintf(codegen->output_file, "%s %s", inst->data.var.original_type_name, inst->data.var.name);
                    } else if (inst->data.var.type == IR_TYPE_PTR && inst->data.var.original_type_name) {
                        const char *c_type_name = codegen_convert_uya_type_to_c(inst->data.var.original_type_name);
                        fprintf(codegen->output_file, "%s* %s", c_type_name ? c_type_name : inst->data.var.original_type_name, inst->data.var.name);
                    } else if (inst->data.var.type == IR_TYPE_FN) {
                        // 函数指针类型：使用通用函数指针类型 void(*)()
                        fprintf(codegen->output_file, "void(*%s)()", inst->data.var.name);
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
                fprintf(codegen->output_file, "}");
            } else {
                fprintf(codegen->output_file, "}");
            }
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
                    // If catch_body is a block, generate its contents without the outer braces
                    // since we're already inside an if statement block
                    if (inst->data.try_catch.catch_body->type == IR_BLOCK) {
                        for (int i = 0; i < inst->data.try_catch.catch_body->data.block.inst_count; i++) {
                            if (!inst->data.try_catch.catch_body->data.block.insts[i]) continue;
                            fprintf(codegen->output_file, "  ");
                            codegen_generate_inst(codegen, inst->data.try_catch.catch_body->data.block.insts[i]);
                            fprintf(codegen->output_file, ";\n");
                        }
                    } else {
                        codegen_generate_inst(codegen, inst->data.try_catch.catch_body);
                    }
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

        case IR_ENUM_DECL:
            // Generate enum declaration: typedef enum { Variant1, Variant2 = value, ... } EnumName;
            fprintf(codegen->output_file, "typedef enum {\n");
            for (int i = 0; i < inst->data.enum_decl.variant_count; i++) {
                fprintf(codegen->output_file, "  %s_%s", inst->data.enum_decl.name, inst->data.enum_decl.variant_names[i]);
                if (inst->data.enum_decl.variant_values[i]) {
                    // Explicit value specified
                    fprintf(codegen->output_file, " = %s", inst->data.enum_decl.variant_values[i]);
                }
                if (i < inst->data.enum_decl.variant_count - 1) {
                    fprintf(codegen->output_file, ",");
                }
                fprintf(codegen->output_file, "\n");
            }
            fprintf(codegen->output_file, "} %s;\n\n", inst->data.enum_decl.name);
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