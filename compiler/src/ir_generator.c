#include "ir/ir.h"
#include "parser/ast.h"
#include "lexer/lexer.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declarations
static IRInst *generate_expr(IRGenerator *ir_gen, struct ASTNode *expr);
static IRInst *generate_stmt(IRGenerator *ir_gen, struct ASTNode *stmt);
static IRInst *generate_function(IRGenerator *ir_gen, struct ASTNode *fn_decl);
static IRInst *generate_test_block(IRGenerator *ir_gen, struct ASTNode *test_block);
static void generate_program(IRGenerator *ir_gen, struct ASTNode *program);

static IRType get_ir_type(struct ASTNode *ast_type) {
    if (!ast_type) return IR_TYPE_VOID;

    switch (ast_type->type) {
        case AST_TYPE_NAMED:
            {
                const char *name = ast_type->data.type_named.name;
                if (strcmp(name, "i32") == 0) return IR_TYPE_I32;
                if (strcmp(name, "i64") == 0) return IR_TYPE_I64;
                if (strcmp(name, "i8") == 0) return IR_TYPE_I8;
                if (strcmp(name, "i16") == 0) return IR_TYPE_I16;
                if (strcmp(name, "u32") == 0) return IR_TYPE_U32;
                if (strcmp(name, "u64") == 0) return IR_TYPE_U64;
                if (strcmp(name, "u8") == 0) return IR_TYPE_U8;
                if (strcmp(name, "u16") == 0) return IR_TYPE_U16;
                if (strcmp(name, "f32") == 0) return IR_TYPE_F32;
                if (strcmp(name, "f64") == 0) return IR_TYPE_F64;
                if (strcmp(name, "bool") == 0) return IR_TYPE_BOOL;
                if (strcmp(name, "void") == 0) return IR_TYPE_VOID;
                if (strcmp(name, "byte") == 0) return IR_TYPE_BYTE;

                // Handle generic type parameter T (temporarily treat as i32 until generics are fully implemented)
                if (strcmp(name, "T") == 0) return IR_TYPE_I32;

                // For user-defined types like Point, Vec3, etc., return STRUCT type
                return IR_TYPE_STRUCT;
            }
        case AST_TYPE_ARRAY:
            return IR_TYPE_ARRAY;
        case AST_TYPE_POINTER:
            return IR_TYPE_PTR;
        case AST_TYPE_ERROR_UNION:
            // For error union types, temporarily return the base type
            // Full error handling implementation will be added later
            return get_ir_type(ast_type->data.type_error_union.base_type);
        case AST_TYPE_ATOMIC:
            // For atomic types, return the base type
            // The atomic flag will be set separately
            return get_ir_type(ast_type->data.type_atomic.base_type);
        default:
            return IR_TYPE_VOID;
    }
}

// Forward declarations
static IRInst *generate_expr(IRGenerator *ir_gen, struct ASTNode *expr);
static IRInst *generate_function(IRGenerator *ir_gen, struct ASTNode *fn_decl);

