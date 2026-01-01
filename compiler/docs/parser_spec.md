# Uya语言语法分析器规范文档

## 1. 概述

### 1.1 设计目标
Uya语言的语法分析器（Parser）负责将词法分析器生成的Token流转换为抽象语法树（AST）。设计目标包括：

- **递归下降解析**：使用递归下降算法构建AST
- **错误恢复**：在遇到语法错误时能够恢复并继续解析
- **类型安全**：生成类型正确的AST节点
- **内存安全**：确保生成的AST符合Uya的内存安全规则
- **切片语法支持**：支持操作符语法 `arr[start:len]`（解析为 `slice(arr, start, len)` 函数调用）
- **For 循环语法**：支持简化语法 `for arr |val| {}` 和传统语法 `for (arr) |val| {}`
- **饱和/包装运算符**：支持 `+|`, `-|`, `*|`, `+%`, `-%`, `*%` 运算符

### 1.2 解析器架构
```
Token流 -> 语法分析器 -> AST -> 类型检查器 -> IR生成器 -> 代码生成器
```

## 2. 语法分析器接口

### 2.1 语法分析器结构

```c
typedef struct Parser {
    Lexer *lexer;              // 词法分析器
    Token *current_token;      // 当前Token
    int error_count;           // 错误计数
    char **errors;             // 错误消息列表
    int error_capacity;        // 错误列表容量
} Parser;
```

### 2.2 语法分析器函数接口

```c
// 创建语法分析器
Parser *parser_new(Lexer *lexer);

// 释放语法分析器
void parser_free(Parser *parser);

// 解析整个程序
ASTNode *parser_parse(Parser *parser);

// 解析声明
ASTNode *parser_parse_declaration(Parser *parser);

// 解析语句
ASTNode *parser_parse_statement(Parser *parser);

// 解析表达式
ASTNode *parser_parse_expression(Parser *parser);

// 解析类型
ASTNode *parser_parse_type(Parser *parser);

// 期望特定类型的Token
Token *parser_expect(Parser *parser, TokenType type);

// 检查当前Token类型
int parser_match(Parser *parser, TokenType type);

// 消费当前Token并获取下一个
Token *parser_consume(Parser *parser);

// 前瞻Token
Token *parser_peek(Parser *parser);
```

## 3. 语法分析器实现

### 3.1 语法分析器初始化

```c
Parser *parser_new(Lexer *lexer) {
    if (!lexer) {
        return NULL;
    }

    Parser *parser = malloc(sizeof(Parser));
    if (!parser) {
        return NULL;
    }

    parser->lexer = lexer;
    parser->current_token = lexer_next_token(lexer);
    parser->error_count = 0;
    parser->errors = malloc(16 * sizeof(char*));
    parser->error_capacity = 16;

    if (!parser->errors) {
        free(parser);
        return NULL;
    }

    return parser;
}

void parser_free(Parser *parser) {
    if (parser) {
        if (parser->current_token) {
            token_free(parser->current_token);
        }
        if (parser->errors) {
            for (int i = 0; i < parser->error_count; i++) {
                free(parser->errors[i]);
            }
            free(parser->errors);
        }
        free(parser);
    }
}
```

### 3.2 Token操作函数

```c
// 检查当前Token是否为指定类型
int parser_match(Parser *parser, TokenType type) {
    return parser->current_token && parser->current_token->type == type;
}

// 期望特定类型的Token，如果不是则报错
Token *parser_expect(Parser *parser, TokenType type) {
    if (!parser->current_token || parser->current_token->type != type) {
        char *error_msg = malloc(256);
        if (error_msg) {
            snprintf(error_msg, 256, 
                    "语法错误: 期望 %d，但在 %s:%d:%d 发现 %d", 
                    type, 
                    parser->current_token ? parser->current_token->filename : "unknown",
                    parser->current_token ? parser->current_token->line : 0,
                    parser->current_token ? parser->current_token->column : 0,
                    parser->current_token ? parser->current_token->type : -1);
            
            // 添加错误到错误列表
            if (parser->error_count < parser->error_capacity) {
                parser->errors[parser->error_count] = error_msg;
                parser->error_count++;
            } else {
                free(error_msg);  // 如果错误列表满了，丢弃错误消息
            }
        }
        return NULL;
    }
    
    Token *current = parser->current_token;
    parser->current_token = lexer_next_token(parser->lexer);
    return current;
}

// 消费当前Token并获取下一个
Token *parser_consume(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }
    
    Token *current = parser->current_token;
    parser->current_token = lexer_next_token(parser->lexer);
    return current;
}
```

