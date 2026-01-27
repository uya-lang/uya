#include "internal.h"
#include <string.h>
#include <stdlib.h>

ASTNode *find_enum_decl_c99(C99CodeGenerator *codegen, const char *enum_name) {
    if (!codegen || !enum_name || !codegen->program_node) {
        return NULL;
    }
    
    ASTNode **decls = codegen->program_node->data.program.decls;
    int decl_count = codegen->program_node->data.program.decl_count;
    
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl || decl->type != AST_ENUM_DECL) {
            continue;
        }
        
        const char *decl_name = decl->data.enum_decl.name;
        if (decl_name && strcmp(decl_name, enum_name) == 0) {
            return decl;
        }
    }
    
    return NULL;
}

// 查找枚举变体的值（返回-1表示未找到）
int find_enum_variant_value(C99CodeGenerator *codegen, ASTNode *enum_decl, const char *variant_name) {
    (void)codegen;  // 未使用参数
    if (!enum_decl || enum_decl->type != AST_ENUM_DECL || !variant_name) {
        return -1;
    }
    
    EnumVariant *variants = enum_decl->data.enum_decl.variants;
    int variant_count = enum_decl->data.enum_decl.variant_count;
    int current_value = 0;
    
    for (int i = 0; i < variant_count; i++) {
        EnumVariant *variant = &variants[i];
        if (!variant->name) {
            continue;
        }
        
        // 确定当前变体的值
        if (variant->value) {
            current_value = atoi(variant->value);
        }
        
        // 检查是否匹配
        if (strcmp(variant->name, variant_name) == 0) {
            return current_value;
        }
        
        // 如果没有显式值，下一个变体的值会自动递增
        if (!variant->value) {
            current_value++;
        }
    }
    
    return -1;
}
int is_enum_defined(C99CodeGenerator *codegen, const char *enum_name) {
    for (int i = 0; i < codegen->enum_definition_count; i++) {
        if (strcmp(codegen->enum_definitions[i].name, enum_name) == 0) {
            return codegen->enum_definitions[i].defined;
        }
    }
    return 0;
}

// 检查枚举是否已添加到表中
int is_enum_in_table(C99CodeGenerator *codegen, const char *enum_name) {
    for (int i = 0; i < codegen->enum_definition_count; i++) {
        if (strcmp(codegen->enum_definitions[i].name, enum_name) == 0) {
            return 1;
        }
    }
    return 0;
}

// 标记枚举已定义
void mark_enum_defined(C99CodeGenerator *codegen, const char *enum_name) {
    for (int i = 0; i < codegen->enum_definition_count; i++) {
        if (strcmp(codegen->enum_definitions[i].name, enum_name) == 0) {
            codegen->enum_definitions[i].defined = 1;
            return;
        }
    }
}

// 添加枚举定义
void add_enum_definition(C99CodeGenerator *codegen, const char *enum_name) {
    // 如果已存在，则返回
    for (int i = 0; i < codegen->enum_definition_count; i++) {
        if (strcmp(codegen->enum_definitions[i].name, enum_name) == 0) {
            return;
        }
    }
    
    if (codegen->enum_definition_count < 64) {
        codegen->enum_definitions[codegen->enum_definition_count].name = enum_name;
        codegen->enum_definitions[codegen->enum_definition_count].defined = 0;
        codegen->enum_definition_count++;
    }
}

// 生成枚举定义
int gen_enum_definition(C99CodeGenerator *codegen, ASTNode *enum_decl) {
    if (!enum_decl || enum_decl->type != AST_ENUM_DECL) {
        return -1;
    }
    
    const char *enum_name = get_safe_c_identifier(codegen, enum_decl->data.enum_decl.name);
    if (!enum_name) {
        return -1;
    }
    
    // 如果已定义，跳过
    if (is_enum_defined(codegen, enum_name)) {
        return 0;
    }
    
    // 添加枚举定义标记
    add_enum_definition(codegen, enum_name);
    
    // 输出枚举定义
    c99_emit(codegen, "enum %s {\n", enum_name);
    codegen->indent_level++;
    
    EnumVariant *variants = enum_decl->data.enum_decl.variants;
    int variant_count = enum_decl->data.enum_decl.variant_count;
    int current_value = 0;
    
    for (int i = 0; i < variant_count; i++) {
        EnumVariant *variant = &variants[i];
        if (!variant->name) {
            return -1;
        }
        
        // 确定变体的值
        if (variant->value) {
            // 有显式值，使用atoi转换
            const char *safe_variant_name = get_safe_c_identifier(codegen, variant->name);
            current_value = atoi(variant->value);
            c99_emit(codegen, "%s = %d", safe_variant_name, current_value);
        } else {
            // 无显式值，使用当前值（从0开始或基于前一个值）
            const char *safe_variant_name = get_safe_c_identifier(codegen, variant->name);
            c99_emit(codegen, "%s", safe_variant_name);
            // 当前值保持不变，供下一个变体使用（C中隐式递增）
        }
        
        // 添加逗号（除非是最后一个）
        if (i < variant_count - 1) {
            fputs(",", codegen->output);
        }
        fputs("\n", codegen->output);
    }
    
    codegen->indent_level--;
    c99_emit(codegen, "};\n");
    
    // 标记为已定义
    mark_enum_defined(codegen, enum_name);
    return 0;
}
