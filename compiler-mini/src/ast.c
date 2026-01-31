#include "ast.h"
#include <stddef.h>
#include <string.h>
#include <stdio.h>

// 创建新的 AST 节点
// 参数：type - 节点类型，line - 行号，column - 列号，arena - Arena 分配器，filename - 文件名（可选）
// 返回：新创建的 AST 节点指针，失败返回 NULL
ASTNode *ast_new_node(ASTNodeType type, int line, int column, Arena *arena, const char *filename) {
    if (arena == NULL) {
        return NULL;
    }
    
    // 从 Arena 分配器分配节点内存
    ASTNode *node = (ASTNode *)arena_alloc(arena, sizeof(ASTNode));
    if (node == NULL) {
        const char *filename_str = filename ? filename : "<unknown>";
        fprintf(stderr, "错误: Arena 内存不足 (%s:%d:%d): 无法分配 AST 节点\n", filename_str, line, column);
        fprintf(stderr, "提示: 请增加 ARENA_BUFFER_SIZE（当前建议至少 16MB）\n");
        return NULL;
    }
    
    // 初始化节点
    node->type = type;
    node->line = line;
    node->column = column;
    node->filename = filename;  // 保存文件名用于错误报告
    
    // 根据节点类型初始化 union 数据
    // 注意：所有指针字段初始化为 NULL，数组字段初始化为 NULL 和 0
    switch (type) {
        case AST_PROGRAM:
            node->data.program.decls = NULL;
            node->data.program.decl_count = 0;
            break;
        case AST_ENUM_DECL:
            node->data.enum_decl.name = NULL;
            node->data.enum_decl.variants = NULL;
            node->data.enum_decl.variant_count = 0;
            break;
        case AST_ERROR_DECL:
            node->data.error_decl.name = NULL;
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
            node->data.fn_decl.is_varargs = 0;
            break;
        case AST_VAR_DECL:
            node->data.var_decl.name = NULL;
            node->data.var_decl.type = NULL;
            node->data.var_decl.init = NULL;
            node->data.var_decl.is_const = 0;
            break;
        case AST_DESTRUCTURE_DECL:
            node->data.destructure_decl.names = NULL;
            node->data.destructure_decl.name_count = 0;
            node->data.destructure_decl.is_const = 0;
            node->data.destructure_decl.init = NULL;
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
        case AST_TRY_EXPR:
            node->data.try_expr.operand = NULL;
            break;
        case AST_CATCH_EXPR:
            node->data.catch_expr.operand = NULL;
            node->data.catch_expr.err_name = NULL;
            node->data.catch_expr.catch_block = NULL;
            break;
        case AST_ERROR_VALUE:
            node->data.error_value.name = NULL;
            break;
        case AST_CALL_EXPR:
            node->data.call_expr.callee = NULL;
            node->data.call_expr.args = NULL;
            node->data.call_expr.arg_count = 0;
            node->data.call_expr.has_ellipsis_forward = 0;
            break;
        case AST_PARAMS:
            /* 无额外数据 */
            break;
        case AST_MEMBER_ACCESS:
            node->data.member_access.object = NULL;
            node->data.member_access.field_name = NULL;
            break;
        case AST_ARRAY_ACCESS:
            node->data.array_access.array = NULL;
            node->data.array_access.index = NULL;
            break;
        case AST_STRUCT_INIT:
            node->data.struct_init.struct_name = NULL;
            node->data.struct_init.field_names = NULL;
            node->data.struct_init.field_values = NULL;
            node->data.struct_init.field_count = 0;
            break;
        case AST_ARRAY_LITERAL:
            node->data.array_literal.elements = NULL;
            node->data.array_literal.element_count = 0;
            node->data.array_literal.repeat_count_expr = NULL;
            break;
        case AST_TUPLE_LITERAL:
            node->data.tuple_literal.elements = NULL;
            node->data.tuple_literal.element_count = 0;
            break;
        case AST_SIZEOF:
            node->data.sizeof_expr.target = NULL;
            node->data.sizeof_expr.is_type = 0;
            break;
        case AST_ALIGNOF:
            node->data.alignof_expr.target = NULL;
            node->data.alignof_expr.is_type = 0;
            break;
        case AST_LEN:
            node->data.len_expr.array = NULL;
            break;
        case AST_CAST_EXPR:
            node->data.cast_expr.expr = NULL;
            node->data.cast_expr.target_type = NULL;
            break;
        case AST_IDENTIFIER:
            node->data.identifier.name = NULL;
            break;
        case AST_NUMBER:
            node->data.number.value = 0;
            break;
        case AST_FLOAT:
            node->data.float_literal.value = 0.0;
            break;
        case AST_BOOL:
            node->data.bool_literal.value = 0;
            break;
        case AST_INT_LIMIT:
            node->data.int_limit.is_max = 0;
            node->data.int_limit.resolved_kind = 0;
            break;
        case AST_STRING:
            node->data.string_literal.value = NULL;
            break;
        case AST_STRING_INTERP:
            node->data.string_interp.segments = NULL;
            node->data.string_interp.segment_count = 0;
            node->data.string_interp.computed_size = 0;
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
        case AST_FOR_STMT:
            node->data.for_stmt.array = NULL;
            node->data.for_stmt.var_name = NULL;
            node->data.for_stmt.is_ref = 0;
            node->data.for_stmt.body = NULL;
            break;
        case AST_RETURN_STMT:
            node->data.return_stmt.expr = NULL;
            break;
        case AST_DEFER_STMT:
            node->data.defer_stmt.body = NULL;
            break;
        case AST_ERRDEFER_STMT:
            node->data.errdefer_stmt.body = NULL;
            break;
        case AST_BREAK_STMT:
            // break 语句不需要数据字段
            break;
        case AST_UNDERSCORE:
            // _ 忽略占位，无数据字段
            break;
        case AST_CONTINUE_STMT:
            // continue 语句不需要数据字段
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
        case AST_TYPE_TUPLE:
            node->data.type_tuple.element_types = NULL;
            node->data.type_tuple.element_count = 0;
            break;
        case AST_TYPE_ERROR_UNION:
            node->data.type_error_union.payload_type = NULL;
            break;
    }
    
    return node;
}