## 4. 语法分析算法

### 4.1 递归下降解析

语法分析器使用递归下降算法，按照以下优先级解析：

1. **程序级**：解析整个程序（函数声明、结构体声明等）
2. **声明级**：解析各种声明（函数、结构体、变量等）
3. **语句级**：解析各种语句（if、while、return等）
4. **表达式级**：解析表达式（从低优先级到高优先级）

### 4.2 程序解析

```c
ASTNode *parser_parse(Parser *parser) {
    if (!parser) {
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
            // 如果解析声明失败，尝试跳过到下一个可能的声明开始
            parser_skip_to_next_decl(parser);
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
```

### 4.3 声明解析

```c
ASTNode *parser_parse_declaration(Parser *parser) {
    if (!parser->current_token) {
        return NULL;
    }

    switch (parser->current_token->type) {
        case TOKEN_STRUCT:
            return parser_parse_struct_decl(parser);
        case TOKEN_FN:
            return parser_parse_fn_decl(parser);
        case TOKEN_EXTERN:
            return parser_parse_extern_decl(parser);

        case TOKEN_INTERFACE:
            return parser_parse_interface_decl(parser);
        case TOKEN_MC:
            return parser_parse_macro_decl(parser);
        default:
            // 不是声明，可能是语句
            return parser_parse_statement(parser);
    }
}

// 解析结构体声明
ASTNode *parser_parse_struct_decl(Parser *parser) {
    if (!parser_expect(parser, TOKEN_STRUCT)) {
        return NULL;
    }

    // 期望结构体名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        parser_add_error(parser, "期望结构体名");
        return NULL;
    }

    ASTNode *struct_decl = ast_new_node(AST_STRUCT_DECL,
                                       parser->current_token->line,
                                       parser->current_token->column,
                                       parser->current_token->filename);
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
        // 解析字段
        ASTNode *field = parser_parse_struct_field(parser);
        if (!field) {
            // 跳过到下一个字段或'}'
            parser_skip_to_field_separator(parser);
            continue;
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

        // 期望 ',' 或 '}'
        if (parser_match(parser, TOKEN_COMMA)) {
            parser_consume(parser);
        } else if (parser_match(parser, TOKEN_RIGHT_BRACE)) {
            break;
        } else {
            parser_add_error(parser, "期望 ',' 或 '}'");
            break;
        }
    }

    // 期望 '}'
    if (!parser_expect(parser, TOKEN_RIGHT_BRACE)) {
        ast_free(struct_decl);
        return NULL;
    }

    return struct_decl;
}

// 解析函数声明
ASTNode *parser_parse_fn_decl(Parser *parser) {
    if (!parser_expect(parser, TOKEN_FN)) {
        return NULL;
    }

    // 期望函数名
    if (!parser_match(parser, TOKEN_IDENTIFIER)) {
        parser_add_error(parser, "期望函数名");
        return NULL;
    }

    ASTNode *fn_decl = ast_new_node(AST_FN_DECL,
                                   parser->current_token->line,
                                   parser->current_token->column,
                                   parser->current_token->filename);
    if (!fn_decl) {
        return NULL;
    }

    fn_decl->data.fn_decl.name = malloc(strlen(parser->current_token->value) + 1);
    if (!fn_decl->data.fn_decl.name) {
        ast_free(fn_decl);
        return NULL;
    }
    strcpy(fn_decl->data.fn_decl.name, parser->current_token->value);

    parser_consume(parser); // 消费函数名

    // 解析参数列表
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        ast_free(fn_decl);
        return NULL;
    }

    // 解析参数
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
                parser_consume(parser);
            } else {
                break;
            }
        } while (!parser_match(parser, TOKEN_RIGHT_PAREN) && parser->current_token);
    }

    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
        ast_free(fn_decl);
        return NULL;
    }

    // 解析返回类型（可选）
    if (parser_match(parser, TOKEN_ARROW)) {
        parser_consume(parser); // 消费 '->'
        fn_decl->data.fn_decl.return_type = parser_parse_type(parser);
        if (!fn_decl->data.fn_decl.return_type) {
            ast_free(fn_decl);
            return NULL;
        }
    } else {
        // 默认返回类型为 void
        fn_decl->data.fn_decl.return_type = ast_new_node(AST_TYPE_NAMED,
                                                        parser->current_token->line,
                                                        parser->current_token->column,
                                                        parser->current_token->filename);
        if (fn_decl->data.fn_decl.return_type) {
            fn_decl->data.fn_decl.return_type->data.type_named.name = malloc(5);
            if (fn_decl->data.fn_decl.return_type->data.type_named.name) {
                strcpy(fn_decl->data.fn_decl.return_type->data.type_named.name, "void");
            }
        }
    }

    // 解析函数体
    fn_decl->data.fn_decl.body = parser_parse_block(parser);
    if (!fn_decl->data.fn_decl.body) {
        ast_free(fn_decl);
        return NULL;
    }

    return fn_decl;
}
```

