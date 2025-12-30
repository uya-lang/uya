#include "parser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

Parser *parser_new(Lexer *lexer) {
    Parser *parser = malloc(sizeof(Parser));
    if (!parser) {
        return NULL;
    }

    parser->lexer = lexer;
    parser->current_token = lexer_next_token(lexer);

    return parser;
}

void parser_free(Parser *parser) {
    if (parser) {
        if (parser->current_token) {
            token_free(parser->current_token);
        }
        free(parser);
    }
}

// 前瞻当前token
static Token *parser_peek(Parser *parser) {
    return parser->current_token;
}

// 消费当前token并获取下一个
static Token *parser_consume(Parser *parser) {
    Token *current = parser->current_token;
    parser->current_token = lexer_next_token(parser->lexer);
    return current;
}

// 检查当前token类型
static int parser_match(Parser *parser, TokenType type) {
    return parser->current_token && parser->current_token->type == type;
}

// 期望特定类型的token
static Token *parser_expect(Parser *parser, TokenType type) {
    if (!parser->current_token || parser->current_token->type != type) {
        fprintf(stderr, "语法错误: 期望 %d, 但在 %s:%d:%d 发现 %d\n",
                type, parser->current_token ? parser->current_token->filename : "unknown",
                parser->current_token ? parser->current_token->line : 0,
                parser->current_token ? parser->current_token->column : 0,
                parser->current_token ? parser->current_token->type : -1);
        return NULL;
    }
    return parser_consume(parser);
}

// 前向声明
static ASTNode *parser_parse_statement(Parser *parser);
static ASTNode *parser_parse_if_stmt(Parser *parser);
static ASTNode *parser_parse_while_stmt(Parser *parser);
static ASTNode *parser_parse_block(Parser *parser);

// 解析类型
static ASTNode *parser_parse_type(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    // Check if it's an array type: [element_type; size]
    if (parser_match(parser, TOKEN_LEFT_BRACKET)) {
        // Parse array type: [i32; 10]
        parser_consume(parser); // consume '['

        ASTNode *array_type = ast_new_node(AST_TYPE_ARRAY,
                                           parser->current_token->line,
                                           parser->current_token->column,
                                           parser->current_token->filename);
        if (!array_type) {
            return NULL;
        }

        // Parse element type
        array_type->data.type_array.element_type = parser_parse_type(parser);
        if (!array_type->data.type_array.element_type) {
            ast_free(array_type);
            return NULL;
        }

        // Expect ';'
        if (!parser_expect(parser, TOKEN_SEMICOLON)) {
            ast_free(array_type);
            return NULL;
        }

        // Parse size
        if (!parser_match(parser, TOKEN_NUMBER)) {
            ast_free(array_type);
            return NULL;
        }

        // Convert string number to integer
        array_type->data.type_array.size = atoi(parser->current_token->value);
        parser_consume(parser); // consume number

        // Expect ']'
        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
            ast_free(array_type);
            return NULL;
        }

        return array_type;
    } else {
        // Handle simple named type
        ASTNode *type_node = ast_new_node(AST_TYPE_NAMED,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
        if (!type_node) {
            return NULL;
        }

        // 保存类型名称
        type_node->data.type_named.name = malloc(strlen(parser->current_token->value) + 1);
        if (!type_node->data.type_named.name) {
            ast_free(type_node);
            return NULL;
        }
        strcpy(type_node->data.type_named.name, parser->current_token->value);

        // 消费类型标识符
        parser_consume(parser);

        return type_node;
    }
}

// 解析表达式（简化版）

