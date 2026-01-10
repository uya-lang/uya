#include "ir_generator_internal.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

IRInst *generate_function(IRGenerator *ir_gen, struct ASTNode *fn_decl) {
    if (!fn_decl || fn_decl->type != AST_FN_DECL) return NULL;

    IRInst *func = irinst_new(IR_FUNC_DEF);
    if (!func) return NULL;

    // Set function name
    func->data.func.name = malloc(strlen(fn_decl->data.fn_decl.name) + 1);
    if (!func->data.func.name) {
        irinst_free(func);
        return NULL;
    }
    strcpy(func->data.func.name, fn_decl->data.fn_decl.name);

    // Set return type
    func->data.func.return_type = get_ir_type(fn_decl->data.fn_decl.return_type);
    func->data.func.is_extern = fn_decl->data.fn_decl.is_extern;
    
    // Check if return type is error union (!T)
    func->data.func.return_type_is_error_union = (fn_decl->data.fn_decl.return_type && 
                                                   fn_decl->data.fn_decl.return_type->type == AST_TYPE_ERROR_UNION) ? 1 : 0;
    
    // Extract return type name for struct types
    func->data.func.return_type_original_name = NULL;
    if (fn_decl->data.fn_decl.return_type && 
        fn_decl->data.fn_decl.return_type->type == AST_TYPE_NAMED &&
        func->data.func.return_type == IR_TYPE_STRUCT) {
        const char *type_name = fn_decl->data.fn_decl.return_type->data.type_named.name;
        if (type_name) {
            func->data.func.return_type_original_name = malloc(strlen(type_name) + 1);
            if (func->data.func.return_type_original_name) {
                strcpy(func->data.func.return_type_original_name, type_name);
            }
        }
    }

    // Handle parameters
    func->data.func.param_count = fn_decl->data.fn_decl.param_count;
    if (fn_decl->data.fn_decl.param_count > 0) {
        func->data.func.params = malloc(fn_decl->data.fn_decl.param_count * sizeof(IRInst*));
        if (!func->data.func.params) {
            irinst_free(func);
            return NULL;
        }

        for (int i = 0; i < fn_decl->data.fn_decl.param_count; i++) {
            // Create parameter as variable declaration
            IRInst *param = irinst_new(IR_VAR_DECL);
            if (!param) {
                irinst_free(func);
                return NULL;
            }

            param->data.var.name = malloc(strlen(fn_decl->data.fn_decl.params[i]->data.var_decl.name) + 1);
            if (!param->data.var.name) {
                irinst_free(param);
                irinst_free(func);
                return NULL;
            }
            strcpy(param->data.var.name, fn_decl->data.fn_decl.params[i]->data.var_decl.name);
            param->data.var.type = get_ir_type(fn_decl->data.fn_decl.params[i]->data.var_decl.type);
            param->data.var.init = NULL;

            // Store original type name for pointer types and struct types
            struct ASTNode *param_type = fn_decl->data.fn_decl.params[i]->data.var_decl.type;
            if (param_type) {
                if (param_type->type == AST_TYPE_POINTER && param_type->data.type_pointer.pointee_type) {
                    // For pointer types, extract the pointee type name
                    struct ASTNode *pointee_type = param_type->data.type_pointer.pointee_type;
                    if (pointee_type->type == AST_TYPE_NAMED) {
                        const char *type_name = pointee_type->data.type_named.name;
                        // Replace "Self" with struct name if we're in an impl context (passed via global state)
                        // For now, we'll check if it's "Self" and replace it later if needed
                        // Check if it's a user-defined type (not a built-in type) or "Self"
                        if (strcmp(type_name, "Self") == 0 || 
                            (strcmp(type_name, "i32") != 0 && strcmp(type_name, "i64") != 0 &&
                             strcmp(type_name, "i8") != 0 && strcmp(type_name, "i16") != 0 &&
                             strcmp(type_name, "u32") != 0 && strcmp(type_name, "u64") != 0 &&
                             strcmp(type_name, "u8") != 0 && strcmp(type_name, "u16") != 0 &&
                             strcmp(type_name, "f32") != 0 && strcmp(type_name, "f64") != 0 &&
                             strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0 &&
                             strcmp(type_name, "byte") != 0)) {
                            param->data.var.original_type_name = malloc(strlen(type_name) + 1);
                            if (param->data.var.original_type_name) {
                                strcpy(param->data.var.original_type_name, type_name);
                            }
                        } else {
                            param->data.var.original_type_name = NULL;
                        }
                    } else {
                        param->data.var.original_type_name = NULL;
                    }
                } else if (param_type->type == AST_TYPE_NAMED) {
                    const char *type_name = param_type->data.type_named.name;
                    // Check if it's a user-defined type (not a built-in type)
                    if (strcmp(type_name, "i32") != 0 && strcmp(type_name, "i64") != 0 &&
                        strcmp(type_name, "i8") != 0 && strcmp(type_name, "i16") != 0 &&
                        strcmp(type_name, "u32") != 0 && strcmp(type_name, "u64") != 0 &&
                        strcmp(type_name, "u8") != 0 && strcmp(type_name, "u16") != 0 &&
                        strcmp(type_name, "f32") != 0 && strcmp(type_name, "f64") != 0 &&
                        strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0 &&
                        strcmp(type_name, "byte") != 0) {
                        param->data.var.original_type_name = malloc(strlen(type_name) + 1);
                        if (param->data.var.original_type_name) {
                            strcpy(param->data.var.original_type_name, type_name);
                        }
                    } else {
                        param->data.var.original_type_name = NULL;
                    }
                } else {
                    param->data.var.original_type_name = NULL;
                }
            } else {
                param->data.var.original_type_name = NULL;
            }

            func->data.func.params[i] = param;
        }
    } else {
        func->data.func.params = NULL;
    }

    // Handle function body - convert AST statements to IR instructions
    if (fn_decl->data.fn_decl.body) {
        if (fn_decl->data.fn_decl.body->type == AST_BLOCK) {
            func->data.func.body_count = fn_decl->data.fn_decl.body->data.block.stmt_count;
            // Debug: print function name and statement count
            if (fn_decl->data.fn_decl.name && strcmp(fn_decl->data.fn_decl.name, "main") == 0) {
                fprintf(stderr, "[DEBUG IR] Function '%s' has %d statements in AST\n", 
                        fn_decl->data.fn_decl.name, func->data.func.body_count);
            }
            func->data.func.body = malloc(func->data.func.body_count * sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }

            int null_count = 0;
            for (int i = 0; i < func->data.func.body_count; i++) {
                // Set up the IR instruction based on the AST statement type
                struct ASTNode *ast_stmt = fn_decl->data.fn_decl.body->data.block.stmts[i];
                IRInst *stmt_ir = generate_stmt(ir_gen, ast_stmt);
                if (!stmt_ir && fn_decl->data.fn_decl.name && strcmp(fn_decl->data.fn_decl.name, "main") == 0) {
                    fprintf(stderr, "[DEBUG IR] Statement %d in 'main' generated NULL IR (AST type: %d)\n", 
                            i, ast_stmt ? ast_stmt->type : -1);
                    null_count++;
                }
                func->data.func.body[i] = stmt_ir;
            }
            if (fn_decl->data.fn_decl.name && strcmp(fn_decl->data.fn_decl.name, "main") == 0 && null_count > 0) {
                fprintf(stderr, "[DEBUG IR] Function 'main' has %d NULL statements out of %d total\n", 
                        null_count, func->data.func.body_count);
            }
        } else {
            // Single statement body
            func->data.func.body_count = 1;
            func->data.func.body = malloc(sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }

            // Handle single statement
            struct ASTNode *ast_stmt = fn_decl->data.fn_decl.body;
            IRInst *stmt_ir = NULL;

            if (ast_stmt->type == AST_VAR_DECL) {
                stmt_ir = irinst_new(IR_VAR_DECL);
                if (stmt_ir) {
                    stmt_ir->data.var.name = malloc(strlen(ast_stmt->data.var_decl.name) + 1);
                    if (stmt_ir->data.var.name) {
                        strcpy(stmt_ir->data.var.name, ast_stmt->data.var_decl.name);
                        stmt_ir->data.var.type = get_ir_type(ast_stmt->data.var_decl.type);
                        stmt_ir->data.var.is_mut = ast_stmt->data.var_decl.is_mut;

                        // Ensure tuple struct declaration exists if type is tuple
                        if (ast_stmt->data.var_decl.type && ast_stmt->data.var_decl.type->type == AST_TYPE_TUPLE) {
                            IRInst *tuple_struct = ensure_tuple_struct_decl(ir_gen, ast_stmt->data.var_decl.type);
                            if (!tuple_struct) {
                                free(stmt_ir->data.var.name);
                                irinst_free(stmt_ir);
                                stmt_ir = NULL;
                            } else {
                                // Store the tuple type name as original_type_name
                                char *tuple_type_name = generate_tuple_type_name(ast_stmt->data.var_decl.type);
                                if (tuple_type_name) {
                                    stmt_ir->data.var.original_type_name = tuple_type_name;
                                } else {
                                    stmt_ir->data.var.original_type_name = NULL;
                                }
                            }
                        } else {
                            stmt_ir->data.var.original_type_name = NULL;
                        }

                        // Handle initialization
                        if (ast_stmt->data.var_decl.init && stmt_ir) {
                            stmt_ir->data.var.init = generate_expr(ir_gen, ast_stmt->data.var_decl.init);
                        }
                    }
                }
            } else if (ast_stmt->type == AST_RETURN_STMT) {
                stmt_ir = irinst_new(IR_RETURN);
                if (stmt_ir && ast_stmt->data.return_stmt.expr) {
                    stmt_ir->data.ret.value = generate_expr(ir_gen, ast_stmt->data.return_stmt.expr);
                }
            } else if (ast_stmt->type == AST_IF_STMT) {
                stmt_ir = irinst_new(IR_IF);
                if (stmt_ir) {
                    // Generate condition
                    stmt_ir->data.if_stmt.condition = generate_expr(ir_gen, ast_stmt->data.if_stmt.condition);

                    // Generate then body
                    if (ast_stmt->data.if_stmt.then_branch) {
                        if (ast_stmt->data.if_stmt.then_branch->type == AST_BLOCK) {
                            stmt_ir->data.if_stmt.then_count = ast_stmt->data.if_stmt.then_branch->data.block.stmt_count;
                            stmt_ir->data.if_stmt.then_body = malloc(stmt_ir->data.if_stmt.then_count * sizeof(IRInst*));
                            if (stmt_ir->data.if_stmt.then_body) {
                                for (int j = 0; j < stmt_ir->data.if_stmt.then_count; j++) {
                                    stmt_ir->data.if_stmt.then_body[j] = generate_stmt(ir_gen, ast_stmt->data.if_stmt.then_branch->data.block.stmts[j]);
                                }
                            }
                        } else {
                            stmt_ir->data.if_stmt.then_count = 1;
                            stmt_ir->data.if_stmt.then_body = malloc(sizeof(IRInst*));
                            if (stmt_ir->data.if_stmt.then_body) {
                                stmt_ir->data.if_stmt.then_body[0] = generate_stmt(ir_gen, ast_stmt->data.if_stmt.then_branch);
                            }
                        }
                    } else {
                        stmt_ir->data.if_stmt.then_count = 0;
                        stmt_ir->data.if_stmt.then_body = NULL;
                    }

                    // Generate else body
                    if (ast_stmt->data.if_stmt.else_branch) {
                        if (ast_stmt->data.if_stmt.else_branch->type == AST_BLOCK) {
                            stmt_ir->data.if_stmt.else_count = ast_stmt->data.if_stmt.else_branch->data.block.stmt_count;
                            stmt_ir->data.if_stmt.else_body = malloc(stmt_ir->data.if_stmt.else_count * sizeof(IRInst*));
                            if (stmt_ir->data.if_stmt.else_body) {
                                for (int j = 0; j < stmt_ir->data.if_stmt.else_count; j++) {
                                    stmt_ir->data.if_stmt.else_body[j] = generate_stmt(ir_gen, ast_stmt->data.if_stmt.else_branch->data.block.stmts[j]);
                                }
                            }
                        } else {
                            stmt_ir->data.if_stmt.else_count = 1;
                            stmt_ir->data.if_stmt.else_body = malloc(sizeof(IRInst*));
                            if (stmt_ir->data.if_stmt.else_body) {
                                stmt_ir->data.if_stmt.else_body[0] = generate_stmt(ir_gen, ast_stmt->data.if_stmt.else_branch);
                            }
                        }
                    } else {
                        stmt_ir->data.if_stmt.else_count = 0;
                        stmt_ir->data.if_stmt.else_body = NULL;
                    }
                }
            } else if (ast_stmt->type == AST_WHILE_STMT) {
                stmt_ir = irinst_new(IR_WHILE);
                if (stmt_ir) {
                    // Generate condition
                    stmt_ir->data.while_stmt.condition = generate_expr(ir_gen, ast_stmt->data.while_stmt.condition);

                    // Generate body
                    if (ast_stmt->data.while_stmt.body) {
                        if (ast_stmt->data.while_stmt.body->type == AST_BLOCK) {
                            stmt_ir->data.while_stmt.body_count = ast_stmt->data.while_stmt.body->data.block.stmt_count;
                            stmt_ir->data.while_stmt.body = malloc(stmt_ir->data.while_stmt.body_count * sizeof(IRInst*));
                            if (stmt_ir->data.while_stmt.body) {
                                for (int j = 0; j < stmt_ir->data.while_stmt.body_count; j++) {
                                    stmt_ir->data.while_stmt.body[j] = generate_stmt(ir_gen, ast_stmt->data.while_stmt.body->data.block.stmts[j]);
                                }
                            }
                        } else {
                            stmt_ir->data.while_stmt.body_count = 1;
                            stmt_ir->data.while_stmt.body = malloc(sizeof(IRInst*));
                            if (stmt_ir->data.while_stmt.body) {
                                stmt_ir->data.while_stmt.body[0] = generate_stmt(ir_gen, ast_stmt->data.while_stmt.body);
                            }
                        }
                    } else {
                        stmt_ir->data.while_stmt.body_count = 0;
                        stmt_ir->data.while_stmt.body = NULL;
                    }
                }
            }

            func->data.func.body[0] = stmt_ir;
        }
    } else {
        func->data.func.body_count = 0;
        func->data.func.body = NULL;
    }

    // Add function to instructions array
    if (ir_gen->inst_count >= ir_gen->inst_capacity) {
        size_t old_capacity = ir_gen->inst_capacity;
        size_t new_capacity = old_capacity * 2;
        IRInst **new_instructions = realloc(ir_gen->instructions,
                                           new_capacity * sizeof(IRInst*));
        if (!new_instructions) {
            irinst_free(func);
            return NULL;
        }
        ir_gen->instructions = new_instructions;
        ir_gen->inst_capacity = new_capacity;
        
        // 初始化新分配的内存为NULL，防止释放未初始化的指针
        for (size_t i = old_capacity; i < new_capacity; i++) {
            ir_gen->instructions[i] = NULL;
        }
    }
    ir_gen->instructions[ir_gen->inst_count++] = func;

    return func;
}

