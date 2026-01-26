#include "internal.h"

ASTNode *find_enum_decl(CodeGenerator *codegen, const char *enum_name) {
    if (!codegen || !codegen->program_node || !enum_name) {
        return NULL;
    }
    
    ASTNode *program = codegen->program_node;
    if (program->type != AST_PROGRAM) {
        return NULL;
    }
    
    for (int i = 0; i < program->data.program.decl_count; i++) {
        ASTNode *decl = program->data.program.decls[i];
        if (decl != NULL && decl->type == AST_ENUM_DECL) {
            if (decl->data.enum_decl.name != NULL && 
                strcmp(decl->data.enum_decl.name, enum_name) == 0) {
                return decl;
            }
        }
    }
    
    return NULL;
}

// 辅助函数：在枚举声明中查找变体索引
// 参数：enum_decl - 枚举声明节点
//       variant_name - 变体名称
// 返回：变体索引（>= 0），未找到返回 -1
int find_enum_variant_index(ASTNode *enum_decl, const char *variant_name) {
    if (!enum_decl || enum_decl->type != AST_ENUM_DECL || !variant_name) {
        return -1;
    }
    
    for (int i = 0; i < enum_decl->data.enum_decl.variant_count; i++) {
        if (enum_decl->data.enum_decl.variants[i].name != NULL && 
            strcmp(enum_decl->data.enum_decl.variants[i].name, variant_name) == 0) {
            return i;
        }
    }
    
    return -1;
}

// 辅助函数：获取枚举变体的值（显式值或计算值）
// 参数：enum_decl - 枚举声明节点
//       variant_index - 变体索引
// 返回：枚举值（整数），失败返回 -1
// 注意：如果变体有显式值，使用显式值；否则使用变体索引（从0开始，或基于前一个变体的值）
int get_enum_variant_value(ASTNode *enum_decl, int variant_index) {
    if (!enum_decl || enum_decl->type != AST_ENUM_DECL || variant_index < 0) {
        return -1;
    }
    
    if (variant_index >= enum_decl->data.enum_decl.variant_count) {
        return -1;
    }
    
    EnumVariant *variant = &enum_decl->data.enum_decl.variants[variant_index];
    
    // 如果变体有显式值，使用显式值
    if (variant->value != NULL) {
        return atoi(variant->value);
    }
    
    // 没有显式值，计算值（基于前一个变体的值）
    if (variant_index == 0) {
        // 第一个变体，值为0
        return 0;
    }
    
    // 获取前一个变体的值
    int prev_value = get_enum_variant_value(enum_decl, variant_index - 1);
    if (prev_value < 0) {
        return -1;
    }
    
    // 当前变体的值 = 前一个变体的值 + 1
    return prev_value + 1;
}

// 辅助函数：在所有枚举声明中查找枚举常量值
// 参数：codegen - 代码生成器指针
//       constant_name - 枚举常量名称（如 AST_PROGRAM, TOKEN_ENUM）
// 返回：枚举值（整数），未找到返回 -1
int find_enum_constant_value(CodeGenerator *codegen, const char *constant_name) {
    if (!codegen || !codegen->program_node || !constant_name) {
        return -1;
    }
    
    ASTNode *program = codegen->program_node;
    if (program->type != AST_PROGRAM) {
        return -1;
    }
    
    // 遍历所有枚举声明，查找匹配的变体
    for (int i = 0; i < program->data.program.decl_count; i++) {
        ASTNode *decl = program->data.program.decls[i];
        if (decl != NULL && decl->type == AST_ENUM_DECL) {
            // 在这个枚举声明中查找变体
            int variant_index = find_enum_variant_index(decl, constant_name);
            if (variant_index >= 0) {
                // 找到匹配的变体，获取其值
                return get_enum_variant_value(decl, variant_index);
            }
        }
    }
    
    return -1;  // 未找到
}

