#include "parser_internal.h"

ASTNode *parser_parse_var_decl(Parser *parser) {
    int is_mut = 0;
    int is_const = 0;
    
    // 支持 var, const
    if (parser_match(parser, TOKEN_VAR)) {
        // var 声明可变变量
        parser_consume(parser); // 消费 'var'
        is_mut = 1;
    } else if (parser_match(parser, TOKEN_CONST)) {
        // const 声明常量变量
        parser_consume(parser); // 消费 'const'
        is_const = 1;
    } else {
        return NULL;
    }

    // 期望标识符（变量名）
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: 期望变量名\n");
        return NULL;
    }

    ASTNode *var_decl = ast_new_node(AST_VAR_DECL,
                                     parser->current_token->line,
                                     parser->current_token->column,
                                     parser->current_token->filename);
    if (!var_decl) {
        return NULL;
    }

    var_decl->data.var_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!var_decl->data.var_decl.name) {
        ast_free(var_decl);
        return NULL;
    }
    strcpy(var_decl->data.var_decl.name, parser->current_token->value);
    var_decl->data.var_decl.is_mut = is_mut;
    var_decl->data.var_decl.is_const = is_const;

    parser_consume(parser); // 消费变量名

    // 期望类型注解 ':'
    if (parser_match(parser, TOKEN_COLON)) {
        parser_consume(parser); // 消费 ':'
        var_decl->data.var_decl.type = parser_parse_type(parser);
        if (!var_decl->data.var_decl.type) {
            ast_free(var_decl);
            return NULL;
        }
    }

    // 期望 '=' 和初始化表达式
    if (parser_match(parser, TOKEN_ASSIGN)) {
        parser_consume(parser); // 消费 '='
        var_decl->data.var_decl.init = parser_parse_expression(parser);
        if (!var_decl->data.var_decl.init) {
            ast_free(var_decl);
            return NULL;
        }
    }

    return var_decl;
}

// 解析返回语句