// Generate test block as a function (returns !void, no parameters)
IRInst *generate_test_block(IRGenerator *ir_gen, struct ASTNode *test_block) {
    if (!test_block || test_block->type != AST_TEST_BLOCK) return NULL;

    IRInst *func = irinst_new(IR_FUNC_DEF);
    if (!func) return NULL;

    // Generate function name from test name (use @test$<name> format, sanitize name)
    // For now, use a simple approach: @test$ followed by a hash of the name
    char test_func_name[256];
    snprintf(test_func_name, sizeof(test_func_name), "@test$%s", test_block->data.test_block.name);
    // Replace spaces and special chars with underscores for valid C identifier
    for (char *p = test_func_name; *p; p++) {
        if (*p == ' ' || *p == '-' || *p == '.') *p = '_';
    }

    func->data.func.name = malloc(strlen(test_func_name) + 1);
    if (!func->data.func.name) {
        irinst_free(func);
        return NULL;
    }
    strcpy(func->data.func.name, test_func_name);

    // Test functions return !void (error union with void base)
    func->data.func.return_type = IR_TYPE_VOID;  // Will be handled as error union in codegen
    func->data.func.is_extern = 0;

    // No parameters for test blocks
    func->data.func.param_count = 0;
    func->data.func.params = NULL;

    // Handle test body - convert AST statements to IR instructions
    if (test_block->data.test_block.body) {
        if (test_block->data.test_block.body->type == AST_BLOCK) {
            func->data.func.body_count = test_block->data.test_block.body->data.block.stmt_count;
            func->data.func.body = malloc(func->data.func.body_count * sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }

            for (int i = 0; i < func->data.func.body_count; i++) {
                struct ASTNode *ast_stmt = test_block->data.test_block.body->data.block.stmts[i];
                IRInst *stmt_ir = generate_stmt(ir_gen, ast_stmt);
                func->data.func.body[i] = stmt_ir;
            }
        } else {
            // Single statement body
            func->data.func.body_count = 1;
            func->data.func.body = malloc(sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }
            func->data.func.body[0] = generate_stmt(ir_gen, test_block->data.test_block.body);
        }
    } else {
        func->data.func.body_count = 0;
        func->data.func.body = NULL;
    }

    // Add function to instructions array
    if (ir_gen->inst_count >= ir_gen->inst_capacity) {
        size_t new_capacity = ir_gen->inst_capacity * 2;
        IRInst **new_instructions = realloc(ir_gen->instructions,
                                           new_capacity * sizeof(IRInst*));
        if (!new_instructions) {
            irinst_free(func);
            return NULL;
        }
        ir_gen->instructions = new_instructions;
        ir_gen->inst_capacity = new_capacity;
    }
    ir_gen->instructions[ir_gen->inst_count++] = func;

    return func;
}

