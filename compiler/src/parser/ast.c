#include "ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

ASTNode *ast_new_node(ASTNodeType type, int line, int column, const char *filename) {
    ASTNode *node = malloc(sizeof(ASTNode));
    if (!node) {
        return NULL;
    }
    
    node->type = type;
    node->line = line;
    node->column = column;
    node->filename = malloc(strlen(filename) + 1);
    if (!node->filename) {
        free(node);
        return NULL;
    }
    strcpy(node->filename, filename);
    
    // 初始化数据为0
    memset(&node->data, 0, sizeof(node->data));
    
    return node;
}

static void ast_free_node_list(ASTNode **nodes, int count) {
    if (nodes) {
        for (int i = 0; i < count; i++) {
            ast_free(nodes[i]);
        }
        free(nodes);
    }
}

void ast_free(ASTNode *node) {
    if (!node) {
        return;
    }
    
    if (node->filename) {
        free(node->filename);
    }
    
    switch (node->type) {
        case AST_PROGRAM:
            ast_free_node_list(node->data.program.decls, node->data.program.decl_count);
            break;
            
        case AST_STRUCT_DECL:
            if (node->data.struct_decl.name) {
                free(node->data.struct_decl.name);
            }
            ast_free_node_list(node->data.struct_decl.fields, node->data.struct_decl.field_count);
            break;
            
        case AST_FN_DECL:
            if (node->data.fn_decl.name) {
                free(node->data.fn_decl.name);
            }
            ast_free_node_list(node->data.fn_decl.params, node->data.fn_decl.param_count);
            ast_free(node->data.fn_decl.return_type);
            ast_free(node->data.fn_decl.body);
            break;
            
        case AST_VAR_DECL:
            if (node->data.var_decl.name) {
                free(node->data.var_decl.name);
            }
            ast_free(node->data.var_decl.type);
            ast_free(node->data.var_decl.init);
            break;
            
        case AST_BINARY_EXPR:
            ast_free(node->data.binary_expr.left);
            ast_free(node->data.binary_expr.right);
            break;
            
        case AST_UNARY_EXPR:
            ast_free(node->data.unary_expr.operand);
            break;
            
        case AST_CALL_EXPR:
            ast_free(node->data.call_expr.callee);
            ast_free_node_list(node->data.call_expr.args, node->data.call_expr.arg_count);
            break;
            
        case AST_IDENTIFIER:
            if (node->data.identifier.name) {
                free(node->data.identifier.name);
            }
            break;
            
        case AST_NUMBER:
            if (node->data.number.value) {
                free(node->data.number.value);
            }
            break;
            
        case AST_STRING:
            if (node->data.string.value) {
                free(node->data.string.value);
            }
            break;
            
        case AST_IF_STMT:
            ast_free(node->data.if_stmt.condition);
            ast_free(node->data.if_stmt.then_branch);
            ast_free(node->data.if_stmt.else_branch);
            break;
            
        case AST_WHILE_STMT:
            ast_free(node->data.while_stmt.condition);
            ast_free(node->data.while_stmt.body);
            break;
            
        case AST_RETURN_STMT:
            ast_free(node->data.return_stmt.expr);
            break;
            
        case AST_BLOCK:
            ast_free_node_list(node->data.block.stmts, node->data.block.stmt_count);
            break;
            
        case AST_TYPE_NAMED:
            if (node->data.type_named.name) {
                free(node->data.type_named.name);
            }
            break;
            
        case AST_TYPE_ARRAY:
            ast_free(node->data.type_array.element_type);
            break;
            
        case AST_TYPE_POINTER:
            ast_free(node->data.type_pointer.pointee_type);
            break;
            
        case AST_TYPE_ERROR_UNION:
            ast_free(node->data.type_error_union.base_type);
            break;
            
        default:
            // 其他类型暂不处理
            break;
    }
    
    free(node);
}

static void print_indent(int indent) {
    for (int i = 0; i < indent; i++) {
        printf("  ");
    }
}

