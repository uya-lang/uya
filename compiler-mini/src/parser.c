#include "parser.h"
#include <stddef.h>
#include <string.h>
#include <stdlib.h>

// 初始化 Parser
int parser_init(Parser *parser, Lexer *lexer, Arena *arena) {
    if (parser == NULL || lexer == NULL || arena == NULL) {
        return -1;
    }
    
    parser->lexer = lexer;
    parser->arena = arena;
    
    // 获取第一个 Token
    parser->current_token = lexer_next_token(lexer, arena);
    
    return 0;
}

// 辅助函数：检查当前 Token 类型是否匹配
static int parser_match(Parser *parser, TokenType type) {
    if (parser == NULL || parser->current_token == NULL) {
        return 0;
    }
    return parser->current_token->type == type;
}

// 辅助函数：消费当前 Token 并获取下一个
static Token *parser_consume(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    Token *current = parser->current_token;
    parser->current_token = lexer_next_token(parser->lexer, parser->arena);
    return current;
}

// 辅助函数：期望特定类型的 Token
static Token *parser_expect(Parser *parser, TokenType type) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    if (parser->current_token->type != type) {
        // 错误：期望的类型不匹配
        return NULL;
    }
    
    return parser_consume(parser);
}

// 从 Arena 复制字符串
static const char *arena_strdup(Arena *arena, const char *src) {
    if (arena == NULL || src == NULL) {
        return NULL;
    }
    
    size_t len = strlen(src) + 1;
    char *result = (char *)arena_alloc(arena, len);
    if (result == NULL) {
        return NULL;
    }
    
    memcpy(result, src, len);
    return result;
}

// 解析类型（Uya Mini 只支持命名类型：i32, bool, void, 或结构体名称）
static ASTNode *parser_parse_type(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // Uya Mini 只支持命名类型（标识符）
    if (parser->current_token->type != TOKEN_IDENTIFIER) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 创建类型节点
    ASTNode *type_node = ast_new_node(AST_TYPE_NAMED, line, column, parser->arena);
    if (type_node == NULL) {
        return NULL;
    }
    
    // 复制类型名称到 Arena
    const char *type_name = arena_strdup(parser->arena, parser->current_token->value);
    if (type_name == NULL) {
        return NULL;
    }
    
    type_node->data.type_named.name = type_name;
    
    // 消费类型标识符
    parser_consume(parser);
    
    return type_node;
}

// 前向声明
ASTNode *parser_parse_statement(Parser *parser);
ASTNode *parser_parse_expression(Parser *parser);  // 前向声明，用于递归调用

// 解析代码块（完善版本，解析语句列表）
static ASTNode *parser_parse_block(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 期望 '{'
    if (!parser_match(parser, TOKEN_LEFT_BRACE)) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 创建代码块节点
    ASTNode *block = ast_new_node(AST_BLOCK, line, column, parser->arena);
    if (block == NULL) {
        return NULL;
    }
    
    // 初始化语句列表
    block->data.block.stmts = NULL;
    block->data.block.stmt_count = 0;
    
    // 消费 '{'
    parser_consume(parser);
    
    // 解析语句列表
    ASTNode **stmts = NULL;
    int stmt_count = 0;
    int stmt_capacity = 0;
    
    while (parser->current_token != NULL && 
           !parser_match(parser, TOKEN_RIGHT_BRACE) && 
           !parser_match(parser, TOKEN_EOF)) {
        
        // 解析语句
        ASTNode *stmt = parser_parse_statement(parser);
        if (stmt == NULL) {
            // 解析失败
            return NULL;
        }
        
        // 扩展语句数组（使用 Arena 分配）
        if (stmt_count >= stmt_capacity) {
            int new_capacity = stmt_capacity == 0 ? 4 : stmt_capacity * 2;
            ASTNode **new_stmts = (ASTNode **)arena_alloc(
                parser->arena, 
                sizeof(ASTNode *) * new_capacity
            );
            if (new_stmts == NULL) {
                return NULL;
            }
            
            // 复制旧语句
            if (stmts != NULL) {
                for (int i = 0; i < stmt_count; i++) {
                    new_stmts[i] = stmts[i];
                }
            }
            
            stmts = new_stmts;
            stmt_capacity = new_capacity;
        }
        
        stmts[stmt_count++] = stmt;
    }
    
    // 期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        return NULL;
    }
    
    block->data.block.stmts = stmts;
    block->data.block.stmt_count = stmt_count;
    
    return block;
}

