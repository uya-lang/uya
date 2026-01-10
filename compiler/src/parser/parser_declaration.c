#include "parser_internal.h"

ASTNode *parser_parse_declaration(Parser *parser) {
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
    } else if (parser_match(parser, TOKEN_ENUM)) {
        return parser_parse_enum_decl(parser);
    } else if (parser_match(parser, TOKEN_ERROR)) {
        return parser_parse_error_decl(parser);
    } else if (parser_match(parser, TOKEN_EXTERN)) {
        return parser_parse_extern_decl(parser);
    } else if (parser_match(parser, TOKEN_IDENTIFIER)) {
        // 尝试解析接口实现声明（新语法：StructName : InterfaceName { ... }）
        // 注意：parser_parse_impl_decl 会在格式不匹配时返回 NULL 且不消费 tokens
        ASTNode *impl_decl = parser_parse_impl_decl(parser);
        if (impl_decl) {
            return impl_decl;
        }
        // 如果解析接口实现失败，继续尝试解析为语句
        return parser_parse_statement(parser);
    } else {
        return parser_parse_statement(parser);
    }
}

ASTNode *parser_parse_fn_decl(Parser *parser) {
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

ASTNode *parser_parse_extern_decl(Parser *parser) {
    if (!parser_match(parser, TOKEN_EXTERN)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 extern

    // 期望 fn 关键字（extern fn name(...) type）
    if (!parser_match(parser, TOKEN_FN)) {
        fprintf(stderr, "语法错误: extern函数声明期望 'fn' 关键字\n");
        return NULL;
    }
    parser_consume(parser); // 消费 fn

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
                parser_match(parser, TOKEN_ASTERISK) ||
                parser_match(parser, TOKEN_FN))) {
        // Try to parse as a type (supports !i32, *T, atomic T, fn(...) type, or simple types)
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

    // 检查是否有函数体（导出函数）或分号（声明外部函数）
    // extern fn name(...) type; - 声明外部函数（导入）
    // extern fn name(...) type { ... } - 导出函数（供 C 调用）
    if (parser_match(parser, TOKEN_LEFT_BRACE)) {
        // 解析函数体（导出函数）
        extern_decl->data.fn_decl.body = parser_parse_block(parser);
        if (!extern_decl->data.fn_decl.body) {
            ast_free(extern_decl);
            return NULL;
        }
    } else if (parser_match(parser, TOKEN_SEMICOLON)) {
        // 声明外部函数，没有函数体
        parser_consume(parser); // 消费 ';'
        extern_decl->data.fn_decl.body = NULL;
    } else {
        // 语法错误：期望 '{' 或 ';'
        fprintf(stderr, "语法错误: extern函数声明期望 '{' 或 ';'\n");
        ast_free(extern_decl);
        return NULL;
    }

    return extern_decl;
}

// 解析结构体声明
ASTNode *parser_parse_struct_decl(Parser *parser) {
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

// 解析枚举声明 (enum EnumName [: UnderlyingType] { Variant1 [= value1], ... })
ASTNode *parser_parse_enum_decl(Parser *parser) {
    if (!parser_match(parser, TOKEN_ENUM)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 enum

    // 期望枚举名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: 期望枚举名\n");
        return NULL;
    }

    ASTNode *enum_decl = ast_new_node(AST_ENUM_DECL, line, col, filename);
    if (!enum_decl) {
        return NULL;
    }

    enum_decl->data.enum_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!enum_decl->data.enum_decl.name) {
        ast_free(enum_decl);
        return NULL;
    }
    strcpy(enum_decl->data.enum_decl.name, parser->current_token->value);

    parser_consume(parser); // 消费枚举名

    // 解析可选的底层类型 (: UnderlyingType)
    enum_decl->data.enum_decl.underlying_type = NULL;
    if (parser_match(parser, TOKEN_COLON)) {
        parser_consume(parser); // 消费 ':'
        enum_decl->data.enum_decl.underlying_type = parser_parse_type(parser);
        if (!enum_decl->data.enum_decl.underlying_type) {
            fprintf(stderr, "语法错误: 期望底层类型\n");
            ast_free(enum_decl);
            return NULL;
        }
    }

    // 期望 '{'
    if (!parser_expect(parser, TOKEN_LEFT_BRACE)) {
        ast_free(enum_decl);
        return NULL;
    }

    // 解析变体列表
    enum_decl->data.enum_decl.variants = NULL;
    enum_decl->data.enum_decl.variant_count = 0;
    int variant_capacity = 0;

    while (parser->current_token && !parser_match(parser, TOKEN_RIGHT_BRACE)) {
        // 期望变体名
        if (!parser_match(parser, TOKEN_IDENTIFIER)) {
            fprintf(stderr, "语法错误: 期望枚举变体名\n");
            ast_free(enum_decl);
            return NULL;
        }

        // 扩容变体列表
        if (enum_decl->data.enum_decl.variant_count >= variant_capacity) {
            int new_capacity = variant_capacity == 0 ? 4 : variant_capacity * 2;
            EnumVariant *new_variants = realloc(enum_decl->data.enum_decl.variants,
                                                new_capacity * sizeof(EnumVariant));
            if (!new_variants) {
                ast_free(enum_decl);
                return NULL;
            }
            enum_decl->data.enum_decl.variants = new_variants;
            variant_capacity = new_capacity;
        }

        // 分配变体名称
        EnumVariant *variant = &enum_decl->data.enum_decl.variants[enum_decl->data.enum_decl.variant_count];
        variant->name = malloc(strlen(parser->current_token->value) + 1);
        if (!variant->name) {
            ast_free(enum_decl);
            return NULL;
        }
        strcpy(variant->name, parser->current_token->value);
        variant->value = NULL; // 默认没有显式值

        parser_consume(parser); // 消费变体名

        // 解析可选的显式值 (= NUM)
        if (parser_match(parser, TOKEN_ASSIGN)) {
            parser_consume(parser); // 消费 '='
            if (!parser_match(parser, TOKEN_NUMBER)) {
                fprintf(stderr, "语法错误: 期望数字值\n");
                ast_free(enum_decl);
                return NULL;
            }
            variant->value = malloc(strlen(parser->current_token->value) + 1);
            if (!variant->value) {
                ast_free(enum_decl);
                return NULL;
            }
            strcpy(variant->value, parser->current_token->value);
            parser_consume(parser); // 消费数字值
        }

        enum_decl->data.enum_decl.variant_count++;

        // 检查是否有逗号
        if (parser_match(parser, TOKEN_COMMA)) {
            parser_consume(parser);
        } else if (!parser_match(parser, TOKEN_RIGHT_BRACE)) {
            fprintf(stderr, "语法错误: 期望 ',' 或 '}'\n");
            ast_free(enum_decl);
            return NULL;
        }
    }

    // 期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        ast_free(enum_decl);
        return NULL;
    }

    return enum_decl;
}