ASTNode *parser_parse_return_stmt(Parser *parser) {
    if (!parser_match(parser, TOKEN_RETURN)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 return

    ASTNode *return_stmt = ast_new_node(AST_RETURN_STMT, line, col, filename);
    if (!return_stmt) {
        return NULL;
    }

    // 解析返回表达式（如果有的话）
    if (parser->current_token && parser->current_token->type != TOKEN_SEMICOLON) {
        return_stmt->data.return_stmt.expr = parser_parse_expression(parser);
    }

    return return_stmt;
}

// 解析语句
ASTNode *parser_parse_defer_stmt(Parser *parser);
ASTNode *parser_parse_errdefer_stmt(Parser *parser);



ASTNode *parser_parse_statement(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    if (parser_match(parser, TOKEN_VAR) || parser_match(parser, TOKEN_CONST)) {
        return parser_parse_var_decl(parser);
    } else if (parser_match(parser, TOKEN_RETURN)) {
        return parser_parse_return_stmt(parser);
    } else if (parser_match(parser, TOKEN_IF)) {
        return parser_parse_if_stmt(parser);
    } else if (parser_match(parser, TOKEN_WHILE)) {
        return parser_parse_while_stmt(parser);
    } else if (parser_match(parser, TOKEN_FOR)) {
        return parser_parse_for_stmt(parser);
    } else if (parser_match(parser, TOKEN_DEFER)) {
        return parser_parse_defer_stmt(parser);
    } else if (parser_match(parser, TOKEN_ERRDEFER)) {
        return parser_parse_errdefer_stmt(parser);
    } else if (parser_match(parser, TOKEN_LEFT_BRACE)) {
        // Parse standalone block statement: { ... }
        return parser_parse_block(parser);
    } else {
        // Parse as expression statement (which may include assignments)
        return parser_parse_expression(parser);
    }
}

// 解析 if 语句


ASTNode *parser_parse_if_stmt(Parser *parser) {
    if (!parser_match(parser, TOKEN_IF)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 'if'

    // 解析条件表达式
    ASTNode *condition = parser_parse_expression(parser);
    if (!condition) {
        fprintf(stderr, "语法错误: if 语句需要条件表达式\n%s:%d:%d\n",
                parser->current_token ? parser->current_token->filename : "unknown",
                parser->current_token ? parser->current_token->line : 0,
                parser->current_token ? parser->current_token->column : 0);
        return NULL;
    }

    ASTNode *if_stmt = ast_new_node(AST_IF_STMT,
                                   line, col, filename);
    if (!if_stmt) {
        ast_free(condition);
        return NULL;
    }

    if_stmt->data.if_stmt.condition = condition;

    // 解析 then 分支（代码块）
    if_stmt->data.if_stmt.then_branch = parser_parse_block(parser);
    if (!if_stmt->data.if_stmt.then_branch) {
        ast_free(if_stmt);
        return NULL;
    }

    // 检查是否有 else 分支
    if (parser_match(parser, TOKEN_ELSE)) {
        parser_consume(parser); // 消费 'else'
        
        // 检查是否是 else if 结构
        if (parser_match(parser, TOKEN_IF)) {
            // 递归解析 else if 作为一个新的 if 语句
            if_stmt->data.if_stmt.else_branch = parser_parse_if_stmt(parser);
            if (!if_stmt->data.if_stmt.else_branch) {
                ast_free(if_stmt);
                return NULL;
            }
        } else {
            // 普通 else 分支，解析代码块
            if_stmt->data.if_stmt.else_branch = parser_parse_block(parser);
            if (!if_stmt->data.if_stmt.else_branch) {
                ast_free(if_stmt);
                return NULL;
            }
        }
    } else {
        if_stmt->data.if_stmt.else_branch = NULL;
    }

    return if_stmt;
}

// 解析 while 语句


ASTNode *parser_parse_while_stmt(Parser *parser) {
    if (!parser_match(parser, TOKEN_WHILE)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 'while'

    // 解析条件表达式
    ASTNode *condition = parser_parse_expression(parser);
    if (!condition) {
        fprintf(stderr, "语法错误: while 语句需要条件表达式\n");
        return NULL;
    }

    ASTNode *while_stmt = ast_new_node(AST_WHILE_STMT,
                                      line, col, filename);
    if (!while_stmt) {
        ast_free(condition);
        return NULL;
    }

    while_stmt->data.while_stmt.condition = condition;

    // 解析循环体（代码块）
    while_stmt->data.while_stmt.body = parser_parse_block(parser);
    if (!while_stmt->data.while_stmt.body) {
        ast_free(while_stmt);
        return NULL;
    }

    return while_stmt;
}

// 解析 for 语句


ASTNode *parser_parse_for_stmt(Parser *parser) {
    if (!parser_match(parser, TOKEN_FOR)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 'for'

    ASTNode *iterable = NULL;
    ASTNode *index_range = NULL;
    
    // 检查是否有括号（旧语法：for (iterable) |val| 或新语法：for iterable |val|）
    if (parser_match(parser, TOKEN_LEFT_PAREN)) {
        // 旧语法：for (iterable) |val| 或 for (iterable, index_range) |item, index|
        parser_consume(parser); // 消费 '('
        
        iterable = parser_parse_expression(parser);
        if (!iterable) {
            fprintf(stderr, "语法错误: for 语句需要可迭代对象\n");
            return NULL;
        }
        
        // 检查是否有索引范围（for (iterable, index_range) 形式）
        if (parser_match(parser, TOKEN_COMMA)) {
            parser_consume(parser); // 消费 ','
            index_range = parser_parse_expression(parser);
            if (!index_range) {
                ast_free(iterable);
                fprintf(stderr, "语法错误: for 语句需要索引范围\n");
                return NULL;
            }
        }
        
        // 期望 ')'
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            ast_free(iterable);
            if (index_range) ast_free(index_range);
            return NULL;
        }
    } else {
        // 新语法：for iterable |val|（不需要括号）
        iterable = parser_parse_expression(parser);
        if (!iterable) {
            fprintf(stderr, "语法错误: for 语句需要可迭代对象\n");
            return NULL;
        }
    }

    // 期望 '|'（开始变量声明）
    if (!parser_expect(parser, TOKEN_PIPE)) {
        ast_free(iterable);
        if (index_range) ast_free(index_range);
        return NULL;
    }

    // 解析项变量名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        ast_free(iterable);
        if (index_range) ast_free(index_range);
        fprintf(stderr, "语法错误: for 语句需要项变量名\n");
        return NULL;
    }

    char *item_var = malloc(strlen(parser->current_token->value) + 1);
    if (!item_var) {
        ast_free(iterable);
        if (index_range) ast_free(index_range);
        return NULL;
    }
    strcpy(item_var, parser->current_token->value);
    parser_consume(parser); // 消费项变量名

    // 检查是否有索引变量（for (iterable, index_range) |item, index| 形式）
    char *index_var = NULL;
    if (parser_match(parser, TOKEN_COMMA)) {
        parser_consume(parser); // 消费 ','
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            ast_free(iterable);
            if (index_range) ast_free(index_range);
            free(item_var);
            fprintf(stderr, "语法错误: for 语句需要索引变量名\n");
            return NULL;
        }

        index_var = malloc(strlen(parser->current_token->value) + 1);
        if (index_var) {
            strcpy(index_var, parser->current_token->value);
        }
        parser_consume(parser); // 消费索引变量名
    }

    // 期望 '|'（结束变量声明）
    if (!parser_expect(parser, TOKEN_PIPE)) {
        ast_free(iterable);
        if (index_range) ast_free(index_range);
        free(item_var);
        if (index_var) free(index_var);
        return NULL;
    }

    // 解析循环体（代码块）
    ASTNode *body = parser_parse_block(parser);
    if (!body) {
        ast_free(iterable);
        if (index_range) ast_free(index_range);
        free(item_var);
        if (index_var) free(index_var);
        return NULL;
    }

    // 创建 for 语句节点
    ASTNode *for_stmt = ast_new_node(AST_FOR_STMT,
                                     line, col, filename);
    if (!for_stmt) {
        ast_free(iterable);
        if (index_range) ast_free(index_range);
        free(item_var);
        if (index_var) free(index_var);
        ast_free(body);
        return NULL;
    }

    for_stmt->data.for_stmt.iterable = iterable;
    for_stmt->data.for_stmt.index_range = index_range;
    for_stmt->data.for_stmt.item_var = item_var;
    for_stmt->data.for_stmt.index_var = index_var;
    for_stmt->data.for_stmt.body = body;

    return for_stmt;
}

// 解析 defer 语句


ASTNode *parser_parse_defer_stmt(Parser *parser) {
    if (!parser_match(parser, TOKEN_DEFER)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 'defer'

    ASTNode *defer_stmt = ast_new_node(AST_DEFER_STMT, line, col, filename);
    if (!defer_stmt) {
        return NULL;
    }

    // 解析 defer 块
    defer_stmt->data.defer_stmt.body = parser_parse_block(parser);
    if (!defer_stmt->data.defer_stmt.body) {
        ast_free(defer_stmt);
        return NULL;
    }

    return defer_stmt;
}

// 解析 errdefer 语句


ASTNode *parser_parse_errdefer_stmt(Parser *parser) {
    if (!parser_match(parser, TOKEN_ERRDEFER)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 'errdefer'

    ASTNode *errdefer_stmt = ast_new_node(AST_ERRDEFER_STMT, line, col, filename);
    if (!errdefer_stmt) {
        return NULL;
    }

    // 解析 errdefer 块
    errdefer_stmt->data.errdefer_stmt.body = parser_parse_block(parser);
    if (!errdefer_stmt->data.errdefer_stmt.body) {
        ast_free(errdefer_stmt);
        return NULL;
    }

    return errdefer_stmt;
}

// 解析代码块


ASTNode *parser_parse_block(Parser *parser) {
    if (!parser_match(parser, TOKEN_LEFT_BRACE)) {
        // Debug: block parsing start failure
        if (parser->current_token && parser->current_token->line >= 169 && parser->current_token->line <= 193) {
            fprintf(stderr, "[DEBUG BLOCK] Expected LEFT_BRACE but got token type %d at line %d:%d\n",
                    parser->current_token->type, parser->current_token->line, parser->current_token->column);
        }
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 '{'
    
    // Debug: block parsing started
    if (line >= 169 && line <= 193) {
        fprintf(stderr, "[DEBUG BLOCK] Started parsing block at line %d:%d\n", line, col);
    }

    ASTNode *block = ast_new_node(AST_BLOCK, line, col, filename);
    if (!block) {
        if (line >= 169 && line <= 193) {
            fprintf(stderr, "[DEBUG BLOCK] Failed to allocate block node\n");
        }
        return NULL;
    }

    // 初始化语句列表
    block->data.block.stmts = NULL;
    block->data.block.stmt_count = 0;
    int capacity = 0;

    // 解析语句直到遇到 '}'
    while (parser->current_token && !parser_match(parser, TOKEN_RIGHT_BRACE)) {
        if (line >= 169 && line <= 193) {
            fprintf(stderr, "[DEBUG BLOCK] Parsing statement, current token: type=%d, line=%d:%d, value=%s\n",
                    parser->current_token->type, parser->current_token->line, parser->current_token->column,
                    parser->current_token->value ? parser->current_token->value : "(null)");
        }
        ASTNode *stmt = parser_parse_statement(parser);
        if (!stmt) {
            // Debug: print parse failure for main function
            if (parser->current_token && parser->current_token->line >= 169 && parser->current_token->line <= 193) {
                fprintf(stderr, "[DEBUG BLOCK] Failed to parse statement at line %d:%d (token type: %d, value: %s)\n",
                        parser->current_token->line, parser->current_token->column,
                        parser->current_token->type,
                        parser->current_token->value ? parser->current_token->value : "(null)");
            }
            // 如果解析语句失败，尝试跳过到下一个分号或右大括号
            while (parser->current_token &&
                   !parser_match(parser, TOKEN_SEMICOLON) &&
                   !parser_match(parser, TOKEN_RIGHT_BRACE)) {
                if (parser->current_token && parser->current_token->line >= 169 && parser->current_token->line <= 193) {
                    fprintf(stderr, "[DEBUG BLOCK] Skipping token: type=%d, value=%s\n",
                            parser->current_token->type,
                            parser->current_token->value ? parser->current_token->value : "(null)");
                }
                parser_consume(parser);
            }
            if (parser_match(parser, TOKEN_SEMICOLON)) {
                parser_consume(parser);
            }
            continue;
        }
        
        if (line >= 169 && line <= 193) {
            fprintf(stderr, "[DEBUG BLOCK] Successfully parsed statement, type=%d\n", stmt->type);
        }

        // 扩容语句列表
        if (block->data.block.stmt_count >= capacity) {
            int new_capacity = capacity == 0 ? 4 : capacity * 2;
            ASTNode **new_stmts = realloc(block->data.block.stmts, new_capacity * sizeof(ASTNode*));
            if (!new_stmts) {
                ast_free(stmt);
                ast_free(block);
                return NULL;
            }
            block->data.block.stmts = new_stmts;
            capacity = new_capacity;
        }

        block->data.block.stmts[block->data.block.stmt_count] = stmt;
        block->data.block.stmt_count++;

        // 消费分号（如果存在）
        if (parser_match(parser, TOKEN_SEMICOLON)) {
            parser_consume(parser);
        }
    }

    if (!parser_match(parser, TOKEN_RIGHT_BRACE)) {
        if (line >= 169 && line <= 193) {
            fprintf(stderr, "[DEBUG BLOCK] Expected RIGHT_BRACE but got token type %d at line %d:%d, value=%s\n",
                    parser->current_token ? parser->current_token->type : -1,
                    parser->current_token ? parser->current_token->line : 0,
                    parser->current_token ? parser->current_token->column : 0,
                    parser->current_token && parser->current_token->value ? parser->current_token->value : "(null)");
        }
        fprintf(stderr, "语法错误: 期望 '}', 但在 %s:%d:%d 找不到\n",
                parser->current_token ? parser->current_token->filename : "unknown",
                parser->current_token ? parser->current_token->line : 0,
                parser->current_token ? parser->current_token->column : 0);
        ast_free(block);
        return NULL;
    }

    parser_consume(parser); // 消费 '}'
    
    if (line >= 169 && line <= 193) {
        fprintf(stderr, "[DEBUG BLOCK] Successfully parsed block with %d statements\n", block->data.block.stmt_count);
    }

    return block;
}

// 解析函数参数