// 解析表达式（增强版，支持二元运算）
static ASTNode *parser_parse_expression(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    // 简单的表达式解析，处理标识符、函数调用、数字等
    ASTNode *left = NULL;

    if (parser_match(parser, TOKEN_IDENTIFIER)) {
        ASTNode *ident = ast_new_node(AST_IDENTIFIER,
                                      parser->current_token->line,
                                      parser->current_token->column,
                                      parser->current_token->filename);
        if (ident) {
            ident->data.identifier.name = malloc(strlen(parser->current_token->value) + 1);
            if (ident->data.identifier.name) {
                strcpy(ident->data.identifier.name, parser->current_token->value);
            }
        }
        parser_consume(parser);

        // Check if this identifier is followed by a function call '('
        if (parser_match(parser, TOKEN_LEFT_PAREN)) {
            // This is a function call: identifier(args)
            ASTNode *call = ast_new_node(AST_CALL_EXPR,
                                         parser->current_token->line,
                                         parser->current_token->column,
                                         parser->current_token->filename);
            if (call) {
                call->data.call_expr.callee = ident;  // Use the identifier as callee
                parser_consume(parser);  // consume '('

                // Parse arguments
                call->data.call_expr.args = NULL;
                call->data.call_expr.arg_count = 0;
                int capacity = 0;

                if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
                    do {
                        ASTNode *arg = parser_parse_expression(parser);
                        if (!arg) {
                            ast_free(call);
                            return NULL;
                        }

                        // Expand arguments array
                        if (call->data.call_expr.arg_count >= capacity) {
                            int new_capacity = capacity == 0 ? 4 : capacity * 2;
                            ASTNode **new_args = realloc(call->data.call_expr.args,
                                                        new_capacity * sizeof(ASTNode*));
                            if (!new_args) {
                                ast_free(arg);
                                ast_free(call);
                                return NULL;
                            }
                            call->data.call_expr.args = new_args;
                            capacity = new_capacity;
                        }

                        call->data.call_expr.args[call->data.call_expr.arg_count] = arg;
                        call->data.call_expr.arg_count++;

                        if (parser_match(parser, TOKEN_COMMA)) {
                            parser_consume(parser); // consume ','
                        } else {
                            break;
                        }
                    } while (!parser_match(parser, TOKEN_RIGHT_PAREN) && parser->current_token);
                }

                if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
                    ast_free(call);
                    return NULL;
                }

                left = call;
            } else {
                ast_free(ident);  // Clean up the identifier we created
                return NULL;
            }
        } else {
            left = ident;
        }
    } else if (parser_match(parser, TOKEN_NUMBER)) {
        ASTNode *num = ast_new_node(AST_NUMBER,
                                    parser->current_token->line,
                                    parser->current_token->column,
                                    parser->current_token->filename);
        if (num) {
            num->data.number.value = malloc(strlen(parser->current_token->value) + 1);
            if (num->data.number.value) {
                strcpy(num->data.number.value, parser->current_token->value);
            }
        }
        parser_consume(parser);
        left = num;
    } else if (parser_match(parser, TOKEN_STRING)) {
        ASTNode *str = ast_new_node(AST_STRING,
                                    parser->current_token->line,
                                    parser->current_token->column,
                                    parser->current_token->filename);
        if (str) {
            str->data.string.value = malloc(strlen(parser->current_token->value) + 1);
            if (str->data.string.value) {
                strcpy(str->data.string.value, parser->current_token->value);
            }
        }
        parser_consume(parser);
        left = str;
    } else if (parser_match(parser, TOKEN_TRUE) || parser_match(parser, TOKEN_FALSE)) {
        ASTNode *bool_node = ast_new_node(AST_BOOL,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
        if (bool_node) {
            bool_node->data.bool_literal.value = parser_match(parser, TOKEN_TRUE);
        }
        parser_consume(parser);
        left = bool_node;
    } else if (parser_match(parser, TOKEN_LEFT_BRACKET)) {
        // Parse array literal: [1, 2, 3, 4, 5]
        parser_consume(parser); // consume '['

        ASTNode *array_literal = ast_new_node(AST_CALL_EXPR,  // Using call expression temporarily
                                              parser->current_token->line,
                                              parser->current_token->column,
                                              parser->current_token->filename);
        if (!array_literal) {
            return NULL;
        }

        // Initialize the array literal as a call to an array constructor
        array_literal->data.call_expr.callee = ast_new_node(AST_IDENTIFIER,
                                                           parser->current_token->line,
                                                           parser->current_token->column,
                                                           parser->current_token->filename);
        if (array_literal->data.call_expr.callee) {
            array_literal->data.call_expr.callee->data.identifier.name = malloc(6);
            if (array_literal->data.call_expr.callee->data.identifier.name) {
                strcpy(array_literal->data.call_expr.callee->data.identifier.name, "array");
            }
        }

        // Parse array elements
        array_literal->data.call_expr.args = NULL;
        array_literal->data.call_expr.arg_count = 0;
        int capacity = 0;

        if (!parser_match(parser, TOKEN_RIGHT_BRACKET)) {
            do {
                ASTNode *element = parser_parse_expression(parser);
                if (!element) {
                    ast_free(array_literal);
                    return NULL;
                }

                // Expand arguments array
                if (array_literal->data.call_expr.arg_count >= capacity) {
                    int new_capacity = capacity == 0 ? 4 : capacity * 2;
                    ASTNode **new_args = realloc(array_literal->data.call_expr.args,
                                                new_capacity * sizeof(ASTNode*));
                    if (!new_args) {
                        ast_free(element);
                        ast_free(array_literal);
                        return NULL;
                    }
                    array_literal->data.call_expr.args = new_args;
                    capacity = new_capacity;
                }

                array_literal->data.call_expr.args[array_literal->data.call_expr.arg_count] = element;
                array_literal->data.call_expr.arg_count++;

                if (parser_match(parser, TOKEN_COMMA)) {
                    parser_consume(parser); // consume ','
                } else {
                    break;
                }
            } while (!parser_match(parser, TOKEN_RIGHT_BRACKET) && parser->current_token);
        }

        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
            ast_free(array_literal);
            return NULL;
        }

        left = array_literal;
    } else {
        return NULL;
    }

    // Now check if there's a binary operator following
    if (parser->current_token) {
        TokenType op_type = parser->current_token->type;

        // Check if it's a binary operator
        if (op_type == TOKEN_PLUS || op_type == TOKEN_MINUS ||
            op_type == TOKEN_ASTERISK || op_type == TOKEN_SLASH ||
            op_type == TOKEN_PERCENT || op_type == TOKEN_EQUAL ||
            op_type == TOKEN_NOT_EQUAL || op_type == TOKEN_LESS ||
            op_type == TOKEN_LESS_EQUAL || op_type == TOKEN_GREATER ||
            op_type == TOKEN_GREATER_EQUAL) {

            parser_consume(parser); // consume the operator

            // Parse the right operand
            ASTNode *right = parser_parse_expression(parser);
            if (!right) {
                ast_free(left);
                return NULL;
            }

            // Create binary expression
            ASTNode *binary_expr = ast_new_node(AST_BINARY_EXPR,
                                               parser->current_token->line,
                                               parser->current_token->column,
                                               parser->current_token->filename);
            if (!binary_expr) {
                ast_free(left);
                ast_free(right);
                return NULL;
            }

            binary_expr->data.binary_expr.left = left;
            binary_expr->data.binary_expr.op = op_type;
            binary_expr->data.binary_expr.right = right;

            return binary_expr;
        }
    }

    return left;
}

