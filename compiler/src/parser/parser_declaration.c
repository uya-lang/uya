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

// 解析顶级声明
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

// 辅助函数：从字符串创建临时 Lexer（用于解析字符串插值中的表达式）
Lexer *create_temp_lexer_from_string(const char *expr_str, int line, int col, const char *filename) {
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
FormatSpec parse_format_spec(const char *spec_str) {
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
ASTNode *parser_parse_string_interpolation(Parser *parser, Token *string_token) {
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
                   !parser_match(parser, TOKEN_ENUM) &&
                   !parser_match(parser, TOKEN_EXTERN) &&
                   !parser_match(parser, TOKEN_IDENTIFIER) && // 可能是接口实现（新语法）
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