static IRInst *generate_expr(IRGenerator *ir_gen, struct ASTNode *expr) {
    if (!expr) return NULL;

    switch (expr->type) {
        case AST_NUMBER: {
            // Create a constant for the number
            IRInst *const_inst = irinst_new(IR_CONSTANT);
            if (!const_inst) return NULL;

            // Store the numeric value
            const_inst->data.constant.value = malloc(strlen(expr->data.number.value) + 1);
            if (!const_inst->data.constant.value) {
                irinst_free(const_inst);
                return NULL;
            }
            strcpy(const_inst->data.constant.value, expr->data.number.value);
            const_inst->data.constant.type = IR_TYPE_I32; // Numbers default to i32

            return const_inst;
        }

        case AST_IDENTIFIER: {
            // Create a reference to an existing variable
            IRInst *id_inst = irinst_new(IR_VAR_DECL);
            if (!id_inst) return NULL;

            id_inst->data.var.name = malloc(strlen(expr->data.identifier.name) + 1);
            if (id_inst->data.var.name) {
                strcpy(id_inst->data.var.name, expr->data.identifier.name);
                id_inst->data.var.type = IR_TYPE_I32; // Default type
                id_inst->data.var.init = NULL;
            } else {
                irinst_free(id_inst);
                return NULL;
            }

            return id_inst;
        }

        case AST_CALL_EXPR: {
            // Handle function calls (including slice operations)
            IRInst *call_inst = irinst_new(IR_CALL);
            if (!call_inst) return NULL;

            // Set function name
            if (expr->data.call_expr.callee && expr->data.call_expr.callee->type == AST_IDENTIFIER) {
                call_inst->data.call.func_name = malloc(strlen(expr->data.call_expr.callee->data.identifier.name) + 1);
                if (call_inst->data.call.func_name) {
                    strcpy(call_inst->data.call.func_name, expr->data.call_expr.callee->data.identifier.name);
                } else {
                    irinst_free(call_inst);
                    return NULL;
                }
            } else if (expr->data.call_expr.callee && expr->data.call_expr.callee->type == AST_MEMBER_ACCESS) {
                // Method call: object.method() - generate function name using the field name
                const char *field_name = expr->data.call_expr.callee->data.member_access.field_name;
                call_inst->data.call.func_name = malloc(strlen(field_name) + 1);
                if (call_inst->data.call.func_name) {
                    strcpy(call_inst->data.call.func_name, field_name);
                } else {
                    irinst_free(call_inst);
                    return NULL;
                }
            } else {
                call_inst->data.call.func_name = malloc(8);
                if (call_inst->data.call.func_name) {
                    strcpy(call_inst->data.call.func_name, "unknown");
                } else {
                    irinst_free(call_inst);
                    return NULL;
                }
            }

            // Handle arguments
            // If this is a method call (callee is member_access), prepend the object as first argument
            int is_method_call = (expr->data.call_expr.callee && expr->data.call_expr.callee->type == AST_MEMBER_ACCESS);
            call_inst->data.call.arg_count = expr->data.call_expr.arg_count + (is_method_call ? 1 : 0);
            
            if (call_inst->data.call.arg_count > 0) {
                call_inst->data.call.args = malloc(call_inst->data.call.arg_count * sizeof(IRInst*));
                if (!call_inst->data.call.args) {
                    irinst_free(call_inst);
                    return NULL;
                }
                
                int arg_index = 0;
                
                // If method call, add object as first argument
                // If the method expects a pointer, we need to pass the address of the object
                if (is_method_call) {
                    IRInst *object_expr = generate_expr(ir_gen, expr->data.call_expr.callee->data.member_access.object);
                    if (!object_expr) {
                        irinst_free(call_inst);
                        return NULL;
                    }
                    
                    // For method calls, the first parameter is typically a pointer to the struct
                    // So we need to take the address of the object if it's a value type
                    // Check if object is a value type (not already a pointer)
                    if (object_expr->type == IR_VAR_DECL && object_expr->data.var.type != IR_TYPE_PTR) {
                        // Create address-of operation: &object
                        IRInst *addr_of = irinst_new(IR_UNARY_OP);
                        if (addr_of) {
                            addr_of->data.unary_op.op = IR_OP_ADDR_OF;
                            addr_of->data.unary_op.operand = object_expr;
                            call_inst->data.call.args[arg_index] = addr_of;
                        } else {
                            call_inst->data.call.args[arg_index] = object_expr;
                        }
                    } else {
                        call_inst->data.call.args[arg_index] = object_expr;
                    }
                    arg_index++;
                }
                
                // Add the rest of the arguments
                for (int i = 0; i < expr->data.call_expr.arg_count; i++) {
                    call_inst->data.call.args[arg_index] = generate_expr(ir_gen, expr->data.call_expr.args[i]);
                    if (!call_inst->data.call.args[arg_index]) {
                        irinst_free(call_inst);
                        return NULL;
                    }
                    arg_index++;
                }
            } else {
                call_inst->data.call.args = NULL;
            }

            return call_inst;
        }


        case AST_BINARY_EXPR: {
            // Handle binary expressions like x > 5, a + b, etc.
            IRInst *binary_op = irinst_new(IR_BINARY_OP);
            if (!binary_op) return NULL;

            // Map AST operator to IR operator
            switch (expr->data.binary_expr.op) {
                case TOKEN_PLUS: binary_op->data.binary_op.op = IR_OP_ADD; break;
                case TOKEN_MINUS: binary_op->data.binary_op.op = IR_OP_SUB; break;
                case TOKEN_ASTERISK: binary_op->data.binary_op.op = IR_OP_MUL; break;
                case TOKEN_SLASH: binary_op->data.binary_op.op = IR_OP_DIV; break;
                case TOKEN_PERCENT: binary_op->data.binary_op.op = IR_OP_MOD; break;
                case TOKEN_EQUAL: binary_op->data.binary_op.op = IR_OP_EQ; break;
                case TOKEN_NOT_EQUAL: binary_op->data.binary_op.op = IR_OP_NE; break;
                case TOKEN_LESS: binary_op->data.binary_op.op = IR_OP_LT; break;
                case TOKEN_LESS_EQUAL: binary_op->data.binary_op.op = IR_OP_LE; break;
                case TOKEN_GREATER: binary_op->data.binary_op.op = IR_OP_GT; break;
                case TOKEN_GREATER_EQUAL: binary_op->data.binary_op.op = IR_OP_GE; break;
                default: binary_op->data.binary_op.op = IR_OP_ADD; break; // default
            }

            // Generate left and right operands
            binary_op->data.binary_op.left = generate_expr(ir_gen, expr->data.binary_expr.left);
            binary_op->data.binary_op.right = generate_expr(ir_gen, expr->data.binary_expr.right);

            // Generate a destination variable name
            char temp_name[32];
            snprintf(temp_name, sizeof(temp_name), "temp_%d", ir_gen->current_id++);
            binary_op->data.binary_op.dest = malloc(strlen(temp_name) + 1);
            if (binary_op->data.binary_op.dest) {
                strcpy(binary_op->data.binary_op.dest, temp_name);
            }

            return binary_op;
        }

        case AST_BOOL: {
            // Handle boolean literals
            IRInst *const_bool = irinst_new(IR_CONSTANT);
            if (!const_bool) return NULL;

            // Convert boolean value to string representation
            if (expr->data.bool_literal.value) {
                const_bool->data.constant.value = malloc(5);  // "true" + null terminator
                if (const_bool->data.constant.value) {
                    strcpy(const_bool->data.constant.value, "true");
                }
            } else {
                const_bool->data.constant.value = malloc(6);  // "false" + null terminator
                if (const_bool->data.constant.value) {
                    strcpy(const_bool->data.constant.value, "false");
                }
            }
            const_bool->data.constant.type = IR_TYPE_BOOL;

            return const_bool;
        }

        case AST_UNARY_EXPR: {
            // Handle unary expressions like &variable, -x, !x, try x
            if (expr->data.unary_expr.op == TOKEN_TRY) {
                // Handle try expressions: try expr (error propagation) and try a + b (overflow checking)
                // For now, we'll generate a special error union operation for try expressions
                IRInst *try_op = irinst_new(IR_ERROR_UNION);
                if (!try_op) return NULL;

                // Generate the operand expression
                try_op->data.error_union.value = generate_expr(ir_gen, expr->data.unary_expr.operand);
                try_op->data.error_union.is_error = 0; // Not an error, just a try operation

                // Generate a destination variable name
                char temp_name[32];
                snprintf(temp_name, sizeof(temp_name), "try_%d", ir_gen->current_id++);
                try_op->data.error_union.dest = malloc(strlen(temp_name) + 1);
                if (try_op->data.error_union.dest) {
                    strcpy(try_op->data.error_union.dest, temp_name);
                }

                return try_op;
            } else {
                // Handle other unary expressions
                IRInst *unary_op = irinst_new(IR_UNARY_OP);
                if (!unary_op) return NULL;

                // Map AST operator to IR operator
                switch (expr->data.unary_expr.op) {
                    case TOKEN_AMPERSAND:
                        unary_op->data.unary_op.op = IR_OP_ADDR_OF;
                        break;
                    case TOKEN_MINUS:
                        unary_op->data.unary_op.op = IR_OP_NEG;
                        break;
                    case TOKEN_EXCLAMATION:
                        unary_op->data.unary_op.op = IR_OP_NOT;
                        break;
                    default:
                        unary_op->data.unary_op.op = IR_OP_ADDR_OF;
                        break; // default to address-of
                }

                // Generate operand
                unary_op->data.unary_op.operand = generate_expr(ir_gen, expr->data.unary_expr.operand);

                // Generate a destination variable name
                char temp_name[32];
                snprintf(temp_name, sizeof(temp_name), "temp_%d", ir_gen->current_id++);
                unary_op->data.unary_op.dest = malloc(strlen(temp_name) + 1);
                if (unary_op->data.unary_op.dest) {
                    strcpy(unary_op->data.unary_op.dest, temp_name);
                }

                return unary_op;
            }
        }

        case AST_MEMBER_ACCESS: {
            // Handle member access like obj.field
            IRInst *member_access = irinst_new(IR_MEMBER_ACCESS);
            if (!member_access) return NULL;

            // Generate the object expression
            member_access->data.member_access.object = generate_expr(ir_gen, expr->data.member_access.object);

            // Copy the field name
            member_access->data.member_access.field_name = malloc(strlen(expr->data.member_access.field_name) + 1);
            if (member_access->data.member_access.field_name) {
                strcpy(member_access->data.member_access.field_name, expr->data.member_access.field_name);
            }

            // Generate a destination variable name
            char temp_name[32];
            snprintf(temp_name, sizeof(temp_name), "temp_%d", ir_gen->current_id++);
            member_access->data.member_access.dest = malloc(strlen(temp_name) + 1);
            if (member_access->data.member_access.dest) {
                strcpy(member_access->data.member_access.dest, temp_name);
            }

            return member_access;
        }

        case AST_STRUCT_INIT: {
            // Handle struct initialization like Point{ x: 10, y: 20 }
            IRInst *struct_init = irinst_new(IR_STRUCT_INIT);
            if (!struct_init) return NULL;

            // Set struct name
            struct_init->data.struct_init.struct_name = malloc(strlen(expr->data.struct_init.struct_name) + 1);
            if (struct_init->data.struct_init.struct_name) {
                strcpy(struct_init->data.struct_init.struct_name, expr->data.struct_init.struct_name);
            }

            // Set up field names and initializations
            struct_init->data.struct_init.field_count = expr->data.struct_init.field_count;
            if (expr->data.struct_init.field_count > 0) {
                struct_init->data.struct_init.field_names = malloc(expr->data.struct_init.field_count * sizeof(char*));
                struct_init->data.struct_init.field_inits = malloc(expr->data.struct_init.field_count * sizeof(IRInst*));

                if (!struct_init->data.struct_init.field_names || !struct_init->data.struct_init.field_inits) {
                    if (struct_init->data.struct_init.field_names) free(struct_init->data.struct_init.field_names);
                    if (struct_init->data.struct_init.field_inits) free(struct_init->data.struct_init.field_inits);
                    irinst_free(struct_init);
                    return NULL;
                }

                for (int i = 0; i < expr->data.struct_init.field_count; i++) {
                    // Copy field name
                    struct_init->data.struct_init.field_names[i] = malloc(strlen(expr->data.struct_init.field_names[i]) + 1);
                    if (struct_init->data.struct_init.field_names[i]) {
                        strcpy(struct_init->data.struct_init.field_names[i], expr->data.struct_init.field_names[i]);
                    }

                    // Generate field initialization expression
                    struct_init->data.struct_init.field_inits[i] = generate_expr(ir_gen, expr->data.struct_init.field_inits[i]);
                }
            } else {
                struct_init->data.struct_init.field_names = NULL;
                struct_init->data.struct_init.field_inits = NULL;
            }

            return struct_init;
        }

        default:
            // For unsupported expressions, create a placeholder
            return irinst_new(IR_VAR_DECL);
    }
}

