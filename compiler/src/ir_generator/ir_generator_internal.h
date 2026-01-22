#ifndef IR_GENERATOR_INTERNAL_H
#define IR_GENERATOR_INTERNAL_H

#include "../ir/ir.h"
#include "../parser/ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Forward declarations for internal functions
// These are declared in this internal header so that files can call each other

// Type-related functions
IRType get_ir_type(struct ASTNode *ast_type);
IRType infer_ir_type_from_expr(struct ASTNode *expr);
char *get_type_name_string(struct ASTNode *type_node);
char *generate_tuple_type_name(struct ASTNode *tuple_type);
IRInst *ensure_tuple_struct_decl(IRGenerator *ir_gen, struct ASTNode *tuple_type);
IRInst *find_struct_decl(IRGenerator *ir_gen, const char *struct_name);

// Expression generation
IRInst *generate_expr(IRGenerator *ir_gen, struct ASTNode *expr);

// Statement generation
IRInst *generate_stmt(IRGenerator *ir_gen, struct ASTNode *stmt);
IRInst *generate_stmt_for_body(IRGenerator *ir_gen, struct ASTNode *stmt);

// Function and program generation
IRInst *generate_function(IRGenerator *ir_gen, struct ASTNode *fn_decl);
IRInst *generate_test_block(IRGenerator *ir_gen, struct ASTNode *test_block);
void generate_program(IRGenerator *ir_gen, struct ASTNode *program);

#endif


