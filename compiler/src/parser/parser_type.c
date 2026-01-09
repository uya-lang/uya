#include "parser_internal.h"

ASTNode *parser_parse_type(Parser *parser) {
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

    // Check if it's a function pointer type: fn(param_types) return_type
    if (parser_match(parser, TOKEN_FN)) {
        parser_consume(parser); // consume 'fn'
        
        // Expect '('
        if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
            return NULL;
        }
        
        ASTNode *fn_type = ast_new_node(AST_TYPE_FN,
                                        parser->current_token->line,
                                        parser->current_token->column,
                                        parser->current_token->filename);
        if (!fn_type) {
            return NULL;
        }
        
        // Parse parameter type list (only types, no parameter names)
        fn_type->data.type_fn.param_types = NULL;
        fn_type->data.type_fn.param_type_count = 0;
        int param_type_capacity = 0;
        
        if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
            do {
                // Parse a parameter type
                ASTNode *param_type = parser_parse_type(parser);
                if (!param_type) {
                    ast_free(fn_type);
                    return NULL;
                }
                
                // Expand parameter type list
                if (fn_type->data.type_fn.param_type_count >= param_type_capacity) {
                    int new_capacity = param_type_capacity == 0 ? 4 : param_type_capacity * 2;
                    ASTNode **new_param_types = realloc(fn_type->data.type_fn.param_types,
                                                       new_capacity * sizeof(ASTNode*));
                    if (!new_param_types) {
                        ast_free(param_type);
                        ast_free(fn_type);
                        return NULL;
                    }
                    fn_type->data.type_fn.param_types = new_param_types;
                    param_type_capacity = new_capacity;
                }
                
                fn_type->data.type_fn.param_types[fn_type->data.type_fn.param_type_count] = param_type;
                fn_type->data.type_fn.param_type_count++;
                
                if (parser_match(parser, TOKEN_COMMA)) {
                    parser_consume(parser); // consume ','
                } else {
                    break;
                }
            } while (!parser_match(parser, TOKEN_RIGHT_PAREN) && parser->current_token);
        }
        
        // Expect ')'
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            ast_free(fn_type);
            return NULL;
        }
        
        // Parse return type
        fn_type->data.type_fn.return_type = parser_parse_type(parser);
        if (!fn_type->data.type_fn.return_type) {
            ast_free(fn_type);
            return NULL;
        }
        
        return fn_type;
    }

    // Check if it's an array type: [element_type : size]
    if (parser_match(parser, TOKEN_LEFT_BRACKET)) {
        // Parse array type: [i32 : 10]
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

        // Expect ':'
        if (!parser_expect(parser, TOKEN_COLON)) {
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
    }
    // Check if it's a tuple type: (T1, T2, ...)
    else if (parser_match(parser, TOKEN_LEFT_PAREN)) {
        parser_consume(parser); // consume '('

        ASTNode *tuple_type = ast_new_node(AST_TYPE_TUPLE,
                                           parser->current_token->line,
                                           parser->current_token->column,
                                           parser->current_token->filename);
        if (!tuple_type) {
            return NULL;
        }

        // Initialize tuple type elements
        tuple_type->data.type_tuple.element_types = NULL;
        tuple_type->data.type_tuple.element_count = 0;
        int element_capacity = 0;

        if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
            do {
                // Parse an element type
                ASTNode *element_type = parser_parse_type(parser);
                if (!element_type) {
                    ast_free(tuple_type);
                    return NULL;
                }

                // Expand element types array
                if (tuple_type->data.type_tuple.element_count >= element_capacity) {
                    int new_capacity = element_capacity == 0 ? 4 : element_capacity * 2;
                    ASTNode **new_element_types = realloc(tuple_type->data.type_tuple.element_types,
                                                         new_capacity * sizeof(ASTNode*));
                    if (!new_element_types) {
                        ast_free(element_type);
                        ast_free(tuple_type);
                        return NULL;
                    }
                    tuple_type->data.type_tuple.element_types = new_element_types;
                    element_capacity = new_capacity;
                }

                tuple_type->data.type_tuple.element_types[tuple_type->data.type_tuple.element_count] = element_type;
                tuple_type->data.type_tuple.element_count++;

                if (parser_match(parser, TOKEN_COMMA)) {
                    parser_consume(parser); // consume ','
                } else {
                    break;
                }
            } while (!parser_match(parser, TOKEN_RIGHT_PAREN) && parser->current_token);
        }

        // Expect ')'
        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            ast_free(tuple_type);
            return NULL;
        }

        return tuple_type;
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

