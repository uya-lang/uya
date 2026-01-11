#include "codegen.h"
#include "lexer.h"
#include <string.h>
#include <llvm-c/TargetMachine.h>
#include <stdio.h>

// 创建代码生成器
// 参数：codegen - CodeGenerator 结构体指针（由调用者分配）
//       arena - Arena 分配器指针
//       module_name - 模块名称（字符串存储在 Arena 中）
// 返回：成功返回0，失败返回非0
int codegen_new(CodeGenerator *codegen, Arena *arena, const char *module_name) {
    if (!codegen || !arena || !module_name) {
        return -1;
    }
    
    // 初始化结构体
    memset(codegen, 0, sizeof(CodeGenerator));
    
    // 设置 Arena 分配器
    codegen->arena = arena;
    
    // 复制模块名称到 Arena
    size_t name_len = strlen(module_name);
    char *name_copy = (char *)arena_alloc(arena, name_len + 1);
    if (!name_copy) {
        return -1;
    }
    memcpy(name_copy, module_name, name_len + 1);
    codegen->module_name = name_copy;
    
    // 创建 LLVM 上下文
    codegen->context = LLVMContextCreate();
    if (!codegen->context) {
        return -1;
    }
    
    // 创建 LLVM 模块
    codegen->module = LLVMModuleCreateWithNameInContext(codegen->module_name, codegen->context);
    if (!codegen->module) {
        LLVMContextDispose(codegen->context);
        return -1;
    }
    
    // 创建 IR 构建器
    codegen->builder = LLVMCreateBuilderInContext(codegen->context);
    if (!codegen->builder) {
        LLVMDisposeModule(codegen->module);
        LLVMContextDispose(codegen->context);
        return -1;
    }
    
    // 初始化结构体类型映射表
    codegen->struct_type_count = 0;
    
    // 初始化变量表和函数表
    codegen->var_map_count = 0;
    codegen->func_map_count = 0;
    codegen->program_node = NULL;
    
    return 0;
}

// 获取基础类型的LLVM类型
// 参数：codegen - 代码生成器指针
//       type_kind - 类型种类（TypeKind枚举：TYPE_I32, TYPE_BOOL, TYPE_VOID）
// 返回：LLVM类型引用，失败返回NULL
// 注意：此函数仅支持基础类型，结构体类型需要使用其他函数
LLVMTypeRef codegen_get_base_type(CodeGenerator *codegen, TypeKind type_kind) {
    if (!codegen || !codegen->context) {
        return NULL;
    }
    
    switch (type_kind) {
        case TYPE_I32:
            // i32 类型映射到 LLVM Int32 类型（全局类型，不依赖context）
            return LLVMInt32Type();
            
        case TYPE_BOOL:
            // bool 类型映射到 LLVM Int1 类型（1位整数，更精确，全局类型）
            return LLVMInt1Type();
            
        case TYPE_VOID:
            // void 类型映射到 LLVM Void 类型（全局类型）
            return LLVMVoidType();
            
        case TYPE_STRUCT:
            // 结构体类型不能使用此函数，应使用其他函数
            return NULL;
            
        default:
            return NULL;
    }
}

// 辅助函数：从AST类型节点获取LLVM类型（仅支持基础类型和已注册的结构体类型）
// 参数：codegen - 代码生成器指针
//       type_node - AST类型节点（AST_TYPE_NAMED）
// 返回：LLVM类型引用，失败返回NULL
static LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node) {
    if (!codegen || !type_node || type_node->type != AST_TYPE_NAMED) {
        return NULL;
    }
    
    const char *type_name = type_node->data.type_named.name;
    if (!type_name) {
        return NULL;
    }
    
    // 基础类型
    if (strcmp(type_name, "i32") == 0) {
        return codegen_get_base_type(codegen, TYPE_I32);
    } else if (strcmp(type_name, "bool") == 0) {
        return codegen_get_base_type(codegen, TYPE_BOOL);
    } else if (strcmp(type_name, "void") == 0) {
        return codegen_get_base_type(codegen, TYPE_VOID);
    }
    
    // 结构体类型（必须在注册表中查找）
    return codegen_get_struct_type(codegen, type_name);
}

// 获取结构体类型的LLVM类型
// 参数：codegen - 代码生成器指针
//       struct_name - 结构体名称
// 返回：LLVM类型引用，未找到返回NULL
LLVMTypeRef codegen_get_struct_type(CodeGenerator *codegen, const char *struct_name) {
    if (!codegen || !struct_name) {
        return NULL;
    }
    
    // 在结构体类型映射表中线性查找
    for (int i = 0; i < codegen->struct_type_count; i++) {
        if (codegen->struct_types[i].name != NULL && 
            strcmp(codegen->struct_types[i].name, struct_name) == 0) {
            return codegen->struct_types[i].llvm_type;
        }
    }
    
    return NULL;  // 未找到
}