## 5. 切片语法解析

### 5.1 切片函数调用解析

```c
// 解析函数调用表达式，特别处理slice函数调用
ASTNode *parser_parse_call_expr(Parser *parser, ASTNode *callee) {
    if (!parser_expect(parser, TOKEN_LEFT_PAREN)) {
        ast_free(callee);
        return NULL;
    }

    ASTNode *call_expr = ast_new_node(AST_CALL_EXPR,
                                     parser->current_token->line,
                                     parser->current_token->column,
                                     parser->current_token->filename);
    if (!call_expr) {
        ast_free(callee);
        return NULL;
    }

    call_expr->data.call_expr.callee = callee;
    call_expr->data.call_expr.args = NULL;
    call_expr->data.call_expr.arg_count = 0;
    int arg_capacity = 0;

    // 检查是否是slice函数调用
    int is_slice_call = 0;
    if (callee->type == AST_IDENTIFIER && 
        strcmp(callee->data.identifier.name, "slice") == 0) {
        is_slice_call = 1;
    }

    if (!parser_match(parser, TOKEN_RIGHT_PAREN)) {
        do {
            ASTNode *arg = parser_parse_expression(parser);
            if (!arg) {
                ast_free(call_expr);
                return NULL;
            }

            // 扩容参数列表
            if (call_expr->data.call_expr.arg_count >= arg_capacity) {
                int new_capacity = arg_capacity == 0 ? 4 : arg_capacity * 2;
                ASTNode **new_args = realloc(call_expr->data.call_expr.args,
                                            new_capacity * sizeof(ASTNode*));
                if (!new_args) {
                    ast_free(arg);
                    ast_free(call_expr);
                    return NULL;
                }
                call_expr->data.call_expr.args = new_args;
                arg_capacity = new_capacity;
            }

            call_expr->data.call_expr.args[call_expr->data.call_expr.arg_count] = arg;
            call_expr->data.call_expr.arg_count++;

            if (parser_match(parser, TOKEN_COMMA)) {
                parser_consume(parser);
            } else {
                break;
            }
        } while (!parser_match(parser, TOKEN_RIGHT_PAREN) && parser->current_token);
    }

    if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
        ast_free(call_expr);
        return NULL;
    }

    // 如果是slice调用，验证参数数量
    if (is_slice_call) {
        if (call_expr->data.call_expr.arg_count != 3) {
            parser_add_error(parser, "slice函数必须有3个参数：slice(arr, start, len)");
            ast_free(call_expr);
            return NULL;
        }
    }

    return call_expr;
}
```