// 解析变量声明
static ASTNode *parser_parse_var_decl(Parser *parser) {
    if (!parser_match(parser, TOKEN_LET) && !parser_match(parser, TOKEN_MUT)) {
        return NULL;
    }

    int is_mut = parser_match(parser, TOKEN_MUT);
    parser_consume(parser); // 消费 let 或 mut

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
    var_decl->data.var_decl.is_const = 0;

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
static ASTNode *parser_parse_return_stmt(Parser *parser) {
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
static ASTNode *parser_parse_statement(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    if (parser_match(parser, TOKEN_LET) || parser_match(parser, TOKEN_MUT)) {
        return parser_parse_var_decl(parser);
    } else if (parser_match(parser, TOKEN_RETURN)) {
        return parser_parse_return_stmt(parser);
    } else if (parser_match(parser, TOKEN_IF)) {
        return parser_parse_if_stmt(parser);
    } else if (parser_match(parser, TOKEN_WHILE)) {
        return parser_parse_while_stmt(parser);
    } else {
        // 解析表达式语句或其他语句
        return parser_parse_expression(parser);
    }
}

// 解析 if 语句
static ASTNode *parser_parse_if_stmt(Parser *parser) {
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
        fprintf(stderr, "语法错误: if 语句需要条件表达式\n");
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
        if_stmt->data.if_stmt.else_branch = parser_parse_block(parser);
        if (!if_stmt->data.if_stmt.else_branch) {
            ast_free(if_stmt);
            return NULL;
        }
    } else {
        if_stmt->data.if_stmt.else_branch = NULL;
    }

    return if_stmt;
}

// 解析 while 语句
static ASTNode *parser_parse_while_stmt(Parser *parser) {
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

// 解析代码块
static ASTNode *parser_parse_block(Parser *parser) {
    if (!parser_match(parser, TOKEN_LEFT_BRACE)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 '{'

    ASTNode *block = ast_new_node(AST_BLOCK, line, col, filename);
    if (!block) {
        return NULL;
    }

    // 初始化语句列表
    block->data.block.stmts = NULL;
    block->data.block.stmt_count = 0;
    int capacity = 0;

    // 解析语句直到遇到 '}'
    while (parser->current_token && !parser_match(parser, TOKEN_RIGHT_BRACE)) {
        ASTNode *stmt = parser_parse_statement(parser);
        if (!stmt) {
            // 如果解析语句失败，尝试跳过到下一个分号或右大括号
            while (parser->current_token &&
                   !parser_match(parser, TOKEN_SEMICOLON) &&
                   !parser_match(parser, TOKEN_RIGHT_BRACE)) {
                parser_consume(parser);
            }
            if (parser_match(parser, TOKEN_SEMICOLON)) {
                parser_consume(parser);
            }
            continue;
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
        fprintf(stderr, "语法错误: 期望 '}', 但在 %s:%d:%d 找不到\n",
                parser->current_token ? parser->current_token->filename : "unknown",
                parser->current_token ? parser->current_token->line : 0,
                parser->current_token ? parser->current_token->column : 0);
        ast_free(block);
        return NULL;
    }

    parser_consume(parser); // 消费 '}'

    return block;
}

// 解析函数参数
static ASTNode *parser_parse_param(Parser *parser) {
    if (!parser->current_token || !parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }

    ASTNode *param = ast_new_node(AST_VAR_DECL,
                                  parser->current_token->line,
                                  parser->current_token->column,
                                  parser->current_token->filename);
    if (!param) {
        return NULL;
    }

    param->data.var_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!param->data.var_decl.name) {
        ast_free(param);
        return NULL;
    }
    strcpy(param->data.var_decl.name, parser->current_token->value);
    param->data.var_decl.is_mut = 0;
    param->data.var_decl.is_const = 0;

    parser_consume(parser); // 消费参数名

    // 期望类型注解 ':'
    if (parser_match(parser, TOKEN_COLON)) {
        parser_consume(parser); // 消费 ':'
        param->data.var_decl.type = parser_parse_type(parser);
        if (!param->data.var_decl.type) {
            ast_free(param);
            return NULL;
        }
    }

    return param;
}

// 解析函数声明
static ASTNode *parser_parse_fn_decl(Parser *parser) {
    if (!parser_match(parser, TOKEN_FN)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 fn

    // 期望函数名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: 期望函数名\n");
        return NULL;
    }

    ASTNode *fn_decl = ast_new_node(AST_FN_DECL, line, col, filename);
    if (!fn_decl) {
        return NULL;
    }

    fn_decl->data.fn_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!fn_decl->data.fn_decl.name) {
        ast_free(fn_decl);
        return NULL;
    }
    strcpy(fn_decl->data.fn_decl.name, parser->current_token->value);
    fn_decl->data.fn_decl.is_extern = 0;

    parser_consume(parser); // 消费函数名

    // 期望 '('
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        ast_free(fn_decl);
        return NULL;
    }

    // 解析参数列表
    fn_decl->data.fn_decl.params = NULL;
    fn_decl->data.fn_decl.param_count = 0;
    int param_capacity = 0;

    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        do {
            ASTNode *param = parser_parse_param(parser);
            if (!param) {
                ast_free(fn_decl);
                return NULL;
            }

            // 扩容参数列表
            if (fn_decl->data.fn_decl.param_count >= param_capacity) {
                int new_capacity = param_capacity == 0 ? 4 : param_capacity * 2;
                ASTNode **new_params = realloc(fn_decl->data.fn_decl.params,
                                               new_capacity * sizeof(ASTNode*));
                if (!new_params) {
                    ast_free(param);
                    ast_free(fn_decl);
                    return NULL;
                }
                fn_decl->data.fn_decl.params = new_params;
                param_capacity = new_capacity;
            }

            fn_decl->data.fn_decl.params[fn_decl->data.fn_decl.param_count] = param;
            fn_decl->data.fn_decl.param_count++;

            if (parser_match(parser, TOKEN_COMMA)) {
                parser_consume(parser); // 消费 ','
            } else {
                break;
            }
        } while (!parser_match(parser, TOKEN_RIGHT_PAREN) && parser->current_token);
    }

    // 期望 ')'
    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
        ast_free(fn_decl);
        return NULL;
    }

    // 检查是否有返回类型（可选）
    // 支持两种语法：fn main() -> i32 和 fn main() i32
    if (parser_match(parser, TOKEN_ARROW)) {
        parser_consume(parser); // 消费 '->'
        fn_decl->data.fn_decl.return_type = parser_parse_type(parser);
        if (!fn_decl->data.fn_decl.return_type) {
            ast_free(fn_decl);
            return NULL;
        }
    } else if (parser->current_token && parser_match(parser, TOKEN_IDENTIFIER)) {
        // Check if the identifier is a type name (for syntax like fn main() i32)
        // We need to check the token value to see if it's a type
        if (strcmp(parser->current_token->value, "i32") == 0 ||
            strcmp(parser->current_token->value, "i64") == 0 ||
            strcmp(parser->current_token->value, "i8") == 0 ||
            strcmp(parser->current_token->value, "i16") == 0 ||
            strcmp(parser->current_token->value, "u32") == 0 ||
            strcmp(parser->current_token->value, "u64") == 0 ||
            strcmp(parser->current_token->value, "u8") == 0 ||
            strcmp(parser->current_token->value, "u16") == 0 ||
            strcmp(parser->current_token->value, "f32") == 0 ||
            strcmp(parser->current_token->value, "f64") == 0 ||
            strcmp(parser->current_token->value, "bool") == 0 ||
            strcmp(parser->current_token->value, "void") == 0) {
            // Manually create the type node
            fn_decl->data.fn_decl.return_type = ast_new_node(AST_TYPE_NAMED, line, col, filename);
            if (fn_decl->data.fn_decl.return_type) {
                fn_decl->data.fn_decl.return_type->data.type_named.name = malloc(strlen(parser->current_token->value) + 1);
                if (fn_decl->data.fn_decl.return_type->data.type_named.name) {
                    strcpy(fn_decl->data.fn_decl.return_type->data.type_named.name, parser->current_token->value);
                }
            }
            // Consume the type identifier token
            parser_consume(parser);
        } else {
            // Not a type name, use default void
            fn_decl->data.fn_decl.return_type = ast_new_node(AST_TYPE_NAMED, line, col, filename);
            if (fn_decl->data.fn_decl.return_type) {
                fn_decl->data.fn_decl.return_type->data.type_named.name = malloc(5);
                if (fn_decl->data.fn_decl.return_type->data.type_named.name) {
                    strcpy(fn_decl->data.fn_decl.return_type->data.type_named.name, "void");
                }
            }
        }
    } else {
        // 默认返回类型为 void
        fn_decl->data.fn_decl.return_type = ast_new_node(AST_TYPE_NAMED, line, col, filename);
        if (fn_decl->data.fn_decl.return_type) {
            fn_decl->data.fn_decl.return_type->data.type_named.name = malloc(5);
            if (fn_decl->data.fn_decl.return_type->data.type_named.name) {
                strcpy(fn_decl->data.fn_decl.return_type->data.type_named.name, "void");
            }
        }
    }

    // 解析函数体（代码块）
    fn_decl->data.fn_decl.body = parser_parse_block(parser);
    if (!fn_decl->data.fn_decl.body) {
        ast_free(fn_decl);
        return NULL;
    }

    return fn_decl;
}