// 解析结构体声明：struct ID { field_list }
// field_list = field { ',' field }
// field = ID ':' type
ASTNode *parser_parse_struct(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 期望 'struct'
    if (!parser_match(parser, TOKEN_STRUCT)) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 消费 'struct'
    parser_consume(parser);
    
    // 期望结构体名称
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }
    
    const char *struct_name = arena_strdup(parser->arena, parser->current_token->value);
    if (struct_name == NULL) {
        return NULL;
    }
    
    // 消费结构体名称
    parser_consume(parser);
    
    // 创建结构体声明节点
    ASTNode *struct_decl = ast_new_node(AST_STRUCT_DECL, line, column, parser->arena);
    if (struct_decl == NULL) {
        return NULL;
    }
    
    struct_decl->data.struct_decl.name = struct_name;
    struct_decl->data.struct_decl.fields = NULL;
    struct_decl->data.struct_decl.field_count = 0;
    
    // 期望 '{'
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) {
        return NULL;
    }
    
    // 解析字段列表
    // 字段列表：field { ',' field }
    // field = ID ':' type
    ASTNode **fields = NULL;
    int field_count = 0;
    int field_capacity = 0;
    
    while (parser->current_token != NULL && 
           !parser_match(parser, TOKEN_RIGHT_BRACE) && 
           !parser_match(parser, TOKEN_EOF)) {
        
        // 解析字段名称
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            return NULL;
        }
        
        int field_line = parser->current_token->line;
        int field_column = parser->current_token->column;
        const char *field_name = arena_strdup(parser->arena, parser->current_token->value);
        if (field_name == NULL) {
            return NULL;
        }
        
        parser_consume(parser);
        
        // 期望 ':'
        if (!parser_expect(parser, TOKEN_COLON)) {
            return NULL;
        }
        
        // 解析字段类型
        ASTNode *field_type = parser_parse_type(parser);
        if (field_type == NULL) {
            return NULL;
        }
        
        // 创建字段节点（使用 AST_VAR_DECL，is_const = 0）
        ASTNode *field = ast_new_node(AST_VAR_DECL, field_line, field_column, parser->arena);
        if (field == NULL) {
            return NULL;
        }
        
        field->data.var_decl.name = field_name;
        field->data.var_decl.type = field_type;
        field->data.var_decl.init = NULL;
        field->data.var_decl.is_const = 0;
        
        // 扩展字段数组（使用 Arena 分配）
        if (field_count >= field_capacity) {
            int new_capacity = field_capacity == 0 ? 4 : field_capacity * 2;
            ASTNode **new_fields = (ASTNode **)arena_alloc(
                parser->arena, 
                sizeof(ASTNode *) * new_capacity
            );
            if (new_fields == NULL) {
                return NULL;
            }
            
            // 复制旧字段
            if (fields != NULL) {
                for (int i = 0; i < field_count; i++) {
                    new_fields[i] = fields[i];
                }
            }
            
            fields = new_fields;
            field_capacity = new_capacity;
        }
        
        fields[field_count++] = field;
        
        // 检查是否有逗号（可选，最后一个字段后不需要逗号）
        if (parser_match(parser, TOKEN_COMMA)) {
            parser_consume(parser);
        }
    }
    
    // 期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        return NULL;
    }
    
    struct_decl->data.struct_decl.fields = fields;
    struct_decl->data.struct_decl.field_count = field_count;
    
    return struct_decl;
}