void ast_print(ASTNode *node, int indent) {
    if (!node) {
        return;
    }
    
    print_indent(indent);
    
    switch (node->type) {
        case AST_PROGRAM:
            printf("Program:\n");
            for (int i = 0; i < node->data.program.decl_count; i++) {
                ast_print(node->data.program.decls[i], indent + 1);
            }
            break;
            
        case AST_STRUCT_DECL:
            printf("StructDecl: %s\n", node->data.struct_decl.name);
            for (int i = 0; i < node->data.struct_decl.field_count; i++) {
                print_indent(indent + 1);
                printf("Field:\n");
                ast_print(node->data.struct_decl.fields[i], indent + 2);
            }
            break;
            
        case AST_FN_DECL:
            printf("FnDecl: %s\n", node->data.fn_decl.name);
            print_indent(indent + 1);
            printf("Params:\n");
            for (int i = 0; i < node->data.fn_decl.param_count; i++) {
                ast_print(node->data.fn_decl.params[i], indent + 2);
            }
            print_indent(indent + 1);
            printf("Return Type:\n");
            ast_print(node->data.fn_decl.return_type, indent + 2);
            print_indent(indent + 1);
            printf("Body:\n");
            ast_print(node->data.fn_decl.body, indent + 2);
            break;
            
        case AST_VAR_DECL:
            printf("VarDecl: %s (mut: %s)\n", 
                   node->data.var_decl.name, 
                   node->data.var_decl.is_mut ? "true" : "false");
            print_indent(indent + 1);
            printf("Type:\n");
            ast_print(node->data.var_decl.type, indent + 2);
            print_indent(indent + 1);
            printf("Init:\n");
            ast_print(node->data.var_decl.init, indent + 2);
            break;
            
        case AST_BINARY_EXPR:
            printf("BinaryExpr: ");
            switch (node->data.binary_expr.op) {
                case 1: printf("+\n"); break;  // TOKEN_PLUS
                case 2: printf("-\n"); break;  // TOKEN_MINUS
                case 3: printf("*\n"); break;  // TOKEN_ASTERISK
                case 4: printf("/\n"); break;  // TOKEN_SLASH
                case 5: printf("==\n"); break; // TOKEN_EQUAL
                case 6: printf("!=\n"); break; // TOKEN_NOT_EQUAL
                case 7: printf("<\n"); break;  // TOKEN_LESS
                case 8: printf("<=\n"); break; // TOKEN_LESS_EQUAL
                case 9: printf(">\n"); break;  // TOKEN_GREATER
                case 10: printf(">=\n"); break; // TOKEN_GREATER_EQUAL
                default: printf("op_%d\n", node->data.binary_expr.op); break;
            }
            ast_print(node->data.binary_expr.left, indent + 1);
            ast_print(node->data.binary_expr.right, indent + 1);
            break;
            
        case AST_IDENTIFIER:
            printf("Identifier: %s\n", node->data.identifier.name);
            break;
            
        case AST_NUMBER:
            printf("Number: %s\n", node->data.number.value);
            break;
            
        case AST_STRING:
            printf("String: \"%s\"\n", node->data.string.value);
            break;
            
        case AST_IF_STMT:
            printf("IfStmt:\n");
            print_indent(indent + 1);
            printf("Condition:\n");
            ast_print(node->data.if_stmt.condition, indent + 2);
            print_indent(indent + 1);
            printf("Then:\n");
            ast_print(node->data.if_stmt.then_branch, indent + 2);
            if (node->data.if_stmt.else_branch) {
                print_indent(indent + 1);
                printf("Else:\n");
                ast_print(node->data.if_stmt.else_branch, indent + 2);
            }
            break;
            
        case AST_WHILE_STMT:
            printf("WhileStmt:\n");
            print_indent(indent + 1);
            printf("Condition:\n");
            ast_print(node->data.while_stmt.condition, indent + 2);
            print_indent(indent + 1);
            printf("Body:\n");
            ast_print(node->data.while_stmt.body, indent + 2);
            break;
            
        case AST_RETURN_STMT:
            printf("ReturnStmt:\n");
            ast_print(node->data.return_stmt.expr, indent + 1);
            break;
            
        case AST_BLOCK:
            printf("Block:\n");
            for (int i = 0; i < node->data.block.stmt_count; i++) {
                ast_print(node->data.block.stmts[i], indent + 1);
            }
            break;
            
        case AST_ASSIGN:
            printf("AssignStmt: %s = ", node->data.assign.dest);
            ast_print(node->data.assign.src, indent + 1);
            break;

        case AST_TYPE_NAMED:
            printf("Type: %s\n", node->data.type_named.name);
            break;

        default:
            printf("Unknown node type: %d\n", node->type);
            break;
    }
}