// 解析外部函数声明
static ASTNode *parser_parse_extern_decl(Parser *parser) {
    if (!parser_match(parser, TOKEN_EXTERN)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 extern

    // 解析返回类型
    ASTNode *return_type = parser_parse_type(parser);
    if (!return_type) {
        fprintf(stderr, "语法错误: extern函数声明期望返回类型\n");
        return NULL;
    }

    // 期望函数名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: extern函数声明期望函数名\n");
        ast_free(return_type);
        return NULL;
    }

    ASTNode *extern_decl = ast_new_node(AST_EXTERN_DECL, line, col, filename);
    if (!extern_decl) {
        ast_free(return_type);
        return NULL;
    }

    extern_decl->data.fn_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!extern_decl->data.fn_decl.name) {
        ast_free(return_type);
        ast_free(extern_decl);
        return NULL;
    }
    strcpy(extern_decl->data.fn_decl.name, parser->current_token->value);
    extern_decl->data.fn_decl.is_extern = 1;
    extern_decl->data.fn_decl.return_type = return_type;

    parser_consume(parser); // 消费函数名

    // 期望 '('
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        ast_free(extern_decl);
        return NULL;
    }

    // 解析参数列表
    extern_decl->data.fn_decl.params = NULL;
    extern_decl->data.fn_decl.param_count = 0;
    int param_capacity = 0;

    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        do {
            // 检查是否是可变参数 ...
            if (parser_match(parser, TOKEN_ELLIPSIS)) {
                // 创建可变参数节点
                ASTNode *vararg_param = ast_new_node(AST_VAR_DECL,
                                                     parser->current_token->line,
                                                     parser->current_token->column,
                                                     parser->current_token->filename);
                if (vararg_param) {
                    vararg_param->data.var_decl.name = malloc(4);
                    if (vararg_param->data.var_decl.name) {
                        strcpy(vararg_param->data.var_decl.name, "...");
                    }
                    vararg_param->data.var_decl.type = ast_new_node(AST_TYPE_NAMED,
                                                                   parser->current_token->line,
                                                                   parser->current_token->column,
                                                                   parser->current_token->filename);
                    if (vararg_param->data.var_decl.type) {
                        vararg_param->data.var_decl.type->data.type_named.name = malloc(4);
                        if (vararg_param->data.var_decl.type->data.type_named.name) {
                            strcpy(vararg_param->data.var_decl.type->data.type_named.name, "...");
                        }
                    }

                    // 扩容参数列表
                    if (extern_decl->data.fn_decl.param_count >= param_capacity) {
                        int new_capacity = param_capacity == 0 ? 4 : param_capacity * 2;
                        ASTNode **new_params = realloc(extern_decl->data.fn_decl.params,
                                                       new_capacity * sizeof(ASTNode*));
                        if (new_params) {
                            extern_decl->data.fn_decl.params = new_params;
                            param_capacity = new_capacity;
                        } else {
                            ast_free(vararg_param);
                            ast_free(extern_decl);
                            return NULL;
                        }
                    }

                    extern_decl->data.fn_decl.params[extern_decl->data.fn_decl.param_count] = vararg_param;
                    extern_decl->data.fn_decl.param_count++;
                }
                parser_consume(parser); // 消费 '...'
                break; // 可变参数是最后一个参数
            }

            // 解析普通参数
            ASTNode *param = parser_parse_param(parser);
            if (!param) {
                ast_free(extern_decl);
                return NULL;
            }

            // 扩容参数列表
            if (extern_decl->data.fn_decl.param_count >= param_capacity) {
                int new_capacity = param_capacity == 0 ? 4 : param_capacity * 2;
                ASTNode **new_params = realloc(extern_decl->data.fn_decl.params,
                                               new_capacity * sizeof(ASTNode*));
                if (!new_params) {
                    ast_free(param);
                    ast_free(extern_decl);
                    return NULL;
                }
                extern_decl->data.fn_decl.params = new_params;
                param_capacity = new_capacity;
            }

            extern_decl->data.fn_decl.params[extern_decl->data.fn_decl.param_count] = param;
            extern_decl->data.fn_decl.param_count++;

            if (parser_match(parser, TOKEN_COMMA)) {
                parser_consume(parser); // 消费 ','

                // 检查逗号后的是否是可变参数 ...
                if (parser_match(parser, TOKEN_ELLIPSIS)) {
                    // 创建可变参数节点
                    ASTNode *vararg_param = ast_new_node(AST_VAR_DECL,
                                                         parser->current_token->line,
                                                         parser->current_token->column,
                                                         parser->current_token->filename);
                    if (vararg_param) {
                        vararg_param->data.var_decl.name = malloc(4);
                        if (vararg_param->data.var_decl.name) {
                            strcpy(vararg_param->data.var_decl.name, "...");
                        }
                        vararg_param->data.var_decl.type = ast_new_node(AST_TYPE_NAMED,
                                                                       parser->current_token->line,
                                                                       parser->current_token->column,
                                                                       parser->current_token->filename);
                        if (vararg_param->data.var_decl.type) {
                            vararg_param->data.var_decl.type->data.type_named.name = malloc(4);
                            if (vararg_param->data.var_decl.type->data.type_named.name) {
                                strcpy(vararg_param->data.var_decl.type->data.type_named.name, "...");
                            }
                        }

                        // 扩容参数列表
                        if (extern_decl->data.fn_decl.param_count >= param_capacity) {
                            int new_capacity = param_capacity == 0 ? 4 : param_capacity * 2;
                            ASTNode **new_params = realloc(extern_decl->data.fn_decl.params,
                                                           new_capacity * sizeof(ASTNode*));
                            if (new_params) {
                                extern_decl->data.fn_decl.params = new_params;
                                param_capacity = new_capacity;
                            } else {
                                ast_free(vararg_param);
                                ast_free(extern_decl);
                                return NULL;
                            }
                        }

                        extern_decl->data.fn_decl.params[extern_decl->data.fn_decl.param_count] = vararg_param;
                        extern_decl->data.fn_decl.param_count++;
                    }
                    parser_consume(parser); // 消费 '...'
                    break; // 可变参数是最后一个参数
                }
            } else {
                break;
            }
        } while (!parser_match(parser, TOKEN_RIGHT_PAREN) && parser->current_token);
    }

    // 期望 ')'
    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
        ast_free(extern_decl);
        return NULL;
    }

    // extern声明没有函数体，所以body为NULL
    extern_decl->data.fn_decl.body = NULL;

    return extern_decl;
}