// 解析函数声明：fn ID '(' [ param_list ] ')' type '{' statements '}'
// param_list = param { ',' param }
// param = ID ':' type
ASTNode *parser_parse_function(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 期望 'fn'
    if (!parser_match(parser, TOKEN_FN)) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 消费 'fn'
    parser_consume(parser);
    
    // 期望函数名称
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }
    
    const char *fn_name = arena_strdup(parser->arena, parser->current_token->value);
    if (fn_name == NULL) {
        return NULL;
    }
    
    // 消费函数名称
    parser_consume(parser);
    
    // 创建函数声明节点
    ASTNode *fn_decl = ast_new_node(AST_FN_DECL, line, column, parser->arena);
    if (fn_decl == NULL) {
        return NULL;
    }
    
    fn_decl->data.fn_decl.name = fn_name;
    fn_decl->data.fn_decl.params = NULL;
    fn_decl->data.fn_decl.param_count = 0;
    fn_decl->data.fn_decl.return_type = NULL;
    fn_decl->data.fn_decl.body = NULL;
    
    // 期望 '('
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        return NULL;
    }
    
    // 解析参数列表（可选）
    ASTNode **params = NULL;
    int param_count = 0;
    int param_capacity = 0;
    
    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        // 有参数
        while (parser->current_token != NULL && 
               !parser_match(parser, TOKEN_RIGHT_PAREN) && 
               !parser_match(parser, TOKEN_EOF)) {
            
            // 解析参数名称
            if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                return NULL;
            }
            
            int param_line = parser->current_token->line;
            int param_column = parser->current_token->column;
            const char *param_name = arena_strdup(parser->arena, parser->current_token->value);
            if (param_name == NULL) {
                return NULL;
            }
            
            parser_consume(parser);
            
            // 期望 ':'
            if (!parser_expect(parser, TOKEN_COLON)) {
                return NULL;
            }
            
            // 解析参数类型
            ASTNode *param_type = parser_parse_type(parser);
            if (param_type == NULL) {
                return NULL;
            }
            
            // 创建参数节点（使用 AST_VAR_DECL，is_const = 0）
            ASTNode *param = ast_new_node(AST_VAR_DECL, param_line, param_column, parser->arena);
            if (param == NULL) {
                return NULL;
            }
            
            param->data.var_decl.name = param_name;
            param->data.var_decl.type = param_type;
            param->data.var_decl.init = NULL;
            param->data.var_decl.is_const = 0;
            
            // 扩展参数数组（使用 Arena 分配）
            if (param_count >= param_capacity) {
                int new_capacity = param_capacity == 0 ? 4 : param_capacity * 2;
                ASTNode **new_params = (ASTNode **)arena_alloc(
                    parser->arena, 
                    sizeof(ASTNode *) * new_capacity
                );
                if (new_params == NULL) {
                    return NULL;
                }
                
                // 复制旧参数
                if (params != NULL) {
                    for (int i = 0; i < param_count; i++) {
                        new_params[i] = params[i];
                    }
                }
                
                params = new_params;
                param_capacity = new_capacity;
            }
            
            params[param_count++] = param;
            
            // 检查是否有逗号
            if (parser_match(parser, TOKEN_COMMA)) {
                parser_consume(parser);
            }
        }
    }
    
    // 期望 ')'
    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
        return NULL;
    }
    
    // 解析返回类型
    ASTNode *return_type = parser_parse_type(parser);
    if (return_type == NULL) {
        return NULL;
    }
    
    // 解析函数体（代码块）
    ASTNode *body = parser_parse_block(parser);
    if (body == NULL) {
        return NULL;
    }
    
    fn_decl->data.fn_decl.params = params;
    fn_decl->data.fn_decl.param_count = param_count;
    fn_decl->data.fn_decl.return_type = return_type;
    fn_decl->data.fn_decl.body = body;
    
    return fn_decl;
}

// 解析声明（函数、结构体或变量声明）
ASTNode *parser_parse_declaration(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 根据第一个 Token 判断声明类型
    if (parser_match(parser, TOKEN_FN)) {
        return parser_parse_function(parser);
    } else if (parser_match(parser, TOKEN_STRUCT)) {
        return parser_parse_struct(parser);
    } else {
        // TODO: 变量声明将在后续会话实现
        return NULL;
    }
}