### 5.2 操作符切片语法解析

```c
// 解析数组下标和切片表达式
ASTNode *parser_parse_subscript_or_slice_expr(Parser *parser, ASTNode *array) {
    if (!parser_expect(parser, TOKEN_LEFT_BRACKET)) {
        ast_free(array);
        return NULL;
    }

    // 检查是否是切片语法（包含冒号）
    Token *next_token = parser_peek_token(parser);
    if (!next_token) {
        ast_free(array);
        return NULL;
    }

    // 查找是否在当前表达式中包含冒号（切片语法）
    int is_slice_syntax = 0;
    Token *temp_token = next_token;
    int paren_depth = 0;
    
    // 简单检查：如果下一个token是冒号，则是切片语法
    if (temp_token->type == TOKEN_COLON) {
        is_slice_syntax = 1;
    } else {
        // 查找后续token中是否有冒号
        Token *lookahead = lexer_peek_n(parser->lexer, 1);  // 向前看1个token
        if (lookahead && lookahead->type == TOKEN_COLON) {
            is_slice_syntax = 1;
        }
    }

    if (is_slice_syntax) {
        // 解析切片语法：arr[start:end] 或 arr[start:end:step]（step可选）
        ASTNode *slice_expr = ast_new_node(AST_SLICE_EXPR,
                                          parser->current_token->line,
                                          parser->current_token->column,
                                          parser->current_token->filename);
        if (!slice_expr) {
            ast_free(array);
            return NULL;
        }

        slice_expr->data.slice_expr.source = array;

        // 解析起始索引（可选）
        if (!parser_match(parser, TOKEN_COLON)) {
            slice_expr->data.slice_expr.start = parser_parse_expression(parser);
            if (!slice_expr->data.slice_expr.start) {
                ast_free(slice_expr);
                return NULL;
            }
        } else {
            // 如果直接是冒号，起始索引为0
            slice_expr->data.slice_expr.start = NULL;  // 表示从开头开始
        }

        // 期望 ':'
        if (!parser_expect(parser, TOKEN_COLON)) {
            ast_free(slice_expr);
            return NULL;
        }

        // 解析结束索引（可选）
        if (!parser_match(parser, TOKEN_RIGHT_BRACKET) && 
            !parser_match(parser, TOKEN_COLON)) {  // 如果不是右括号也不是另一个冒号（step）
            slice_expr->data.slice_expr.end = parser_parse_expression(parser);
            if (!slice_expr->data.slice_expr.end) {
                ast_free(slice_expr);
                return NULL;
            }
        } else {
            // 如果直接是右括号或另一个冒号，结束索引为数组长度
            slice_expr->data.slice_expr.end = NULL;  // 表示到末尾
        }

        // 解析步长（可选，当前版本不支持）
        if (parser_match(parser, TOKEN_COLON)) {
            parser_add_error(parser, "当前版本不支持步长语法 arr[start:end:step]");
            ast_free(slice_expr);
            return NULL;
        }

        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
            ast_free(slice_expr);
            return NULL;
        }

        return slice_expr;
    } else {
        // 普通数组下标访问：arr[index]
        ASTNode *index_expr = parser_parse_expression(parser);
        if (!index_expr) {
            ast_free(array);
            return NULL;
        }

        if (!parser_expect(parser, TOKEN_RIGHT_BRACKET)) {
            ast_free(index_expr);
            ast_free(array);
            return NULL;
        }

        ASTNode *subscript_expr = ast_new_node(AST_SUBSCRIPT_EXPR,
                                              parser->current_token->line,
                                              parser->current_token->column,
                                              parser->current_token->filename);
        if (!subscript_expr) {
            ast_free(index_expr);
            ast_free(array);
            return NULL;
        }

        subscript_expr->data.subscript_expr.array = array;
        subscript_expr->data.subscript_expr.index = index_expr;

        return subscript_expr;
    }
}
```

### 5.3 切片表达式AST节点

