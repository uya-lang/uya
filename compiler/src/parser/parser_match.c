#include "parser_internal.h"

ASTNode *parser_parse_match_expr(Parser *parser) {
    if (!parser_match(parser, TOKEN_MATCH)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // consume 'match'

    // Parse the expression to match
    if (!parser->current_token) {
        fprintf(stderr, "语法错误: match 表达式需要匹配的表达式（当前token为NULL）\n");
        return NULL;
    }
    
    // Special handling: if current token is identifier, parse it directly
    // to avoid struct initialization ambiguity (identifier followed by '{'
    // would be parsed as struct init in parser_parse_expression)
    ASTNode *expr = NULL;
    if (parser_match(parser, TOKEN_IDENTIFIER)) {
        // Create identifier node
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
        parser_consume(parser); // consume identifier
        expr = ident;
    } else {
        // For non-identifier expressions, use the full expression parser
        expr = parser_parse_expression(parser);
        if (!expr) {
            fprintf(stderr, "语法错误: match 表达式需要匹配的表达式（在 %s:%d:%d，当前token类型=%d，值=%s）\n",
                    parser->current_token ? parser->current_token->filename : "unknown",
                    parser->current_token ? parser->current_token->line : 0,
                    parser->current_token ? parser->current_token->column : 0,
                    parser->current_token ? parser->current_token->type : -1,
                    parser->current_token && parser->current_token->value ? parser->current_token->value : "(null)");
            return NULL;
        }
    }

    // Expect '{'
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) {
        ast_free(expr);
        return NULL;
    }

    // Create match expression node
    ASTNode *match_expr = ast_new_node(AST_MATCH_EXPR, line, col, filename);
    if (!match_expr) {
        ast_free(expr);
        return NULL;
    }

    match_expr->data.match_expr.expr = expr;
    match_expr->data.match_expr.patterns = NULL;
    match_expr->data.match_expr.pattern_count = 0;
    int pattern_capacity = 0;

    // Parse pattern => body pairs
    while (parser->current_token && !parser_match(parser, TOKEN_RIGHT_BRACE)) {
        // Parse pattern
        ASTNode *pattern = ast_new_node(AST_PATTERN,
                                       parser->current_token->line,
                                       parser->current_token->column,
                                       parser->current_token->filename);
        if (!pattern) {
            ast_free(match_expr);
            return NULL;
        }

        // Parse the pattern expression (only basic expressions, no binary operators)
        // For match patterns, we only parse a single expression, not binary operations
        ASTNode *pattern_expr = NULL;
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
            pattern_expr = ident;
        } else if (parser_match(parser, TOKEN_NUMBER)) {
            fprintf(stderr, "[DEBUG MATCH] Parsing number pattern, current token: type=%d, line=%d:%d, value=%s\n",
                    parser->current_token->type,
                    parser->current_token->line,
                    parser->current_token->column,
                    parser->current_token->value ? parser->current_token->value : "(null)");
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
            fprintf(stderr, "[DEBUG MATCH] After consuming number, current token: type=%d, line=%d:%d, value=%s\n",
                    parser->current_token ? parser->current_token->type : -1,
                    parser->current_token ? parser->current_token->line : 0,
                    parser->current_token ? parser->current_token->column : 0,
                    parser->current_token && parser->current_token->value ? parser->current_token->value : "(null)");
            pattern_expr = num;
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
            pattern_expr = str;
        } else if (parser_match(parser, TOKEN_LEFT_PAREN)) {
            // Parse tuple literal or parenthesized expression
            pattern_expr = parser_parse_tuple_literal(parser);
        } else {
            // For other cases, use the full expression parser
            pattern_expr = parser_parse_expression(parser);
        }
        
        if (!pattern_expr) {
            ast_free(pattern);
            ast_free(match_expr);
            return NULL;
        }
        pattern->data.pattern.pattern_expr = pattern_expr;

        // Expect '=>'
        if (!parser->current_token) {
            fprintf(stderr, "[DEBUG MATCH] Current token is NULL before expecting TOKEN_ARROW\n");
            ast_free(pattern);
            ast_free(match_expr);
            return NULL;
        }
        if (!parser_match(parser, TOKEN_ARROW)) {
            fprintf(stderr, "[DEBUG MATCH] Expected TOKEN_ARROW (%d) but got type %d, value=%s\n",
                    TOKEN_ARROW,
                    parser->current_token ? parser->current_token->type : -1,
                    parser->current_token && parser->current_token->value ? parser->current_token->value : "(null)");
            ast_free(pattern);
            ast_free(match_expr);
            return NULL;
        }
        parser_consume(parser); // consume '=>'
        fprintf(stderr, "[DEBUG MATCH] After consuming TOKEN_ARROW, current token: type=%d, value=%s\n",
                parser->current_token ? parser->current_token->type : -1,
                parser->current_token && parser->current_token->value ? parser->current_token->value : "(null)");

        // Parse the body for this pattern
        fprintf(stderr, "[DEBUG MATCH] About to parse body expression\n");
        pattern->data.pattern.body = parser_parse_expression(parser); // For now, just parse as expression
        fprintf(stderr, "[DEBUG MATCH] Body expression parsed, result=%p, current_token=%p\n", 
                pattern->data.pattern.body, (void*)parser->current_token);
        if (parser->current_token) {
            fprintf(stderr, "[DEBUG MATCH] After body parse, current token: type=%d, value=%s\n",
                    parser->current_token->type,
                    parser->current_token->value ? parser->current_token->value : "(null)");
        }
        if (!pattern->data.pattern.body) {
            fprintf(stderr, "[DEBUG MATCH] Body is NULL, freeing pattern and match_expr\n");
            ast_free(pattern);
            ast_free(match_expr);
            return NULL;
        }

        // Expand patterns array
        fprintf(stderr, "[DEBUG MATCH] Expanding patterns array, count=%d, capacity=%d\n", 
                match_expr->data.match_expr.pattern_count, pattern_capacity);
        if (match_expr->data.match_expr.pattern_count >= pattern_capacity) {
            fprintf(stderr, "[DEBUG MATCH] Reallocating patterns array\n");
            int new_capacity = pattern_capacity == 0 ? 4 : pattern_capacity * 2;
            ASTNode **new_patterns = realloc(match_expr->data.match_expr.patterns,
                                           new_capacity * sizeof(ASTNode*));
            if (!new_patterns) {
                ast_free(pattern);
                ast_free(match_expr);
                return NULL;
            }
            match_expr->data.match_expr.patterns = new_patterns;
            pattern_capacity = new_capacity;
            fprintf(stderr, "[DEBUG MATCH] Patterns array reallocated, new capacity=%d\n", pattern_capacity);
        }

        fprintf(stderr, "[DEBUG MATCH] Adding pattern to array at index %d\n", match_expr->data.match_expr.pattern_count);
        match_expr->data.match_expr.patterns[match_expr->data.match_expr.pattern_count] = pattern;
        match_expr->data.match_expr.pattern_count++;
        fprintf(stderr, "[DEBUG MATCH] Pattern added, new count=%d\n", match_expr->data.match_expr.pattern_count);
        fprintf(stderr, "[DEBUG MATCH] Before checking comma, current_token=%p\n", (void*)parser->current_token);

        // Check for comma between patterns (optional)
        fprintf(stderr, "[DEBUG MATCH] About to check for comma\n");
        if (parser_match(parser, TOKEN_COMMA)) {
            fprintf(stderr, "[DEBUG MATCH] Found comma\n");
            parser_consume(parser);
        }

        // If we encounter 'else', it should be the last pattern
        if (parser_match(parser, TOKEN_IDENTIFIER) &&
            parser->current_token && parser->current_token->value &&
            strcmp(parser->current_token->value, "else") == 0) {
            // This is an else pattern - handle specially if needed
            // For now, just parse it as a regular pattern
        }
    }

    // Expect '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        ast_free(match_expr);
        return NULL;
    }

    return match_expr;
}