// 解析错误声明 (error ErrorName;)
ASTNode *parser_parse_error_decl(Parser *parser) {
    if (!parser_match(parser, TOKEN_ERROR)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

    parser_consume(parser); // 消费 error

    // 期望错误名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        fprintf(stderr, "语法错误: 期望错误名\n");
        return NULL;
    }

    ASTNode *error_decl = ast_new_node(AST_ERROR_DECL, line, col, filename);
    if (!error_decl) {
        return NULL;
    }

    error_decl->data.error_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!error_decl->data.error_decl.name) {
        ast_free(error_decl);
        return NULL;
    }
    strcpy(error_decl->data.error_decl.name, parser->current_token->value);

    parser_consume(parser); // 消费错误名

    // 期望 ';'
    if (!parser_expect(parser, TOKEN_SEMICOLON)) {
        ast_free(error_decl);
        return NULL;
    }

    return error_decl;
}

// 解析接口实现声明 (StructName : InterfaceName { ... })
// 新语法（0.24版本）：移除了 impl 关键字
ASTNode *parser_parse_impl_decl(Parser *parser) {
    // 期望结构体名称（第一个标识符）
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        return NULL;
    }

    int line = parser->current_token->line;
    int col = parser->current_token->column;
    const char *filename = parser->current_token->filename;

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
ASTNode *parser_parse_test_block(Parser *parser) {
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

ASTNode *parser_parse_param(Parser *parser) {
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