static IRInst *generate_function(IRGenerator *ir_gen, struct ASTNode *fn_decl) {
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
            func->data.func.body = malloc(func->data.func.body_count * sizeof(IRInst*));
            if (!func->data.func.body) {
                irinst_free(func);
                return NULL;
            }

            for (int i = 0; i < func->data.func.body_count; i++) {
                // Set up the IR instruction based on the AST statement type
                struct ASTNode *ast_stmt = fn_decl->data.fn_decl.body->data.block.stmts[i];
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

                        // Handle initialization
                        if (ast_stmt->data.var_decl.init) {
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

// Generate test block as a function (returns !void, no parameters)
static IRInst *generate_test_block(IRGenerator *ir_gen, struct ASTNode *test_block) {
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

// Generate statement for function body (doesn't add to main array)
static IRInst *generate_stmt_for_body(IRGenerator *ir_gen, struct ASTNode *stmt) {
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

            // Store original type name for user-defined types
            if (stmt->data.var_decl.type && stmt->data.var_decl.type->type == AST_TYPE_NAMED) {
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
            } else {
                var_decl->data.var.original_type_name = NULL;
            }

            if (stmt->data.var_decl.init) {
                var_decl->data.var.init = generate_expr(ir_gen, stmt->data.var_decl.init);
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
                if (stmt->data.if_stmt.else_branch->type == AST_BLOCK) {
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

            // Set destination (variable name)
            assign->data.assign.dest = malloc(strlen(stmt->data.assign.dest) + 1);
            if (assign->data.assign.dest) {
                strcpy(assign->data.assign.dest, stmt->data.assign.dest);
            }

            // Set source (right-hand side expression)
            if (stmt->data.assign.src) {
                assign->data.assign.src = generate_expr(ir_gen, stmt->data.assign.src);
            } else {
                assign->data.assign.src = NULL;
            }

            return assign;
        }

        default:
            return NULL;
    }
}

static IRInst *generate_stmt(IRGenerator *ir_gen, struct ASTNode *stmt) {
    // Top-level statements (like function declarations) should be added to main array
    // Function body statements should only be stored in the function's body array
    IRInst *result = generate_stmt_for_body(ir_gen, stmt);

    return result;
}

static void generate_program(IRGenerator *ir_gen, struct ASTNode *program) {
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

void *irgenerator_generate(IRGenerator *ir_gen, struct ASTNode *ast) {
    if (!ir_gen || !ast) {
        return NULL;
    }

    printf("生成中间表示...\n");

    // Reset counters
    ir_gen->current_id = 0;
    ir_gen->inst_count = 0;

    // Generate IR from AST
    generate_program(ir_gen, ast);

    printf("生成了 %d 条IR指令\n", ir_gen->inst_count);

    return ir_gen;
}

void ir_free(void *ir) {
    // IR的清理函数
    printf("清理IR资源...\n");
    if (ir) {
        IRGenerator *ir_gen = (IRGenerator *)ir;
        irgenerator_free(ir_gen);
    }
}