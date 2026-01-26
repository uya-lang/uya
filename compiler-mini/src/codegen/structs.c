#include "internal.h"

// 前向声明
LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node);

// 注册结构体
void register_structs_in_node(CodeGenerator *codegen, ASTNode *node) {
    if (!codegen || !node) {
        return;
    }
    
    // 如果是结构体声明，注册它
    if (node->type == AST_STRUCT_DECL) {
        codegen_register_struct_type(codegen, node);
        return;
    }
    
    // 如果是代码块，递归遍历其中的语句
    if (node->type == AST_BLOCK) {
        for (int i = 0; i < node->data.block.stmt_count; i++) {
            ASTNode *stmt = node->data.block.stmts[i];
            if (stmt != NULL) {
                register_structs_in_node(codegen, stmt);
            }
        }
        return;
    }
    
    // 如果是 if 语句，递归遍历 then 和 else 分支
    if (node->type == AST_IF_STMT) {
        if (node->data.if_stmt.then_branch != NULL) {
            register_structs_in_node(codegen, node->data.if_stmt.then_branch);
        }
        if (node->data.if_stmt.else_branch != NULL) {
            register_structs_in_node(codegen, node->data.if_stmt.else_branch);
        }
        return;
    }
    
    // 如果是 while 语句，递归遍历循环体
    if (node->type == AST_WHILE_STMT) {
        if (node->data.while_stmt.body != NULL) {
            register_structs_in_node(codegen, node->data.while_stmt.body);
        }
        return;
    }
    
    // 如果是 for 语句，递归遍历循环体
    if (node->type == AST_FOR_STMT) {
        if (node->data.for_stmt.body != NULL) {
            register_structs_in_node(codegen, node->data.for_stmt.body);
        }
        return;
    }
}

// 查找结构体声明
ASTNode *find_struct_decl(CodeGenerator *codegen, const char *struct_name) {
    if (!codegen || !struct_name) {
        return NULL;
    }
    
    // 首先在全局作用域查找
    if (codegen->program_node) {
        ASTNode *program = codegen->program_node;
        if (program->type == AST_PROGRAM) {
            for (int i = 0; i < program->data.program.decl_count; i++) {
                ASTNode *decl = program->data.program.decls[i];
                if (decl != NULL && decl->type == AST_STRUCT_DECL) {
                    if (decl->data.struct_decl.name != NULL && 
                        strcmp(decl->data.struct_decl.name, struct_name) == 0) {
                        return decl;
                    }
                }
            }
        }
    }
    
    // 如果全局作用域未找到，在已注册的结构体类型中查找（包括函数内部注册的）
    for (int i = 0; i < codegen->struct_type_count; i++) {
        if (codegen->struct_types[i].name != NULL &&
            strcmp(codegen->struct_types[i].name, struct_name) == 0) {
            // 返回存储的 AST 节点
            return codegen->struct_types[i].ast_node;
        }
    }
    
    return NULL;
}

// 从类型查找结构体名称
const char *find_struct_name_from_type(CodeGenerator *codegen, LLVMTypeRef struct_type) {
    if (!codegen || !struct_type) {
        return NULL;
    }
    
    // 在结构体类型映射表中查找匹配的类型
    for (int i = 0; i < codegen->struct_type_count; i++) {
        if (codegen->struct_types[i].llvm_type == struct_type) {
            return codegen->struct_types[i].name;
        }
    }
    
    return NULL;  // 未找到
}

// 查找结构体字段索引
int find_struct_field_index(ASTNode *struct_decl, const char *field_name) {
    if (!struct_decl || struct_decl->type != AST_STRUCT_DECL || !field_name) {
        return -1;
    }
    
    for (int i = 0; i < struct_decl->data.struct_decl.field_count; i++) {
        ASTNode *field = struct_decl->data.struct_decl.fields[i];
        if (field != NULL && field->type == AST_VAR_DECL) {
            if (field->data.var_decl.name != NULL && 
                strcmp(field->data.var_decl.name, field_name) == 0) {
                return i;  // 找到字段，返回索引
            }
        }
    }
    
    return -1;  // 未找到
}

// 查找结构体字段 AST 类型
ASTNode *find_struct_field_ast_type(CodeGenerator *codegen, ASTNode *struct_decl, const char *field_name) {
    if (!codegen || !struct_decl || struct_decl->type != AST_STRUCT_DECL || !field_name) {
        return NULL;
    }
    
    for (int i = 0; i < struct_decl->data.struct_decl.field_count; i++) {
        ASTNode *field = struct_decl->data.struct_decl.fields[i];
        if (field != NULL && field->type == AST_VAR_DECL) {
            if (field->data.var_decl.name != NULL && 
                strcmp(field->data.var_decl.name, field_name) == 0) {
                return field->data.var_decl.type;  // 返回字段的类型节点
            }
        }
    }
    
    return NULL;  // 未找到
}