// 合并多个 AST_PROGRAM 节点为一个程序节点
// 参数：programs - AST_PROGRAM 节点数组
//       count - 程序节点数量
//       arena - Arena 分配器
// 返回：合并后的 AST_PROGRAM 节点，失败返回 NULL
ASTNode *ast_merge_programs(ASTNode **programs, int count, Arena *arena) {
    if (programs == NULL || count <= 0 || arena == NULL) {
        return NULL;
    }
    
    // 验证所有输入节点都是 AST_PROGRAM 类型
    for (int i = 0; i < count; i++) {
        if (programs[i] == NULL || programs[i]->type != AST_PROGRAM) {
            return NULL;
        }
    }
    
    // 计算所有程序节点的声明总数
    int total_decl_count = 0;
    for (int i = 0; i < count; i++) {
        total_decl_count += programs[i]->data.program.decl_count;
    }
    
    // 创建新的 AST_PROGRAM 节点
    // 使用第一个程序节点的行号、列号和文件名
    ASTNode *merged = ast_new_node(AST_PROGRAM, programs[0]->line, programs[0]->column, arena, programs[0]->filename);
    if (merged == NULL) {
        return NULL;
    }
    
    // 如果总声明数为 0，直接返回空程序节点
    if (total_decl_count == 0) {
        merged->data.program.decls = NULL;
        merged->data.program.decl_count = 0;
        return merged;
    }
    
    // 分配声明数组（使用 Arena）
    ASTNode **decls = (ASTNode **)arena_alloc(arena, sizeof(ASTNode *) * total_decl_count);
    if (decls == NULL) {
        const char *filename_str = programs[0]->filename ? programs[0]->filename : "<unknown>";
        fprintf(stderr, "错误: Arena 内存不足 (%s:%d:%d): 无法分配 AST 合并数组（需要 %d 个声明）\n", 
                filename_str, programs[0]->line, programs[0]->column, total_decl_count);
        fprintf(stderr, "提示: 请增加 ARENA_BUFFER_SIZE（当前建议至少 16MB）\n");
        return NULL;
    }
    
    // 遍历所有程序节点，复制声明到新数组
    int decl_index = 0;
    for (int i = 0; i < count; i++) {
        ASTNode *program = programs[i];
        for (int j = 0; j < program->data.program.decl_count; j++) {
            decls[decl_index++] = program->data.program.decls[j];
        }
    }
    
    // 设置合并后的程序节点
    merged->data.program.decls = decls;
    merged->data.program.decl_count = total_decl_count;
    
    return merged;
}