```c
// 在AST节点类型中添加切片表达式类型
typedef enum {
    // ... 其他类型
    AST_SLICE_EXPR,      // 切片表达式
    // ... 其他类型
} ASTNodeType;

// 在AST节点数据结构中添加切片表达式数据
union {
    // ... 其他结构
    // 切片表达式
    struct {
        struct ASTNode *source;    // 源数组
        struct ASTNode *start;     // 起始索引（NULL表示从开头）
        struct ASTNode *end;       // 结束索引（NULL表示到末尾）
        struct ASTNode *step;      // 步长（当前版本为NULL，不支持）
    } slice_expr;
    // ... 其他结构
} data;
```

## 6. 表达式解析

### 6.1 表达式优先级解析

语法分析器按照以下优先级解析表达式：

1. **Primary**：标识符、字面量、括号表达式
2. **Postfix**：函数调用、数组下标、切片操作、成员访问
3. **Unary**：一元运算符
4. **Multiplicative**：乘法、除法、取模
5. **Additive**：加法、减法
6. **Shift**：位移运算
7. **Relational**：比较运算
8. **Equality**：相等性比较
9. **Bitwise AND**
10. **Bitwise XOR**
11. **Bitwise OR**
12. **Logical AND**
13. **Logical OR**
14. **Assignment**：赋值