// 注册结构体类型（从AST结构体声明创建LLVM结构体类型并注册）
// 参数：codegen - 代码生成器指针
//       struct_decl - AST结构体声明节点
// 返回：成功返回0，失败返回非0
// 注意：如果结构体类型已注册，会返回成功（不重复注册）
int codegen_register_struct_type(CodeGenerator *codegen, ASTNode *struct_decl) {
    if (!codegen || !struct_decl || struct_decl->type != AST_STRUCT_DECL) {
        return -1;
    }
    
    const char *struct_name = struct_decl->data.struct_decl.name;
    if (!struct_name) {
        return -1;
    }
    
    // 检查是否已经注册
    if (codegen_get_struct_type(codegen, struct_name) != NULL) {
        return 0;  // 已注册，返回成功
    }
    
    // 检查映射表是否已满
    if (codegen->struct_type_count >= 64) {
        return -1;  // 映射表已满
    }
    
    int field_count = struct_decl->data.struct_decl.field_count;
    if (field_count < 0) {
        return -1;
    }
    
    // 准备字段类型数组
    LLVMTypeRef *field_types = NULL;
    if (field_count > 0) {
        // 使用固定大小数组（栈分配，无堆分配）
        // 注意：最多支持16个字段（如果超过需要调整）
        if (field_count > 16) {
            return -1;  // 字段数过多
        }
        LLVMTypeRef field_types_array[16];
        field_types = field_types_array;
        
        // 遍历字段，获取每个字段的LLVM类型
        for (int i = 0; i < field_count; i++) {
            ASTNode *field = struct_decl->data.struct_decl.fields[i];
            if (!field || field->type != AST_VAR_DECL) {
                return -1;
            }
            
            ASTNode *field_type_node = field->data.var_decl.type;
            LLVMTypeRef field_llvm_type = get_llvm_type_from_ast(codegen, field_type_node);
            if (!field_llvm_type) {
                return -1;  // 字段类型无效或未找到（结构体类型需要先注册）
            }
            
            field_types[i] = field_llvm_type;
        }
    }
    
    // 创建LLVM结构体类型
    LLVMTypeRef struct_type;
    if (field_count == 0) {
        // 空结构体
        struct_type = LLVMStructTypeInContext(codegen->context, NULL, 0, 0);
    } else {
        // 非空结构体（packed=0，使用默认对齐）
        struct_type = LLVMStructTypeInContext(codegen->context, field_types, field_count, 0);
    }
    
    if (!struct_type) {
        return -1;
    }
    
    // 注册到映射表
    // 复制结构体名称到Arena（如果需要，但通常名称已经在Arena中）
    int idx = codegen->struct_type_count;
    codegen->struct_types[idx].name = struct_name;  // 名称已经在Arena中
    codegen->struct_types[idx].llvm_type = struct_type;
    codegen->struct_type_count++;
    
    return 0;
}

// 辅助函数：在变量表中查找变量
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：LLVM值引用（变量指针），未找到返回NULL
static LLVMValueRef lookup_var(CodeGenerator *codegen, const char *var_name) {
    if (!codegen || !var_name) {
        return NULL;
    }
    
    // 线性查找（从后向前查找，由于禁止变量遮蔽，理论上只需要查找最后一个匹配项）
    for (int i = codegen->var_map_count - 1; i >= 0; i--) {
        if (codegen->var_map[i].name != NULL && 
            strcmp(codegen->var_map[i].name, var_name) == 0) {
            return codegen->var_map[i].value;
        }
    }
    
    return NULL;  // 未找到
}

// 辅助函数：在变量表中查找变量类型
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：LLVM类型引用，未找到返回NULL
static LLVMTypeRef lookup_var_type(CodeGenerator *codegen, const char *var_name) {
    if (!codegen || !var_name) {
        return NULL;
    }
    
    // 线性查找（从后向前查找，由于禁止变量遮蔽，理论上只需要查找最后一个匹配项）
    for (int i = codegen->var_map_count - 1; i >= 0; i--) {
        if (codegen->var_map[i].name != NULL && 
            strcmp(codegen->var_map[i].name, var_name) == 0) {
            return codegen->var_map[i].type;
        }
    }
    
    return NULL;  // 未找到
}

// 辅助函数：在变量表中添加变量
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称（存储在 Arena 中）
//       value - LLVM值（变量指针）
//       type - 变量类型（用于 LLVMBuildLoad2）
//       struct_name - 结构体名称（仅当类型是结构体类型时有效，存储在 Arena 中，可为 NULL）
// 返回：成功返回0，失败返回非0
static int add_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef value, LLVMTypeRef type, const char *struct_name) {
    if (!codegen || !var_name || !value || !type) {
        return -1;
    }
    
    // 检查映射表是否已满
    if (codegen->var_map_count >= 256) {
        return -1;  // 映射表已满
    }
    
    // 添加到映射表
    int idx = codegen->var_map_count;
    codegen->var_map[idx].name = var_name;
    codegen->var_map[idx].value = value;
    codegen->var_map[idx].type = type;
    codegen->var_map[idx].struct_name = struct_name;  // 结构体名称（可为 NULL）
    codegen->var_map_count++;
    
    return 0;
}

// 辅助函数：在变量表中查找变量结构体名称
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：结构体名称（如果变量是结构体类型），未找到返回 NULL
static const char *lookup_var_struct_name(CodeGenerator *codegen, const char *var_name) {
    if (!codegen || !var_name) {
        return NULL;
    }
    
    // 线性查找（从后向前查找，由于禁止变量遮蔽，理论上只需要查找最后一个匹配项）
    for (int i = codegen->var_map_count - 1; i >= 0; i--) {
        if (codegen->var_map[i].name != NULL && 
            strcmp(codegen->var_map[i].name, var_name) == 0) {
            return codegen->var_map[i].struct_name;
        }
    }
    
    return NULL;  // 未找到
}

// 辅助函数：在函数表中查找函数
// 参数：codegen - 代码生成器指针
//       func_name - 函数名称
// 返回：LLVM函数值，未找到返回NULL
static LLVMValueRef lookup_func(CodeGenerator *codegen, const char *func_name) {
    if (!codegen || !func_name) {
        return NULL;
    }
    
    // 线性查找
    for (int i = 0; i < codegen->func_map_count; i++) {
        if (codegen->func_map[i].name != NULL && 
            strcmp(codegen->func_map[i].name, func_name) == 0) {
            return codegen->func_map[i].func;
        }
    }
    
    return NULL;  // 未找到
}

// 辅助函数：从程序节点中查找结构体声明
// 参数：codegen - 代码生成器指针
//       struct_name - 结构体名称
// 返回：找到的结构体声明节点指针，未找到返回 NULL
static ASTNode *find_struct_decl(CodeGenerator *codegen, const char *struct_name) {
    if (!codegen || !codegen->program_node || !struct_name) {
        return NULL;
    }
    
    ASTNode *program = codegen->program_node;
    if (program->type != AST_PROGRAM) {
        return NULL;
    }
    
    for (int i = 0; i < program->data.program.decl_count; i++) {
        ASTNode *decl = program->data.program.decls[i];
        if (decl != NULL && decl->type == AST_STRUCT_DECL) {
            if (decl->data.struct_decl.name != NULL && 
                strcmp(decl->data.struct_decl.name, struct_name) == 0) {
                return decl;
            }
        }
    }
    
    return NULL;
}