// 解析结构体声明
static ASTNode *parser_parse_struct_decl(Parser *parser) {
    if (!parser_match(parser, TOKEN_STRUCT)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 struct

    // 期望结构体名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: 期望结构体名\n");
        return NULL;
    }

    ASTNode *struct_decl = ast_new_node(AST_STRUCT_DECL, line, col, filename);
    if (!struct_decl) {
        return NULL;
    }

    struct_decl->data.struct_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!struct_decl->data.struct_decl.name) {
        ast_free(struct_decl);
        return NULL;
    }
    strcpy(struct_decl->data.struct_decl.name, parser->current_token->value);

    parser_consume(parser); // 消费结构体名

    // 期望 '{'
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) {
        ast_free(struct_decl);
        return NULL;
    }

    // 解析字段列表
    struct_decl->data.struct_decl.fields = NULL;
    struct_decl->data.struct_decl.field_count = 0;
    int field_capacity = 0;

    while (parser->current_token && !parser_match(parser, TOKEN_RIGHT_BRACE)) {
        // 期望字段名
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            fprintf(stderr, "语法错误: 期望字段名\n");
            ast_free(struct_decl);
            return NULL;
        }

        ASTNode *field = ast_new_node(AST_VAR_DECL,
                                      parser->current_token->line,
                                      parser->current_token->column,
                                      parser->current_token->filename);
        if (!field) {
            ast_free(struct_decl);
            return NULL;
        }

        field->data.var_decl.name = malloc(strlen(parser->current_token->value) + 1);
        if (!field->data.var_decl.name) {
            ast_free(field);
            ast_free(struct_decl);
            return NULL;
        }
        strcpy(field->data.var_decl.name, parser->current_token->value);
        field->data.var_decl.is_mut = 0;
        field->data.var_decl.is_const = 0;

        parser_consume(parser); // 消费字段名

        // 期望 ':'
        if (!parser_expect(parser, TOKEN_COLON)) {
            ast_free(field);
            ast_free(struct_decl);
            return NULL;
        }

        // 解析字段类型
        field->data.var_decl.type = parser_parse_type(parser);
        if (!field->data.var_decl.type) {
            ast_free(field);
            ast_free(struct_decl);
            return NULL;
        }

        // 检查是否有逗号
        if (parser_match(parser, TOKEN_COMMA)) {
            parser_consume(parser);
        }

        // 扩容字段列表
        if (struct_decl->data.struct_decl.field_count >= field_capacity) {
            int new_capacity = field_capacity == 0 ? 4 : field_capacity * 2;
            ASTNode **new_fields = realloc(struct_decl->data.struct_decl.fields,
                                           new_capacity * sizeof(ASTNode*));
            if (!new_fields) {
                ast_free(field);
                ast_free(struct_decl);
                return NULL;
            }
            struct_decl->data.struct_decl.fields = new_fields;
            field_capacity = new_capacity;
        }

        struct_decl->data.struct_decl.fields[struct_decl->data.struct_decl.field_count] = field;
        struct_decl->data.struct_decl.field_count++;
    }

    // 期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        ast_free(struct_decl);
        return NULL;
    }

    return struct_decl;
}