void generate_program(IRGenerator *ir_gen, struct ASTNode *program) {
    if (!program || program->type != AST_PROGRAM) return;

    for (int i = 0; i < program->data.program.decl_count; i++) {
        struct ASTNode *decl = program->data.program.decls[i];
        if (decl->type == AST_FN_DECL) {
            generate_function(ir_gen, decl);
        } else if (decl->type == AST_TEST_BLOCK) {
            generate_test_block(ir_gen, decl);
        } else if (decl->type == AST_IMPL_DECL) {
            // Handle impl declarations: convert each method to a regular function
            // Replace "Self" type names with the struct name in method parameters
            const char *struct_name = decl->data.impl_decl.struct_name;
            for (int j = 0; j < decl->data.impl_decl.method_count; j++) {
                struct ASTNode *method = decl->data.impl_decl.methods[j];
                if (method && method->type == AST_FN_DECL) {
                    // Replace "Self" in parameter types with struct_name
                    for (int k = 0; k < method->data.fn_decl.param_count; k++) {
                        struct ASTNode *param_type = method->data.fn_decl.params[k]->data.var_decl.type;
                        if (param_type && param_type->type == AST_TYPE_POINTER && 
                            param_type->data.type_pointer.pointee_type &&
                            param_type->data.type_pointer.pointee_type->type == AST_TYPE_NAMED &&
                            strcmp(param_type->data.type_pointer.pointee_type->data.type_named.name, "Self") == 0) {
                            // Replace "Self" with struct_name
                            free(param_type->data.type_pointer.pointee_type->data.type_named.name);
                            param_type->data.type_pointer.pointee_type->data.type_named.name = malloc(strlen(struct_name) + 1);
                            if (param_type->data.type_pointer.pointee_type->data.type_named.name) {
                                strcpy(param_type->data.type_pointer.pointee_type->data.type_named.name, struct_name);
                            }
                        }
                    }
                    generate_function(ir_gen, method);
                }
            }
        } else if (decl->type == AST_ENUM_DECL) {
            // Handle enum declarations
            IRInst *enum_ir = irinst_new(IR_ENUM_DECL);
            if (enum_ir) {
                // Set enum name
                enum_ir->data.enum_decl.name = malloc(strlen(decl->data.enum_decl.name) + 1);
                if (enum_ir->data.enum_decl.name) {
                    strcpy(enum_ir->data.enum_decl.name, decl->data.enum_decl.name);
                }

                // Set underlying type (default to i32 if not specified)
                if (decl->data.enum_decl.underlying_type) {
                    enum_ir->data.enum_decl.underlying_type = get_ir_type(decl->data.enum_decl.underlying_type);
                } else {
                    enum_ir->data.enum_decl.underlying_type = IR_TYPE_I32;  // Default underlying type
                }

                // Handle variants
                enum_ir->data.enum_decl.variant_count = decl->data.enum_decl.variant_count;
                if (decl->data.enum_decl.variant_count > 0) {
                    enum_ir->data.enum_decl.variant_names = malloc(decl->data.enum_decl.variant_count * sizeof(char*));
                    enum_ir->data.enum_decl.variant_values = malloc(decl->data.enum_decl.variant_count * sizeof(char*));
                    if (enum_ir->data.enum_decl.variant_names && enum_ir->data.enum_decl.variant_values) {
                        for (int j = 0; j < decl->data.enum_decl.variant_count; j++) {
                            // Copy variant name
                            enum_ir->data.enum_decl.variant_names[j] = malloc(strlen(decl->data.enum_decl.variants[j].name) + 1);
                            if (enum_ir->data.enum_decl.variant_names[j]) {
                                strcpy(enum_ir->data.enum_decl.variant_names[j], decl->data.enum_decl.variants[j].name);
                            }

                            // Copy variant value (if specified)
                            if (decl->data.enum_decl.variants[j].value) {
                                enum_ir->data.enum_decl.variant_values[j] = malloc(strlen(decl->data.enum_decl.variants[j].value) + 1);
                                if (enum_ir->data.enum_decl.variant_values[j]) {
                                    strcpy(enum_ir->data.enum_decl.variant_values[j], decl->data.enum_decl.variants[j].value);
                                }
                            } else {
                                enum_ir->data.enum_decl.variant_values[j] = NULL;  // No explicit value
                            }
                        }
                    }
                } else {
                    enum_ir->data.enum_decl.variant_names = NULL;
                    enum_ir->data.enum_decl.variant_values = NULL;
                }

                enum_ir->id = ir_gen->current_id++;

                // Add to instructions array
                if (ir_gen->inst_count >= ir_gen->inst_capacity) {
                    size_t new_capacity = ir_gen->inst_capacity * 2;
                    IRInst **new_instructions = realloc(ir_gen->instructions,
                                                       new_capacity * sizeof(IRInst*));
                    if (new_instructions) {
                        ir_gen->instructions = new_instructions;
                        ir_gen->inst_capacity = new_capacity;
                    }
                }
                if (ir_gen->inst_count < ir_gen->inst_capacity) {
                    ir_gen->instructions[ir_gen->inst_count++] = enum_ir;
                }
            }
        } else if (decl->type == AST_TYPE_TUPLE) {
            // Handle tuple type declarations - tuples don't need separate IR instructions
            // They are handled inline during expression processing
            // TODO: Generate IR_STRUCT_DECL for tuple types
        } else if (decl->type == AST_TUPLE_LITERAL) {
            // Handle tuple literals - these are processed as expressions
            // This shouldn't happen here since tuple literals are expressions, not declarations
            // But we'll add it for completeness
        } else if (decl->type == AST_STRUCT_DECL) {
            // Handle struct declarations
            IRInst *struct_ir = irinst_new(IR_STRUCT_DECL);
            if (struct_ir) {
                // Set struct name
                struct_ir->data.struct_decl.name = malloc(strlen(decl->data.struct_decl.name) + 1);
                if (struct_ir->data.struct_decl.name) {
                    strcpy(struct_ir->data.struct_decl.name, decl->data.struct_decl.name);
                }

                // Handle fields
                struct_ir->data.struct_decl.field_count = decl->data.struct_decl.field_count;
                if (decl->data.struct_decl.field_count > 0) {
                    struct_ir->data.struct_decl.fields = malloc(decl->data.struct_decl.field_count * sizeof(IRInst*));
                    if (struct_ir->data.struct_decl.fields) {
                        for (int j = 0; j < decl->data.struct_decl.field_count; j++) {
                            // Create field as variable declaration
                            IRInst *field = irinst_new(IR_VAR_DECL);
                            if (field) {
                                field->data.var.name = malloc(strlen(decl->data.struct_decl.fields[j]->data.var_decl.name) + 1);
                                if (field->data.var.name) {
                                    strcpy(field->data.var.name, decl->data.struct_decl.fields[j]->data.var_decl.name);
                                    
                                    // Check if the type is atomic
                                    struct ASTNode *field_type = decl->data.struct_decl.fields[j]->data.var_decl.type;
                                    field->data.var.is_atomic = (field_type && field_type->type == AST_TYPE_ATOMIC) ? 1 : 0;
                                    
                                    field->data.var.type = get_ir_type(field_type);
                                    field->data.var.is_mut = decl->data.struct_decl.fields[j]->data.var_decl.is_mut;
                                    field->data.var.init = NULL;
                                    field->id = ir_gen->current_id++;
                                    struct_ir->data.struct_decl.fields[j] = field;
                                }
                            }
                        }
                    }
                } else {
                    struct_ir->data.struct_decl.fields = NULL;
                }

                struct_ir->id = ir_gen->current_id++;

                // Add to instructions array
                if (ir_gen->inst_count >= ir_gen->inst_capacity) {
                    size_t new_capacity = ir_gen->inst_capacity * 2;
                    IRInst **new_instructions = realloc(ir_gen->instructions,
                                                       new_capacity * sizeof(IRInst*));
                    if (new_instructions) {
                        ir_gen->instructions = new_instructions;
                        ir_gen->inst_capacity = new_capacity;
                    }
                }
                if (ir_gen->inst_count < ir_gen->inst_capacity) {
                    ir_gen->instructions[ir_gen->inst_count++] = struct_ir;
                }
            }
        }
    }
}