// 辅助函数：在结构体声明中查找字段索引
// 参数：struct_decl - 结构体声明节点
//       field_name - 字段名称
// 返回：字段索引（>= 0），未找到返回 -1
static int find_struct_field_index(ASTNode *struct_decl, const char *field_name) {
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

// 辅助函数：在函数表中添加函数
// 参数：codegen - 代码生成器指针
//       func_name - 函数名称（存储在 Arena 中）
//       func - LLVM函数值
// 返回：成功返回0，失败返回非0
static int add_func(CodeGenerator *codegen, const char *func_name, LLVMValueRef func) {
    if (!codegen || !func_name || !func) {
        return -1;
    }
    
    // 检查映射表是否已满
    if (codegen->func_map_count >= 64) {
        return -1;  // 映射表已满
    }
    
    // 添加到映射表
    int idx = codegen->func_map_count;
    codegen->func_map[idx].name = func_name;
    codegen->func_map[idx].func = func;
    codegen->func_map_count++;
    
    return 0;
}

// 生成表达式代码（从表达式AST节点生成LLVM值）
// 参数：codegen - 代码生成器指针
//       expr - 表达式AST节点
// 返回：LLVM值引用（LLVMValueRef），失败返回NULL
// 注意：此函数需要在函数上下文中调用（builder需要在函数的基本块中）
//       标识符和函数调用使用变量表和函数表查找
LLVMValueRef codegen_gen_expr(CodeGenerator *codegen, ASTNode *expr) {
    if (!codegen || !expr || !codegen->builder) {
        return NULL;
    }
    
    switch (expr->type) {
        case AST_NUMBER: {
            // 数字字面量：创建 i32 常量
            int value = expr->data.number.value;
            LLVMTypeRef i32_type = codegen_get_base_type(codegen, TYPE_I32);
            if (!i32_type) {
                return NULL;
            }
            return LLVMConstInt(i32_type, (unsigned long long)value, 1);  // 1 表示有符号
        }
        
        case AST_BOOL: {
            // 布尔字面量：创建 i1 常量（true=1, false=0）
            int value = expr->data.bool_literal.value;
            LLVMTypeRef bool_type = codegen_get_base_type(codegen, TYPE_BOOL);
            if (!bool_type) {
                return NULL;
            }
            return LLVMConstInt(bool_type, value ? 1ULL : 0ULL, 0);  // 0 表示无符号（布尔值）
        }
        
        case AST_UNARY_EXPR: {
            // 一元表达式（! 和 -）
            ASTNode *operand = expr->data.unary_expr.operand;
            if (!operand) {
                return NULL;
            }
            
            LLVMValueRef operand_val = codegen_gen_expr(codegen, operand);
            if (!operand_val) {
                return NULL;
            }
            
            int op = expr->data.unary_expr.op;
            
            // 根据运算符类型生成对应的LLVM指令
            // 注意：需要知道操作数的类型，这里暂时假设可以从operand_val推断
            // TODO: 从类型检查信息获取操作数类型，或从LLVM值获取类型
            
            // 简化实现：假设操作数类型可以从operand_val获取
            LLVMTypeRef operand_type = LLVMTypeOf(operand_val);
            
            if (op == TOKEN_EXCLAMATION) {
                // 逻辑非：!operand
                // 对于布尔值（i1），使用 XOR 1
                if (LLVMGetTypeKind(operand_type) == LLVMIntegerTypeKind) {
                    LLVMValueRef one = LLVMConstInt(operand_type, 1ULL, 0);
                    return LLVMBuildXor(codegen->builder, operand_val, one, "");
                }
            } else if (op == TOKEN_MINUS) {
                // 一元负号：-operand
                // 对于整数，使用 sub 0, operand
                if (LLVMGetTypeKind(operand_type) == LLVMIntegerTypeKind) {
                    LLVMValueRef zero = LLVMConstInt(operand_type, 0ULL, 1);
                    return LLVMBuildSub(codegen->builder, zero, operand_val, "");
                }
            }
            
            return NULL;
        }
        
        case AST_BINARY_EXPR: {
            // 二元表达式（算术、比较、逻辑运算符）
            ASTNode *left = expr->data.binary_expr.left;
            ASTNode *right = expr->data.binary_expr.right;
            if (!left || !right) {
                return NULL;
            }
            
            LLVMValueRef left_val = codegen_gen_expr(codegen, left);
            LLVMValueRef right_val = codegen_gen_expr(codegen, right);
            if (!left_val || !right_val) {
                return NULL;
            }
            
            int op = expr->data.binary_expr.op;
            
            // 获取操作数类型
            LLVMTypeRef left_type = LLVMTypeOf(left_val);
            LLVMTypeRef right_type = LLVMTypeOf(right_val);
            
            // 简化：假设左右操作数类型相同（类型检查应该已经保证）
            
            // 算术运算符（i32）
            if (LLVMGetTypeKind(left_type) == LLVMIntegerTypeKind && 
                LLVMGetTypeKind(right_type) == LLVMIntegerTypeKind) {
                
                if (op == TOKEN_PLUS) {
                    return LLVMBuildAdd(codegen->builder, left_val, right_val, "");
                } else if (op == TOKEN_MINUS) {
                    return LLVMBuildSub(codegen->builder, left_val, right_val, "");
                } else if (op == TOKEN_ASTERISK) {
                    return LLVMBuildMul(codegen->builder, left_val, right_val, "");
                } else if (op == TOKEN_SLASH) {
                    return LLVMBuildSDiv(codegen->builder, left_val, right_val, "");  // 有符号除法
                } else if (op == TOKEN_PERCENT) {
                    return LLVMBuildSRem(codegen->builder, left_val, right_val, "");  // 有符号取模
                }
                
                // 比较运算符（返回 i1）
                LLVMTypeRef bool_type = codegen_get_base_type(codegen, TYPE_BOOL);
                if (!bool_type) {
                    return NULL;
                }
                
                if (op == TOKEN_EQUAL) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntEQ, left_val, right_val, "");
                } else if (op == TOKEN_NOT_EQUAL) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntNE, left_val, right_val, "");
                } else if (op == TOKEN_LESS) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntSLT, left_val, right_val, "");
                } else if (op == TOKEN_LESS_EQUAL) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntSLE, left_val, right_val, "");
                } else if (op == TOKEN_GREATER) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntSGT, left_val, right_val, "");
                } else if (op == TOKEN_GREATER_EQUAL) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntSGE, left_val, right_val, "");
                }
            }
            
            // 逻辑运算符（布尔值，i1）
            // 简化实现：对于逻辑运算符，假设操作数是布尔类型（i1）
            // 实际实现中，应该从类型检查信息获取操作数类型
            if (op == TOKEN_LOGICAL_AND) {
                // 逻辑与：对于 i1 类型，使用 AND
                // 简化：假设操作数是布尔类型
                return LLVMBuildAnd(codegen->builder, left_val, right_val, "");
            } else if (op == TOKEN_LOGICAL_OR) {
                // 逻辑或：对于 i1 类型，使用 OR
                return LLVMBuildOr(codegen->builder, left_val, right_val, "");
            }
            
            return NULL;
        }
        
        case AST_IDENTIFIER: {
            // 标识符：从变量表查找变量，然后加载值
            const char *var_name = expr->data.identifier.name;
            if (!var_name) {
                return NULL;
            }
            
            // 查找变量
            LLVMValueRef var_ptr = lookup_var(codegen, var_name);
            if (!var_ptr) {
                return NULL;  // 变量未找到
            }
            
            // 使用 LLVMBuildLoad2 加载变量值（LLVM 18 使用新 API）
            // 从变量表查找变量类型
            LLVMTypeRef var_type = lookup_var_type(codegen, var_name);
            if (!var_type) {
                return NULL;
            }
            return LLVMBuildLoad2(codegen->builder, var_type, var_ptr, var_name);
        }
            
        case AST_CALL_EXPR: {
            // 函数调用：从函数表查找函数，然后调用
            ASTNode *callee = expr->data.call_expr.callee;
            if (!callee || callee->type != AST_IDENTIFIER) {
                return NULL;
            }
            
            const char *func_name = callee->data.identifier.name;
            if (!func_name) {
                return NULL;
            }
            
            // 查找函数
            LLVMValueRef func = lookup_func(codegen, func_name);
            if (!func) {
                return NULL;  // 函数未找到
            }
            
            // 生成参数值
            int arg_count = expr->data.call_expr.arg_count;
            if (arg_count > 16) {
                return NULL;  // 参数过多（限制为16个）
            }
            
            LLVMValueRef args[16];
            for (int i = 0; i < arg_count; i++) {
                ASTNode *arg_expr = expr->data.call_expr.args[i];
                if (!arg_expr) {
                    return NULL;
                }
                args[i] = codegen_gen_expr(codegen, arg_expr);
                if (!args[i]) {
                    return NULL;
                }
            }
            
            // 调用函数（LLVM 18 使用 LLVMBuildCall2）
            // 获取函数类型（LLVMTypeOf 返回函数签名类型）
            LLVMTypeRef func_type = LLVMTypeOf(func);
            if (!func_type) {
                return NULL;
            }
            return LLVMBuildCall2(codegen->builder, func_type, func, args, arg_count, "");
        }
            
        case AST_MEMBER_ACCESS: {
            // 字段访问：使用 GEP + Load 获取字段值
            ASTNode *object = expr->data.member_access.object;
            const char *field_name = expr->data.member_access.field_name;
            
            if (!object || !field_name) {
                return NULL;
            }
            
            // 如果对象是标识符（变量），从变量表获取结构体名称
            const char *struct_name = NULL;
            LLVMValueRef object_ptr = NULL;
            
            if (object->type == AST_IDENTIFIER) {
                const char *var_name = object->data.identifier.name;
                if (var_name) {
                    object_ptr = lookup_var(codegen, var_name);
                    struct_name = lookup_var_struct_name(codegen, var_name);
                }
            }
            
            if (!object_ptr) {
                // 对象不是标识符或变量未找到，生成对象表达式
                LLVMValueRef object_val = codegen_gen_expr(codegen, object);
                if (!object_val) {
                    return NULL;
                }
                
                // 对于非标识符对象（如结构体字面量），需要先 store 到临时变量
                // 获取对象类型
                LLVMTypeRef object_type = LLVMTypeOf(object_val);
                if (!object_type) {
                    return NULL;
                }
                
                // 使用 alloca 分配临时空间
                object_ptr = LLVMBuildAlloca(codegen->builder, object_type, "");
                if (!object_ptr) {
                    return NULL;
                }
                
                // store 对象值到临时变量
                LLVMBuildStore(codegen->builder, object_val, object_ptr);
                
                // 对于结构体字面量，可以从 AST 获取结构体名称
                if (object->type == AST_STRUCT_INIT) {
                    struct_name = object->data.struct_init.struct_name;
                }
            }
            
            if (!struct_name) {
                return NULL;  // 无法确定结构体名称
            }
            
            // 查找结构体声明
            ASTNode *struct_decl = find_struct_decl(codegen, struct_name);
            if (!struct_decl) {
                return NULL;
            }
            
            // 查找字段索引
            int field_index = find_struct_field_index(struct_decl, field_name);
            if (field_index < 0) {
                return NULL;  // 字段不存在
            }
            
            // 获取结构体类型
            LLVMTypeRef struct_type = codegen_get_struct_type(codegen, struct_name);
            if (!struct_type) {
                return NULL;
            }
            
            // 使用 GEP 获取字段地址
            LLVMValueRef indices[2];
            indices[0] = LLVMConstInt(LLVMInt32TypeInContext(codegen->context), 0ULL, 0);  // 结构体指针本身
            indices[1] = LLVMConstInt(LLVMInt32TypeInContext(codegen->context), (unsigned long long)field_index, 0);  // 字段索引
            
            LLVMValueRef field_ptr = LLVMBuildGEP2(codegen->builder, struct_type, object_ptr, indices, 2, "");
            if (!field_ptr) {
                return NULL;
            }
            
            // 获取字段类型（从结构体声明中）
            if (field_index >= struct_decl->data.struct_decl.field_count) {
                return NULL;
            }
            ASTNode *field = struct_decl->data.struct_decl.fields[field_index];
            if (!field || field->type != AST_VAR_DECL) {
                return NULL;
            }
            ASTNode *field_type_node = field->data.var_decl.type;
            LLVMTypeRef field_type = get_llvm_type_from_ast(codegen, field_type_node);
            if (!field_type) {
                return NULL;
            }
            
            // load 字段值
            return LLVMBuildLoad2(codegen->builder, field_type, field_ptr, "");
        }
            
        case AST_STRUCT_INIT: {
            // 结构体字面量：使用 alloca + store 创建结构体值
            const char *struct_name = expr->data.struct_init.struct_name;
            int field_count = expr->data.struct_init.field_count;
            const char **field_names = expr->data.struct_init.field_names;
            ASTNode **field_values = expr->data.struct_init.field_values;
            
            if (!struct_name) {
                return NULL;
            }
            
            // 获取结构体类型
            LLVMTypeRef struct_type = codegen_get_struct_type(codegen, struct_name);
            if (!struct_type) {
                return NULL;
            }
            
            // 查找结构体声明（用于字段索引映射）
            ASTNode *struct_decl = find_struct_decl(codegen, struct_name);
            if (!struct_decl) {
                return NULL;
            }
            
            // 使用 alloca 分配栈空间
            LLVMValueRef struct_ptr = LLVMBuildAlloca(codegen->builder, struct_type, "");
            if (!struct_ptr) {
                return NULL;
            }
            
            // 生成每个字段的值并 store 到结构体中
            // 注意：字段值需要按照结构体声明中的字段顺序存储
            // 但 AST_STRUCT_INIT 中的字段可能是任意顺序的（使用字段名称）
            // 所以我们需要根据字段名称找到字段索引
            
            if (field_count > 16) {
                return NULL;  // 字段数过多
            }
            
            // 为每个字段生成值并 store
            // 使用 GEP (GetElementPtr) 获取每个字段的地址，然后 store 字段值
            for (int i = 0; i < field_count; i++) {
                const char *field_name = field_names[i];
                ASTNode *field_value = field_values[i];
                
                if (!field_name || !field_value) {
                    return NULL;
                }
                
                // 查找字段索引
                int field_index = find_struct_field_index(struct_decl, field_name);
                if (field_index < 0) {
                    return NULL;  // 字段不存在
                }
                
                // 生成字段值
                LLVMValueRef field_val = codegen_gen_expr(codegen, field_value);
                if (!field_val) {
                    return NULL;
                }
                
                // 使用 GEP 获取字段地址（字段索引是 unsigned int）
                LLVMValueRef indices[2];
                indices[0] = LLVMConstInt(LLVMInt32TypeInContext(codegen->context), 0ULL, 0);  // 结构体指针本身
                indices[1] = LLVMConstInt(LLVMInt32TypeInContext(codegen->context), (unsigned long long)field_index, 0);  // 字段索引
                
                LLVMValueRef field_ptr = LLVMBuildGEP2(codegen->builder, struct_type, struct_ptr, indices, 2, "");
                if (!field_ptr) {
                    return NULL;
                }
                
                // store 字段值到字段地址
                LLVMBuildStore(codegen->builder, field_val, field_ptr);
            }
            
            // 返回结构体值（load 结构体指针）
            return LLVMBuildLoad2(codegen->builder, struct_type, struct_ptr, "");
        }
            
        default:
            return NULL;
    }
}