```c
// 主表达式解析函数
ASTNode *parser_parse_expression(Parser *parser) {
    return parser_parse_assignment_expr(parser);
}

// 赋值表达式
ASTNode *parser_parse_assignment_expr(Parser *parser) {
    ASTNode *left = parser_parse_logical_or_expr(parser);
    if (!left) {
        return NULL;
    }

    if (parser_match(parser, TOKEN_ASSIGN)) {
        parser_consume(parser); // 消费 '='
        ASTNode *right = parser_parse_assignment_expr(parser);
        if (!right) {
            ast_free(left);
            return NULL;
        }

        ASTNode *assign_expr = ast_new_node(AST_BINARY_EXPR,
                                           parser->current_token->line,
                                           parser->current_token->column,
                                           parser->current_token->filename);
        if (!assign_expr) {
            ast_free(left);
            ast_free(right);
            return NULL;
        }

        assign_expr->data.binary_expr.left = left;
        assign_expr->data.binary_expr.op = TOKEN_ASSIGN;
        assign_expr->data.binary_expr.right = right;

        return assign_expr;
    }

    return left;
}

// 逻辑或表达式
ASTNode *parser_parse_logical_or_expr(Parser *parser) {
    ASTNode *left = parser_parse_logical_and_expr(parser);
    if (!left) {
        return NULL;
    }

    while (parser_match(parser, TOKEN_LOGICAL_OR)) {
        Token *op_token = parser_consume(parser);
        ASTNode *right = parser_parse_logical_and_expr(parser);
        if (!right) {
            ast_free(left);
            return NULL;
        }

        ASTNode *binary_expr = ast_new_node(AST_BINARY_EXPR,
                                           op_token->line,
                                           op_token->column,
                                           op_token->filename);
        if (!binary_expr) {
            ast_free(left);
            ast_free(right);
            return NULL;
        }

        binary_expr->data.binary_expr.left = left;
        binary_expr->data.binary_expr.op = op_token->type;
        binary_expr->data.binary_expr.right = right;

        left = binary_expr;
    }

    return left;
}

// 一元表达式
ASTNode *parser_parse_unary_expr(Parser *parser) {
    if (parser_match(parser, TOKEN_MINUS) || 
        parser_match(parser, TOKEN_EXCLAMATION) || 
        parser_match(parser, TOKEN_TILDE)) {
        Token *op_token = parser_consume(parser);
        
        ASTNode *operand = parser_parse_unary_expr(parser);
        if (!operand) {
            return NULL;
        }

        ASTNode *unary_expr = ast_new_node(AST_UNARY_EXPR,
                                          op_token->line,
                                          op_token->column,
                                          op_token->filename);
        if (!unary_expr) {
            ast_free(operand);
            return NULL;
        }

        unary_expr->data.unary_expr.op = op_token->type;
        unary_expr->data.unary_expr.operand = operand;

        return unary_expr;
    }

    return parser_parse_postfix_expr(parser);
}

// 后缀表达式（包含函数调用、数组下标、切片等）
ASTNode *parser_parse_postfix_expr(Parser *parser) {
    ASTNode *primary = parser_parse_primary_expr(parser);
    if (!primary) {
        return NULL;
    }

    while (1) {
        if (parser_match(parser, TOKEN_LEFT_PAREN)) {
            // 函数调用
            primary = parser_parse_call_expr(parser, primary);
        } else if (parser_match(parser, TOKEN_LEFT_BRACKET)) {
            // 数组下标或切片
            primary = parser_parse_subscript_or_slice_expr(parser, primary);
        } else if (parser_match(parser, TOKEN_DOT)) {
            // 成员访问
            primary = parser_parse_member_access_expr(parser, primary);
        } else {
            break;
        }
    }

    return primary;
}

// 主要表达式（标识符、字面量、括号表达式）
ASTNode *parser_parse_primary_expr(Parser *parser) {
    if (parser_match(parser, TOKEN_LEFT_PAREN)) {
        parser_consume(parser); // 消费 '('
        ASTNode *expr = parser_parse_expression(parser);
        if (!expr) {
            return NULL;
        }

        if (!parser_expect(parser, TOKEN_RIGHT_PAREN)) {
            ast_free(expr);
            return NULL;
        }

        return expr;
    } else if (parser_match(parser, TOKEN_IDENTIFIER)) {
        ASTNode *ident = ast_new_node(AST_IDENTIFIER,
                                     parser->current_token->line,
                                     parser->current_token->column,
                                     parser->current_token->filename);
        if (!ident) {
            return NULL;
        }

        ident->data.identifier.name = malloc(strlen(parser->current_token->value) + 1);
        if (!ident->data.identifier.name) {
            ast_free(ident);
            return NULL;
        }
        strcpy(ident->data.identifier.name, parser->current_token->value);

        parser_consume(parser); // 消费标识符
        return ident;
    } else if (parser_match(parser, TOKEN_NUMBER)) {
        ASTNode *num = ast_new_node(AST_NUMBER,
                                   parser->current_token->line,
                                   parser->current_token->column,
                                   parser->current_token->filename);
        if (!num) {
            return NULL;
        }

        num->data.number.value = malloc(strlen(parser->current_token->value) + 1);
        if (!num->data.number.value) {
            ast_free(num);
            return NULL;
        }
        strcpy(num->data.number.value, parser->current_token->value);

        parser_consume(parser); // 消费数字
        return num;
    } else if (parser_match(parser, TOKEN_STRING)) {
        ASTNode *str = ast_new_node(AST_STRING,
                                   parser->current_token->line,
                                   parser->current_token->column,
                                   parser->current_token->filename);
        if (!str) {
            return NULL;
        }

        str->data.string.value = malloc(strlen(parser->current_token->value) + 1);
        if (!str->data.string.value) {
            ast_free(str);
            return NULL;
        }
        strcpy(str->data.string.value, parser->current_token->value);

        parser_consume(parser); // 消费字符串
        return str;
    } else if (parser_match(parser, TOKEN_TRUE) || parser_match(parser, TOKEN_FALSE)) {
        ASTNode *bool_val = ast_new_node(AST_BOOL,
                                        parser->current_token->line,
                                        parser->current_token->column,
                                        parser->current_token->filename);
        if (!bool_val) {
            return NULL;
        }

        bool_val->data.bool_literal.value = parser_match(parser, TOKEN_TRUE);
        parser_consume(parser); // 消费布尔值
        return bool_val;
    }

    parser_add_error(parser, "期望表达式");
    return NULL;
}
```

## 7. 错误恢复机制

### 7.1 同步点定义

语法分析器在遇到错误时会跳转到预定义的同步点：