// 解析程序（顶层声明列表）
ASTNode *parser_parse(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 创建程序节点
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    ASTNode *program = ast_new_node(AST_PROGRAM, line, column, parser->arena);
    if (program == NULL) {
        return NULL;
    }
    
    // 初始化声明列表
    program->data.program.decls = NULL;
    program->data.program.decl_count = 0;
    
    // 解析顶层声明列表
    ASTNode **decls = NULL;
    int decl_count = 0;
    int decl_capacity = 0;
    
    while (parser->current_token != NULL && !parser_match(parser, TOKEN_EOF)) {
        ASTNode *decl = parser_parse_declaration(parser);
        if (decl == NULL) {
            // 解析失败或到达文件末尾
            break;
        }
        
        // 扩展声明数组（使用 Arena 分配）
        if (decl_count >= decl_capacity) {
            int new_capacity = decl_capacity == 0 ? 4 : decl_capacity * 2;
            ASTNode **new_decls = (ASTNode **)arena_alloc(
                parser->arena, 
                sizeof(ASTNode *) * new_capacity
            );
            if (new_decls == NULL) {
                return NULL;
            }
            
            // 复制旧声明
            if (decls != NULL) {
                for (int i = 0; i < decl_count; i++) {
                    new_decls[i] = decls[i];
                }
            }
            
            decls = new_decls;
            decl_capacity = new_capacity;
        }
        
        decls[decl_count++] = decl;
    }
    
    program->data.program.decls = decls;
    program->data.program.decl_count = decl_count;
    
    return program;
}

