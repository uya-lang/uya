#include "ir_generator_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

IRInst *generate_stmt_for_body(IRGenerator *ir_gen, struct ASTNode *stmt) {
    if (!stmt) return NULL;

    switch (stmt->type) {
        case AST_VAR_DECL: {
            IRInst *var_decl = irinst_new(IR_VAR_DECL);
            if (!var_decl) return NULL;

            var_decl->data.var.name = malloc(strlen(stmt->data.var_decl.name) + 1);
            if (!var_decl->data.var.name) {
                irinst_free(var_decl);
                return NULL;
            }
            strcpy(var_decl->data.var.name, stmt->data.var_decl.name);
            
            // Check if the type is atomic
            var_decl->data.var.is_atomic = (stmt->data.var_decl.type && stmt->data.var_decl.type->type == AST_TYPE_ATOMIC) ? 1 : 0;
            
            var_decl->data.var.type = get_ir_type(stmt->data.var_decl.type);
            var_decl->data.var.is_mut = stmt->data.var_decl.is_mut;

            // Ensure tuple struct declaration exists if type is tuple
            if (stmt->data.var_decl.type && stmt->data.var_decl.type->type == AST_TYPE_TUPLE) {
                IRInst *tuple_struct = ensure_tuple_struct_decl(ir_gen, stmt->data.var_decl.type);
                if (!tuple_struct) {
                    irinst_free(var_decl);
                    return NULL;
                }
                // Store the tuple type name as original_type_name
                char *tuple_type_name = generate_tuple_type_name(stmt->data.var_decl.type);
                if (tuple_type_name) {
                    var_decl->data.var.original_type_name = tuple_type_name;
                }
            }

            // Store original type name for user-defined types
            if (stmt->data.var_decl.type) {
                if (stmt->data.var_decl.type->type == AST_TYPE_TUPLE) {
                    // Already handled above, skip
                } else if (stmt->data.var_decl.type->type == AST_TYPE_POINTER && stmt->data.var_decl.type->data.type_pointer.pointee_type) {
                    // For pointer types, extract the pointee type name
                    struct ASTNode *pointee_type = stmt->data.var_decl.type->data.type_pointer.pointee_type;
                    if (pointee_type->type == AST_TYPE_NAMED) {
                        const char *type_name = pointee_type->data.type_named.name;
                        // For pointer types, store the pointee type name (including built-in types like i32)
                        // This is needed for code generation to generate the correct type (e.g., int32_t* instead of void*)
                        var_decl->data.var.original_type_name = malloc(strlen(type_name) + 1);
                        if (var_decl->data.var.original_type_name) {
                            strcpy(var_decl->data.var.original_type_name, type_name);
                        }
                    } else {
                        var_decl->data.var.original_type_name = NULL;
                    }
                } else if (stmt->data.var_decl.type->type == AST_TYPE_ARRAY) {
                    // For array types, extract element type name
                    struct ASTNode *element_type = stmt->data.var_decl.type->data.type_array.element_type;
                    if (element_type && element_type->type == AST_TYPE_NAMED) {
                        const char *type_name = element_type->data.type_named.name;
                        // Check if it's a user-defined type (not a built-in type)
                        if (strcmp(type_name, "i32") != 0 && strcmp(type_name, "i64") != 0 &&
                            strcmp(type_name, "i8") != 0 && strcmp(type_name, "i16") != 0 &&
                            strcmp(type_name, "u32") != 0 && strcmp(type_name, "u64") != 0 &&
                            strcmp(type_name, "u8") != 0 && strcmp(type_name, "u16") != 0 &&
                            strcmp(type_name, "f32") != 0 && strcmp(type_name, "f64") != 0 &&
                            strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0 &&
                            strcmp(type_name, "byte") != 0) {
                            // This is a user-defined type, store the original name
                            var_decl->data.var.original_type_name = malloc(strlen(type_name) + 1);
                            if (var_decl->data.var.original_type_name) {
                                strcpy(var_decl->data.var.original_type_name, type_name);
                            }
                        } else {
                            var_decl->data.var.original_type_name = NULL;
                        }
                    } else {
                        var_decl->data.var.original_type_name = NULL;
                    }
                } else if (stmt->data.var_decl.type->type == AST_TYPE_NAMED) {
                    const char *type_name = stmt->data.var_decl.type->data.type_named.name;
                    // Check if it's a user-defined type (not a built-in type)
                    if (strcmp(type_name, "i32") != 0 && strcmp(type_name, "i64") != 0 &&
                        strcmp(type_name, "i8") != 0 && strcmp(type_name, "i16") != 0 &&
                        strcmp(type_name, "u32") != 0 && strcmp(type_name, "u64") != 0 &&
                        strcmp(type_name, "u8") != 0 && strcmp(type_name, "u16") != 0 &&
                        strcmp(type_name, "f32") != 0 && strcmp(type_name, "f64") != 0 &&
                        strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0 &&
                        strcmp(type_name, "byte") != 0) {
                        // This is a user-defined type, store the original name
                        var_decl->data.var.original_type_name = malloc(strlen(type_name) + 1);
                        if (var_decl->data.var.original_type_name) {
                            strcpy(var_decl->data.var.original_type_name, type_name);
                        }
                    } else {
                        var_decl->data.var.original_type_name = NULL;
                    }
                } else if (stmt->data.var_decl.type->type == AST_TYPE_TUPLE) {
                    // Already handled above, skip (tuple type name is already set)
                } else {
                    var_decl->data.var.original_type_name = NULL;
                }
            } else {
                var_decl->data.var.original_type_name = NULL;
            }

            if (stmt->data.var_decl.init) {
                var_decl->data.var.init = generate_expr(ir_gen, stmt->data.var_decl.init);
                
                // If variable type is tuple and init is tuple literal (IR_STRUCT_INIT with tuple_N name),
                // update the struct_name to use the correct tuple type name
                if (stmt->data.var_decl.type && stmt->data.var_decl.type->type == AST_TYPE_TUPLE &&
                    var_decl->data.var.init && var_decl->data.var.init->type == IR_STRUCT_INIT &&
                    var_decl->data.var.original_type_name) {
                    // Check if struct_name is in tuple_N format
                    const char *struct_name = var_decl->data.var.init->data.struct_init.struct_name;
                    if (struct_name && strncmp(struct_name, "tuple_", 6) == 0) {
                        // Check if it's the old format (tuple_N where N is just a number)
                        int is_old_format = 1;
                        for (int i = 6; struct_name[i] != '\0'; i++) {
                            if (struct_name[i] < '0' || struct_name[i] > '9') {
                                is_old_format = 0;
                                break;
                            }
                        }
                        if (is_old_format) {
                            // Update struct_name to use the correct tuple type name
                            free(var_decl->data.var.init->data.struct_init.struct_name);
                            var_decl->data.var.init->data.struct_init.struct_name = malloc(strlen(var_decl->data.var.original_type_name) + 1);
                            if (var_decl->data.var.init->data.struct_init.struct_name) {
                                strcpy(var_decl->data.var.init->data.struct_init.struct_name, var_decl->data.var.original_type_name);
                            }
                        }
                    }
                }
            } else {
                var_decl->data.var.init = NULL;
            }

            return var_decl;
        }

        case AST_RETURN_STMT: {
            IRInst *ret = irinst_new(IR_RETURN);
            if (!ret) return NULL;

            if (stmt->data.return_stmt.expr) {
                ret->data.ret.value = generate_expr(ir_gen, stmt->data.return_stmt.expr);
            } else {
                ret->data.ret.value = NULL; // void return
            }

            return ret;
        }

        case AST_IF_STMT: {
            IRInst *if_inst = irinst_new(IR_IF);
            if (!if_inst) return NULL;

            // Generate condition
            if_inst->data.if_stmt.condition = generate_expr(ir_gen, stmt->data.if_stmt.condition);

            // Generate then body
            if (stmt->data.if_stmt.then_branch) {
                if (stmt->data.if_stmt.then_branch->type == AST_BLOCK) {
                    if_inst->data.if_stmt.then_count = stmt->data.if_stmt.then_branch->data.block.stmt_count;
                    if_inst->data.if_stmt.then_body = malloc(if_inst->data.if_stmt.then_count * sizeof(IRInst*));
                    if (!if_inst->data.if_stmt.then_body) {
                        irinst_free(if_inst);
                        return NULL;
                    }

                    for (int i = 0; i < if_inst->data.if_stmt.then_count; i++) {
                        if_inst->data.if_stmt.then_body[i] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.then_branch->data.block.stmts[i]);
                    }
                } else {
                    if_inst->data.if_stmt.then_count = 1;
                    if_inst->data.if_stmt.then_body = malloc(sizeof(IRInst*));
                    if (if_inst->data.if_stmt.then_body) {
                        if_inst->data.if_stmt.then_body[0] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.then_branch);
                    }
                }
            } else {
                if_inst->data.if_stmt.then_count = 0;
                if_inst->data.if_stmt.then_body = NULL;
            }

            // Generate else body
            if (stmt->data.if_stmt.else_branch) {
                if (stmt->data.if_stmt.else_branch->type == AST_IF_STMT) {
                    // This is an else-if chain, so generate nested IR_IF
                    if_inst->data.if_stmt.else_count = 1;
                    if_inst->data.if_stmt.else_body = malloc(sizeof(IRInst*));
                    if (if_inst->data.if_stmt.else_body) {
                        if_inst->data.if_stmt.else_body[0] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.else_branch);
                    }
                } else if (stmt->data.if_stmt.else_branch->type == AST_BLOCK) {
                    if_inst->data.if_stmt.else_count = stmt->data.if_stmt.else_branch->data.block.stmt_count;
                    if_inst->data.if_stmt.else_body = malloc(if_inst->data.if_stmt.else_count * sizeof(IRInst*));
                    if (!if_inst->data.if_stmt.else_body) {
                        // Clean up then body
                        if (if_inst->data.if_stmt.then_body) {
                            free(if_inst->data.if_stmt.then_body);
                        }
                        irinst_free(if_inst);
                        return NULL;
                    }

                    for (int i = 0; i < if_inst->data.if_stmt.else_count; i++) {
                        if_inst->data.if_stmt.else_body[i] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.else_branch->data.block.stmts[i]);
                    }
                } else {
                    if_inst->data.if_stmt.else_count = 1;
                    if_inst->data.if_stmt.else_body = malloc(sizeof(IRInst*));
                    if (if_inst->data.if_stmt.else_body) {
                        if_inst->data.if_stmt.else_body[0] = generate_stmt_for_body(ir_gen, stmt->data.if_stmt.else_branch);
                    }
                }
            } else {
                if_inst->data.if_stmt.else_count = 0;
                if_inst->data.if_stmt.else_body = NULL;
            }

            return if_inst;
        }

        case AST_WHILE_STMT: {
            IRInst *while_inst = irinst_new(IR_WHILE);
            if (!while_inst) return NULL;

            // Generate condition
            while_inst->data.while_stmt.condition = generate_expr(ir_gen, stmt->data.while_stmt.condition);

            // Generate body
            if (stmt->data.while_stmt.body) {
                if (stmt->data.while_stmt.body->type == AST_BLOCK) {
                    while_inst->data.while_stmt.body_count = stmt->data.while_stmt.body->data.block.stmt_count;
                    while_inst->data.while_stmt.body = malloc(while_inst->data.while_stmt.body_count * sizeof(IRInst*));
                    if (!while_inst->data.while_stmt.body) {
                        irinst_free(while_inst);
                        return NULL;
                    }

                    for (int i = 0; i < while_inst->data.while_stmt.body_count; i++) {
                        while_inst->data.while_stmt.body[i] = generate_stmt_for_body(ir_gen, stmt->data.while_stmt.body->data.block.stmts[i]);
                    }
                } else {
                    while_inst->data.while_stmt.body_count = 1;
                    while_inst->data.while_stmt.body = malloc(sizeof(IRInst*));
                    if (while_inst->data.while_stmt.body) {
                        while_inst->data.while_stmt.body[0] = generate_stmt_for_body(ir_gen, stmt->data.while_stmt.body);
                    }
                }
            } else {
                while_inst->data.while_stmt.body_count = 0;
                while_inst->data.while_stmt.body = NULL;
            }

            return while_inst;
        }

        case AST_FOR_STMT: {
            IRInst *for_inst = irinst_new(IR_FOR);
            if (!for_inst) return NULL;

            // Generate iterable expression
            for_inst->data.for_stmt.iterable = generate_expr(ir_gen, stmt->data.for_stmt.iterable);

            // Generate index range (if present)
            if (stmt->data.for_stmt.index_range) {
                for_inst->data.for_stmt.index_range = generate_expr(ir_gen, stmt->data.for_stmt.index_range);
            } else {
                for_inst->data.for_stmt.index_range = NULL;
            }

            // Copy variable names
            if (stmt->data.for_stmt.item_var) {
                for_inst->data.for_stmt.item_var = malloc(strlen(stmt->data.for_stmt.item_var) + 1);
                if (for_inst->data.for_stmt.item_var) {
                    strcpy(for_inst->data.for_stmt.item_var, stmt->data.for_stmt.item_var);
                }
            } else {
                for_inst->data.for_stmt.item_var = NULL;
            }

            if (stmt->data.for_stmt.index_var) {
                for_inst->data.for_stmt.index_var = malloc(strlen(stmt->data.for_stmt.index_var) + 1);
                if (for_inst->data.for_stmt.index_var) {
                    strcpy(for_inst->data.for_stmt.index_var, stmt->data.for_stmt.index_var);
                }
            } else {
                for_inst->data.for_stmt.index_var = NULL;
            }

            // Generate body
            if (stmt->data.for_stmt.body) {
                if (stmt->data.for_stmt.body->type == AST_BLOCK) {
                    for_inst->data.for_stmt.body_count = stmt->data.for_stmt.body->data.block.stmt_count;
                    for_inst->data.for_stmt.body = malloc(for_inst->data.for_stmt.body_count * sizeof(IRInst*));
                    if (!for_inst->data.for_stmt.body) {
                        irinst_free(for_inst);
                        return NULL;
                    }

                    for (int i = 0; i < for_inst->data.for_stmt.body_count; i++) {
                        for_inst->data.for_stmt.body[i] = generate_stmt_for_body(ir_gen, stmt->data.for_stmt.body->data.block.stmts[i]);
                    }
                } else {
                    for_inst->data.for_stmt.body_count = 1;
                    for_inst->data.for_stmt.body = malloc(sizeof(IRInst*));
                    if (for_inst->data.for_stmt.body) {
                        for_inst->data.for_stmt.body[0] = generate_stmt_for_body(ir_gen, stmt->data.for_stmt.body);
                    }
                }
            } else {
                for_inst->data.for_stmt.body_count = 0;
                for_inst->data.for_stmt.body = NULL;
            }

            return for_inst;
        }

        case AST_ASSIGN: {
            IRInst *assign = irinst_new(IR_ASSIGN);
            if (!assign) return NULL;

            // 检查目标是否是表达式（如 arr[0]）还是简单变量
            if (stmt->data.assign.dest_expr) {
                // 表达式赋值：arr[0] = value
                assign->data.assign.dest = NULL;
                assign->data.assign.dest_expr = generate_expr(ir_gen, stmt->data.assign.dest_expr);
            } else if (stmt->data.assign.dest) {
                // 简单变量赋值：var = value
                assign->data.assign.dest = malloc(strlen(stmt->data.assign.dest) + 1);
                if (assign->data.assign.dest) {
                    strcpy(assign->data.assign.dest, stmt->data.assign.dest);
                }
                assign->data.assign.dest_expr = NULL;
            } else {
                assign->data.assign.dest = NULL;
                assign->data.assign.dest_expr = NULL;
            }

            // Set source (right-hand side expression)
            if (stmt->data.assign.src) {
                assign->data.assign.src = generate_expr(ir_gen, stmt->data.assign.src);
            } else {
                assign->data.assign.src = NULL;
            }

            return assign;
        }

        case AST_DEFER_STMT: {
            IRInst *defer_inst = irinst_new(IR_DEFER);
            if (!defer_inst) return NULL;

            // Generate defer body
            if (stmt->data.defer_stmt.body) {
                if (stmt->data.defer_stmt.body->type == AST_BLOCK) {
                    defer_inst->data.defer.body_count = stmt->data.defer_stmt.body->data.block.stmt_count;
                    defer_inst->data.defer.body = malloc(defer_inst->data.defer.body_count * sizeof(IRInst*));
                    if (!defer_inst->data.defer.body) {
                        irinst_free(defer_inst);
                        return NULL;
                    }

                    for (int i = 0; i < defer_inst->data.defer.body_count; i++) {
                        defer_inst->data.defer.body[i] = generate_stmt_for_body(ir_gen, stmt->data.defer_stmt.body->data.block.stmts[i]);
                    }
                } else {
                    defer_inst->data.defer.body_count = 1;
                    defer_inst->data.defer.body = malloc(sizeof(IRInst*));
                    if (defer_inst->data.defer.body) {
                        defer_inst->data.defer.body[0] = generate_stmt_for_body(ir_gen, stmt->data.defer_stmt.body);
                    }
                }
            } else {
                defer_inst->data.defer.body_count = 0;
                defer_inst->data.defer.body = NULL;
            }

            return defer_inst;
        }

        case AST_ERRDEFER_STMT: {
            IRInst *errdefer_inst = irinst_new(IR_ERRDEFER);
            if (!errdefer_inst) return NULL;

            // Generate errdefer body
            if (stmt->data.errdefer_stmt.body) {
                if (stmt->data.errdefer_stmt.body->type == AST_BLOCK) {
                    errdefer_inst->data.errdefer.body_count = stmt->data.errdefer_stmt.body->data.block.stmt_count;
                    errdefer_inst->data.errdefer.body = malloc(errdefer_inst->data.errdefer.body_count * sizeof(IRInst*));
                    if (!errdefer_inst->data.errdefer.body) {
                        irinst_free(errdefer_inst);
                        return NULL;
                    }

                    for (int i = 0; i < errdefer_inst->data.errdefer.body_count; i++) {
                        errdefer_inst->data.errdefer.body[i] = generate_stmt_for_body(ir_gen, stmt->data.errdefer_stmt.body->data.block.stmts[i]);
                    }
                } else {
                    errdefer_inst->data.errdefer.body_count = 1;
                    errdefer_inst->data.errdefer.body = malloc(sizeof(IRInst*));
                    if (errdefer_inst->data.errdefer.body) {
                        errdefer_inst->data.errdefer.body[0] = generate_stmt_for_body(ir_gen, stmt->data.errdefer_stmt.body);
                    }
                }
            } else {
                errdefer_inst->data.errdefer.body_count = 0;
                errdefer_inst->data.errdefer.body = NULL;
            }

            return errdefer_inst;
        }

        case AST_BLOCK: {
            // Handle nested blocks - generate IR_BLOCK instruction
            IRInst *block_inst = irinst_new(IR_BLOCK);
            if (!block_inst) return NULL;

            block_inst->data.block.inst_count = stmt->data.block.stmt_count;
            block_inst->data.block.insts = malloc(block_inst->data.block.inst_count * sizeof(IRInst*));
            if (!block_inst->data.block.insts) {
                irinst_free(block_inst);
                return NULL;
            }

            for (int i = 0; i < block_inst->data.block.inst_count; i++) {
                block_inst->data.block.insts[i] = generate_stmt_for_body(ir_gen, stmt->data.block.stmts[i]);
            }

            return block_inst;
        }

        case AST_CALL_EXPR:
            // Expression statement: function call as a statement
            // Convert the call expression directly to IR_CALL
            return generate_expr(ir_gen, stmt);

        case AST_CATCH_EXPR:
            // Catch expression statement: expr catch |err| { ... }
            // Convert catch expression to IR_TRY_CATCH
            return generate_expr(ir_gen, stmt);

        case AST_MATCH_EXPR:
            // Match expression statement: match expr { pattern => body, ... }
            // Convert match expression to IR_IF (nested if-else chain)
            return generate_expr(ir_gen, stmt);

        case AST_BINARY_EXPR:
        case AST_UNARY_EXPR:
        case AST_IDENTIFIER:
        case AST_NUMBER:
        case AST_STRING:
        case AST_STRING_INTERPOLATION:
        case AST_BOOL:
        case AST_NULL:
        case AST_MEMBER_ACCESS:
        case AST_SUBSCRIPT_EXPR:
            // Other expression types used as statements
            // Convert expression to IR (discard result for statement form)
            return generate_expr(ir_gen, stmt);

        default:
            return NULL;
    }
}

IRInst *generate_stmt(IRGenerator *ir_gen, struct ASTNode *stmt) {
    // Top-level statements (like function declarations) should be added to main array
    // Function body statements should only be stored in the function's body array
    IRInst *result = generate_stmt_for_body(ir_gen, stmt);

    return result;
}
