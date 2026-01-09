#include "parser_internal.h"

ASTNode *parser_parse_expression(Parser *parser) {
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

    // Check for match expressions first: match expr { pattern => body, ... }
    if (parser_match(parser, TOKEN_MATCH)) {
        return parser_parse_match_expr(parser);
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
            // This is a member access: identifier.field or identifier.0 (tuple field access)
            parser_consume(parser); // consume '.'

            // Expect field name (identifier) or number (tuple field index)
            if (!parser_match(parser, TOKEN_IDENTIFIER) && !parser_match(parser, TOKEN_NUMBER)) {
                ast_free(ident);
                fprintf(stderr, "语法错误: 成员访问需要字段名或数字索引\n");
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
            parser_consume(parser);  // consume field name or index

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
    }
    // Check if this is a tuple literal: (expr1, expr2, ...)
    else if (parser_match(parser, TOKEN_LEFT_PAREN)) {
        left = parser_parse_tuple_literal(parser);
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
    
    // Now check if there's an operator following (loop to handle chained operators)
    while (parser->current_token && left) {
        TokenType op_type = parser->current_token->type;

        // Check if it's a binary operator (including assignment)
        // Handle logical operators (&&, ||) separately to ensure correct precedence
        if (op_type == TOKEN_LOGICAL_AND || op_type == TOKEN_LOGICAL_OR) {
            parser_consume(parser); // consume the operator
            
            // Parse the right operand using comparison_or_higher to avoid parsing logical operators
            ASTNode *right = parser_parse_comparison_or_higher(parser);
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
            
            // Update left for next iteration
            left = binary_expr;
            // Continue loop to check for more operators
        } else if (op_type == TOKEN_PLUS || op_type == TOKEN_MINUS ||
            op_type == TOKEN_ASTERISK || op_type == TOKEN_SLASH ||
            op_type == TOKEN_PERCENT || op_type == TOKEN_EQUAL ||  // comparison ==
            op_type == TOKEN_NOT_EQUAL || op_type == TOKEN_LESS ||
            op_type == TOKEN_LESS_EQUAL || op_type == TOKEN_GREATER ||
            op_type == TOKEN_GREATER_EQUAL ||
            op_type == TOKEN_PLUS_PIPE || op_type == TOKEN_MINUS_PIPE || op_type == TOKEN_ASTERISK_PIPE ||
            op_type == TOKEN_PLUS_PERCENT || op_type == TOKEN_MINUS_PERCENT || op_type == TOKEN_ASTERISK_PERCENT) {

            parser_consume(parser); // consume the operator

            // Parse the right operand (for comparison and arithmetic operators, use comparison_or_higher)
            ASTNode *right = parser_parse_comparison_or_higher(parser);
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

            // Update left for next iteration
            left = binary_expr;
            // Continue loop to check for more operators
        } else {
            // No more binary operators, break the loop
            break;
        }
    }

    // Handle assignment operator separately (after binary operators)
    if (parser->current_token && left && parser->current_token->type == TOKEN_ASSIGN) {
        if (left->type == AST_IDENTIFIER) {
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

            // Set destination and source (simple variable assignment)
            assign_expr->data.assign.dest = malloc(strlen(left->data.identifier.name) + 1);
            if (assign_expr->data.assign.dest) {
                strcpy(assign_expr->data.assign.dest, left->data.identifier.name);
            }
            assign_expr->data.assign.dest_expr = NULL;
            assign_expr->data.assign.src = right;

            ast_free(left); // Free the temporary identifier

            return assign_expr;
        } else if (left->type == AST_SUBSCRIPT_EXPR) {
            // Array element assignment: arr[0] = value
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

            // Set destination expression and source (array element assignment)
            assign_expr->data.assign.dest = NULL;
            assign_expr->data.assign.dest_expr = left;  // Keep the subscript expression
            assign_expr->data.assign.src = right;

            return assign_expr;
        }
    }

    // Check for catch syntax: expr catch |err| { ... } or expr catch { ... }
    if (left && parser_match(parser, TOKEN_CATCH)) {
        // Debug: catch expression parsing
        if (left->line >= 169 && left->line <= 193) {
            fprintf(stderr, "[DEBUG PARSER] Parsing catch expression at line %d\n", left->line);
        }
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
            // parser_expect already consumed the '|' token, so we don't need to consume again
        }
        
        // Parse catch body
        // Debug: check current token before parsing block
        if (left && left->line >= 169 && left->line <= 193) {
            fprintf(stderr, "[DEBUG CATCH] Before parsing catch block, current token: type=%d, line=%d:%d, value=%s\n",
                    parser->current_token ? parser->current_token->type : -1,
                    parser->current_token ? parser->current_token->line : 0,
                    parser->current_token ? parser->current_token->column : 0,
                    parser->current_token && parser->current_token->value ? parser->current_token->value : "(null)");
        }
        ASTNode *catch_body = parser_parse_block(parser);
        if (!catch_body) {
            if (left && left->line >= 169 && left->line <= 193) {
                fprintf(stderr, "[DEBUG CATCH] Failed to parse catch block, current token: type=%d, line=%d:%d, value=%s\n",
                        parser->current_token ? parser->current_token->type : -1,
                        parser->current_token ? parser->current_token->line : 0,
                        parser->current_token ? parser->current_token->column : 0,
                        parser->current_token && parser->current_token->value ? parser->current_token->value : "(null)");
            }
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


ASTNode *parser_parse_comparison_or_higher(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    // Check for try operator first
    if (parser_match(parser, TOKEN_TRY)) {
        parser_consume(parser); // consume 'try'

        // Parse the entire expression, including binary operations, as the try operand
        ASTNode *operand = parser_parse_comparison_or_higher(parser);
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

        ASTNode *operand = parser_parse_comparison_or_higher(parser);
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

        ASTNode *operand = parser_parse_comparison_or_higher(parser);
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

        ASTNode *operand = parser_parse_comparison_or_higher(parser);
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

    // Check for match expressions first: match expr { pattern => body, ... }
    if (parser_match(parser, TOKEN_MATCH)) {
        return parser_parse_match_expr(parser);
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
            // This is a member access: identifier.field or identifier.0 (tuple field access)
            parser_consume(parser); // consume '.'

            // Expect field name (identifier) or number (tuple field index)
            if (!parser_match(parser, TOKEN_IDENTIFIER) && !parser_match(parser, TOKEN_NUMBER)) {
                ast_free(ident);
                fprintf(stderr, "语法错误: 成员访问需要字段名或数字索引\n");
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
            parser_consume(parser);  // consume field name or index

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
    }
    // Check if this is a tuple literal: (expr1, expr2, ...)
    else if (parser_match(parser, TOKEN_LEFT_PAREN)) {
        left = parser_parse_tuple_literal(parser);
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
    
    // Now check if there's an operator following (loop to handle chained operators)
    // NOTE: This function does NOT handle logical operators (&&, ||)
    while (parser->current_token && left) {
        TokenType op_type = parser->current_token->type;

        // Check if it's a binary operator (excluding logical operators)
        if (op_type == TOKEN_PLUS || op_type == TOKEN_MINUS ||
            op_type == TOKEN_ASTERISK || op_type == TOKEN_SLASH ||
            op_type == TOKEN_PERCENT || op_type == TOKEN_EQUAL ||  // comparison ==
            op_type == TOKEN_NOT_EQUAL || op_type == TOKEN_LESS ||
            op_type == TOKEN_LESS_EQUAL || op_type == TOKEN_GREATER ||
            op_type == TOKEN_GREATER_EQUAL ||
            op_type == TOKEN_PLUS_PIPE || op_type == TOKEN_MINUS_PIPE || op_type == TOKEN_ASTERISK_PIPE ||
            op_type == TOKEN_PLUS_PERCENT || op_type == TOKEN_MINUS_PERCENT || op_type == TOKEN_ASTERISK_PERCENT) {

            parser_consume(parser); // consume the operator

            // Parse the right operand (recursively call comparison_or_higher)
            ASTNode *right = parser_parse_comparison_or_higher(parser);
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

            // Update left for next iteration
            left = binary_expr;
            // Continue loop to check for more operators
        } else {
            // No more binary operators (or logical operators which we don't handle), break the loop
            break;
        }
    }

    return left;
}


