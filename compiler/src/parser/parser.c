#include "parser.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

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
static ASTNode *parser_parse_for_stmt(Parser *parser);
static ASTNode *parser_parse_block(Parser *parser);
static ASTNode *parser_parse_expression(Parser *parser);
static ASTNode *parser_parse_string_interpolation(Parser *parser, Token *string_token);

// 解析类型
static ASTNode *parser_parse_type(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    // Check if it's an error union type: !T
    if (parser_match(parser, TOKEN_EXCLAMATION)) {
        parser_consume(parser); // consume '!'
        
        ASTNode *error_union_type = ast_new_node(AST_TYPE_ERROR_UNION,
                                                 parser->current_token->line,
                                                 parser->current_token->column,
                                                 parser->current_token->filename);
        if (!error_union_type) {
            return NULL;
        }
        
        // Parse the base type
        error_union_type->data.type_error_union.base_type = parser_parse_type(parser);
        if (!error_union_type->data.type_error_union.base_type) {
            ast_free(error_union_type);
            return NULL;
        }
        
        return error_union_type;
    }

    // Check if it's an atomic type: atomic T
    if (parser_match(parser, TOKEN_ATOMIC)) {
        parser_consume(parser); // consume 'atomic'
        
        ASTNode *atomic_type = ast_new_node(AST_TYPE_ATOMIC,
                                            parser->current_token->line,
                                            parser->current_token->column,
                                            parser->current_token->filename);
        if (!atomic_type) {
            return NULL;
        }
        
        // Parse the base type
        atomic_type->data.type_atomic.base_type = parser_parse_type(parser);
        if (!atomic_type->data.type_atomic.base_type) {
            ast_free(atomic_type);
            return NULL;
        }
        
        return atomic_type;
    }

    // Check if it's a pointer type: *T
    if (parser_match(parser, TOKEN_ASTERISK)) {
        parser_consume(parser); // consume '*'
        
        ASTNode *pointer_type = ast_new_node(AST_TYPE_POINTER,
                                             parser->current_token->line,
                                             parser->current_token->column,
                                             parser->current_token->filename);
        if (!pointer_type) {
            return NULL;
        }
        
        // Parse the pointee type
        pointer_type->data.type_pointer.pointee_type = parser_parse_type(parser);
        if (!pointer_type->data.type_pointer.pointee_type) {
            ast_free(pointer_type);
            return NULL;
        }
        
        return pointer_type;
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

// 解析表达式（增强版，支持一元和二元运算）
static ASTNode *parser_parse_expression(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    // Check for try operator first
    if (parser_match(parser, TOKEN_TRY)) {
        parser_consume(parser); // consume 'try'

        // Parse the entire expression, including binary operations, as the try operand
        ASTNode *operand = parser_parse_expression(parser);
        if (!operand) return NULL;

        // Create a unary expression node for try
        ASTNode *unary_expr = ast_new_node(AST_UNARY_EXPR,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
        if (!unary_expr) {
            ast_free(operand);
            return NULL;
        }

        unary_expr->data.unary_expr.op = TOKEN_TRY;
        unary_expr->data.unary_expr.operand = operand;

        return unary_expr;
    }
    
    // Check for unary operators first (like &x, -x, !x)
    if (parser_match(parser, TOKEN_AMPERSAND)) {
        parser_consume(parser); // consume '&'

        ASTNode *operand = parser_parse_expression(parser);
        if (!operand) return NULL;

        ASTNode *unary_expr = ast_new_node(AST_UNARY_EXPR,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
        if (!unary_expr) {
            ast_free(operand);
            return NULL;
        }

        unary_expr->data.unary_expr.op = TOKEN_AMPERSAND;
        unary_expr->data.unary_expr.operand = operand;

        return unary_expr;
    } else if (parser_match(parser, TOKEN_MINUS)) {
        parser_consume(parser); // consume '-'

        ASTNode *operand = parser_parse_expression(parser);
        if (!operand) return NULL;

        ASTNode *unary_expr = ast_new_node(AST_UNARY_EXPR,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
        if (!unary_expr) {
            ast_free(operand);
            return NULL;
        }

        unary_expr->data.unary_expr.op = TOKEN_MINUS;
        unary_expr->data.unary_expr.operand = operand;

        return unary_expr;
    } else if (parser_match(parser, TOKEN_EXCLAMATION)) {
        parser_consume(parser); // consume '!'

        ASTNode *operand = parser_parse_expression(parser);
        if (!operand) return NULL;

        ASTNode *unary_expr = ast_new_node(AST_UNARY_EXPR,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
        if (!unary_expr) {
            ast_free(operand);
            return NULL;
        }

        unary_expr->data.unary_expr.op = TOKEN_EXCLAMATION;
        unary_expr->data.unary_expr.operand = operand;

        return unary_expr;
    }

    // 简单的表达式解析，处理标识符、函数调用、数字等
    ASTNode *left = NULL;

    // Handle both TOKEN_IDENTIFIER and TOKEN_ERROR (error is a keyword but can be used as identifier in error.ErrorName)
    if (parser_match(parser, TOKEN_IDENTIFIER) || parser_match(parser, TOKEN_ERROR)) {
        ASTNode *ident = ast_new_node(AST_IDENTIFIER,
                                      parser->current_token->line,
                                      parser->current_token->column,
                                      parser->current_token->filename);
        if (ident) {
            // For TOKEN_ERROR, use "error" as the name
            const char *name = parser_match(parser, TOKEN_ERROR) ? "error" : parser->current_token->value;
            ident->data.identifier.name = malloc(strlen(name) + 1);
            if (ident->data.identifier.name) {
                strcpy(ident->data.identifier.name, name);
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
        }
        // Check if this identifier is followed by struct initialization '{'
        else if (parser_match(parser, TOKEN_LEFT_BRACE)) {
            // This is a struct initialization: StructName{ field: value, ... }
            parser_consume(parser); // consume '{'

            ASTNode *struct_init = ast_new_node(AST_STRUCT_INIT,
                                               parser->current_token->line,
                                               parser->current_token->column,
                                               parser->current_token->filename);
            if (!struct_init) {
                ast_free(ident);  // Clean up the identifier
                return NULL;
            }

            // Set struct name from the identifier
            struct_init->data.struct_init.struct_name = malloc(strlen(ident->data.identifier.name) + 1);
            if (struct_init->data.struct_init.struct_name) {
                strcpy(struct_init->data.struct_init.struct_name, ident->data.identifier.name);
            } else {
                ast_free(struct_init);
                ast_free(ident);
                return NULL;
            }

            // Initialize fields array
            struct_init->data.struct_init.field_names = NULL;
            struct_init->data.struct_init.field_inits = NULL;
            struct_init->data.struct_init.field_count = 0;
            int capacity = 0;

            // Parse field initializations: field_name: value
            if (!parser_match(parser, TOKEN_RIGHT_BRACE)) {
                do {
                    // Expect field name (identifier)
                    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                        ast_free(struct_init);
                        ast_free(ident);
                        fprintf(stderr, "语法错误: 结构体初始化需要字段名\n");
                        return NULL;
                    }

                    char *field_name = malloc(strlen(parser->current_token->value) + 1);
                    if (!field_name) {
                        ast_free(struct_init);
                        ast_free(ident);
                        return NULL;
                    }
                    strcpy(field_name, parser->current_token->value);
                    parser_consume(parser); // consume field name

                    // Expect ':'
                    if (!parser_expect(parser, TOKEN_COLON)) {
                        free(field_name);
                        ast_free(struct_init);
                        ast_free(ident);
                        return NULL;
                    }

                    // Parse field value
                    ASTNode *field_value = parser_parse_expression(parser);
                    if (!field_value) {
                        free(field_name);
                        ast_free(struct_init);
                        ast_free(ident);
                        return NULL;
                    }

                    // Expand arrays
                    if (struct_init->data.struct_init.field_count >= capacity) {
                        int new_capacity = capacity == 0 ? 4 : capacity * 2;
                        char **new_names = realloc(struct_init->data.struct_init.field_names,
                                                  new_capacity * sizeof(char*));
                        ASTNode **new_values = realloc(struct_init->data.struct_init.field_inits,
                                                      new_capacity * sizeof(ASTNode*));
                        if (!new_names || !new_values) {
                            if (new_names) free(new_names);
                            if (new_values) free(new_values);
                            free(field_name);
                            ast_free(field_value);
                            ast_free(struct_init);
                            ast_free(ident);
                            return NULL;
                        }
                        struct_init->data.struct_init.field_names = new_names;
                        struct_init->data.struct_init.field_inits = new_values;
                        capacity = new_capacity;
                    }

                    struct_init->data.struct_init.field_names[struct_init->data.struct_init.field_count] = field_name;
                    struct_init->data.struct_init.field_inits[struct_init->data.struct_init.field_count] = field_value;
                    struct_init->data.struct_init.field_count++;

                    if (parser_match(parser, TOKEN_COMMA)) {
                        parser_consume(parser); // consume ','
                    } else {
                        break;
                    }
                } while (!parser_match(parser, TOKEN_RIGHT_BRACE) && parser->current_token);
            }

            // Expect '}'
            if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
                ast_free(struct_init);
                ast_free(ident);
                return NULL;
            }

            ast_free(ident);  // Free the temporary identifier
            left = struct_init;
        }
        // Check if this identifier is followed by member access '.'
        else if (parser_match(parser, TOKEN_DOT)) {
            // This is a member access: identifier.field
            parser_consume(parser); // consume '.'

            // Expect field name (identifier)
            if (!parser_match(parser, TOKEN_IDENTIFIER)) {
                ast_free(ident);
                fprintf(stderr, "语法错误: 成员访问需要字段名\n");
                return NULL;
            }

            ASTNode *member_access = ast_new_node(AST_MEMBER_ACCESS,
                                                 parser->current_token->line,
                                                 parser->current_token->column,
                                                 parser->current_token->filename);
            if (!member_access) {
                ast_free(ident);
                return NULL;
            }

            member_access->data.member_access.object = ident;  // Use the identifier as object
            member_access->data.member_access.field_name = malloc(strlen(parser->current_token->value) + 1);
            if (member_access->data.member_access.field_name) {
                strcpy(member_access->data.member_access.field_name, parser->current_token->value);
            }
            parser_consume(parser);  // consume field name

            // Check if this is a method call: object.method()
            if (parser_match(parser, TOKEN_LEFT_PAREN)) {
                // This is a method call: object.method(args)
                ASTNode *call = ast_new_node(AST_CALL_EXPR,
                                             parser->current_token->line,
                                             parser->current_token->column,
                                             parser->current_token->filename);
                if (!call) {
                    ast_free(member_access);
                    return NULL;
                }
                
                call->data.call_expr.callee = member_access;  // Use member_access as callee
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
                            ASTNode **new_args = realloc(call->data.call_expr.args, new_capacity * sizeof(ASTNode*));
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
                            parser_consume(parser);  // consume ','
                        } else {
                            break;
                        }
                    } while (parser->current_token && !parser_match(parser, TOKEN_RIGHT_PAREN));
                }
                
                // Expect ')'
                if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
                    ast_free(call);
                    return NULL;
                }
                
                left = call;
            } else {
                left = member_access;
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
        Token *string_token = parser->current_token;
        // 检查是否包含字符串插值语法 ${...}
        const char *value = string_token->value;
        if (value && strstr(value, "${") != NULL) {
            // 包含插值，解析为字符串插值节点
            ASTNode *interp = parser_parse_string_interpolation(parser, string_token);
            parser_consume(parser);  // 消费字符串 token
            if (interp) {
                left = interp;
            } else {
                // 解析失败，作为普通字符串处理
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
                left = str;
            }
        } else {
            // 普通字符串
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
        }
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

    // Now check for postfix operators (array subscript, member access, function call)
    while (parser->current_token && left) {
        TokenType op_type = parser->current_token->type;
        
        // Check for array subscript: arr[index] or slice: arr[start:len]
        if (op_type == TOKEN_LEFT_BRACKET) {
            parser_consume(parser); // consume '['
            
            ASTNode *start_expr = parser_parse_expression(parser);
            if (!start_expr) {
                ast_free(left);
                return NULL;
            }
            
            // 检查是否是切片语法（有冒号）
            if (parser_match(parser, TOKEN_COLON)) {
                // 切片语法：arr[start:len]
                parser_consume(parser); // consume ':'
                
                ASTNode *len_expr = parser_parse_expression(parser);
                if (!len_expr) {
                    ast_free(start_expr);
                    ast_free(left);
                    return NULL;
                }
                
                if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
                    ast_free(start_expr);
                    ast_free(len_expr);
                    ast_free(left);
                    return NULL;
                }
                
                // 创建slice函数调用：slice(arr, start, len)
                ASTNode *slice_call = ast_new_node(AST_CALL_EXPR,
                                                   left->line,
                                                   left->column,
                                                   left->filename);
                if (!slice_call) {
                    ast_free(start_expr);
                    ast_free(len_expr);
                    ast_free(left);
                    return NULL;
                }
                
                // callee: slice
                ASTNode *slice_ident = ast_new_node(AST_IDENTIFIER,
                                                    left->line,
                                                    left->column,
                                                    left->filename);
                if (!slice_ident) {
                    ast_free(start_expr);
                    ast_free(len_expr);
                    ast_free(left);
                    ast_free(slice_call);
                    return NULL;
                }
                slice_ident->data.identifier.name = malloc(6);
                if (slice_ident->data.identifier.name) {
                    strcpy(slice_ident->data.identifier.name, "slice");
                }
                slice_call->data.call_expr.callee = slice_ident;
                
                // args: [arr, start, len]
                slice_call->data.call_expr.args = malloc(3 * sizeof(ASTNode*));
                if (!slice_call->data.call_expr.args) {
                    ast_free(start_expr);
                    ast_free(len_expr);
                    ast_free(left);
                    ast_free(slice_ident);
                    ast_free(slice_call);
                    return NULL;
                }
                slice_call->data.call_expr.args[0] = left;
                slice_call->data.call_expr.args[1] = start_expr;
                slice_call->data.call_expr.args[2] = len_expr;
                slice_call->data.call_expr.arg_count = 3;
                
                left = slice_call;
                continue;  // Continue to check for more postfix operators
            } else {
                // 数组下标语法：arr[index]
                if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
                    ast_free(start_expr);
                    ast_free(left);
                    return NULL;
                }
                
                ASTNode *subscript = ast_new_node(AST_SUBSCRIPT_EXPR,
                                                 left->line,
                                                 left->column,
                                                 left->filename);
                if (!subscript) {
                    ast_free(start_expr);
                    ast_free(left);
                    return NULL;
                }
                
                subscript->data.subscript_expr.array = left;
                subscript->data.subscript_expr.index = start_expr;
                left = subscript;
                continue;  // Continue to check for more postfix operators
            }
        }
        
        // Check if it's a binary operator (including assignment)
        break;
    }
    
    // Now check if there's an operator following
    if (parser->current_token && left) {
        TokenType op_type = parser->current_token->type;

        // Check if it's a binary operator (including assignment)
        if (op_type == TOKEN_PLUS || op_type == TOKEN_MINUS ||
            op_type == TOKEN_ASTERISK || op_type == TOKEN_SLASH ||
            op_type == TOKEN_PERCENT || op_type == TOKEN_EQUAL ||  // comparison ==
            op_type == TOKEN_NOT_EQUAL || op_type == TOKEN_LESS ||
            op_type == TOKEN_LESS_EQUAL || op_type == TOKEN_GREATER ||
            op_type == TOKEN_GREATER_EQUAL ||
            op_type == TOKEN_PLUS_PIPE || op_type == TOKEN_MINUS_PIPE || op_type == TOKEN_ASTERISK_PIPE ||
            op_type == TOKEN_PLUS_PERCENT || op_type == TOKEN_MINUS_PERCENT || op_type == TOKEN_ASTERISK_PERCENT) {

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
        // Handle assignment operator separately
        else if (op_type == TOKEN_ASSIGN && left && left->type == AST_IDENTIFIER) {
            parser_consume(parser); // consume the assignment operator

            // Parse the right operand
            ASTNode *right = parser_parse_expression(parser);
            if (!right) {
                ast_free(left);
                return NULL;
            }

            // Create assignment expression
            ASTNode *assign_expr = ast_new_node(AST_ASSIGN,
                                               parser->current_token->line,
                                               parser->current_token->column,
                                               parser->current_token->filename);
            if (!assign_expr) {
                ast_free(left);
                ast_free(right);
                return NULL;
            }

            // Set destination and source
            assign_expr->data.assign.dest = malloc(strlen(left->data.identifier.name) + 1);
            if (assign_expr->data.assign.dest) {
                strcpy(assign_expr->data.assign.dest, left->data.identifier.name);
            }
            assign_expr->data.assign.src = right;

            ast_free(left); // Free the temporary identifier

            return assign_expr;
        }
    }

    // Check for catch syntax: expr catch |err| { ... } or expr catch { ... }
    if (left && parser_match(parser, TOKEN_CATCH)) {
        parser_consume(parser); // consume 'catch'
        
        // Parse optional error variable: |err|
        char *error_var = NULL;
        if (parser_match(parser, TOKEN_PIPE)) {
            parser_consume(parser); // consume '|'
            if (parser_match(parser, TOKEN_IDENTIFIER)) {
                error_var = malloc(strlen(parser->current_token->value) + 1);
                if (error_var) {
                    strcpy(error_var, parser->current_token->value);
                }
                parser_consume(parser); // consume identifier
            }
            if (!parser_expect(parser, TOKEN_PIPE)) {
                if (error_var) free(error_var);
                ast_free(left);
                return NULL;
            }
            parser_consume(parser); // consume '|'
        }
        
        // Parse catch body
        ASTNode *catch_body = parser_parse_block(parser);
        if (!catch_body) {
            if (error_var) free(error_var);
            ast_free(left);
            return NULL;
        }
        
        // Create catch expression node
        ASTNode *catch_expr = ast_new_node(AST_CATCH_EXPR,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
        if (!catch_expr) {
            if (error_var) free(error_var);
            ast_free(catch_body);
            ast_free(left);
            return NULL;
        }
        
        catch_expr->data.catch_expr.expr = left;
        catch_expr->data.catch_expr.error_var = error_var;
        catch_expr->data.catch_expr.catch_body = catch_body;
        
        return catch_expr;
    }

    return left;
}

// 解析变量声明
static ASTNode *parser_parse_var_decl(Parser *parser) {
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
static ASTNode *parser_parse_defer_stmt(Parser *parser);
static ASTNode *parser_parse_errdefer_stmt(Parser *parser);

static ASTNode *parser_parse_statement(Parser *parser) {
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

// 解析 for 语句
static ASTNode *parser_parse_for_stmt(Parser *parser) {
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
static ASTNode *parser_parse_defer_stmt(Parser *parser) {
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
static ASTNode *parser_parse_errdefer_stmt(Parser *parser) {
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
    // 支持两种语法：fn main() -> i32 和 fn main() i32 (or fn main() !i32)
    if (parser_match(parser, TOKEN_ARROW)) {
        parser_consume(parser); // 消费 '->'
        fn_decl->data.fn_decl.return_type = parser_parse_type(parser);
        if (!fn_decl->data.fn_decl.return_type) {
            ast_free(fn_decl);
            return NULL;
        }
    } else if (parser->current_token && 
               (parser_match(parser, TOKEN_IDENTIFIER) || 
                parser_match(parser, TOKEN_EXCLAMATION) ||
                parser_match(parser, TOKEN_ATOMIC) ||
                parser_match(parser, TOKEN_ASTERISK))) {
        // Try to parse as a type (supports !i32, *T, atomic T, or simple types)
        ASTNode *return_type = parser_parse_type(parser);
        if (return_type) {
            fn_decl->data.fn_decl.return_type = return_type;
        } else {
            // If parsing failed, check if it's a simple type identifier
            if (parser_match(parser, TOKEN_IDENTIFIER) &&
                (strcmp(parser->current_token->value, "i32") == 0 ||
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
                 strcmp(parser->current_token->value, "void") == 0)) {
                // Manually create the type node
                fn_decl->data.fn_decl.return_type = ast_new_node(AST_TYPE_NAMED, line, col, filename);
                if (fn_decl->data.fn_decl.return_type) {
                    fn_decl->data.fn_decl.return_type->data.type_named.name = malloc(strlen(parser->current_token->value) + 1);
                    if (fn_decl->data.fn_decl.return_type->data.type_named.name) {
                        strcpy(fn_decl->data.fn_decl.return_type->data.type_named.name, parser->current_token->value);
                    }
                }
                parser_consume(parser);
            } else {
                // Default to void if type parsing failed
                fn_decl->data.fn_decl.return_type = ast_new_node(AST_TYPE_NAMED, line, col, filename);
                if (fn_decl->data.fn_decl.return_type) {
                    fn_decl->data.fn_decl.return_type->data.type_named.name = malloc(5);
                    if (fn_decl->data.fn_decl.return_type->data.type_named.name) {
                        strcpy(fn_decl->data.fn_decl.return_type->data.type_named.name, "void");
                    }
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

    // 期望函数名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: extern函数声明期望函数名\n");
        return NULL;
    }

    ASTNode *extern_decl = ast_new_node(AST_EXTERN_DECL, line, col, filename);
    if (!extern_decl) {
        return NULL;
    }

    extern_decl->data.fn_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!extern_decl->data.fn_decl.name) {
        ast_free(extern_decl);
        return NULL;
    }
    strcpy(extern_decl->data.fn_decl.name, parser->current_token->value);
    extern_decl->data.fn_decl.is_extern = 1;

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

    // 解析返回类型（在参数列表之后）
    // 支持两种语法：extern func() -> i32 和 extern func() i32 (or extern func() !i32)
    if (parser_match(parser, TOKEN_ARROW)) {
        parser_consume(parser); // 消费 '->'
        extern_decl->data.fn_decl.return_type = parser_parse_type(parser);
        if (!extern_decl->data.fn_decl.return_type) {
            ast_free(extern_decl);
            return NULL;
        }
    } else if (parser->current_token && 
               (parser_match(parser, TOKEN_IDENTIFIER) || 
                parser_match(parser, TOKEN_EXCLAMATION) ||
                parser_match(parser, TOKEN_ATOMIC) ||
                parser_match(parser, TOKEN_ASTERISK))) {
        // Try to parse as a type (supports !i32, *T, atomic T, or simple types)
        ASTNode *return_type = parser_parse_type(parser);
        if (return_type) {
            extern_decl->data.fn_decl.return_type = return_type;
        } else {
            // If parsing failed, check if it's a simple type identifier
            if (parser_match(parser, TOKEN_IDENTIFIER)) {
                return_type = ast_new_node(AST_TYPE_NAMED, line, col, filename);
                if (return_type) {
                    return_type->data.type_named.name = malloc(strlen(parser->current_token->value) + 1);
                    if (return_type->data.type_named.name) {
                        strcpy(return_type->data.type_named.name, parser->current_token->value);
                        extern_decl->data.fn_decl.return_type = return_type;
                    } else {
                        ast_free(return_type);
                        ast_free(extern_decl);
                        return NULL;
                    }
                }
                parser_consume(parser);
            } else {
                // Default to void if type parsing failed
                extern_decl->data.fn_decl.return_type = ast_new_node(AST_TYPE_NAMED, line, col, filename);
                if (extern_decl->data.fn_decl.return_type) {
                    extern_decl->data.fn_decl.return_type->data.type_named.name = malloc(5);
                    if (extern_decl->data.fn_decl.return_type->data.type_named.name) {
                        strcpy(extern_decl->data.fn_decl.return_type->data.type_named.name, "void");
                    }
                }
            }
        }
    } else {
        // 默认返回类型为 void
        extern_decl->data.fn_decl.return_type = ast_new_node(AST_TYPE_NAMED, line, col, filename);
        if (extern_decl->data.fn_decl.return_type) {
            extern_decl->data.fn_decl.return_type->data.type_named.name = malloc(5);
            if (extern_decl->data.fn_decl.return_type->data.type_named.name) {
                strcpy(extern_decl->data.fn_decl.return_type->data.type_named.name, "void");
            }
        }
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

// 解析 impl 声明 (impl StructName : InterfaceName { ... })
static ASTNode *parser_parse_impl_decl(Parser *parser) {
    if (!parser_match(parser, TOKEN_IMPL)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 'impl'

    // 期望结构体名称
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: 期望结构体名称\n");
        return NULL;
    }

    ASTNode *impl_decl = ast_new_node(AST_IMPL_DECL, line, col, filename);
    if (!impl_decl) {
        return NULL;
    }

    impl_decl->data.impl_decl.struct_name = malloc(strlen(parser->current_token->value) + 1);
    if (!impl_decl->data.impl_decl.struct_name) {
        ast_free(impl_decl);
        return NULL;
    }
    strcpy(impl_decl->data.impl_decl.struct_name, parser->current_token->value);
    parser_consume(parser); // 消费结构体名称

    // 期望 ':'
    if (!parser_expect(parser, TOKEN_COLON)) {
        ast_free(impl_decl);
        return NULL;
    }

    // 期望接口名称
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: 期望接口名称\n");
        ast_free(impl_decl);
        return NULL;
    }

    impl_decl->data.impl_decl.interface_name = malloc(strlen(parser->current_token->value) + 1);
    if (!impl_decl->data.impl_decl.interface_name) {
        ast_free(impl_decl);
        return NULL;
    }
    strcpy(impl_decl->data.impl_decl.interface_name, parser->current_token->value);
    parser_consume(parser); // 消费接口名称

    // 期望 '{'
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) {
        ast_free(impl_decl);
        return NULL;
    }

    // 解析方法列表
    impl_decl->data.impl_decl.methods = NULL;
    impl_decl->data.impl_decl.method_count = 0;
    int method_capacity = 0;

    while (parser->current_token && !parser_match(parser, TOKEN_RIGHT_BRACE)) {
        ASTNode *method = parser_parse_fn_decl(parser);
        if (!method) {
            fprintf(stderr, "语法错误: 期望方法声明，跳过当前token\n");
            // Skip current token and continue parsing other methods
            if (parser->current_token) {
                parser_consume(parser);
            }
            continue;
        }

        // 扩容方法列表
        if (impl_decl->data.impl_decl.method_count >= method_capacity) {
            int new_capacity = method_capacity == 0 ? 4 : method_capacity * 2;
            ASTNode **new_methods = realloc(impl_decl->data.impl_decl.methods,
                                           new_capacity * sizeof(ASTNode*));
            if (!new_methods) {
                ast_free(method);
                ast_free(impl_decl);
                return NULL;
            }
            impl_decl->data.impl_decl.methods = new_methods;
            method_capacity = new_capacity;
        }

        impl_decl->data.impl_decl.methods[impl_decl->data.impl_decl.method_count] = method;
        impl_decl->data.impl_decl.method_count++;
    }

    // 期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        // Even if closing brace is missing, return the impl_decl we have so far
        // This allows partial parsing to continue
    }

    return impl_decl;
}

// 解析测试块 (test "说明文字" { ... })
static ASTNode *parser_parse_test_block(Parser *parser) {
    // 检查是否是 test 标识符
    if (!parser->current_token || 
        parser->current_token->type != TOKEN_IDENTIFIER ||
        strcmp(parser->current_token->value, "test") != 0) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 test

    // 期望字符串字面量（测试名称）
    if (!parser_match(parser, TOKEN_STRING)) {
        return NULL; // 不是 test 块，返回 NULL
    }

    ASTNode *test_block = ast_new_node(AST_TEST_BLOCK, line, col, filename);
    if (!test_block) {
        return NULL;
    }

    // 保存测试名称
    test_block->data.test_block.name = malloc(strlen(parser->current_token->value) + 1);
    if (!test_block->data.test_block.name) {
        ast_free(test_block);
        return NULL;
    }
    strcpy(test_block->data.test_block.name, parser->current_token->value);
    parser_consume(parser); // 消费字符串

    // 解析测试体（代码块）
    test_block->data.test_block.body = parser_parse_block(parser);
    if (!test_block->data.test_block.body) {
        ast_free(test_block);
        return NULL;
    }

    return test_block;
}

// 解析顶级声明
static ASTNode *parser_parse_declaration(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    // 先尝试解析 test 块（test 标识符后跟字符串）
    ASTNode *test_node = parser_parse_test_block(parser);
    if (test_node) {
        return test_node;
    }

    if (parser_match(parser, TOKEN_FN)) {
        return parser_parse_fn_decl(parser);
    } else if (parser_match(parser, TOKEN_STRUCT)) {
        return parser_parse_struct_decl(parser);
    } else if (parser_match(parser, TOKEN_EXTERN)) {
        return parser_parse_extern_decl(parser);
    } else if (parser_match(parser, TOKEN_IMPL)) {
        return parser_parse_impl_decl(parser);
    } else {
        return parser_parse_statement(parser);
    }
}

// 辅助函数：从字符串创建临时 Lexer（用于解析字符串插值中的表达式）
static Lexer *create_temp_lexer_from_string(const char *expr_str, int line, int col, const char *filename) {
    Lexer *lexer = malloc(sizeof(Lexer));
    if (!lexer) {
        return NULL;
    }
    
    size_t expr_len = strlen(expr_str);
    lexer->buffer = malloc(expr_len + 1);
    if (!lexer->buffer) {
        free(lexer);
        return NULL;
    }
    strcpy(lexer->buffer, expr_str);
    // buffer_size 应该是实际字符串长度，而不是缓冲区大小
    lexer->buffer_size = expr_len;
    lexer->position = 0;
    lexer->line = line;
    lexer->column = col;
    lexer->filename = malloc(strlen(filename) + 1);
    if (!lexer->filename) {
        free(lexer->buffer);
        free(lexer);
        return NULL;
    }
    strcpy(lexer->filename, filename);
    
    return lexer;
}

// 解析格式说明符字符串（如 ":d", ":.2f", ":#06x" 等）
static FormatSpec parse_format_spec(const char *spec_str) {
    FormatSpec spec = {0};
    spec.width = -1;
    spec.precision = -1;
    spec.type = '\0';
    
    if (!spec_str || *spec_str == '\0') {
        return spec;
    }
    
    // 跳过开头的 ':'
    if (*spec_str == ':') {
        spec_str++;
    }
    
    const char *p = spec_str;
    int flags_len = 0;
    char flags_buf[16] = {0};
    
    // 解析 flags (#, 0, -, +, 空格)
    while (*p && (strchr("#0-+ ", *p) != NULL)) {
        if (flags_len < 15) {
            flags_buf[flags_len++] = *p;
        }
        p++;
    }
    if (flags_len > 0) {
        spec.flags = malloc(flags_len + 1);
        if (spec.flags) {
            strncpy(spec.flags, flags_buf, flags_len);
            spec.flags[flags_len] = '\0';
        }
    }
    
    // 解析 width (数字)
    if (isdigit(*p)) {
        spec.width = 0;
        while (isdigit(*p)) {
            spec.width = spec.width * 10 + (*p - '0');
            p++;
        }
    }
    
    // 解析 precision (.数字)
    if (*p == '.') {
        p++;
        spec.precision = 0;
        while (isdigit(*p)) {
            spec.precision = spec.precision * 10 + (*p - '0');
            p++;
        }
    }
    
    // 解析 type (最后一个字符)
    if (*p != '\0') {
        spec.type = *p;
    }
    
    return spec;
}

// 解析字符串插值
static ASTNode *parser_parse_string_interpolation(Parser *parser, Token *string_token) {
    const char *value = string_token->value;
    if (!value) {
        return NULL;
    }
    
    // 创建字符串插值节点
    ASTNode *interp_node = ast_new_node(AST_STRING_INTERPOLATION,
                                        string_token->line,
                                        string_token->column,
                                        string_token->filename);
    if (!interp_node) {
        return NULL;
    }
    
    interp_node->data.string_interpolation.text_segments = NULL;
    interp_node->data.string_interpolation.interp_exprs = NULL;
    interp_node->data.string_interpolation.format_specs = NULL;
    interp_node->data.string_interpolation.segment_count = 0;
    interp_node->data.string_interpolation.text_count = 0;
    interp_node->data.string_interpolation.interp_count = 0;
    
    // 解析字符串内容（去掉引号）
    // token value 格式：包含引号的完整字符串，如 "text${expr}text"
    // 我们需要去掉首尾的引号
    size_t len = strlen(value);
    if (len < 2 || value[0] != '"' || value[len - 1] != '"') {
        // 不是有效的字符串格式
        ast_free(interp_node);
        return NULL;
    }
    
    // 提取字符串内容（去掉引号）
    // 分配 len - 2 + 1 = len - 1 字节（len - 2 个字符 + 1 个 null terminator）
    size_t content_len = len - 2;
    char *content = malloc(content_len + 1);
    if (!content) {
        ast_free(interp_node);
        return NULL;
    }
    if (content_len > 0) {
        strncpy(content, value + 1, content_len);
        content[content_len] = '\0';
    } else {
        content[0] = '\0';
    }
    
    // 临时数组存储文本段和插值表达式
    char **text_segments = NULL;
    ASTNode **interp_exprs = NULL;
    FormatSpec *format_specs = NULL;
    int text_capacity = 0;
    int interp_capacity = 0;
    int text_count = 0;
    int interp_count = 0;
    
    const char *p = content;
    const char *content_end = content + content_len;
    const char *text_start = p;
    
    while (p < content_end && *p != '\0') {
        if (p + 1 < content_end && *p == '$' && *(p + 1) == '{') {
            // 找到插值开始 ${，先保存当前文本段
            // 确保 text_start 在有效范围内
            if (text_start < content || text_start > content_end) {
                goto error;
            }
            size_t text_len = (p > text_start) ? (p - text_start) : 0;
            // 确保 text_len 不会导致越界
            if (text_start + text_len > content_end) {
                text_len = (content_end > text_start) ? (content_end - text_start) : 0;
            }
            if (text_len > 0) {
                // 需要扩容
                if (text_count >= text_capacity) {
                    int new_capacity = text_capacity == 0 ? 4 : text_capacity * 2;
                    char **new_segments = realloc(text_segments, new_capacity * sizeof(char*));
                    if (!new_segments) {
                        goto error;
                    }
                    text_segments = new_segments;
                    text_capacity = new_capacity;
                }
                
                text_segments[text_count] = malloc(text_len + 1);
                if (!text_segments[text_count]) {
                    goto error;
                }
                strncpy(text_segments[text_count], text_start, text_len);
                text_segments[text_count][text_len] = '\0';
                text_count++;
            }
            
            // 跳过 "${"
            p += 2;
            // 检查边界
            if (p >= content_end) {
                goto error;
            }
            const char *expr_start = p;
            
            // 查找匹配的 '}'（需要处理嵌套）
            int brace_depth = 1;
            const char *expr_end = NULL;
            const char *format_start = NULL;
            
            while (p < content_end && *p != '\0' && brace_depth > 0) {
                if (*p == '{') {
                    brace_depth++;
                } else if (*p == '}') {
                    brace_depth--;
                    if (brace_depth == 0) {
                        expr_end = p;
                        break;
                    }
                } else if (*p == ':' && brace_depth == 1 && format_start == NULL) {
                    // 找到格式说明符开始（只记录第一个冒号）
                    format_start = p;
                }
                p++;
            }
            
            if (!expr_end) {
                // 没有找到匹配的 '}'
                goto error;
            }
            
            // 提取表达式字符串
            const char *actual_expr_end = format_start ? format_start : expr_end;
            // 确保 actual_expr_end 在 expr_start 之后
            if (actual_expr_end < expr_start) {
                goto error;
            }
            // 确保不会超出 content 边界
            if (actual_expr_end > content_end) {
                actual_expr_end = content_end;
            }
            size_t expr_len = actual_expr_end - expr_start;
            char *expr_str = malloc(expr_len + 1);
            if (!expr_str) {
                goto error;
            }
            if (expr_len > 0) {
                strncpy(expr_str, expr_start, expr_len);
                expr_str[expr_len] = '\0';
            } else {
                expr_str[0] = '\0';
            }
            
            // 创建临时 Lexer 解析表达式
            // 计算列号：原始列号 + 1（跳过引号）+ (expr_start - content)
            int expr_column = string_token->column + 1 + (int)(expr_start - content);
            Lexer *temp_lexer = create_temp_lexer_from_string(expr_str, string_token->line, 
                                                               expr_column,
                                                               string_token->filename);
            if (!temp_lexer) {
                free(expr_str);
                goto error;
            }
            
            Parser *temp_parser = parser_new(temp_lexer);
            if (!temp_parser) {
                lexer_free(temp_lexer);
                free(expr_str);
                goto error;
            }
            
            ASTNode *expr = parser_parse_expression(temp_parser);
            parser_free(temp_parser);
            lexer_free(temp_lexer);
            free(expr_str);
            
            if (!expr) {
                goto error;
            }
            
            // 扩容插值数组
            if (interp_count >= interp_capacity) {
                int new_capacity = interp_capacity == 0 ? 4 : interp_capacity * 2;
                ASTNode **new_exprs = realloc(interp_exprs, new_capacity * sizeof(ASTNode*));
                FormatSpec *new_specs = realloc(format_specs, new_capacity * sizeof(FormatSpec));
                if (!new_exprs || !new_specs) {
                    ast_free(expr);
                    goto error;
                }
                interp_exprs = new_exprs;
                format_specs = new_specs;
                interp_capacity = new_capacity;
            }
            
            interp_exprs[interp_count] = expr;
            
            // 解析格式说明符
            if (format_start) {
                size_t format_len = expr_end - format_start;
                char *format_str = malloc(format_len + 1);
                if (!format_str) {
                    goto error;
                }
                strncpy(format_str, format_start, format_len);
                format_str[format_len] = '\0';
                format_specs[interp_count] = parse_format_spec(format_str);
                free(format_str);
            } else {
                format_specs[interp_count].flags = NULL;
                format_specs[interp_count].width = -1;
                format_specs[interp_count].precision = -1;
                format_specs[interp_count].type = '\0';
            }
            
            interp_count++;
            
            // 跳过 '}'
            p = expr_end + 1;
            // 检查边界
            if (p > content_end) {
                p = content_end;
            }
            text_start = p;
        } else if (p + 1 < content_end && *p == '\\') {
            // 跳过转义字符（确保不会越界）
            p += 2;
            // 确保不会超出边界
            if (p > content_end) {
                p = content_end;
            }
        } else {
            p++;
        }
    }
    
    // 保存最后的文本段
    const char *text_end = (p < content_end) ? p : content_end;
    size_t text_len = (text_end > text_start) ? (text_end - text_start) : 0;
    if (text_len > 0) {
        if (text_count >= text_capacity) {
            int new_capacity = text_capacity == 0 ? 4 : text_capacity * 2;
            char **new_segments = realloc(text_segments, new_capacity * sizeof(char*));
            if (!new_segments) {
                goto error;
            }
            text_segments = new_segments;
            text_capacity = new_capacity;
        }
        
        text_segments[text_count] = malloc(text_len + 1);
        if (!text_segments[text_count]) {
            goto error;
        }
        strncpy(text_segments[text_count], text_start, text_len);
        text_segments[text_count][text_len] = '\0';
        text_count++;
    }
    
    // 赋值给节点
    interp_node->data.string_interpolation.text_segments = text_segments;
    interp_node->data.string_interpolation.interp_exprs = interp_exprs;
    interp_node->data.string_interpolation.format_specs = format_specs;
    interp_node->data.string_interpolation.text_count = text_count;
    interp_node->data.string_interpolation.interp_count = interp_count;
    interp_node->data.string_interpolation.segment_count = text_count + interp_count;
    
    free(content);
    return interp_node;
    
error:
    // 清理资源
    if (text_segments) {
        for (int i = 0; i < text_count; i++) {
            free(text_segments[i]);
        }
        free(text_segments);
    }
    if (interp_exprs) {
        for (int i = 0; i < interp_count; i++) {
            ast_free(interp_exprs[i]);
        }
        free(interp_exprs);
    }
    if (format_specs) {
        for (int i = 0; i < interp_count; i++) {
            if (format_specs[i].flags) {
                free(format_specs[i].flags);
            }
        }
        free(format_specs);
    }
    free(content);
    ast_free(interp_node);
    return NULL;
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
                   !parser_match(parser, TOKEN_IMPL) &&
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