#include "ast.h"
#include <stddef.h>
#include <string.h>

// 创建新的 AST 节点
// 参数：type - 节点类型，line - 行号，column - 列号，arena - Arena 分配器
// 返回：新创建的 AST 节点指针，失败返回 NULL
ASTNode *ast_new_node(ASTNodeType type, int line, int column, Arena *arena) {
    if (arena == NULL) {
        return NULL;
    }
    
    // 从 Arena 分配器分配节点内存
    ASTNode *node = (ASTNode *)arena_alloc(arena, sizeof(ASTNode));
    if (node == NULL) {
        return NULL;
    }
    
    // 初始化节点
    node->type = type;
    node->line = line;
    node->column = column;
    
    // 根据节点类型初始化 union 数据
    // 注意：所有指针字段初始化为 NULL，数组字段初始化为 NULL 和 0
    switch (type) {
        case AST_PROGRAM:
            node->data.program.decls = NULL;
            node->data.program.decl_count = 0;
            break;
        case AST_STRUCT_DECL:
            node->data.struct_decl.name = NULL;
            node->data.struct_decl.fields = NULL;
            node->data.struct_decl.field_count = 0;
            break;
        case AST_FN_DECL:
            node->data.fn_decl.name = NULL;
            node->data.fn_decl.params = NULL;
            node->data.fn_decl.param_count = 0;
            node->data.fn_decl.return_type = NULL;
            node->data.fn_decl.body = NULL;
            break;
        case AST_VAR_DECL:
            node->data.var_decl.name = NULL;
            node->data.var_decl.type = NULL;
            node->data.var_decl.init = NULL;
            node->data.var_decl.is_const = 0;
            break;
        case AST_BINARY_EXPR:
            node->data.binary_expr.left = NULL;
            node->data.binary_expr.op = 0;
            node->data.binary_expr.right = NULL;
            break;
        case AST_UNARY_EXPR:
            node->data.unary_expr.op = 0;
            node->data.unary_expr.operand = NULL;
            break;
        case AST_CALL_EXPR:
            node->data.call_expr.callee = NULL;
            node->data.call_expr.args = NULL;
            node->data.call_expr.arg_count = 0;
            break;
        case AST_MEMBER_ACCESS:
            node->data.member_access.object = NULL;
            node->data.member_access.field_name = NULL;
            break;
        case AST_STRUCT_INIT:
            node->data.struct_init.struct_name = NULL;
            node->data.struct_init.field_names = NULL;
            node->data.struct_init.field_values = NULL;
            node->data.struct_init.field_count = 0;
            break;
        case AST_IDENTIFIER:
            node->data.identifier.name = NULL;
            break;
        case AST_NUMBER:
            node->data.number.value = 0;
            break;
        case AST_BOOL:
            node->data.bool_literal.value = 0;
            break;
        case AST_IF_STMT:
            node->data.if_stmt.condition = NULL;
            node->data.if_stmt.then_branch = NULL;
            node->data.if_stmt.else_branch = NULL;
            break;
        case AST_WHILE_STMT:
            node->data.while_stmt.condition = NULL;
            node->data.while_stmt.body = NULL;
            break;
        case AST_RETURN_STMT:
            node->data.return_stmt.expr = NULL;
            break;
        case AST_ASSIGN:
            node->data.assign.dest = NULL;
            node->data.assign.src = NULL;
            break;
        case AST_EXPR_STMT:
            // 表达式语句的数据存储在表达式的节点中，这里不需要额外数据
            break;
        case AST_BLOCK:
            node->data.block.stmts = NULL;
            node->data.block.stmt_count = 0;
            break;
        case AST_TYPE_NAMED:
            node->data.type_named.name = NULL;
            break;
        case AST_TYPE_POINTER:
            node->data.type_pointer.pointed_type = NULL;
            node->data.type_pointer.is_ffi_pointer = 0;
            break;
        case AST_TYPE_ARRAY:
            node->data.type_array.element_type = NULL;
            node->data.type_array.size_expr = NULL;
            break;
    }
    
    return node;
}