// 生成语句代码（从语句AST节点生成LLVM IR指令）
// 参数：codegen - 代码生成器指针
//       stmt - 语句AST节点
// 返回：成功返回0，失败返回非0
// 注意：此函数需要在函数上下文中调用（builder需要在函数的基本块中）
int codegen_gen_stmt(CodeGenerator *codegen, ASTNode *stmt) {
    if (!codegen || !stmt || !codegen->builder) {
        return -1;
    }
    
    switch (stmt->type) {
        case AST_VAR_DECL: {
            // 变量声明：使用 alloca 分配栈空间，如果有初始值则 store
            const char *var_name = stmt->data.var_decl.name;
            ASTNode *var_type = stmt->data.var_decl.type;
            ASTNode *init_expr = stmt->data.var_decl.init;
            
            if (!var_name || !var_type) {
                return -1;
            }
            
            // 获取变量类型
            LLVMTypeRef llvm_type = get_llvm_type_from_ast(codegen, var_type);
            if (!llvm_type) {
                return -1;
            }
            
            // 提取结构体名称（如果类型是结构体类型）
            const char *struct_name = NULL;
            if (var_type->type == AST_TYPE_NAMED) {
                const char *type_name = var_type->data.type_named.name;
                if (type_name && strcmp(type_name, "i32") != 0 && 
                    strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0) {
                    // 可能是结构体类型
                    if (codegen_get_struct_type(codegen, type_name) != NULL) {
                        struct_name = type_name;  // 名称已经在 Arena 中
                    }
                }
            }
            
            // 使用 alloca 分配栈空间
            LLVMValueRef var_ptr = LLVMBuildAlloca(codegen->builder, llvm_type, var_name);
            if (!var_ptr) {
                return -1;
            }
            
            // 添加到变量表
            if (add_var(codegen, var_name, var_ptr, llvm_type, struct_name) != 0) {
                return -1;
            }
            
            // 如果有初始值，生成初始值代码并 store
            if (init_expr) {
                LLVMValueRef init_val = codegen_gen_expr(codegen, init_expr);
                if (!init_val) {
                    return -1;
                }
                LLVMBuildStore(codegen->builder, init_val, var_ptr);
            }
            
            return 0;
        }
        
        case AST_RETURN_STMT: {
            // return 语句：生成返回值并返回（void函数返回NULL）
            ASTNode *return_expr = stmt->data.return_stmt.expr;
            
            if (return_expr) {
                // 有返回值：生成返回值表达式并返回
                LLVMValueRef return_val = codegen_gen_expr(codegen, return_expr);
                if (!return_val) {
                    return -1;
                }
                LLVMBuildRet(codegen->builder, return_val);
            } else {
                // void 返回
                LLVMBuildRetVoid(codegen->builder);
            }
            
            return 0;
        }
        
        case AST_ASSIGN: {
            // 赋值语句：生成源表达式值，store 到目标变量
            ASTNode *dest = stmt->data.assign.dest;
            ASTNode *src = stmt->data.assign.src;
            
            if (!dest || !src) {
                return -1;
            }
            
            // 目标必须是标识符
            if (dest->type != AST_IDENTIFIER) {
                return -1;  // 暂不支持其他类型的赋值目标
            }
            
            const char *var_name = dest->data.identifier.name;
            if (!var_name) {
                return -1;
            }
            
            // 查找变量
            LLVMValueRef var_ptr = lookup_var(codegen, var_name);
            if (!var_ptr) {
                return -1;  // 变量未找到
            }
            
            // 生成源表达式值
            LLVMValueRef src_val = codegen_gen_expr(codegen, src);
            if (!src_val) {
                return -1;
            }
            
            // store 值到变量
            LLVMBuildStore(codegen->builder, src_val, var_ptr);
            
            return 0;
        }
        
        case AST_EXPR_STMT: {
            // 表达式语句：根据 parser 实现，表达式语句直接返回表达式节点
            // 而不是 AST_EXPR_STMT 节点，所以这里不应该被执行
            // 但为了完整性，如果遇到这种情况，尝试将其当作表达式处理
            LLVMValueRef expr_val = codegen_gen_expr(codegen, stmt);
            // 忽略返回值（即使失败也返回0，因为表达式语句的返回值不重要）
            (void)expr_val;
            return 0;
        }
        
        case AST_BLOCK: {
            // 代码块：递归处理语句列表
            int stmt_count = stmt->data.block.stmt_count;
            ASTNode **stmts = stmt->data.block.stmts;
            
            for (int i = 0; i < stmt_count; i++) {
                if (!stmts[i]) {
                    continue;
                }
                if (codegen_gen_stmt(codegen, stmts[i]) != 0) {
                    return -1;
                }
            }
            
            return 0;
        }
        
        case AST_IF_STMT: {
            // if 语句：创建条件分支基本块
            ASTNode *condition = stmt->data.if_stmt.condition;
            ASTNode *then_branch = stmt->data.if_stmt.then_branch;
            ASTNode *else_branch = stmt->data.if_stmt.else_branch;
            
            if (!condition || !then_branch) {
                return -1;
            }
            
            // 生成条件表达式
            LLVMValueRef cond_val = codegen_gen_expr(codegen, condition);
            if (!cond_val) {
                return -1;
            }
            
            // 获取当前函数和基本块
            LLVMValueRef current_func = LLVMGetBasicBlockParent(LLVMGetInsertBlock(codegen->builder));
            if (!current_func) {
                return -1;
            }
            
            // 创建 then 基本块
            LLVMBasicBlockRef then_bb = LLVMAppendBasicBlock(current_func, "if.then");
            LLVMBasicBlockRef end_bb = LLVMAppendBasicBlock(current_func, "if.end");
            LLVMBasicBlockRef else_bb = NULL;
            if (else_branch) {
                else_bb = LLVMAppendBasicBlock(current_func, "if.else");
            }
            
            // 条件分支
            if (else_bb) {
                LLVMBuildCondBr(codegen->builder, cond_val, then_bb, else_bb);
            } else {
                LLVMBuildCondBr(codegen->builder, cond_val, then_bb, end_bb);
            }
            
            // 生成 then 分支
            LLVMPositionBuilderAtEnd(codegen->builder, then_bb);
            if (codegen_gen_stmt(codegen, then_branch) != 0) {
                return -1;
            }
            // then 分支结束前跳转到 end
            LLVMBuildBr(codegen->builder, end_bb);
            
            // 生成 else 分支（如果有）
            if (else_bb && else_branch) {
                LLVMPositionBuilderAtEnd(codegen->builder, else_bb);
                if (codegen_gen_stmt(codegen, else_branch) != 0) {
                    return -1;
                }
                // else 分支结束前跳转到 end
                LLVMBuildBr(codegen->builder, end_bb);
            }
            
            // 设置构建器到 end 基本块
            LLVMPositionBuilderAtEnd(codegen->builder, end_bb);
            
            return 0;
        }
        
        case AST_WHILE_STMT: {
            // while 语句：创建循环基本块
            ASTNode *condition = stmt->data.while_stmt.condition;
            ASTNode *body = stmt->data.while_stmt.body;
            
            if (!condition || !body) {
                return -1;
            }
            
            // 获取当前函数
            LLVMValueRef current_func = LLVMGetBasicBlockParent(LLVMGetInsertBlock(codegen->builder));
            if (!current_func) {
                return -1;
            }
            
            // 创建基本块：cond（条件检查）、body（循环体）、end（结束）
            LLVMBasicBlockRef cond_bb = LLVMAppendBasicBlock(current_func, "while.cond");
            LLVMBasicBlockRef body_bb = LLVMAppendBasicBlock(current_func, "while.body");
            LLVMBasicBlockRef end_bb = LLVMAppendBasicBlock(current_func, "while.end");
            
            // 跳转到条件检查
            LLVMBuildBr(codegen->builder, cond_bb);
            
            // 生成条件检查
            LLVMPositionBuilderAtEnd(codegen->builder, cond_bb);
            LLVMValueRef cond_val = codegen_gen_expr(codegen, condition);
            if (!cond_val) {
                return -1;
            }
            LLVMBuildCondBr(codegen->builder, cond_val, body_bb, end_bb);
            
            // 生成循环体
            LLVMPositionBuilderAtEnd(codegen->builder, body_bb);
            if (codegen_gen_stmt(codegen, body) != 0) {
                return -1;
            }
            // 循环体结束前跳转到条件检查
            LLVMBuildBr(codegen->builder, cond_bb);
            
            // 设置构建器到 end 基本块
            LLVMPositionBuilderAtEnd(codegen->builder, end_bb);
            
            return 0;
        }
        
        default: {
            // 未知语句类型，或者可能是表达式节点（表达式语句）
            // 根据 parser 实现，表达式语句直接返回表达式节点
            // 尝试将其当作表达式处理（忽略返回值）
            LLVMValueRef expr_val = codegen_gen_expr(codegen, stmt);
            // 忽略返回值（即使失败也返回0，因为表达式语句的返回值不重要）
            (void)expr_val;
            return 0;
        }
    }
}