```c
// 跳转到下一个声明的开始
void parser_skip_to_next_decl(Parser *parser) {
    while (parser->current_token && 
           parser->current_token->type != TOKEN_STRUCT &&
           parser->current_token->type != TOKEN_FN &&
           parser->current_token->type != TOKEN_EXTERN &&
           parser->current_token->type != TOKEN_INTERFACE &&
           parser->current_token->type != TOKEN_EOF) {
        parser_consume(parser);
    }
}

// 跳转到下一个语句的开始
void parser_skip_to_next_stmt(Parser *parser) {
    while (parser->current_token && 
           parser->current_token->type != TOKEN_LET &&
           parser->current_token->type != TOKEN_MUT &&
           parser->current_token->type != TOKEN_IF &&
           parser->current_token->type != TOKEN_WHILE &&
           parser->current_token->type != TOKEN_RETURN &&
           parser->current_token->type != TOKEN_FN &&
           parser->current_token->type != TOKEN_LEFT_BRACE &&
           parser->current_token->type != TOKEN_RIGHT_BRACE &&
           parser->current_token->type != TOKEN_SEMICOLON &&
           parser->current_token->type != TOKEN_EOF) {
        parser_consume(parser);
    }
    
    if (parser_match(parser, TOKEN_SEMICOLON)) {
        parser_consume(parser);  // 消费分号，作为语句结束
    }
}
```

### 7.2 错误报告

```c
// 添加错误消息
void parser_add_error(Parser *parser, const char *fmt, ...) {
    char *error_msg = malloc(512);
    if (!error_msg) {
        return;
    }

    va_list args;
    va_start(args, fmt);
    vsnprintf(error_msg, 512, fmt, args);
    va_end(args);

    // 添加位置信息
    char *full_error = malloc(strlen(error_msg) + 64);
    if (full_error) {
        snprintf(full_error, strlen(error_msg) + 64, 
                "语法错误 (%s:%d:%d): %s", 
                parser->current_token ? parser->current_token->filename : "unknown",
                parser->current_token ? parser->current_token->line : 0,
                parser->current_token ? parser->current_token->column : 0,
                error_msg);
        
        // 扩容错误列表
        if (parser->error_count >= parser->error_capacity) {
            int new_capacity = parser->error_capacity * 2;
            char **new_errors = realloc(parser->errors, 
                                       new_capacity * sizeof(char*));
            if (new_errors) {
                parser->errors = new_errors;
                parser->error_capacity = new_capacity;
            } else {
                free(full_error);
                free(error_msg);
                return;
            }
        }

        parser->errors[parser->error_count] = full_error;
        parser->error_count++;
    } else {
        free(error_msg);
    }
}
```

## 8. 与Uya语言哲学的一致性

语法分析器完全符合Uya语言的核心哲学：

1. **安全优先**：生成的AST结构确保类型安全
2. **零运行时开销**：所有语法验证在编译期完成
3. **显式控制**：语法结构明确，无隐式转换
4. **数学确定性**：每个语法结构都有明确的定义

## 9. 性能特性

### 9.1 时间复杂度
- 递归下降解析：O(n)，其中n是Token数量
- 错误恢复：O(k)，其中k是跳过的Token数量

### 9.2 空间复杂度
- AST构建：O(m)，其中m是语法树节点数量
- 符号表：O(s)，其中s是符号数量

## 10. 与切片语法的集成

### 10.1 切片语法支持
- **函数语法**：`slice(arr, start, len)` - 传统函数调用形式
- **操作符语法**：`arr[start:end]` - Python风格切片语法
- **负数索引**：`arr[-n]` 自动转换为 `len(arr) - n`
- **边界检查**：所有切片操作都经过编译期或运行时边界验证

### 10.2 语法糖实现
- 操作符语法 `[start:end]` 在解析阶段转换为函数调用 `slice(arr, start, end-start)`
- 保持与函数语法相同的语义和安全保证

> **Uya语法分析器 = 递归下降解析 + 错误恢复 + 切片语法支持**；
> **零运行时开销，编译期语法验证，失败即编译错误**；
> **通过路径零指令，安全路径直接生成AST**。