#include "internal.h"
#include <string.h>

// 检查结构体是否已添加到表中
int is_struct_in_table(C99CodeGenerator *codegen, const char *struct_name) {
    if (!struct_name) return 0;
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (codegen->struct_definitions[i].name && 
            strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            return 1;
        }
    }
    return 0;
}

// 检查结构体是否已定义
int is_struct_defined(C99CodeGenerator *codegen, const char *struct_name) {
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            return codegen->struct_definitions[i].defined;
        }
    }
    return 0;
}

// 标记结构体已定义
void mark_struct_defined(C99CodeGenerator *codegen, const char *struct_name) {
    for (int i = 0; i < codegen->struct_definition_count; i++) {
        if (strcmp(codegen->struct_definitions[i].name, struct_name) == 0) {
            codegen->struct_definitions[i].defined = 1;
            return;
        }
    }
    
    // 如果不在表中，添加
    if (codegen->struct_definition_count < 64) {
        codegen->struct_definitions[codegen->struct_definition_count].name = struct_name;
        codegen->struct_definitions[codegen->struct_definition_count].defined = 1;
        codegen->struct_definition_count++;
    }
}

// 添加结构体定义
void add_struct_definition(C99CodeGenerator *codegen, const char *struct_name) {
    if (is_struct_defined(codegen, struct_name)) {
        return;
    }
    
    if (codegen->struct_definition_count < 64) {
        codegen->struct_definitions[codegen->struct_definition_count].name = struct_name;
        codegen->struct_definitions[codegen->struct_definition_count].defined = 0;
        codegen->struct_definition_count++;
    }
}

// 查找结构体声明
ASTNode *find_struct_decl_c99(C99CodeGenerator *codegen, const char *struct_name) {
    if (!codegen || !struct_name || !codegen->program_node) {
        return NULL;
    }
    
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_STRUCT_DECL) {
            continue;
        }
        
        const char *decl_name = decl->data.struct_decl.name;
        if (decl_name && strcmp(decl_name, struct_name) == 0) {
            return decl;
        }
    }
    
    return NULL;
}

// 查找结构体字段类型
ASTNode *find_struct_field_type(C99CodeGenerator *codegen, ASTNode *struct_decl, const char *field_name) {
    if (!codegen || !struct_decl || struct_decl->type != AST_STRUCT_DECL || !field_name) {
        return NULL;
    }
    
    for (int i = 0; i < struct_decl->data.struct_decl.field_count; i++) {
        ASTNode *field = struct_decl->data.struct_decl.fields[i];
        if (field && field->type == AST_VAR_DECL) {
            if (field->data.var_decl.name && strcmp(field->data.var_decl.name, field_name) == 0) {
                return field->data.var_decl.type;
            }
        }
    }
    
    return NULL;
}

// 生成结构体定义
int gen_struct_definition(C99CodeGenerator *codegen, ASTNode *struct_decl) {
    if (!struct_decl || struct_decl->type != AST_STRUCT_DECL) {
        return -1;
    }
    
    const char *struct_name = get_safe_c_identifier(codegen, struct_decl->data.struct_decl.name);
    if (!struct_name) {
        return -1;
    }
    
    // 如果已定义，跳过
    if (is_struct_defined(codegen, struct_name)) {
        return 0;
    }
    
    // 添加结构体定义标记
    add_struct_definition(codegen, struct_name);
    
    // 输出结构体定义
    c99_emit(codegen, "struct %s {\n", struct_name);
    codegen->indent_level++;
    
    // 生成字段
    int field_count = struct_decl->data.struct_decl.field_count;
    ASTNode **fields = struct_decl->data.struct_decl.fields;
    
    // 如果是空结构体，添加一个占位符字段以确保大小为 1（符合 Uya 规范）
    if (field_count == 0) {
        c99_emit(codegen, "char _empty;\n");
    } else {
        for (int i = 0; i < field_count; i++) {
            ASTNode *field = fields[i];
            if (!field || field->type != AST_VAR_DECL) {
                return -1;
            }
            
            const char *field_name = get_safe_c_identifier(codegen, field->data.var_decl.name);
            ASTNode *field_type = field->data.var_decl.type;
            
            if (!field_name || !field_type) {
                return -1;
            }
            
            // 检查是否为数组类型
            if (field_type->type == AST_TYPE_ARRAY) {
                ASTNode *element_type = field_type->data.type_array.element_type;
                ASTNode *size_expr = field_type->data.type_array.size_expr;
                const char *elem_type_c = c99_type_to_c(codegen, element_type);
                
                // 评估数组大小
                int array_size = -1;
                if (size_expr) {
                    array_size = eval_const_expr(codegen, size_expr);
                    if (array_size <= 0) {
                        array_size = 1;  // 占位符
                    }
                } else {
                    array_size = 1;  // 占位符
                }
                
                c99_emit(codegen, "%s %s[%d];\n", elem_type_c, field_name, array_size);
            } else {
                const char *field_type_c = c99_type_to_c(codegen, field_type);
                c99_emit(codegen, "%s %s;\n", field_type_c, field_name);
            }
        }
    }
    
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    
    // 标记为已定义
    mark_struct_defined(codegen, struct_name);
    return 0;
}