// 生成函数代码（从函数声明AST节点生成LLVM函数）
// 参数：codegen - 代码生成器指针
//       fn_decl - 函数声明AST节点
// 返回：成功返回0，失败返回非0
int codegen_gen_function(CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!codegen || !fn_decl || fn_decl->type != AST_FN_DECL) {
        return -1;
    }
    
    const char *func_name = fn_decl->data.fn_decl.name;
    ASTNode *return_type_node = fn_decl->data.fn_decl.return_type;
    ASTNode *body = fn_decl->data.fn_decl.body;
    int param_count = fn_decl->data.fn_decl.param_count;
    ASTNode **params = fn_decl->data.fn_decl.params;
    
    if (!func_name || !return_type_node || !body) {
        return -1;
    }
    
    // 获取返回类型
    LLVMTypeRef return_type = get_llvm_type_from_ast(codegen, return_type_node);
    if (!return_type) {
        return -1;
    }
    
    // 准备参数类型数组
    LLVMTypeRef *param_types = NULL;
    if (param_count > 0) {
        // 使用固定大小数组（栈分配，无堆分配）
        // 注意：最多支持16个参数（如果超过需要调整）
        if (param_count > 16) {
            return -1;  // 参数过多
        }
        LLVMTypeRef param_types_array[16];
        param_types = param_types_array;
        
        // 遍历参数，获取每个参数的类型
        for (int i = 0; i < param_count; i++) {
            ASTNode *param = params[i];
            if (!param || param->type != AST_VAR_DECL) {
                return -1;
            }
            
            ASTNode *param_type_node = param->data.var_decl.type;
            LLVMTypeRef param_type = get_llvm_type_from_ast(codegen, param_type_node);
            if (!param_type) {
                return -1;
            }
            
            param_types[i] = param_type;
        }
    }
    
    // 创建函数类型
    LLVMTypeRef func_type = LLVMFunctionType(return_type, param_types, param_count, 0);
    if (!func_type) {
        return -1;
    }
    
    // 添加函数到模块
    LLVMValueRef func = LLVMAddFunction(codegen->module, func_name, func_type);
    if (!func) {
        return -1;
    }
    
    // 添加到函数表
    if (add_func(codegen, func_name, func) != 0) {
        return -1;
    }
    
    // 创建函数体的基本块
    LLVMBasicBlockRef entry_bb = LLVMAppendBasicBlock(func, "entry");
    if (!entry_bb) {
        return -1;
    }
    
    // 设置构建器位置到入口基本块
    LLVMPositionBuilderAtEnd(codegen->builder, entry_bb);
    
    // 保存当前变量表状态（用于函数结束后恢复）
    int saved_var_map_count = codegen->var_map_count;
    
    // 处理函数参数：将参数值 store 到 alloca 分配的栈变量
    for (int i = 0; i < param_count; i++) {
        ASTNode *param = params[i];
        if (!param || param->type != AST_VAR_DECL) {
            return -1;
        }
        
        const char *param_name = param->data.var_decl.name;
        ASTNode *param_type_node = param->data.var_decl.type;
        if (!param_name || !param_type_node) {
            return -1;
        }
        
        // 获取参数类型
        LLVMTypeRef param_type = get_llvm_type_from_ast(codegen, param_type_node);
        if (!param_type) {
            return -1;
        }
        
        // 提取结构体名称（如果类型是结构体类型）
        const char *struct_name = NULL;
        if (param_type_node->type == AST_TYPE_NAMED) {
            const char *type_name = param_type_node->data.type_named.name;
            if (type_name && strcmp(type_name, "i32") != 0 && 
                strcmp(type_name, "bool") != 0 && strcmp(type_name, "void") != 0) {
                // 可能是结构体类型
                if (codegen_get_struct_type(codegen, type_name) != NULL) {
                    struct_name = type_name;  // 名称已经在 Arena 中
                }
            }
        }
        
        // 使用 alloca 分配栈空间（存储参数值）
        LLVMValueRef param_ptr = LLVMBuildAlloca(codegen->builder, param_type, param_name);
        if (!param_ptr) {
            return -1;
        }
        
        // 获取函数参数值（LLVMGetParam）
        LLVMValueRef param_val = LLVMGetParam(func, i);
        if (!param_val) {
            return -1;
        }
        
        // store 参数值到栈变量
        LLVMBuildStore(codegen->builder, param_val, param_ptr);
        
        // 添加到变量表
        if (add_var(codegen, param_name, param_ptr, param_type, struct_name) != 0) {
            return -1;
        }
    }
    
    // 生成函数体代码
    if (codegen_gen_stmt(codegen, body) != 0) {
        // 恢复变量表状态（如果失败）
        codegen->var_map_count = saved_var_map_count;
        return -1;
    }
    
    // 检查函数是否已经有返回语句
    // 如果当前基本块没有终止符（return），需要添加默认返回
    LLVMBasicBlockRef current_bb = LLVMGetInsertBlock(codegen->builder);
    if (current_bb) {
        LLVMValueRef terminator = LLVMGetBasicBlockTerminator(current_bb);
        if (!terminator) {
            // 没有终止符，添加默认返回
            if (LLVMGetTypeKind(return_type) == LLVMVoidTypeKind) {
                // void 返回
                LLVMBuildRetVoid(codegen->builder);
            } else {
                // 非 void 返回，生成默认返回值（0）
                // 注意：这应该不会发生，因为类型检查应该确保所有非 void 函数都有返回值
                // 但为了安全，我们生成一个默认值
                LLVMValueRef default_val = NULL;
                if (LLVMGetTypeKind(return_type) == LLVMIntegerTypeKind) {
                    default_val = LLVMConstInt(return_type, 0ULL, 0);
                }
                if (default_val) {
                    LLVMBuildRet(codegen->builder, default_val);
                } else {
                    return -1;  // 无法生成默认返回值
                }
            }
        }
    }
    
    // 恢复变量表状态（函数结束）
    codegen->var_map_count = saved_var_map_count;
    
    return 0;
}

