#include "parser_internal.h"

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