// 解析顶级声明
static ASTNode *parser_parse_declaration(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    if (parser_match(parser, TOKEN_FN)) {
        return parser_parse_fn_decl(parser);
    } else if (parser_match(parser, TOKEN_STRUCT)) {
        return parser_parse_struct_decl(parser);
    } else if (parser_match(parser, TOKEN_EXTERN)) {
        return parser_parse_extern_decl(parser);
    } else {
        return parser_parse_statement(parser);
    }
}

ASTNode *parser_parse(Parser *parser) {
    if (!parser || !parser->current_token) {
        return NULL;
    }

    ASTNode *program = ast_new_node(AST_PROGRAM,
                                    parser->current_token->line,
                                    parser->current_token->column,
                                    parser->current_token->filename);
    if (!program) {
        return NULL;
    }

    // 初始化声明列表
    program->data.program.decls = NULL;
    program->data.program.decl_count = 0;
    int capacity = 0;

    // 解析所有顶级声明
    while (parser->current_token && !parser_match(parser, TOKEN_EOF)) {
        ASTNode *decl = parser_parse_declaration(parser);
        if (!decl) {
            // 如果解析声明失败，跳过到下一个可能的声明开始
            while (parser->current_token &&
                   !parser_match(parser, TOKEN_FN) &&
                   !parser_match(parser, TOKEN_STRUCT) &&
                   !parser_match(parser, TOKEN_EXTERN) &&
                   !parser_match(parser, TOKEN_EOF)) {
                parser_consume(parser);
            }
            continue;
        }

        // 扩容声明列表
        if (program->data.program.decl_count >= capacity) {
            int new_capacity = capacity == 0 ? 8 : capacity * 2;
            ASTNode **new_decls = realloc(program->data.program.decls,
                                          new_capacity * sizeof(ASTNode*));
            if (!new_decls) {
                ast_free(decl);
                ast_free(program);
                return NULL;
            }
            program->data.program.decls = new_decls;
            capacity = new_capacity;
        }

        program->data.program.decls[program->data.program.decl_count] = decl;
        program->data.program.decl_count++;
    }

    return program;
}