// 解析元组字面量: (expr1, expr2, ...)
// 注意：调用此函数前必须确认当前 token 是 TOKEN_LEFT_PAREN


ASTNode *parser_parse_tuple_literal(Parser *parser) {
    // 当前 token 应该是 TOKEN_LEFT_PAREN（由调用者检查）
    parser_consume(parser); // consume '('

    ASTNode *tuple_literal = ast_new_node(AST_TUPLE_LITERAL,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
    if (!tuple_literal) {
        return NULL;
    }

    // Initialize tuple literal elements
    tuple_literal->data.tuple_literal.elements = NULL;
    tuple_literal->data.tuple_literal.element_count = 0;
    int element_capacity = 0;

    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        do {
            // Parse an element expression
            ASTNode *element = parser_parse_expression(parser);
            if (!element) {
                ast_free(tuple_literal);
                return NULL;
            }

            // Expand elements array
            if (tuple_literal->data.tuple_literal.element_count >= element_capacity) {
                int new_capacity = element_capacity == 0 ? 4 : element_capacity * 2;
                ASTNode **new_elements = realloc(tuple_literal->data.tuple_literal.elements,
                                               new_capacity * sizeof(ASTNode*));
                if (!new_elements) {
                    ast_free(element);
                    ast_free(tuple_literal);
                    return NULL;
                }
                tuple_literal->data.tuple_literal.elements = new_elements;
                element_capacity = new_capacity;
            }

            tuple_literal->data.tuple_literal.elements[tuple_literal->data.tuple_literal.element_count] = element;
            tuple_literal->data.tuple_literal.element_count++;

            if (parser_match(parser, TOKEN_COMMA)) {
                parser_consume(parser); // consume ','
            } else {
                break;
            }
        } while (!parser_match(parser, TOKEN_RIGHT_PAREN) && parser->current_token);
    }

    // Expect ')'
    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
        ast_free(tuple_literal);
        return NULL;
    }

    return tuple_literal;
}