// 解析基础表达式（基础版本，仅支持数字、标识符、布尔字面量和括号表达式）
// 注意：完整的表达式解析（包括运算符、函数调用等）将在会话4实现
static ASTNode *parser_parse_primary_expr(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 解析数字字面量
    if (parser->current_token->type == TOKEN_NUMBER) {
        ASTNode *node = ast_new_node(AST_NUMBER, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        // 将字符串转换为整数
        int value = atoi(parser->current_token->value);
        node->data.number.value = value;
        
        parser_consume(parser);
        return node;
    }
    
    // 解析布尔字面量
    if (parser->current_token->type == TOKEN_TRUE) {
        ASTNode *node = ast_new_node(AST_BOOL, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.bool_literal.value = 1;  // true
        
        parser_consume(parser);
        return node;
    }
    
    if (parser->current_token->type == TOKEN_FALSE) {
        ASTNode *node = ast_new_node(AST_BOOL, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        node->data.bool_literal.value = 0;  // false
        
        parser_consume(parser);
        return node;
    }
    
    // 解析标识符
    if (parser->current_token->type == TOKEN_IDENTIFIER) {
        ASTNode *node = ast_new_node(AST_IDENTIFIER, line, column, parser->arena);
        if (node == NULL) {
            return NULL;
        }
        
        const char *name = arena_strdup(parser->arena, parser->current_token->value);
        if (name == NULL) {
            return NULL;
        }
        
        node->data.identifier.name = name;
        
        parser_consume(parser);
        return node;
    }
    
    // 解析括号表达式
    if (parser->current_token->type == TOKEN_LEFT_PAREN) {
        parser_consume(parser);  // 消费 '('
        
        // 解析内部表达式（递归调用）
        ASTNode *expr = parser_parse_expression(parser);
        if (expr == NULL) {
            return NULL;
        }
        
        // 期望 ')'
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            return NULL;
        }
        
        return expr;
    }
    
    // 无法识别的基础表达式
    return NULL;
}

// 解析表达式（基础版本，仅支持基础表达式）
// 注意：完整的表达式解析（包括运算符、函数调用等）将在会话4实现
ASTNode *parser_parse_expression(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    // 基础版本：只解析基础表达式（数字、标识符、布尔、括号）
    // 会话4将扩展为完整的表达式解析（包括运算符、函数调用等）
    return parser_parse_primary_expr(parser);
}

// 解析语句
ASTNode *parser_parse_statement(Parser *parser) {
    if (parser == NULL || parser->current_token == NULL) {
        return NULL;
    }
    
    int line = parser->current_token->line;
    int column = parser->current_token->column;
    
    // 根据第一个 Token 判断语句类型
    if (parser_match(parser, TOKEN_RETURN)) {
        // 解析 return 语句
        parser_consume(parser);  // 消费 'return'
        
        ASTNode *stmt = ast_new_node(AST_RETURN_STMT, line, column, parser->arena);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析返回值表达式（可选，void 函数可以没有返回值）
        if (parser_match(parser, TOKEN_SEMICOLON)) {
            // 没有返回值（void 函数）
            stmt->data.return_stmt.expr = NULL;
        } else {
            // 有返回值表达式
            ASTNode *expr = parser_parse_expression(parser);
            if (expr == NULL) {
                return NULL;
            }
            stmt->data.return_stmt.expr = expr;
        }
        
        // 期望 ';'
        if (!parser_expect(parser, TOKEN_SEMICOLON)) {
            return NULL;
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_IF)) {
        // 解析 if 语句
        parser_consume(parser);  // 消费 'if'
        
        ASTNode *stmt = ast_new_node(AST_IF_STMT, line, column, parser->arena);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析条件表达式
        ASTNode *condition = parser_parse_expression(parser);
        if (condition == NULL) {
            return NULL;
        }
        stmt->data.if_stmt.condition = condition;
        
        // 解析 then 分支（代码块）
        ASTNode *then_branch = parser_parse_block(parser);
        if (then_branch == NULL) {
            return NULL;
        }
        stmt->data.if_stmt.then_branch = then_branch;
        
        // 解析 else 分支（可选）
        if (parser_match(parser, TOKEN_ELSE)) {
            parser_consume(parser);  // 消费 'else'
            
            ASTNode *else_branch = parser_parse_block(parser);
            if (else_branch == NULL) {
                return NULL;
            }
            stmt->data.if_stmt.else_branch = else_branch;
        } else {
            stmt->data.if_stmt.else_branch = NULL;
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_WHILE)) {
        // 解析 while 语句
        parser_consume(parser);  // 消费 'while'
        
        ASTNode *stmt = ast_new_node(AST_WHILE_STMT, line, column, parser->arena);
        if (stmt == NULL) {
            return NULL;
        }
        
        // 解析条件表达式
        ASTNode *condition = parser_parse_expression(parser);
        if (condition == NULL) {
            return NULL;
        }
        stmt->data.while_stmt.condition = condition;
        
        // 解析循环体（代码块）
        ASTNode *body = parser_parse_block(parser);
        if (body == NULL) {
            return NULL;
        }
        stmt->data.while_stmt.body = body;
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_CONST) || parser_match(parser, TOKEN_VAR)) {
        // 解析变量声明
        int is_const = parser_match(parser, TOKEN_CONST);
        parser_consume(parser);  // 消费 'const' 或 'var'
        
        // 期望变量名称
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            return NULL;
        }
        
        const char *var_name = arena_strdup(parser->arena, parser->current_token->value);
        if (var_name == NULL) {
            return NULL;
        }
        
        parser_consume(parser);  // 消费变量名称
        
        ASTNode *stmt = ast_new_node(AST_VAR_DECL, line, column, parser->arena);
        if (stmt == NULL) {
            return NULL;
        }
        
        stmt->data.var_decl.name = var_name;
        stmt->data.var_decl.is_const = is_const ? 1 : 0;
        
        // 期望 ':'
        if (!parser_expect(parser, TOKEN_COLON)) {
            return NULL;
        }
        
        // 解析类型
        ASTNode *type = parser_parse_type(parser);
        if (type == NULL) {
            return NULL;
        }
        stmt->data.var_decl.type = type;
        
        // 期望 '='
        if (!parser_expect(parser, TOKEN_ASSIGN)) {
            return NULL;
        }
        
        // 解析初始值表达式
        ASTNode *init = parser_parse_expression(parser);
        if (init == NULL) {
            return NULL;
        }
        stmt->data.var_decl.init = init;
        
        // 期望 ';'
        if (!parser_expect(parser, TOKEN_SEMICOLON)) {
            return NULL;
        }
        
        return stmt;
    }
    
    if (parser_match(parser, TOKEN_LEFT_BRACE)) {
        // 解析代码块语句
        return parser_parse_block(parser);
    }
    
    // 解析表达式语句（表达式后加分号）
    // 注意：AST_EXPR_STMT 节点在 union 中没有对应的数据结构
    // 根据 ast.c 的注释，表达式语句的数据存储在表达式的节点中
    // 所以这里直接返回表达式节点（表达式节点本身可以作为语句）
    ASTNode *expr = parser_parse_expression(parser);
    if (expr == NULL) {
        return NULL;
    }
    
    // 期望 ';'
    if (!parser_expect(parser, TOKEN_SEMICOLON)) {
        return NULL;
    }
    
    // 直接返回表达式节点（表达式节点可以作为语句）
    return expr;
}