// 从AST生成代码
// 参数：codegen - 代码生成器指针
//       ast - AST 根节点（程序节点）
//       output_file - 输出文件路径
// 返回：成功返回0，失败返回非0
int codegen_generate(CodeGenerator *codegen, ASTNode *ast, const char *output_file) {
    if (!codegen || !ast || !output_file) {
        return -1;
    }
    
    // 检查是否是程序节点
    if (ast->type != AST_PROGRAM) {
        return -1;
    }
    
    // 保存程序节点（用于查找结构体声明）
    codegen->program_node = ast;
    
    int decl_count = ast->data.program.decl_count;
    ASTNode **decls = ast->data.program.decls;
    
    if (!decls && decl_count > 0) {
        return -1;
    }
    
    // 第一步：注册所有结构体类型
    // 使用多次遍历的方式处理结构体依赖关系（如果结构体字段是其他结构体类型）
    // 每次遍历注册所有可以注册的结构体，直到所有结构体都注册或无法继续注册
    int max_iterations = decl_count + 1;  // 最多迭代 decl_count + 1 次
    int iteration = 0;
    
    while (iteration < max_iterations) {
        int registered_this_iteration = 0;
        
        // 遍历所有声明，尝试注册结构体类型
        for (int i = 0; i < decl_count; i++) {
            ASTNode *decl = decls[i];
            if (!decl) {
                continue;
            }
            
            if (decl->type == AST_STRUCT_DECL) {
                // 尝试注册结构体类型（如果已经注册，会返回成功）
                if (codegen_register_struct_type(codegen, decl) == 0) {
                    registered_this_iteration = 1;
                }
            }
        }
        
        // 如果这一轮没有注册任何结构体，说明所有可以注册的结构体都已注册
        if (!registered_this_iteration) {
            break;
        }
        
        iteration++;
    }
    
    // 第二步：生成所有函数的代码
    // 注意：函数代码生成需要在结构体类型注册之后，因为函数参数/返回值可能使用结构体类型
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) {
            continue;
        }
        
        if (decl->type == AST_FN_DECL) {
            // 生成函数代码
            if (codegen_gen_function(codegen, decl) != 0) {
                return -1;  // 函数代码生成失败
            }
        }
    }
    
    // 第三步：生成目标代码
    // 初始化LLVM目标（只需要初始化一次，但重复初始化是安全的）
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();
    LLVMInitializeNativeAsmParser();
    
    // 获取默认目标三元组（例如："x86_64-pc-linux-gnu"）
    char *target_triple = LLVMGetDefaultTargetTriple();
    if (!target_triple) {
        return -1;
    }
    
    // 查找目标
    char *error_msg = NULL;
    LLVMTargetRef target = NULL;
    if (LLVMGetTargetFromTriple(target_triple, &target, &error_msg) != 0) {
        // 错误处理：释放错误消息
        if (error_msg) {
            LLVMDisposeMessage(error_msg);
        }
        LLVMDisposeMessage(target_triple);
        return -1;
    }
    
    // 创建目标机器（使用默认的CPU和特性）
    // 优化级别：0 = 无优化，1 = 少量优化，2 = 默认优化，3 = 激进优化
    LLVMCodeGenOptLevel opt_level = LLVMCodeGenLevelDefault;
    LLVMRelocMode reloc_mode = LLVMRelocDefault;
    LLVMCodeModel code_model = LLVMCodeModelDefault;
    
    LLVMTargetMachineRef target_machine = LLVMCreateTargetMachine(
        target,
        target_triple,
        "",  // CPU（空字符串表示默认）
        "",  // Features（空字符串表示默认）
        opt_level,
        reloc_mode,
        code_model
    );
    
    if (!target_machine) {
        LLVMDisposeMessage(target_triple);
        return -1;
    }
    
    // 配置模块的目标数据布局
    LLVMSetTarget(codegen->module, target_triple);
    LLVMTargetDataRef target_data = LLVMCreateTargetDataLayout(target_machine);
    if (target_data) {
        // LLVM 18中，LLVMSetModuleDataLayout 直接接受 LLVMTargetDataRef 类型
        LLVMSetModuleDataLayout(codegen->module, target_data);
        LLVMDisposeTargetData(target_data);
    }
    
    // 生成目标代码到文件
    char *error = NULL;
    if (LLVMTargetMachineEmitToFile(target_machine, codegen->module, (char *)output_file,
                                     LLVMObjectFile, &error) != 0) {
        // 生成失败
        if (error) {
            // 注意：在实际应用中，可能想要打印错误消息
            // 但为了保持简单，这里只是释放错误消息
            LLVMDisposeMessage(error);
        }
        LLVMDisposeTargetMachine(target_machine);
        LLVMDisposeMessage(target_triple);
        return -1;
    }
    
    // 清理资源
    LLVMDisposeTargetMachine(target_machine);
    LLVMDisposeMessage(target_triple);
    
    return 0;
}

