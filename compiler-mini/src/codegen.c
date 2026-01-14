#include "codegen.h"
#include "lexer.h"
#include <string.h>
#include <stdlib.h>
#include <llvm-c/TargetMachine.h>
#include <llvm-c/Target.h>
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
    // 注意：需要检查 Arena 的剩余空间
    extern size_t arena_get_used(Arena *arena);  // 前向声明（如果存在）
    char *name_copy = (char *)arena_alloc(arena, name_len + 1);
    if (!name_copy) {
        // 尝试获取 Arena 使用情况（如果可能）
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
    codegen->global_var_map_count = 0;
    codegen->basic_block_counter = 0;
    codegen->string_literal_counter = 0;
    codegen->loop_stack_depth = 0;
    codegen->program_node = NULL;
    
    return 0;
}

// 获取基础类型的LLVM类型
// 参数：codegen - 代码生成器指针
//       type_kind - 类型种类（TypeKind枚举：TYPE_I32, TYPE_USIZE, TYPE_BOOL, TYPE_BYTE, TYPE_VOID）
// 返回：LLVM类型引用，失败返回NULL
// 注意：此函数仅支持基础类型，结构体类型需要使用其他函数
//       usize 类型大小根据目标平台确定（32位平台=u32，64位平台=u64）
LLVMTypeRef codegen_get_base_type(CodeGenerator *codegen, TypeKind type_kind) {
    if (!codegen) {
        return NULL;
    }
    
    switch (type_kind) {
        case TYPE_I32:
            // i32 类型映射到 LLVM Int32 类型（全局类型，不依赖context）
            return LLVMInt32Type();
            
        case TYPE_USIZE:
            // usize 类型：平台相关的无符号大小类型
            // 根据目标平台的指针大小确定 usize 的大小
            if (codegen->module) {
                LLVMTargetDataRef target_data = LLVMGetModuleDataLayout(codegen->module);
                if (target_data) {
                    // 获取指针大小（字节数）
                    unsigned pointer_size = LLVMPointerSize(target_data);
                    if (pointer_size == 4) {
                        // 32位平台：usize = u32
                        return LLVMInt32Type();
                    } else if (pointer_size == 8) {
                        // 64位平台：usize = u64
                        return LLVMInt64Type();
                    }
                }
            }
            // 如果无法获取目标平台信息，默认使用 64 位（大多数现代平台）
            return LLVMInt64Type();
            
        case TYPE_BOOL:
            // bool 类型映射到 LLVM Int1 类型（1位整数，更精确，全局类型）
            return LLVMInt1Type();
            
        case TYPE_BYTE:
            // byte 类型映射到 LLVM Int8 类型（8位无符号整数，全局类型）
            return LLVMInt8Type();
            
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

// 前向声明
static ASTNode *find_enum_decl(CodeGenerator *codegen, const char *enum_name);
static int get_enum_variant_value(ASTNode *enum_decl, int variant_index);

// 辅助函数：从AST类型节点获取LLVM类型（支持基础类型、结构体类型、指针类型和数组类型）
// 参数：codegen - 代码生成器指针
//       type_node - AST类型节点（AST_TYPE_NAMED、AST_TYPE_POINTER 或 AST_TYPE_ARRAY）
// 返回：LLVM类型引用，失败返回NULL
static LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node) {
    if (!codegen || !type_node) {
        return NULL;
    }
    
    switch (type_node->type) {
        case AST_TYPE_NAMED: {
            // 命名类型（基础类型或结构体类型）
            const char *type_name = type_node->data.type_named.name;
            if (!type_name) {
                return NULL;
            }
            
            // 基础类型
            if (strcmp(type_name, "i32") == 0) {
                return codegen_get_base_type(codegen, TYPE_I32);
            } else if (strcmp(type_name, "usize") == 0) {
                return codegen_get_base_type(codegen, TYPE_USIZE);
            } else if (strcmp(type_name, "bool") == 0) {
                return codegen_get_base_type(codegen, TYPE_BOOL);
            } else if (strcmp(type_name, "byte") == 0) {
                return codegen_get_base_type(codegen, TYPE_BYTE);
            } else if (strcmp(type_name, "void") == 0) {
                return codegen_get_base_type(codegen, TYPE_VOID);
            }
            
            // 枚举类型或结构体类型
            // 先检查是否是枚举类型（枚举类型在LLVM中就是i32类型）
            ASTNode *enum_decl = find_enum_decl(codegen, type_name);
            if (enum_decl != NULL) {
                // 枚举类型，返回i32类型（默认底层类型）
                return codegen_get_base_type(codegen, TYPE_I32);
            }
            
            // 结构体类型（必须在注册表中查找）
            return codegen_get_struct_type(codegen, type_name);
        }
        
        case AST_TYPE_POINTER: {
            // 指针类型（&T 或 *T）
            // 普通指针和 FFI 指针在 LLVM 中都映射为指针类型
            ASTNode *pointed_type = type_node->data.type_pointer.pointed_type;
            if (!pointed_type) {
                return NULL;
            }
            
            // 递归获取指向的类型的 LLVM 类型
            LLVMTypeRef pointed_llvm_type = get_llvm_type_from_ast(codegen, pointed_type);
            if (!pointed_llvm_type) {
                return NULL;
            }
            
            // 创建指针类型（地址空间 0，默认）
            return LLVMPointerType(pointed_llvm_type, 0);
        }
        
        case AST_TYPE_ARRAY: {
            // 数组类型（[T: N]）
            ASTNode *element_type = type_node->data.type_array.element_type;
            ASTNode *size_expr = type_node->data.type_array.size_expr;
            if (!element_type || !size_expr) {
                return NULL;
            }
            
            // 数组大小必须是编译期常量（数字字面量）
            if (size_expr->type != AST_NUMBER) {
                return NULL;  // 数组大小必须是编译期常量
            }
            
            int array_size = size_expr->data.number.value;
            if (array_size < 0) {
                return NULL;  // 数组大小必须非负
            }
            
            // 递归获取元素类型的 LLVM 类型
            LLVMTypeRef element_llvm_type = get_llvm_type_from_ast(codegen, element_type);
            if (!element_llvm_type) {
                return NULL;
            }
            
            // 创建数组类型
            return LLVMArrayType(element_llvm_type, (unsigned int)array_size);
        }
        
        default:
            return NULL;
    }
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

// 辅助函数：在变量表中查找变量（先查找局部变量，再查找全局变量）
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：LLVM值引用（变量指针），未找到返回NULL
static LLVMValueRef lookup_var(CodeGenerator *codegen, const char *var_name) {
    if (!codegen || !var_name) {
        return NULL;
    }
    
    // 先查找局部变量表（从后向前查找，由于禁止变量遮蔽，理论上只需要查找最后一个匹配项）
    for (int i = codegen->var_map_count - 1; i >= 0; i--) {
        if (codegen->var_map[i].name != NULL && 
            strcmp(codegen->var_map[i].name, var_name) == 0) {
            return codegen->var_map[i].value;
        }
    }
    
    // 如果局部变量表中未找到，查找全局变量表
    for (int i = 0; i < codegen->global_var_map_count; i++) {
        if (codegen->global_var_map[i].name != NULL && 
            strcmp(codegen->global_var_map[i].name, var_name) == 0) {
            return codegen->global_var_map[i].global_var;
        }
    }
    
    return NULL;  // 未找到
}

// 前向声明
static ASTNode *find_struct_decl(CodeGenerator *codegen, const char *struct_name);
static int find_enum_variant_index(ASTNode *enum_decl, const char *variant_name);
static int find_struct_field_index(ASTNode *struct_decl, const char *field_name);
static const char *lookup_var_struct_name(CodeGenerator *codegen, const char *var_name);
static LLVMTypeRef lookup_var_type(CodeGenerator *codegen, const char *var_name);
static ASTNode *lookup_var_ast_type(CodeGenerator *codegen, const char *var_name);

// 辅助函数：生成左值表达式的地址
// 参数：codegen - 代码生成器指针
//       expr - 左值表达式节点
// 返回：LLVM值引用（地址），失败返回NULL
static LLVMValueRef codegen_gen_lvalue_address(CodeGenerator *codegen, ASTNode *expr) {
    if (!codegen || !expr) {
        return NULL;
    }
    
    switch (expr->type) {
        case AST_IDENTIFIER: {
            // 标识符（变量）：从变量表查找指针
            const char *var_name = expr->data.identifier.name;
            if (!var_name) {
                return NULL;
            }
            return lookup_var(codegen, var_name);
        }
        
        case AST_UNARY_EXPR: {
            // 解引用表达式：*expr
            // 对于赋值 *p = value，p 是指针，我们需要返回 p 的值（即指针本身）
            int op = expr->data.unary_expr.op;
            if (op != TOKEN_ASTERISK) {
                return NULL;  // 只有解引用表达式可以作为左值
            }
            
            ASTNode *operand = expr->data.unary_expr.operand;
            if (!operand) {
                return NULL;
            }
            
            // 操作数应该是指针类型，直接返回操作数的值（指针值本身）
            LLVMValueRef operand_val = codegen_gen_expr(codegen, operand);
            if (!operand_val) {
                return NULL;
            }
            
            // 验证操作数是指针类型
            LLVMTypeRef operand_type = LLVMTypeOf(operand_val);
            if (!operand_type || LLVMGetTypeKind(operand_type) != LLVMPointerTypeKind) {
                return NULL;  // 操作数不是指针类型
            }
            
            // 返回指针值本身（这是我们要存储的地址）
            return operand_val;
        }
        
        case AST_MEMBER_ACCESS: {
            // 字段访问：使用 GEP 获取字段地址（用于赋值语句如 p.x = value）
            ASTNode *object = expr->data.member_access.object;
            const char *field_name = expr->data.member_access.field_name;
            
            if (!object || !field_name) {
                return NULL;
            }
            
            // 如果对象是标识符（变量），从变量表获取结构体名称和对象指针
            const char *struct_name = NULL;
            LLVMValueRef object_ptr = NULL;
            
            if (object->type == AST_IDENTIFIER) {
                const char *var_name = object->data.identifier.name;
                if (var_name) {
                    object_ptr = lookup_var(codegen, var_name);
                    struct_name = lookup_var_struct_name(codegen, var_name);
                    
                    // 检查变量类型是否是指针类型（无论 struct_name 是否设置）
                    ASTNode *var_ast_type = lookup_var_ast_type(codegen, var_name);
                    if (var_ast_type && var_ast_type->type == AST_TYPE_POINTER) {
                        // 变量是指针类型，需要加载指针值
                        LLVMTypeRef var_type = lookup_var_type(codegen, var_name);
                        if (var_type && object_ptr) {
                            // 加载指针变量的值（即指针值本身）
                            object_ptr = LLVMBuildLoad2(codegen->builder, var_type, object_ptr, var_name);
                            
                            // 从指针类型中获取指向的结构体类型名称
                            ASTNode *pointed_type = var_ast_type->data.type_pointer.pointed_type;
                            if (pointed_type && pointed_type->type == AST_TYPE_NAMED) {
                                struct_name = pointed_type->data.type_named.name;
                            }
                        }
                    }
                }
            }
            
            if (!object_ptr || !struct_name) {
                // 对象不是标识符或变量未找到，需要生成对象表达式值
                // 对于字段访问作为左值，我们暂时不支持复杂表达式
                return NULL;
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
            indices[0] = LLVMConstInt(LLVMInt32Type(), 0ULL, 0);  // 结构体指针本身
            indices[1] = LLVMConstInt(LLVMInt32Type(), (unsigned long long)field_index, 0);  // 字段索引
            
            LLVMValueRef field_ptr = LLVMBuildGEP2(codegen->builder, struct_type, object_ptr, indices, 2, "");
            if (!field_ptr) {
                return NULL;
            }
            
            // 返回字段地址（不需要加载值）
            return field_ptr;
        }
        
        default:
            // 暂不支持其他类型的左值（如数组访问等）
            return NULL;
    }
}

// 辅助函数：在变量表中查找变量类型（先查找局部变量，再查找全局变量）
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：LLVM类型引用，未找到返回NULL
static LLVMTypeRef lookup_var_type(CodeGenerator *codegen, const char *var_name) {
    if (!codegen || !var_name) {
        return NULL;
    }
    
    // 先查找局部变量表（从后向前查找，由于禁止变量遮蔽，理论上只需要查找最后一个匹配项）
    for (int i = codegen->var_map_count - 1; i >= 0; i--) {
        if (codegen->var_map[i].name != NULL && 
            strcmp(codegen->var_map[i].name, var_name) == 0) {
            return codegen->var_map[i].type;
        }
    }
    
    // 如果局部变量表中未找到，查找全局变量表
    for (int i = 0; i < codegen->global_var_map_count; i++) {
        if (codegen->global_var_map[i].name != NULL && 
            strcmp(codegen->global_var_map[i].name, var_name) == 0) {
            return codegen->global_var_map[i].type;
        }
    }
    
    return NULL;  // 未找到
}

// 辅助函数：在变量表中查找变量 AST 类型节点（仅查找局部变量）
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：AST类型节点，未找到返回NULL
static ASTNode *lookup_var_ast_type(CodeGenerator *codegen, const char *var_name) {
    if (!codegen || !var_name) {
        return NULL;
    }
    
    // 查找局部变量表（从后向前查找）
    for (int i = codegen->var_map_count - 1; i >= 0; i--) {
        if (codegen->var_map[i].name != NULL && 
            strcmp(codegen->var_map[i].name, var_name) == 0) {
            return codegen->var_map[i].ast_type;
        }
    }
    
    return NULL;  // 未找到（全局变量暂不支持）
}

// 辅助函数：在变量表中添加变量
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称（存储在 Arena 中）
//       value - LLVM值（变量指针）
//       type - 变量类型（用于 LLVMBuildLoad2）
//       struct_name - 结构体名称（仅当类型是结构体类型时有效，存储在 Arena 中，可为 NULL）
//       ast_type - AST 类型节点（用于从 AST 重新构建类型，可为 NULL）
// 返回：成功返回0，失败返回非0
static int add_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef value, LLVMTypeRef type, const char *struct_name, ASTNode *ast_type) {
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
    codegen->var_map[idx].ast_type = ast_type;  // AST 类型节点（可为 NULL）
    codegen->var_map_count++;
    
    return 0;
}

// 辅助函数：在变量表中查找变量结构体名称（先查找局部变量，再查找全局变量）
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：结构体名称（如果变量是结构体类型），未找到返回 NULL
static const char *lookup_var_struct_name(CodeGenerator *codegen, const char *var_name) {
    if (!codegen || !var_name) {
        return NULL;
    }
    
    // 先查找局部变量表（从后向前查找，由于禁止变量遮蔽，理论上只需要查找最后一个匹配项）
    for (int i = codegen->var_map_count - 1; i >= 0; i--) {
        if (codegen->var_map[i].name != NULL && 
            strcmp(codegen->var_map[i].name, var_name) == 0) {
            return codegen->var_map[i].struct_name;
        }
    }
    
    // 如果局部变量表中未找到，查找全局变量表
    for (int i = 0; i < codegen->global_var_map_count; i++) {
        if (codegen->global_var_map[i].name != NULL && 
            strcmp(codegen->global_var_map[i].name, var_name) == 0) {
            return codegen->global_var_map[i].struct_name;
        }
    }
    
    return NULL;  // 未找到
}

// 辅助函数：在全局变量表中添加全局变量
// 参数：codegen - 代码生成器指针
//       var_name - 全局变量名称（存储在 Arena 中）
//       global_var - LLVM全局变量值（指针）
//       type - 全局变量类型（用于 LLVMBuildLoad2）
//       struct_name - 结构体名称（仅当类型是结构体类型时有效，存储在 Arena 中，可为 NULL）
// 返回：成功返回0，失败返回非0
static int add_global_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef global_var, LLVMTypeRef type, const char *struct_name) {
    if (!codegen || !var_name || !global_var || !type) {
        return -1;
    }
    
    // 检查映射表是否已满
    if (codegen->global_var_map_count >= 64) {
        return -1;  // 映射表已满
    }
    
    // 添加到映射表
    int idx = codegen->global_var_map_count;
    codegen->global_var_map[idx].name = var_name;
    codegen->global_var_map[idx].global_var = global_var;
    codegen->global_var_map[idx].type = type;
    codegen->global_var_map[idx].struct_name = struct_name;  // 结构体名称（可为 NULL）
    codegen->global_var_map_count++;
    
    return 0;
}

// 辅助函数：在函数表中查找函数
// 参数：codegen - 代码生成器指针
//       func_name - 函数名称
//       func_type_out - 输出参数：函数类型（可选，可以为NULL）
// 返回：LLVM函数值，未找到返回NULL
static LLVMValueRef lookup_func(CodeGenerator *codegen, const char *func_name, LLVMTypeRef *func_type_out) {
    if (!codegen || !func_name) {
        return NULL;
    }
    
    // 线性查找
    for (int i = 0; i < codegen->func_map_count; i++) {
        if (codegen->func_map[i].name != NULL && 
            strcmp(codegen->func_map[i].name, func_name) == 0) {
            if (func_type_out) {
                *func_type_out = codegen->func_map[i].func_type;
            }
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

// 辅助函数：从程序节点中查找枚举声明
// 参数：codegen - 代码生成器指针
//       enum_name - 枚举名称
// 返回：找到的枚举声明节点指针，未找到返回 NULL
static ASTNode *find_enum_decl(CodeGenerator *codegen, const char *enum_name) {
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
static int find_enum_variant_index(ASTNode *enum_decl, const char *variant_name) {
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
static int get_enum_variant_value(ASTNode *enum_decl, int variant_index) {
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

// 辅助函数：从LLVM结构体类型查找结构体名称
// 参数：codegen - 代码生成器指针
//       struct_type - LLVM结构体类型
// 返回：结构体名称（存储在Arena中），未找到返回NULL
static const char *find_struct_name_from_type(CodeGenerator *codegen, LLVMTypeRef struct_type) {
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

// 生成结构体比较代码（逐字段比较）
// 参数：codegen - 代码生成器指针
//       left_val - 左操作数的结构体值
//       right_val - 右操作数的结构体值
//       struct_decl - 结构体声明节点
//       is_equal - 1 表示 == 比较，0 表示 != 比较
// 返回：比较结果值（LLVMValueRef），失败返回NULL
static LLVMValueRef codegen_gen_struct_comparison(
    CodeGenerator *codegen,
    LLVMValueRef left_val,
    LLVMValueRef right_val,
    ASTNode *struct_decl,
    int is_equal
) {
    if (!codegen || !left_val || !right_val || !struct_decl || 
        struct_decl->type != AST_STRUCT_DECL) {
        return NULL;
    }
    
    int field_count = struct_decl->data.struct_decl.field_count;
    
    // 处理空结构体（0个字段）
    if (field_count == 0) {
        // 空结构体总是相等
        LLVMTypeRef bool_type = codegen_get_base_type(codegen, TYPE_BOOL);
        if (!bool_type) {
            return NULL;
        }
        LLVMValueRef result = LLVMConstInt(bool_type, is_equal ? 1ULL : 0ULL, 0);
        return result;
    }
    
    // 对于每个字段，提取并比较字段值
    LLVMValueRef field_comparisons[16];  // 最多支持16个字段
    if (field_count > 16) {
        return NULL;  // 字段数过多
    }
    
    int valid_comparisons = 0;
    
    for (int i = 0; i < field_count; i++) {
        ASTNode *field = struct_decl->data.struct_decl.fields[i];
        if (!field || field->type != AST_VAR_DECL) {
            return NULL;
        }
        
        ASTNode *field_type_node = field->data.var_decl.type;
        if (!field_type_node || field_type_node->type != AST_TYPE_NAMED) {
            return NULL;
        }
        
        const char *field_type_name = field_type_node->data.type_named.name;
        if (!field_type_name) {
            return NULL;
        }
        
        // 提取字段值
        LLVMValueRef left_field = LLVMBuildExtractValue(codegen->builder, left_val, i, "");
        LLVMValueRef right_field = LLVMBuildExtractValue(codegen->builder, right_val, i, "");
        if (!left_field || !right_field) {
            return NULL;
        }
        
        // 根据字段类型进行比较
        LLVMValueRef field_eq = NULL;
        
        if (strcmp(field_type_name, "i32") == 0 || strcmp(field_type_name, "bool") == 0) {
            // 基础类型（i32、bool）：使用整数比较
            field_eq = LLVMBuildICmp(codegen->builder, LLVMIntEQ, left_field, right_field, "");
        } else {
            // 嵌套结构体类型：递归调用结构体比较
            const char *struct_name = find_struct_name_from_type(
                codegen, 
                LLVMTypeOf(left_field)
            );
            if (!struct_name) {
                return NULL;
            }
            
            ASTNode *nested_struct_decl = find_struct_decl(codegen, struct_name);
            if (!nested_struct_decl) {
                return NULL;
            }
            
            // 递归调用结构体比较（使用 == 比较，然后根据 is_equal 决定是否取反）
            field_eq = codegen_gen_struct_comparison(
                codegen,
                left_field,
                right_field,
                nested_struct_decl,
                1  // 使用 == 比较
            );
        }
        
        if (!field_eq) {
            return NULL;
        }
        
        field_comparisons[valid_comparisons++] = field_eq;
    }
    
    // 组合所有字段比较结果（逻辑与）
    if (valid_comparisons == 0) {
        return NULL;
    }
    
    LLVMValueRef result = field_comparisons[0];
    for (int i = 1; i < valid_comparisons; i++) {
        result = LLVMBuildAnd(codegen->builder, result, field_comparisons[i], "");
        if (!result) {
            return NULL;
        }
    }
    
    // 如果是 != 比较，对结果取反
    if (!is_equal) {
        LLVMTypeRef bool_type = codegen_get_base_type(codegen, TYPE_BOOL);
        if (!bool_type) {
            return NULL;
        }
        LLVMValueRef one = LLVMConstInt(bool_type, 1ULL, 0);
        result = LLVMBuildXor(codegen->builder, result, one, "");  // XOR 1 实现取反
    }
    
    return result;
}

// 辅助函数：在函数表中添加函数
// 参数：codegen - 代码生成器指针
//       func_name - 函数名称（存储在 Arena 中）
//       func - LLVM函数值
//       func_type - LLVM函数类型（函数签名类型）
// 返回：成功返回0，失败返回非0
static int add_func(CodeGenerator *codegen, const char *func_name, LLVMValueRef func, LLVMTypeRef func_type) {
    if (!codegen || !func_name || !func || !func_type) {
        return -1;
    }
    
    // 检查映射表是否已满
    if (codegen->func_map_count >= 256) {
        return -1;  // 映射表已满
    }
    
    // 添加到映射表
    int idx = codegen->func_map_count;
    codegen->func_map[idx].name = func_name;
    codegen->func_map[idx].func = func;
    codegen->func_map[idx].func_type = func_type;
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
        
        case AST_STRING: {
            // 字符串字面量：创建全局字符串常量，返回指向它的指针（*byte 类型）
            const char *str_value = expr->data.string_literal.value;
            if (!str_value) {
                return NULL;
            }
            
            // 计算字符串长度（不包括 null 终止符，LLVMConstStringInContext 会自动添加）
            size_t str_len = strlen(str_value);
            
            // 创建 i8 数组类型（字符串长度 + 1 个 null 终止符）
            LLVMTypeRef i8_type = LLVMInt8Type();
            LLVMTypeRef array_type = LLVMArrayType(i8_type, (unsigned int)(str_len + 1));
            
            // 创建字符串常量值（LLVMConstStringInContext 会自动添加 null 终止符）
            // 参数：context, string, length, dontNullTerminate
            // dontNullTerminate = 0 表示自动添加 null 终止符
            LLVMValueRef str_const = LLVMConstStringInContext(codegen->context, str_value, (unsigned int)str_len, 0);
            if (!str_const) {
                return NULL;
            }
            
            // 生成唯一的全局变量名称
            int str_id = codegen->string_literal_counter++;
            char global_name[64];
            snprintf(global_name, sizeof(global_name), "str.%d", str_id);
            
            // 将名称复制到 Arena
            size_t name_len = strlen(global_name);
            char *name_copy = (char *)arena_alloc(codegen->arena, name_len + 1);
            if (!name_copy) {
                return NULL;
            }
            memcpy(name_copy, global_name, name_len + 1);
            
            // 创建全局变量（类型为数组）
            LLVMValueRef global_var = LLVMAddGlobal(codegen->module, array_type, name_copy);
            if (!global_var) {
                return NULL;
            }
            
            // 设置初始值为字符串常量
            LLVMSetInitializer(global_var, str_const);
            
            // 设置为常量（不可变）
            LLVMSetGlobalConstant(global_var, 1);
            
            // 设置链接属性（内部链接）
            LLVMSetLinkage(global_var, LLVMInternalLinkage);
            
            // 全局变量本身就是一个指针，可以直接返回
            return global_var;
        }
        
        case AST_UNARY_EXPR: {
            // 一元表达式（!, -, &, *）
            ASTNode *operand = expr->data.unary_expr.operand;
            if (!operand) {
                return NULL;
            }
            
            int op = expr->data.unary_expr.op;
            
            if (op == TOKEN_AMPERSAND) {
                // 取地址运算符：&expr
                // 操作数必须是左值（变量、字段访问等）
                // 对于标识符（变量），直接从变量表获取指针
                if (operand->type == AST_IDENTIFIER) {
                    const char *var_name = operand->data.identifier.name;
                    if (!var_name) {
                        return NULL;
                    }
                    LLVMValueRef var_ptr = lookup_var(codegen, var_name);
                    if (!var_ptr) {
                        return NULL;  // 变量未找到
                    }
                    // 变量指针已经是地址，直接返回
                    return var_ptr;
                }
                // 对于其他表达式（如字段访问、数组访问），需要先计算表达式值
                // 然后分配临时空间存储值，返回临时空间的地址
                // 注意：这是一个简化实现，完整的左值检查应该在类型检查阶段完成
                LLVMValueRef operand_val = codegen_gen_expr(codegen, operand);
                if (!operand_val) {
                    return NULL;
                }
                LLVMTypeRef operand_type = LLVMTypeOf(operand_val);
                if (!operand_type) {
                    return NULL;
                }
                // 使用 alloca 分配临时空间
                LLVMValueRef temp_ptr = LLVMBuildAlloca(codegen->builder, operand_type, "");
                if (!temp_ptr) {
                    return NULL;
                }
                // store 值到临时空间
                LLVMBuildStore(codegen->builder, operand_val, temp_ptr);
                // 返回临时空间的地址
                return temp_ptr;
            } else if (op == TOKEN_ASTERISK) {
                // 解引用运算符：*expr
                // 操作数必须是指针类型
                // 如果操作数是标识符，从 AST 类型节点获取指向的类型（避免使用 LLVMGetElementType）
                LLVMValueRef operand_val = NULL;
                LLVMTypeRef pointed_type = NULL;
                
                if (operand->type == AST_IDENTIFIER) {
                    // 优化：对于标识符，从变量表获取 AST 类型节点，然后从 AST 重新构建指向的类型
                    const char *var_name = operand->data.identifier.name;
                    if (var_name) {
                        ASTNode *var_ast_type = lookup_var_ast_type(codegen, var_name);
                        if (var_ast_type && var_ast_type->type == AST_TYPE_POINTER) {
                            // 从 AST 类型节点获取指向的类型节点
                            ASTNode *pointed_ast_type = var_ast_type->data.type_pointer.pointed_type;
                            if (pointed_ast_type) {
                                // 从 AST 类型节点重新构建指向类型的 LLVM 类型
                                pointed_type = get_llvm_type_from_ast(codegen, pointed_ast_type);
                                if (pointed_type) {
                                    // 需要加载指针变量的值（指针变量本身存储的是指针值）
                                    LLVMValueRef var_ptr = lookup_var(codegen, var_name);
                                    LLVMTypeRef var_type = lookup_var_type(codegen, var_name);
                                    if (var_ptr && var_type) {
                                        // 加载指针变量的值（即指针值本身）
                                        operand_val = LLVMBuildLoad2(codegen->builder, var_type, var_ptr, var_name);
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 如果优化路径失败，使用通用方法
                if (!operand_val || !pointed_type) {
                    operand_val = codegen_gen_expr(codegen, operand);
                    if (!operand_val) {
                        return NULL;
                    }
                    LLVMTypeRef operand_type = LLVMTypeOf(operand_val);
                    if (!operand_type) {
                        return NULL;
                    }
                    // 检查操作数类型是否为指针类型
                    if (LLVMGetTypeKind(operand_type) != LLVMPointerTypeKind) {
                        return NULL;  // 操作数不是指针类型
                    }
                    // 获取指针指向的类型（通用方法仍然使用 LLVMGetElementType）
                    pointed_type = LLVMGetElementType(operand_type);
                    if (!pointed_type) {
                        return NULL;
                    }
                }
                
                // 使用 LLVMBuildLoad2 加载指针指向的值
                return LLVMBuildLoad2(codegen->builder, pointed_type, operand_val, "");
            }
            
            // 处理其他一元运算符（!, -）
            LLVMValueRef operand_val = codegen_gen_expr(codegen, operand);
            if (!operand_val) {
                return NULL;
            }
            
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
            
            int op = expr->data.binary_expr.op;
            
            // 特殊处理逻辑运算符（&&, ||）以实现短路求值
            if (op == TOKEN_LOGICAL_AND || op == TOKEN_LOGICAL_OR) {
                // 获取当前基本块
                LLVMBasicBlockRef current_bb = LLVMGetInsertBlock(codegen->builder);
                if (!current_bb) {
                    return NULL;
                }
                
                // 获取当前基本块所在的函数
                LLVMValueRef func = LLVMGetBasicBlockParent(current_bb);
                if (!func) {
                    return NULL;
                }
                
                // 生成左操作数
                LLVMValueRef left_val = codegen_gen_expr(codegen, left);
                if (!left_val) {
                    return NULL;
                }
                
                // 检查左操作数类型是否为i1（布尔类型）
                LLVMTypeRef left_type = LLVMTypeOf(left_val);
                if (LLVMGetTypeKind(left_type) != LLVMIntegerTypeKind || LLVMGetIntTypeWidth(left_type) != 1) {
                    fprintf(stderr, "错误: 逻辑运算符左操作数必须是布尔类型 (i1)\n");
                    return NULL;
                }
                
                // 创建临时变量来存储结果
                LLVMValueRef result = LLVMBuildAlloca(codegen->builder, left_type, "bool_result");
                
                // 创建基本块（使用计数器生成唯一名称）
                int bb_id = codegen->basic_block_counter++;
                char then_name[32], else_name[32], merge_name[32];
                snprintf(then_name, sizeof(then_name), "logical_then.%d", bb_id);
                snprintf(else_name, sizeof(else_name), "logical_else.%d", bb_id);
                snprintf(merge_name, sizeof(merge_name), "logical_merge.%d", bb_id);
                LLVMBasicBlockRef then_bb = LLVMAppendBasicBlock(func, then_name);
                LLVMBasicBlockRef else_bb = LLVMAppendBasicBlock(func, else_name);
                LLVMBasicBlockRef merge_bb = LLVMAppendBasicBlock(func, merge_name);
                
                if (op == TOKEN_LOGICAL_AND) {
                    // 短路与：if (left) then evaluate right else result = false
                    LLVMBuildCondBr(codegen->builder, left_val, then_bb, else_bb);
                    
                    // then_bb：计算右操作数
                    LLVMPositionBuilderAtEnd(codegen->builder, then_bb);
                    LLVMValueRef right_val = codegen_gen_expr(codegen, right);
                    if (!right_val) {
                        return NULL;
                    }
                    // 检查右操作数类型是否为i1（布尔类型）
                    LLVMTypeRef right_type = LLVMTypeOf(right_val);
                    if (LLVMGetTypeKind(right_type) != LLVMIntegerTypeKind || LLVMGetIntTypeWidth(right_type) != 1) {
                        fprintf(stderr, "错误: 逻辑运算符右操作数必须是布尔类型 (i1)\n");
                        return NULL;
                    }
                    LLVMBuildStore(codegen->builder, right_val, result);
                    LLVMBuildBr(codegen->builder, merge_bb);
                    
                    // else_bb：结果为false
                    LLVMPositionBuilderAtEnd(codegen->builder, else_bb);
                    LLVMBuildStore(codegen->builder, LLVMConstInt(left_type, 0, 0), result);
                    LLVMBuildBr(codegen->builder, merge_bb);
                } else if (op == TOKEN_LOGICAL_OR) {
                    // 短路或：if (left) then result = true else evaluate right
                    LLVMBuildCondBr(codegen->builder, left_val, then_bb, else_bb);
                    
                    // then_bb：结果为true
                    LLVMPositionBuilderAtEnd(codegen->builder, then_bb);
                    LLVMBuildStore(codegen->builder, LLVMConstInt(left_type, 1, 0), result);
                    LLVMBuildBr(codegen->builder, merge_bb);
                    
                    // else_bb：计算右操作数
                    LLVMPositionBuilderAtEnd(codegen->builder, else_bb);
                    LLVMValueRef right_val = codegen_gen_expr(codegen, right);
                    if (!right_val) {
                        return NULL;
                    }
                    // 检查右操作数类型是否为i1（布尔类型）
                    LLVMTypeRef right_type = LLVMTypeOf(right_val);
                    if (LLVMGetTypeKind(right_type) != LLVMIntegerTypeKind || LLVMGetIntTypeWidth(right_type) != 1) {
                        fprintf(stderr, "错误: 逻辑运算符右操作数必须是布尔类型 (i1)\n");
                        return NULL;
                    }
                    LLVMBuildStore(codegen->builder, right_val, result);
                    LLVMBuildBr(codegen->builder, merge_bb);
                }
                
                // merge_bb：加载结果
                LLVMPositionBuilderAtEnd(codegen->builder, merge_bb);
                return LLVMBuildLoad2(codegen->builder, left_type, result, "");
            }
            
            // 处理其他二元表达式
            LLVMValueRef left_val = codegen_gen_expr(codegen, left);
            LLVMValueRef right_val = codegen_gen_expr(codegen, right);
            
            // 如果其中一个操作数生成失败，尝试处理 null 标识符
            if (!left_val && left->type == AST_IDENTIFIER) {
                const char *left_name = left->data.identifier.name;
                if (left_name && strcmp(left_name, "null") == 0) {
                    // left 是 null 标识符，需要从 right 获取类型
                    if (right_val) {
                        LLVMTypeRef right_type = LLVMTypeOf(right_val);
                        if (LLVMGetTypeKind(right_type) == LLVMPointerTypeKind) {
                            left_val = LLVMConstNull(right_type);
                        }
                    }
                }
            }
            if (!right_val && right->type == AST_IDENTIFIER) {
                const char *right_name = right->data.identifier.name;
                if (right_name && strcmp(right_name, "null") == 0) {
                    // right 是 null 标识符，需要从 left 获取类型
                    if (left_val) {
                        LLVMTypeRef left_type = LLVMTypeOf(left_val);
                        if (LLVMGetTypeKind(left_type) == LLVMPointerTypeKind) {
                            right_val = LLVMConstNull(left_type);
                        }
                    }
                }
            }
            
            if (!left_val || !right_val) {
                return NULL;
            }
            
            // 获取操作数类型
            LLVMTypeRef left_type = LLVMTypeOf(left_val);
            LLVMTypeRef right_type = LLVMTypeOf(right_val);
            
            // 算术运算符和比较运算符（支持 i32 和 usize 混合运算）
            if (LLVMGetTypeKind(left_type) == LLVMIntegerTypeKind && 
                LLVMGetTypeKind(right_type) == LLVMIntegerTypeKind) {
                
                // 类型提升：如果操作数类型不同，将 i32 提升为 usize
                unsigned left_width = LLVMGetIntTypeWidth(left_type);
                unsigned right_width = LLVMGetIntTypeWidth(right_type);
                
                // 获取 usize 类型（用于类型提升）
                LLVMTypeRef usize_type = codegen_get_base_type(codegen, TYPE_USIZE);
                if (!usize_type) {
                    return NULL;
                }
                unsigned usize_width = LLVMGetIntTypeWidth(usize_type);
                
                // 标记是否至少有一个操作数是 usize（用于决定使用有符号还是无符号运算）
                int is_usize_op = 0;
                
                // 如果左操作数是 i32，右操作数是 usize，将左操作数提升为 usize
                if (left_width == 32 && right_width == usize_width) {
                    left_val = LLVMBuildZExt(codegen->builder, left_val, usize_type, "");
                    left_type = usize_type;
                    is_usize_op = 1;
                }
                // 如果左操作数是 usize，右操作数是 i32，将右操作数提升为 usize
                else if (left_width == usize_width && right_width == 32) {
                    right_val = LLVMBuildZExt(codegen->builder, right_val, usize_type, "");
                    right_type = usize_type;
                    is_usize_op = 1;
                }
                // 如果两个操作数都是 usize
                else if (left_width == usize_width && right_width == usize_width) {
                    is_usize_op = 1;
                }
                
                // 算术运算符（i32 或 usize）
                if (op == TOKEN_PLUS) {
                    return LLVMBuildAdd(codegen->builder, left_val, right_val, "");
                } else if (op == TOKEN_MINUS) {
                    return LLVMBuildSub(codegen->builder, left_val, right_val, "");
                } else if (op == TOKEN_ASTERISK) {
                    return LLVMBuildMul(codegen->builder, left_val, right_val, "");
                } else if (op == TOKEN_SLASH) {
                    // 对于 usize，使用无符号除法；对于 i32，使用有符号除法
                    if (is_usize_op) {
                        return LLVMBuildUDiv(codegen->builder, left_val, right_val, "");  // 无符号除法
                    } else {
                        return LLVMBuildSDiv(codegen->builder, left_val, right_val, "");  // 有符号除法
                    }
                } else if (op == TOKEN_PERCENT) {
                    // 对于 usize，使用无符号取模；对于 i32，使用有符号取模
                    if (is_usize_op) {
                        return LLVMBuildURem(codegen->builder, left_val, right_val, "");  // 无符号取模
                    } else {
                        return LLVMBuildSRem(codegen->builder, left_val, right_val, "");  // 有符号取模
                    }
                }
                
                // 比较运算符（返回 i1）
                // 对于 i32 使用有符号比较，对于 usize 使用无符号比较
                // LLVMBuildICmp 自动返回 i1 类型
                if (op == TOKEN_EQUAL) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntEQ, left_val, right_val, "");
                } else if (op == TOKEN_NOT_EQUAL) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntNE, left_val, right_val, "");
                } else if (op == TOKEN_LESS) {
                    LLVMIntPredicate pred = is_usize_op ? LLVMIntULT : LLVMIntSLT;
                    return LLVMBuildICmp(codegen->builder, pred, left_val, right_val, "");
                } else if (op == TOKEN_LESS_EQUAL) {
                    LLVMIntPredicate pred = is_usize_op ? LLVMIntULE : LLVMIntSLE;
                    return LLVMBuildICmp(codegen->builder, pred, left_val, right_val, "");
                } else if (op == TOKEN_GREATER) {
                    LLVMIntPredicate pred = is_usize_op ? LLVMIntUGT : LLVMIntSGT;
                    return LLVMBuildICmp(codegen->builder, pred, left_val, right_val, "");
                } else if (op == TOKEN_GREATER_EQUAL) {
                    LLVMIntPredicate pred = is_usize_op ? LLVMIntUGE : LLVMIntSGE;
                    return LLVMBuildICmp(codegen->builder, pred, left_val, right_val, "");
                }
            }
            
            // 指针比较运算符（仅支持 == 和 !=）
            if (LLVMGetTypeKind(left_type) == LLVMPointerTypeKind &&
                LLVMGetTypeKind(right_type) == LLVMPointerTypeKind) {
                
                // 仅支持 == 和 != 运算符
                if (op == TOKEN_EQUAL) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntEQ, left_val, right_val, "");
                } else if (op == TOKEN_NOT_EQUAL) {
                    return LLVMBuildICmp(codegen->builder, LLVMIntNE, left_val, right_val, "");
                }
                // 指针不支持其他比较运算符（<, >, <=, >=）
                return NULL;
            }
            
            // 结构体比较运算符（仅支持 == 和 !=）
            if (LLVMGetTypeKind(left_type) == LLVMStructTypeKind &&
                LLVMGetTypeKind(right_type) == LLVMStructTypeKind) {
                
                // 仅支持 == 和 != 运算符
                if (op == TOKEN_EQUAL || op == TOKEN_NOT_EQUAL) {
                    // 从LLVM类型查找结构体名称
                    const char *struct_name = find_struct_name_from_type(codegen, left_type);
                    if (!struct_name) {
                        return NULL;
                    }
                    
                    // 查找结构体声明
                    ASTNode *struct_decl = find_struct_decl(codegen, struct_name);
                    if (!struct_decl) {
                        return NULL;
                    }
                    
                    // 调用结构体比较函数
                    int is_equal = (op == TOKEN_EQUAL) ? 1 : 0;
                    return codegen_gen_struct_comparison(
                        codegen,
                        left_val,
                        right_val,
                        struct_decl,
                        is_equal
                    );
                }
                // 结构体不支持其他比较运算符（<, >, <=, >=）
                return NULL;
            }
            

            
            return NULL;
        }
        
        case AST_IDENTIFIER: {
            // 标识符：从变量表查找变量，然后加载值
            const char *var_name = expr->data.identifier.name;
            if (!var_name) {
                return NULL;
            }
            
            // 特殊处理 null 标识符：null 不是变量，但在比较运算符中会被特殊处理
            // 这里返回 NULL，让调用者（比较运算符）来处理
            if (strcmp(var_name, "null") == 0) {
                return NULL;  // null 标识符在比较运算符中会被特殊处理
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
            LLVMTypeRef func_type = NULL;
            LLVMValueRef func = lookup_func(codegen, func_name, &func_type);
            if (!func || !func_type) {
                return NULL;  // 函数未找到或函数类型无效
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
            return LLVMBuildCall2(codegen->builder, func_type, func, args, arg_count, "");
        }
            
        case AST_MEMBER_ACCESS: {
            // 字段访问或枚举值访问：使用 GEP + Load 获取字段值，或返回枚举值常量
            ASTNode *object = expr->data.member_access.object;
            const char *field_name = expr->data.member_access.field_name;
            
            if (!object || !field_name) {
                return NULL;
            }
            
            // 检查是否是枚举值访问（EnumName.Variant）
            // 如果对象是标识符且不是变量，可能是枚举类型名称
            if (object->type == AST_IDENTIFIER) {
                const char *enum_name = object->data.identifier.name;
                if (enum_name) {
                    // 检查是否是枚举类型名称（先检查变量表，如果不是变量，可能是枚举类型）
                    LLVMValueRef var_ptr = lookup_var(codegen, enum_name);
                    if (!var_ptr) {
                        // 不是变量，可能是枚举类型名称
                        ASTNode *enum_decl = find_enum_decl(codegen, enum_name);
                        if (enum_decl != NULL) {
                            // 是枚举类型，查找变体索引
                            int variant_index = find_enum_variant_index(enum_decl, field_name);
                            if (variant_index >= 0) {
                                // 获取枚举值（显式值或计算值）
                                int enum_value = get_enum_variant_value(enum_decl, variant_index);
                                if (enum_value < 0) {
                                    return NULL;
                                }
                                
                                // 找到变体，返回i32常量
                                LLVMTypeRef i32_type = codegen_get_base_type(codegen, TYPE_I32);
                                if (!i32_type) {
                                    return NULL;
                                }
                                return LLVMConstInt(i32_type, (unsigned long long)enum_value, 0);
                            }
                            // 变体不存在
                            return NULL;
                        }
                    }
                }
            }
            
            // 如果对象是标识符（变量），从变量表获取结构体名称
            const char *struct_name = NULL;
            LLVMValueRef object_ptr = NULL;
            
            if (object->type == AST_IDENTIFIER) {
                const char *var_name = object->data.identifier.name;
                if (var_name) {
                    object_ptr = lookup_var(codegen, var_name);
                    struct_name = lookup_var_struct_name(codegen, var_name);
                    
                    // 检查变量类型是否是指针类型（无论 struct_name 是否设置）
                    ASTNode *var_ast_type = lookup_var_ast_type(codegen, var_name);
                    if (var_ast_type && var_ast_type->type == AST_TYPE_POINTER) {
                        // 变量是指针类型，需要加载指针值
                        LLVMTypeRef var_type = lookup_var_type(codegen, var_name);
                        if (var_type && object_ptr) {
                            // 加载指针变量的值（即指针值本身）
                            object_ptr = LLVMBuildLoad2(codegen->builder, var_type, object_ptr, var_name);
                            
                            // 从指针类型中获取指向的结构体类型名称
                            ASTNode *pointed_type = var_ast_type->data.type_pointer.pointed_type;
                            if (pointed_type && pointed_type->type == AST_TYPE_NAMED) {
                                struct_name = pointed_type->data.type_named.name;
                            }
                        }
                    }
                }
            }
            
            if (!object_ptr) {
                // 对象不是标识符或变量未找到，生成对象表达式
                LLVMValueRef object_val = codegen_gen_expr(codegen, object);
                if (!object_val) {
                    return NULL;
                }
                
                // 对于非标识符对象（如结构体字面量、嵌套字段访问），需要先 store 到临时变量
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
                
                // 获取结构体名称
                if (object->type == AST_STRUCT_INIT) {
                    // 对于结构体字面量，可以从 AST 获取结构体名称
                    struct_name = object->data.struct_init.struct_name;
                } else if (object->type == AST_MEMBER_ACCESS) {
                    // 对于嵌套字段访问，从对象值的类型中获取结构体名称
                    // 检查类型是否为结构体类型
                    if (LLVMGetTypeKind(object_type) == LLVMStructTypeKind) {
                        struct_name = find_struct_name_from_type(codegen, object_type);
                    }
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
            indices[0] = LLVMConstInt(LLVMInt32Type(), 0ULL, 0);  // 结构体指针本身
            indices[1] = LLVMConstInt(LLVMInt32Type(), (unsigned long long)field_index, 0);  // 字段索引
            
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
        
        case AST_ARRAY_ACCESS: {
            // 数组访问：使用 GEP + Load 获取元素值
            ASTNode *array_expr = expr->data.array_access.array;
            ASTNode *index_expr = expr->data.array_access.index;
            
            if (!array_expr || !index_expr) {
                return NULL;
            }
            
            // 生成数组表达式值（可能是标识符、数组字面量等）
            LLVMValueRef array_val = codegen_gen_expr(codegen, array_expr);
            if (!array_val) {
                return NULL;
            }
            
            LLVMTypeRef array_val_type = LLVMTypeOf(array_val);
            if (!array_val_type) {
                return NULL;
            }
            
            // 检查是否是数组类型
            LLVMTypeKind array_val_kind = LLVMGetTypeKind(array_val_type);
            LLVMTypeRef array_type = NULL;
            LLVMValueRef array_ptr = NULL;
            
            if (array_val_kind == LLVMArrayTypeKind) {
                // 数组值类型，需要分配临时空间存储数组值
                array_type = array_val_type;
                array_ptr = LLVMBuildAlloca(codegen->builder, array_type, "");
                if (!array_ptr) {
                    return NULL;
                }
                LLVMBuildStore(codegen->builder, array_val, array_ptr);
            } else if (array_val_kind == LLVMPointerTypeKind) {
                // 指针类型（数组变量在栈上的地址）
                array_ptr = array_val;
                array_type = LLVMGetElementType(array_val_type);
                if (!array_type || LLVMGetTypeKind(array_type) != LLVMArrayTypeKind) {
                    return NULL;  // 指针指向的不是数组类型
                }
            } else {
                return NULL;  // 不是数组类型
            }
            
            // 生成索引表达式值
            LLVMValueRef index_val = codegen_gen_expr(codegen, index_expr);
            if (!index_val) {
                return NULL;
            }
            
            // 获取元素类型
            LLVMTypeRef element_type = LLVMGetElementType(array_type);
            if (!element_type) {
                return NULL;
            }
            
            // 使用 GEP 获取元素地址
            LLVMValueRef indices[2];
            indices[0] = LLVMConstInt(LLVMInt32Type(), 0ULL, 0);  // 数组指针本身
            indices[1] = index_val;  // 元素索引（运行时值）
            
            LLVMValueRef element_ptr = LLVMBuildGEP2(codegen->builder, array_type, array_ptr, indices, 2, "");
            if (!element_ptr) {
                return NULL;
            }
            
            // load 元素值
            return LLVMBuildLoad2(codegen->builder, element_type, element_ptr, "");
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
            
            // 检查字段数组：如果 field_count > 0，数组必须不为 NULL
            if (field_count > 0) {
                if (!field_names || !field_values) {
                    return NULL;  // 字段数组为 NULL 但字段数量 > 0
                }
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
                indices[0] = LLVMConstInt(LLVMInt32Type(), 0ULL, 0);  // 结构体指针本身
                indices[1] = LLVMConstInt(LLVMInt32Type(), (unsigned long long)field_index, 0);  // 字段索引
                
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
        
        case AST_ARRAY_LITERAL: {
            // 数组字面量：使用 alloca + store 创建数组值
            int element_count = expr->data.array_literal.element_count;
            ASTNode **elements = expr->data.array_literal.elements;
            
            if (element_count == 0) {
                // 空数组：无法推断类型，返回NULL
                return NULL;
            }
            
            // 从第一个元素生成值以推断元素类型
            LLVMValueRef first_element_val = codegen_gen_expr(codegen, elements[0]);
            if (!first_element_val) {
                return NULL;
            }
            
            LLVMTypeRef element_type = LLVMTypeOf(first_element_val);
            if (!element_type) {
                return NULL;
            }
            
            // 创建数组类型
            LLVMTypeRef array_type = LLVMArrayType(element_type, (unsigned int)element_count);
            if (!array_type) {
                return NULL;
            }
            
            // 使用 alloca 分配数组空间
            LLVMValueRef array_ptr = LLVMBuildAlloca(codegen->builder, array_type, "");
            if (!array_ptr) {
                return NULL;
            }
            
            // 为每个元素生成值并 store 到数组中
            for (int i = 0; i < element_count; i++) {
                ASTNode *element = elements[i];
                if (!element) {
                    return NULL;
                }
                
                // 生成元素值
                LLVMValueRef element_val = codegen_gen_expr(codegen, element);
                if (!element_val) {
                    return NULL;
                }
                
                // 使用 GEP 获取元素地址
                LLVMValueRef indices[2];
                indices[0] = LLVMConstInt(LLVMInt32Type(), 0ULL, 0);  // 数组指针本身
                indices[1] = LLVMConstInt(LLVMInt32Type(), (unsigned long long)i, 0);  // 元素索引
                
                LLVMValueRef element_ptr = LLVMBuildGEP2(codegen->builder, array_type, array_ptr, indices, 2, "");
                if (!element_ptr) {
                    return NULL;
                }
                
                // store 元素值到元素地址
                LLVMBuildStore(codegen->builder, element_val, element_ptr);
            }
            
            // 返回数组值（load 数组指针）
            return LLVMBuildLoad2(codegen->builder, array_type, array_ptr, "");
        }
        
        case AST_SIZEOF: {
            // sizeof 表达式：返回类型大小（i32 常量）
            ASTNode *target = expr->data.sizeof_expr.target;
            int is_type = expr->data.sizeof_expr.is_type;
            
            if (!target) {
                return NULL;
            }
            
            LLVMTypeRef llvm_type = NULL;
            
            if (is_type) {
                // target 是类型节点
                llvm_type = get_llvm_type_from_ast(codegen, target);
            } else {
                // target 是表达式节点，需要获取类型而不生成代码
                // 对于标识符（变量），直接从变量表获取类型
                if (target->type == AST_IDENTIFIER) {
                    const char *var_name = target->data.identifier.name;
                    if (!var_name) {
                        return NULL;
                    }
                    llvm_type = lookup_var_type(codegen, var_name);
                    // 如果变量表中找不到，可能是枚举类型或结构体类型名称（在 sizeof 中）
                    // 尝试作为类型名称处理
                    if (!llvm_type) {
                        // 先检查是否是枚举类型（枚举类型在LLVM中就是i32类型）
                        ASTNode *enum_decl = find_enum_decl(codegen, var_name);
                        if (enum_decl != NULL) {
                            llvm_type = codegen_get_base_type(codegen, TYPE_I32);
                        } else {
                            // 检查是否是结构体类型
                            LLVMTypeRef struct_type = codegen_get_struct_type(codegen, var_name);
                            if (struct_type) {
                                llvm_type = struct_type;
                            } else {
                                return NULL;
                            }
                        }
                    }
                } else {
                    // 对于其他表达式类型，生成代码以获取类型
                    LLVMValueRef target_val = codegen_gen_expr(codegen, target);
                    if (!target_val) {
                        return NULL;
                    }
                    llvm_type = LLVMTypeOf(target_val);
                }
            }
            
            if (!llvm_type) {
                return NULL;
            }
            
            // 获取类型大小（字节数）
            // 注意：这里使用简化实现，对于基础类型直接返回常量
            // 对于复杂类型（结构体、数组），需要使用 TargetData 获取准确大小
            unsigned long long size = 0;
            
            LLVMTypeKind kind = LLVMGetTypeKind(llvm_type);
            switch (kind) {
                case LLVMIntegerTypeKind: {
                    // 整数类型：根据位宽计算字节数
                    unsigned width = LLVMGetIntTypeWidth(llvm_type);
                    size = (width + 7) / 8;  // 向上取整到字节
                    break;
                }
                case LLVMPointerTypeKind: {
                    // 指针类型：使用 TargetData API 获取指针大小（平台相关）
                    // 注意：DataLayout 应该在 codegen_generate() 的第零步就已经设置
                    LLVMTargetDataRef target_data = LLVMGetModuleDataLayout(codegen->module);
                    if (!target_data) {
                        // 如果无法获取 TargetData，返回错误（不应该发生，因为 DataLayout 已设置）
                        return NULL;
                    }
                    size = LLVMPointerSize(target_data);
                    break;
                }
                case LLVMArrayTypeKind: {
                    // 数组类型：元素大小 * 元素数量
                    LLVMTypeRef element_type = LLVMGetElementType(llvm_type);
                    unsigned element_count = LLVMGetArrayLength(llvm_type);
                    // 获取元素大小（递归计算）
                    LLVMTypeKind element_kind = LLVMGetTypeKind(element_type);
                    unsigned long long element_size = 0;
                    if (element_kind == LLVMIntegerTypeKind) {
                        unsigned width = LLVMGetIntTypeWidth(element_type);
                        element_size = (width + 7) / 8;
                    } else if (element_kind == LLVMPointerTypeKind) {
                        // 指针类型：使用 TargetData API 获取指针大小（平台相关）
                        // 注意：DataLayout 应该在 codegen_generate() 的第零步就已经设置
                        LLVMTargetDataRef target_data = LLVMGetModuleDataLayout(codegen->module);
                        if (!target_data) {
                            // 如果无法获取 TargetData，返回错误（不应该发生，因为 DataLayout 已设置）
                            return NULL;
                        }
                        element_size = LLVMPointerSize(target_data);
                    } else if (element_kind == LLVMStructTypeKind) {
                        // 结构体类型的数组：使用 TargetData 获取元素大小
                        LLVMTargetDataRef target_data = LLVMGetModuleDataLayout(codegen->module);
                        if (!target_data) {
                            return NULL;  // 模块的 DataLayout 未设置
                        }
                        element_size = LLVMStoreSizeOfType(target_data, element_type);
                    } else {
                        // 其他复杂类型，无法计算大小
                        return NULL;
                    }
                    size = element_size * element_count;
                    break;
                }
                case LLVMStructTypeKind: {
                    // 结构体类型：使用 TargetData 获取准确大小
                    LLVMTargetDataRef target_data = LLVMGetModuleDataLayout(codegen->module);
                    if (!target_data) {
                        return NULL;  // 模块的 DataLayout 未设置
                    }
                    // 使用 LLVMStoreSizeOfType 获取结构体的存储大小（字节数）
                    size = LLVMStoreSizeOfType(target_data, llvm_type);
                    
                    // 特殊处理：空结构体的大小应该是 1 字节（规范要求）
                    // LLVM 对空结构体返回 0，但根据规范（2.3.6 节），空结构体大小为 1 字节
                    if (size == 0) {
                        // 检查是否是空结构体（通过检查字段数）
                        unsigned element_count = LLVMCountStructElementTypes(llvm_type);
                        if (element_count == 0) {
                            size = 1;  // 空结构体大小为 1 字节
                        }
                    }
                    break;
                }
                default:
                    // 其他类型，无法计算大小
                    return NULL;
            }
            
            // 创建 i32 常量
            LLVMTypeRef i32_type = codegen_get_base_type(codegen, TYPE_I32);
            if (!i32_type) {
                return NULL;
            }
            return LLVMConstInt(i32_type, size, 0);  // 无符号整数
        }
        
        case AST_ALIGNOF: {
            // alignof 表达式：返回类型对齐值（i32 常量）
            ASTNode *target = expr->data.alignof_expr.target;
            int is_type = expr->data.alignof_expr.is_type;
            
            if (!target) {
                return NULL;
            }
            
            LLVMTypeRef llvm_type = NULL;
            
            if (is_type) {
                // target 是类型节点
                llvm_type = get_llvm_type_from_ast(codegen, target);
            } else {
                // target 是表达式节点，需要获取类型而不生成代码
                // 对于标识符（变量），直接从变量表获取类型
                if (target->type == AST_IDENTIFIER) {
                    const char *var_name = target->data.identifier.name;
                    if (!var_name) {
                        return NULL;
                    }
                    llvm_type = lookup_var_type(codegen, var_name);
                    // 如果变量表中找不到，可能是枚举类型或结构体类型名称（在 alignof 中）
                    // 尝试作为类型名称处理
                    if (!llvm_type) {
                        // 先检查是否是枚举类型（枚举类型在LLVM中就是i32类型）
                        ASTNode *enum_decl = find_enum_decl(codegen, var_name);
                        if (enum_decl != NULL) {
                            llvm_type = codegen_get_base_type(codegen, TYPE_I32);
                        } else {
                            // 检查是否是结构体类型
                            LLVMTypeRef struct_type = codegen_get_struct_type(codegen, var_name);
                            if (struct_type) {
                                llvm_type = struct_type;
                            } else {
                                return NULL;
                            }
                        }
                    }
                } else {
                    // 对于其他表达式类型，生成代码以获取类型
                    LLVMValueRef target_val = codegen_gen_expr(codegen, target);
                    if (!target_val) {
                        return NULL;
                    }
                    llvm_type = LLVMTypeOf(target_val);
                }
            }
            
            if (!llvm_type) {
                return NULL;
            }
            
            // 获取类型对齐值（字节数）
            // 使用 TargetData 获取准确的对齐值
            LLVMTargetDataRef target_data = LLVMGetModuleDataLayout(codegen->module);
            if (!target_data) {
                return NULL;  // 模块的 DataLayout 未设置
            }
            
            unsigned long long alignment = 0;
            
            LLVMTypeKind kind = LLVMGetTypeKind(llvm_type);
            switch (kind) {
                case LLVMIntegerTypeKind: {
                    // 整数类型：使用 TargetData 获取对齐值
                    alignment = LLVMABIAlignmentOfType(target_data, llvm_type);
                    break;
                }
                case LLVMPointerTypeKind: {
                    // 指针类型：使用 TargetData 获取对齐值（平台相关）
                    alignment = LLVMABIAlignmentOfType(target_data, llvm_type);
                    break;
                }
                case LLVMArrayTypeKind: {
                    // 数组类型：对齐值等于元素类型的对齐值
                    LLVMTypeRef element_type = LLVMGetElementType(llvm_type);
                    alignment = LLVMABIAlignmentOfType(target_data, element_type);
                    break;
                }
                case LLVMStructTypeKind: {
                    // 结构体类型：使用 TargetData 获取对齐值（等于最大字段对齐值）
                    alignment = LLVMABIAlignmentOfType(target_data, llvm_type);
                    break;
                }
                default:
                    // 其他类型，无法计算对齐值
                    return NULL;
            }
            
            // 创建 i32 常量
            LLVMTypeRef i32_type = codegen_get_base_type(codegen, TYPE_I32);
            if (!i32_type) {
                return NULL;
            }
            return LLVMConstInt(i32_type, alignment, 0);  // 无符号整数
        }
        
        case AST_LEN: {
            // len 表达式：返回数组元素个数（i32 常量）
            ASTNode *array_expr = expr->data.len_expr.array;
            
            if (!array_expr) {
                return NULL;
            }
            
            LLVMTypeRef array_type = NULL;
            
            // 获取数组表达式的类型
            if (array_expr->type == AST_IDENTIFIER) {
                // 标识符（变量）：从变量表获取类型
                const char *var_name = array_expr->data.identifier.name;
                if (!var_name) {
                    return NULL;
                }
                array_type = lookup_var_type(codegen, var_name);
            } else {
                // 其他表达式类型：生成代码以获取类型
                LLVMValueRef array_val = codegen_gen_expr(codegen, array_expr);
                if (!array_val) {
                    return NULL;
                }
                array_type = LLVMTypeOf(array_val);
            }
            
            if (!array_type) {
                return NULL;
            }
            
            // 验证是数组类型
            LLVMTypeKind kind = LLVMGetTypeKind(array_type);
            if (kind != LLVMArrayTypeKind) {
                return NULL;  // 不是数组类型
            }
            
            // 获取数组长度（元素个数）
            unsigned element_count = LLVMGetArrayLength(array_type);
            
            // 创建 i32 常量
            LLVMTypeRef i32_type = codegen_get_base_type(codegen, TYPE_I32);
            if (!i32_type) {
                return NULL;
            }
            return LLVMConstInt(i32_type, element_count, 0);  // 无符号整数
        }
        
        case AST_CAST_EXPR: {
            // 类型转换表达式（expr as type）
            ASTNode *expr_node = expr->data.cast_expr.expr;
            ASTNode *target_type_node = expr->data.cast_expr.target_type;
            
            if (!expr_node || !target_type_node) {
                return NULL;
            }
            
            // 生成源表达式代码
            LLVMValueRef source_val = codegen_gen_expr(codegen, expr_node);
            if (!source_val) {
                return NULL;
            }
            
            // 获取目标类型
            LLVMTypeRef target_type = get_llvm_type_from_ast(codegen, target_type_node);
            if (!target_type) {
                return NULL;
            }
            
            LLVMTypeRef source_type = LLVMTypeOf(source_val);
            LLVMTypeKind source_kind = LLVMGetTypeKind(source_type);
            LLVMTypeKind target_kind = LLVMGetTypeKind(target_type);
            
            // 根据源类型和目标类型进行转换
            if (source_kind == LLVMIntegerTypeKind && target_kind == LLVMIntegerTypeKind) {
                unsigned source_width = LLVMGetIntTypeWidth(source_type);
                unsigned target_width = LLVMGetIntTypeWidth(target_type);
                
                // 获取 usize 类型宽度（用于判断 i32 ↔ usize 转换）
                LLVMTypeRef usize_type = codegen_get_base_type(codegen, TYPE_USIZE);
                unsigned usize_width = 0;
                if (usize_type) {
                    usize_width = LLVMGetIntTypeWidth(usize_type);
                }
                
                if (source_width == 32 && target_width == 8) {
                    // i32 as byte：截断转换（保留低 8 位）
                    return LLVMBuildTrunc(codegen->builder, source_val, target_type, "");
                } else if (source_width == 8 && target_width == 32) {
                    // byte as i32：零扩展转换（无符号扩展）
                    return LLVMBuildZExt(codegen->builder, source_val, target_type, "");
                } else if (source_width == 32 && target_width == 1) {
                    // i32 as bool：非零值为 true，零值为 false
                    LLVMTypeRef i32_type = codegen_get_base_type(codegen, TYPE_I32);
                    if (!i32_type) {
                        return NULL;
                    }
                    LLVMValueRef zero = LLVMConstInt(i32_type, 0, 1);  // 有符号零
                    return LLVMBuildICmp(codegen->builder, LLVMIntNE, source_val, zero, "");
                } else if (source_width == 1 && target_width == 32) {
                    // bool as i32：true 转换为 1，false 转换为 0（零扩展）
                    return LLVMBuildZExt(codegen->builder, source_val, target_type, "");
                } else if (source_width == 32 && target_width == usize_width && usize_width > 0) {
                    // i32 as usize：零扩展转换（如果 usize 是 64 位）或直接使用（如果 usize 是 32 位）
                    if (usize_width > 32) {
                        return LLVMBuildZExt(codegen->builder, source_val, target_type, "");
                    } else {
                        // 32位平台：usize 也是 32 位，直接返回（虽然类型不同，但宽度相同）
                        // 实际上在这种情况下，我们可能需要重新解释，但 LLVM 不支持位相同的类型重新解释
                        // 所以使用零扩展（虽然是 no-op）
                        return LLVMBuildZExt(codegen->builder, source_val, target_type, "");
                    }
                } else if (source_width == usize_width && target_width == 32 && usize_width > 0) {
                    // usize as i32：截断转换（如果 usize 是 64 位）或直接使用（如果 usize 是 32 位）
                    if (usize_width > 32) {
                        return LLVMBuildTrunc(codegen->builder, source_val, target_type, "");
                    } else {
                        // 32位平台：usize 也是 32 位，使用截断（虽然是 no-op）
                        return LLVMBuildTrunc(codegen->builder, source_val, target_type, "");
                    }
                }
            }
            
            // 不支持的转换（类型检查阶段应该已经拒绝）
            return NULL;
        }
            
        default:
            return NULL;
    }
}

// 辅助函数：生成分支代码并确保控制流正确连接
// 参数：codegen - 代码生成器指针
//       branch_bb - 分支基本块（代码生成的位置）
//       branch_stmt - 分支语句AST节点（AST_BLOCK节点）
//       target_bb - 目标基本块（如果分支没有终止符，跳转到这里）
// 返回：成功返回0，失败返回非0
// 说明：此函数在branch_bb中生成分支代码，生成后检查当前构建器所在的基本块是否有终止符。
//       如果当前基本块没有终止符（说明控制流需要继续），添加跳转到target_bb。
//       这正确处理了嵌套控制流的情况（嵌套if、while等会创建自己的基本块）。
static int gen_branch_with_terminator(CodeGenerator *codegen, 
                                       LLVMBasicBlockRef branch_bb,
                                       ASTNode *branch_stmt,
                                       LLVMBasicBlockRef target_bb) {
    if (!codegen || !branch_bb || !branch_stmt || !target_bb) {
        return -1;
    }
    
    // 定位构建器到分支基本块
    LLVMPositionBuilderAtEnd(codegen->builder, branch_bb);
    
    // 生成分支代码（可能包含嵌套控制流，构建器可能被移动到其他基本块）
    if (codegen_gen_stmt(codegen, branch_stmt) != 0) {
        return -1;
    }
    
    // 检查当前构建器所在的基本块是否有终止符
    // 如果分支包含嵌套控制流，构建器可能已经移动到其他基本块
    LLVMBasicBlockRef current_bb = LLVMGetInsertBlock(codegen->builder);
    if (current_bb && !LLVMGetBasicBlockTerminator(current_bb)) {
        // 当前基本块没有终止符，添加跳转到目标基本块
        LLVMBuildBr(codegen->builder, target_bb);
    }
    
    return 0;
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
                    strcmp(type_name, "bool") != 0 && strcmp(type_name, "byte") != 0 && 
                    strcmp(type_name, "void") != 0) {
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
            if (add_var(codegen, var_name, var_ptr, llvm_type, struct_name, var_type) != 0) {
                return -1;
            }
            
            // 如果有初始值，生成初始值代码并 store
            if (init_expr) {
                LLVMValueRef init_val = NULL;
                
                // 特殊处理空数组字面量：如果变量类型是数组类型，空数组表示未初始化
                if (init_expr->type == AST_ARRAY_LITERAL &&
                    init_expr->data.array_literal.element_count == 0 &&
                    LLVMGetTypeKind(llvm_type) == LLVMArrayTypeKind) {
                    // 空数组字面量用于数组类型变量，不进行初始化（变量已通过 alloca 分配，内容未定义）
                    // 跳过初始化代码生成
                    init_val = NULL;
                }
                // 特殊处理 null 标识符：检查是否是 null 字面量
                else if (init_expr->type == AST_IDENTIFIER) {
                    const char *init_name = init_expr->data.identifier.name;
                    if (init_name && strcmp(init_name, "null") == 0) {
                        // null 字面量：检查变量类型是否为指针类型
                        if (LLVMGetTypeKind(llvm_type) == LLVMPointerTypeKind) {
                            init_val = LLVMConstNull(llvm_type);
                        } else {
                            fprintf(stderr, "错误: 变量 %s 的类型不是指针类型，不能初始化为 null\n", var_name);
                            return -1;
                        }
                    }
                }
                
                // 如果不是特殊处理的情况，使用通用方法生成初始值
                if (!init_val && !(init_expr->type == AST_ARRAY_LITERAL &&
                                   init_expr->data.array_literal.element_count == 0 &&
                                   LLVMGetTypeKind(llvm_type) == LLVMArrayTypeKind)) {
                    init_val = codegen_gen_expr(codegen, init_expr);
                    if (!init_val) {
                        fprintf(stderr, "错误: 变量 %s 的初始值表达式生成失败\n", var_name);
                        return -1;
                    }
                }
                
                // 如果有初始值（空数组字面量时 init_val 为 NULL，跳过 store）
                if (init_val) {
                    // 检查类型是否匹配，如果不匹配则进行类型转换
                    LLVMTypeRef init_type = LLVMTypeOf(init_val);
                    if (init_type != llvm_type) {
                        // 类型不匹配，需要进行类型转换
                        LLVMTypeKind var_type_kind = LLVMGetTypeKind(llvm_type);
                        LLVMTypeKind init_type_kind = LLVMGetTypeKind(init_type);
                        
                        if (var_type_kind == LLVMIntegerTypeKind && init_type_kind == LLVMIntegerTypeKind) {
                            // 整数类型之间的转换
                            unsigned var_width = LLVMGetIntTypeWidth(llvm_type);
                            unsigned init_width = LLVMGetIntTypeWidth(init_type);
                            
                            if (var_width < init_width) {
                                // 截断转换（例如 i32 -> i8）
                                init_val = LLVMBuildTrunc(codegen->builder, init_val, llvm_type, "");
                            } else if (var_width > init_width) {
                                // 零扩展转换（例如 i8 -> i32，byte 是无符号的，使用零扩展）
                                init_val = LLVMBuildZExt(codegen->builder, init_val, llvm_type, "");
                            }
                            // 如果宽度相同，类型应该相同，不需要转换
                        }
                        // 其他类型不匹配的情况会在类型检查阶段被拒绝
                    }
                    
                    LLVMBuildStore(codegen->builder, init_val, var_ptr);
                }
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
            // 赋值语句：生成源表达式值，store 到目标左值表达式
            ASTNode *dest = stmt->data.assign.dest;
            ASTNode *src = stmt->data.assign.src;
            
            if (!dest || !src) {
                return -1;
            }
            
            // 生成目标左值表达式的地址
            LLVMValueRef dest_ptr = codegen_gen_lvalue_address(codegen, dest);
            if (!dest_ptr) {
                return -1;  // 无法生成左值地址（不支持的类型或错误）
            }
            
            // 生成源表达式值
            LLVMValueRef src_val = codegen_gen_expr(codegen, src);
            if (!src_val) {
                return -1;
            }
            
            // store 值到目标地址
            // LLVMBuildStore 会自动处理类型匹配
            LLVMBuildStore(codegen->builder, src_val, dest_ptr);
            
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
                fprintf(stderr, "错误: 条件表达式生成失败\n");
                return -1;
            }
            
            // 获取当前函数
            LLVMValueRef current_func = LLVMGetBasicBlockParent(LLVMGetInsertBlock(codegen->builder));
            if (!current_func) {
                return -1;
            }
            
            // 创建基本块（使用计数器生成唯一名称）
            int bb_id = codegen->basic_block_counter++;
            char then_name[32], end_name[32], else_name[32];
            snprintf(then_name, sizeof(then_name), "if.then.%d", bb_id);
            snprintf(end_name, sizeof(end_name), "if.end.%d", bb_id);
            LLVMBasicBlockRef then_bb = LLVMAppendBasicBlock(current_func, then_name);
            LLVMBasicBlockRef end_bb = LLVMAppendBasicBlock(current_func, end_name);
            
            // 生成条件分支指令
            if (else_branch) {
                // 有else分支：
                // 1. 创建else_bb
                // 2. 生成条件分支指令：条件为真跳转到then_bb，条件为假跳转到else_bb
                // 3. 生成then分支代码
                // 4. 生成else分支代码
                
                snprintf(else_name, sizeof(else_name), "if.else.%d", bb_id);
                LLVMBasicBlockRef else_bb = LLVMAppendBasicBlock(current_func, else_name);
                
                // 生成条件分支指令
                LLVMBuildCondBr(codegen->builder, cond_val, then_bb, else_bb);
                
                // 生成then分支代码（使用辅助函数处理嵌套控制流）
                if (gen_branch_with_terminator(codegen, then_bb, then_branch, end_bb) != 0) {
                    return -1;
                }
                
                // 生成else分支代码（使用辅助函数处理嵌套控制流）
                if (gen_branch_with_terminator(codegen, else_bb, else_branch, end_bb) != 0) {
                    return -1;
                }
            } else {
                // 没有else分支：
                // 1. 生成条件分支指令：条件为真跳转到then_bb，条件为假跳转到end_bb
                // 2. 生成then分支代码
                
                // 生成条件分支指令
                LLVMBuildCondBr(codegen->builder, cond_val, then_bb, end_bb);
                
                // 生成then分支代码（使用辅助函数处理嵌套控制流）
                if (gen_branch_with_terminator(codegen, then_bb, then_branch, end_bb) != 0) {
                    return -1;
                }
            }
            
            // 最后设置构建器到end_bb
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
            
            // 创建基本块：cond（条件检查）、body（循环体）、end（结束）（使用计数器生成唯一名称）
            int bb_id = codegen->basic_block_counter++;
            char cond_name[32], body_name[32], end_name[32];
            snprintf(cond_name, sizeof(cond_name), "while.cond.%d", bb_id);
            snprintf(body_name, sizeof(body_name), "while.body.%d", bb_id);
            snprintf(end_name, sizeof(end_name), "while.end.%d", bb_id);
            LLVMBasicBlockRef cond_bb = LLVMAppendBasicBlock(current_func, cond_name);
            LLVMBasicBlockRef body_bb = LLVMAppendBasicBlock(current_func, body_name);
            LLVMBasicBlockRef end_bb = LLVMAppendBasicBlock(current_func, end_name);
            
            // 将循环基本块推入栈（用于 break/continue）
            if (codegen->loop_stack_depth >= LOOP_STACK_SIZE) {
                return -1;  // 循环嵌套过深
            }
            codegen->loop_stack[codegen->loop_stack_depth].cond_bb = cond_bb;
            codegen->loop_stack[codegen->loop_stack_depth].end_bb = end_bb;
            codegen->loop_stack[codegen->loop_stack_depth].inc_bb = NULL;  // while 循环没有 inc_bb
            codegen->loop_stack_depth++;
            
            // 跳转到条件检查
            LLVMBuildBr(codegen->builder, cond_bb);
            
            // 生成条件检查
            LLVMPositionBuilderAtEnd(codegen->builder, cond_bb);
            LLVMValueRef cond_val = codegen_gen_expr(codegen, condition);
            if (!cond_val) {
                codegen->loop_stack_depth--;  // 错误恢复：弹出栈
                return -1;
            }
            LLVMBuildCondBr(codegen->builder, cond_val, body_bb, end_bb);
            
            // 生成循环体
            LLVMPositionBuilderAtEnd(codegen->builder, body_bb);
            if (codegen_gen_stmt(codegen, body) != 0) {
                codegen->loop_stack_depth--;  // 错误恢复：弹出栈
                return -1;
            }
            
            // 检查循环体结束前是否需要跳转（如果已经有终止符，不需要再跳转）
            LLVMBasicBlockRef current_bb = LLVMGetInsertBlock(codegen->builder);
            if (current_bb && !LLVMGetBasicBlockTerminator(current_bb)) {
                // 循环体结束前跳转到条件检查（continue 会跳过这里）
                LLVMBuildBr(codegen->builder, cond_bb);
            }
            
            // 从栈中弹出循环信息
            codegen->loop_stack_depth--;
            
            // 设置构建器到 end 基本块
            LLVMPositionBuilderAtEnd(codegen->builder, end_bb);
            
            return 0;
        }
        
        case AST_FOR_STMT: {
            // for 语句：数组遍历循环
            ASTNode *array_expr = stmt->data.for_stmt.array;
            const char *var_name = stmt->data.for_stmt.var_name;
            int is_ref = stmt->data.for_stmt.is_ref;
            ASTNode *body = stmt->data.for_stmt.body;
            
            if (!array_expr || !var_name || !body) {
                return -1;
            }
            
            // 获取当前函数
            LLVMValueRef current_func = LLVMGetBasicBlockParent(LLVMGetInsertBlock(codegen->builder));
            if (!current_func) {
                return -1;
            }
            
            // 创建基本块：init（初始化）、cond（条件检查）、body（循环体）、inc（递增）、end（结束）
            int bb_id = codegen->basic_block_counter++;
            char init_name[32], cond_name[32], body_name[32], inc_name[32], end_name[32];
            snprintf(init_name, sizeof(init_name), "for.init.%d", bb_id);
            snprintf(cond_name, sizeof(cond_name), "for.cond.%d", bb_id);
            snprintf(body_name, sizeof(body_name), "for.body.%d", bb_id);
            snprintf(inc_name, sizeof(inc_name), "for.inc.%d", bb_id);
            snprintf(end_name, sizeof(end_name), "for.end.%d", bb_id);
            LLVMBasicBlockRef init_bb = LLVMAppendBasicBlock(current_func, init_name);
            LLVMBasicBlockRef cond_bb = LLVMAppendBasicBlock(current_func, cond_name);
            LLVMBasicBlockRef body_bb = LLVMAppendBasicBlock(current_func, body_name);
            LLVMBasicBlockRef inc_bb = LLVMAppendBasicBlock(current_func, inc_name);
            LLVMBasicBlockRef end_bb = LLVMAppendBasicBlock(current_func, end_name);
            
            // 将循环基本块推入栈（用于 break/continue）
            if (codegen->loop_stack_depth >= LOOP_STACK_SIZE) {
                return -1;  // 循环嵌套过深
            }
            codegen->loop_stack[codegen->loop_stack_depth].cond_bb = cond_bb;
            codegen->loop_stack[codegen->loop_stack_depth].end_bb = end_bb;
            codegen->loop_stack[codegen->loop_stack_depth].inc_bb = inc_bb;  // for 循环有 inc_bb
            codegen->loop_stack_depth++;
            
            // 在当前基本块分配循环索引变量 i（在所有基本块中使用）
            LLVMTypeRef i32_type = codegen_get_base_type(codegen, TYPE_I32);
            if (!i32_type) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            // 分配循环索引变量 i（在当前基本块中分配，这样可以在所有后续基本块中使用）
            LLVMValueRef index_ptr = LLVMBuildAlloca(codegen->builder, i32_type, "");
            if (!index_ptr) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            // 获取数组变量的地址（指针）
            // 对于数组变量，我们使用 lvalue_address 获取其地址，而不是加载整个数组的值
            LLVMValueRef array_ptr = codegen_gen_lvalue_address(codegen, array_expr);
            if (!array_ptr) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            // 获取数组类型：如果 array_expr 是标识符，从变量表获取类型；否则从指针类型推导
            LLVMTypeRef array_type = NULL;
            if (array_expr->type == AST_IDENTIFIER) {
                // 标识符：从变量表获取类型（变量表中存储的是数组类型，不是指针类型）
                const char *array_var_name = array_expr->data.identifier.name;
                array_type = lookup_var_type(codegen, array_var_name);
                if (!array_type) {
                    codegen->loop_stack_depth--;
                    return -1;
                }
            } else {
                // 其他表达式：从指针类型推导数组类型
                LLVMTypeRef array_ptr_type = LLVMTypeOf(array_ptr);
                if (!array_ptr_type || LLVMGetTypeKind(array_ptr_type) != LLVMPointerTypeKind) {
                    codegen->loop_stack_depth--;
                    return -1;
                }
                array_type = LLVMGetElementType(array_ptr_type);
                if (!array_type) {
                    codegen->loop_stack_depth--;
                    return -1;
                }
            }
            
            // 验证是数组类型
            if (LLVMGetTypeKind(array_type) != LLVMArrayTypeKind) {
                codegen->loop_stack_depth--;
                return -1;  // 不是数组类型
            }
            
            // 获取数组长度
            unsigned array_length = LLVMGetArrayLength(array_type);
            LLVMValueRef array_length_val = LLVMConstInt(i32_type, array_length, 0);
            
            // 获取元素类型
            LLVMTypeRef element_type = LLVMGetElementType(array_type);
            if (!element_type) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            // 确定循环变量类型（在当前基本块中，这样可以在所有后续基本块中使用）
            LLVMTypeRef loop_var_type = NULL;
            ASTNode *loop_var_ast_type = NULL;
            
            if (is_ref) {
                // 引用迭代：循环变量是指向元素的指针
                loop_var_type = LLVMPointerType(element_type, 0);
                
                // 创建指针类型的 AST 节点，以便 *item 解引用时能正确获取类型信息
                // 首先需要获取元素类型的 AST 节点
                ASTNode *element_ast_type = NULL;
                if (array_expr->type == AST_IDENTIFIER) {
                    // 从数组变量的 AST 类型节点中提取元素类型
                    const char *array_var_name = array_expr->data.identifier.name;
                    ASTNode *array_ast_type = lookup_var_ast_type(codegen, array_var_name);
                    if (array_ast_type && array_ast_type->type == AST_TYPE_ARRAY) {
                        element_ast_type = array_ast_type->data.type_array.element_type;
                    }
                }
                
                // 如果成功获取元素类型，创建指针类型节点
                if (element_ast_type) {
                    loop_var_ast_type = ast_new_node(AST_TYPE_POINTER, stmt->line, stmt->column, codegen->arena);
                    if (loop_var_ast_type) {
                        loop_var_ast_type->data.type_pointer.pointed_type = element_ast_type;
                        loop_var_ast_type->data.type_pointer.is_ffi_pointer = 0;  // 普通指针
                    }
                }
            } else {
                // 值迭代：循环变量是元素值
                loop_var_type = element_type;
                
                // 对于值迭代，也需要获取元素类型的 AST 节点
                if (array_expr->type == AST_IDENTIFIER) {
                    const char *array_var_name = array_expr->data.identifier.name;
                    ASTNode *array_ast_type = lookup_var_ast_type(codegen, array_var_name);
                    if (array_ast_type && array_ast_type->type == AST_TYPE_ARRAY) {
                        loop_var_ast_type = array_ast_type->data.type_array.element_type;
                    }
                }
            }
            
            // 分配循环变量空间（在当前基本块中分配，这样可以在所有后续基本块中使用）
            LLVMValueRef loop_var_ptr = LLVMBuildAlloca(codegen->builder, loop_var_type, "");
            if (!loop_var_ptr) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            // 添加循环变量到变量表（在循环开始前添加一次，而不是每次迭代都添加）
            if (add_var(codegen, var_name, loop_var_ptr, loop_var_type, NULL, loop_var_ast_type) != 0) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            // 跳转到初始化基本块
            LLVMBuildBr(codegen->builder, init_bb);
            
            // 生成初始化代码（初始化循环索引 i = 0）
            LLVMPositionBuilderAtEnd(codegen->builder, init_bb);
            LLVMBuildStore(codegen->builder, LLVMConstInt(i32_type, 0, 0), index_ptr);
            
            // 跳转到条件检查
            LLVMBuildBr(codegen->builder, cond_bb);
            
            // 生成条件检查（i < array_length）
            LLVMPositionBuilderAtEnd(codegen->builder, cond_bb);
            LLVMValueRef index_val = LLVMBuildLoad2(codegen->builder, i32_type, index_ptr, "");
            if (!index_val) {
                codegen->loop_stack_depth--;
                return -1;
            }
            LLVMValueRef cond_val = LLVMBuildICmp(codegen->builder, LLVMIntSLT, index_val, array_length_val, "");
            if (!cond_val) {
                codegen->loop_stack_depth--;
                return -1;
            }
            LLVMBuildCondBr(codegen->builder, cond_val, body_bb, end_bb);
            
            // 生成循环体
            LLVMPositionBuilderAtEnd(codegen->builder, body_bb);
            
            // 重新加载索引值（因为在不同的基本块中，index_val 不可用）
            LLVMValueRef index_val_body = LLVMBuildLoad2(codegen->builder, i32_type, index_ptr, "");
            if (!index_val_body) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            // 生成循环变量（值迭代：load array[i]，引用迭代：getelementptr array[i]）
            LLVMValueRef indices[2];
            indices[0] = LLVMConstInt(i32_type, 0, 0);  // 数组指针本身
            indices[1] = index_val_body;  // 元素索引（运行时值）
            
            LLVMValueRef element_ptr = LLVMBuildGEP2(codegen->builder, array_type, array_ptr, indices, 2, "");
            if (!element_ptr) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            LLVMValueRef loop_var_val = NULL;
            
            if (is_ref) {
                // 引用迭代：循环变量是指向元素的指针
                loop_var_val = element_ptr;
            } else {
                // 值迭代：循环变量是元素值
                loop_var_val = LLVMBuildLoad2(codegen->builder, element_type, element_ptr, "");
                if (!loop_var_val) {
                    codegen->loop_stack_depth--;
                    return -1;
                }
            }
            
            // 存储循环变量值（变量已经在循环开始前添加到变量表）
            // 对于引用迭代，loop_var_val 是指针值，需要存储到 loop_var_ptr（指针的指针）
            // 对于值迭代，loop_var_val 是元素值，需要存储到 loop_var_ptr（指向元素的指针）
            LLVMBuildStore(codegen->builder, loop_var_val, loop_var_ptr);
            
            // 生成循环体代码
            if (codegen_gen_stmt(codegen, body) != 0) {
                codegen->loop_stack_depth--;
                return -1;
            }
            
            // 检查循环体结束前是否需要跳转（如果已经有终止符，不需要再跳转）
            LLVMBasicBlockRef current_bb = LLVMGetInsertBlock(codegen->builder);
            if (current_bb && !LLVMGetBasicBlockTerminator(current_bb)) {
                // 循环体结束前跳转到递增基本块（continue 会跳过这里）
                LLVMBuildBr(codegen->builder, inc_bb);
            }
            
            // 生成递增代码（i = i + 1）
            LLVMPositionBuilderAtEnd(codegen->builder, inc_bb);
            LLVMValueRef index_val_inc = LLVMBuildLoad2(codegen->builder, i32_type, index_ptr, "");
            if (!index_val_inc) {
                codegen->loop_stack_depth--;
                return -1;
            }
            LLVMValueRef index_val_next = LLVMBuildAdd(codegen->builder, index_val_inc, LLVMConstInt(i32_type, 1, 0), "");
            if (!index_val_next) {
                codegen->loop_stack_depth--;
                return -1;
            }
            LLVMBuildStore(codegen->builder, index_val_next, index_ptr);
            
            // 跳转到条件检查
            LLVMBuildBr(codegen->builder, cond_bb);
            
            // 从栈中弹出循环信息
            codegen->loop_stack_depth--;
            
            // 设置构建器到 end 基本块
            LLVMPositionBuilderAtEnd(codegen->builder, end_bb);
            
            return 0;
        }
        
        case AST_BREAK_STMT: {
            // break 语句：跳转到循环结束基本块
            if (codegen->loop_stack_depth == 0) {
                return -1;  // break 不在循环中（类型检查应该已经检查过了）
            }
            LLVMBasicBlockRef end_bb = codegen->loop_stack[codegen->loop_stack_depth - 1].end_bb;
            LLVMBuildBr(codegen->builder, end_bb);
            return 0;
        }
        
        case AST_CONTINUE_STMT: {
            // continue 语句：跳转到循环递增基本块（for 循环）或条件检查基本块（while 循环）
            if (codegen->loop_stack_depth == 0) {
                return -1;  // continue 不在循环中（类型检查应该已经检查过了）
            }
            LLVMBasicBlockRef inc_bb = codegen->loop_stack[codegen->loop_stack_depth - 1].inc_bb;
            if (inc_bb) {
                // for 循环：跳转到递增基本块
                LLVMBuildBr(codegen->builder, inc_bb);
            } else {
                // while 循环：跳转到条件检查基本块
                LLVMBasicBlockRef cond_bb = codegen->loop_stack[codegen->loop_stack_depth - 1].cond_bb;
                LLVMBuildBr(codegen->builder, cond_bb);
            }
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

// 声明函数（创建函数声明并添加到函数表，但不生成函数体）
// 参数：codegen - 代码生成器指针
//       fn_decl - 函数声明AST节点
// 返回：成功返回0，失败返回非0
static int codegen_declare_function(CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!codegen || !fn_decl || fn_decl->type != AST_FN_DECL) {
        return -1;
    }
    
    const char *func_name = fn_decl->data.fn_decl.name;
    ASTNode *return_type_node = fn_decl->data.fn_decl.return_type;
    int param_count = fn_decl->data.fn_decl.param_count;
    ASTNode **params = fn_decl->data.fn_decl.params;
    
    if (!func_name || !return_type_node) {
        return -1;
    }
    
    // 检查函数是否已经声明（在函数表中查找）
    LLVMTypeRef func_type_check = NULL;
    if (lookup_func(codegen, func_name, &func_type_check) != NULL) {
        return 0;  // 已在函数表中，跳过
    }
    
    // 获取返回类型
    LLVMTypeRef return_type = get_llvm_type_from_ast(codegen, return_type_node);
    if (!return_type) {
        return -1;
    }
    
    // 准备参数类型数组
    LLVMTypeRef *param_types = NULL;
    if (param_count > 0) {
        if (param_count > 16) {
            return -1;
        }
        LLVMTypeRef param_types_array[16];
        param_types = param_types_array;
        
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
    
    // 创建函数类型（最后一个参数 isVarArg 表示是否为可变参数函数）
    int is_varargs = fn_decl->data.fn_decl.is_varargs;
    LLVMTypeRef func_type = LLVMFunctionType(return_type, param_types, param_count, is_varargs);
    if (!func_type) {
        return -1;
    }
    
    // 创建函数声明（添加到模块）
    LLVMValueRef func = LLVMAddFunction(codegen->module, func_name, func_type);
    if (!func) {
        return -1;
    }
    
    // 添加到函数表
    if (add_func(codegen, func_name, func, func_type) != 0) {
        return -1;
    }
    
    return 0;
}

// 生成全局变量代码（从变量声明AST节点生成LLVM全局变量）
// 参数：codegen - 代码生成器指针
//       var_decl - 变量声明AST节点（必须是顶层变量声明）
// 返回：成功返回0，失败返回非0
static int codegen_gen_global_var(CodeGenerator *codegen, ASTNode *var_decl) {
    if (!codegen || !var_decl || var_decl->type != AST_VAR_DECL) {
        return -1;
    }
    
    const char *var_name = var_decl->data.var_decl.name;
    ASTNode *var_type_node = var_decl->data.var_decl.type;
    ASTNode *init_expr = var_decl->data.var_decl.init;
    
    if (!var_name || !var_type_node) {
        return -1;
    }
    
    // 获取变量类型
    LLVMTypeRef llvm_type = get_llvm_type_from_ast(codegen, var_type_node);
    if (!llvm_type) {
        return -1;
    }
    
    // 提取结构体名称（如果类型是结构体类型）
    const char *struct_name = NULL;
    if (var_type_node->type == AST_TYPE_NAMED) {
        const char *type_name = var_type_node->data.type_named.name;
        if (type_name && strcmp(type_name, "i32") != 0 && 
            strcmp(type_name, "bool") != 0 && strcmp(type_name, "byte") != 0 && 
            strcmp(type_name, "void") != 0) {
            // 可能是结构体类型
            if (codegen_get_struct_type(codegen, type_name) != NULL) {
                struct_name = type_name;  // 名称已经在 Arena 中
            }
        }
    }
    
    // 创建全局变量（使用内部链接，因为没有导出机制）
    LLVMValueRef global_var = LLVMAddGlobal(codegen->module, llvm_type, var_name);
    if (!global_var) {
        return -1;
    }
    
    // 设置链接属性（内部链接，全局变量在当前模块内可见）
    LLVMSetLinkage(global_var, LLVMInternalLinkage);
    
    // 设置初始值
    LLVMValueRef init_val = NULL;
    if (init_expr) {
        // 对于常量表达式（数字字面量、布尔字面量），可以直接使用
        // 注意：这里简化处理，只支持常量字面量，不支持复杂表达式
        if (init_expr->type == AST_NUMBER) {
            int value = init_expr->data.number.value;
            if (LLVMGetTypeKind(llvm_type) == LLVMIntegerTypeKind) {
                init_val = LLVMConstInt(llvm_type, (unsigned long long)value, 1);  // 1 表示有符号
            }
        } else if (init_expr->type == AST_BOOL) {
            int value = init_expr->data.bool_literal.value;
            if (LLVMGetTypeKind(llvm_type) == LLVMIntegerTypeKind) {
                init_val = LLVMConstInt(llvm_type, value ? 1ULL : 0ULL, 0);  // 0 表示无符号（布尔值）
            }
        }
        // TODO: 支持其他常量表达式（如结构体字面量、数组字面量等）
    }
    
    // 如果没有初始值或初始值不是常量，使用零初始化
    if (!init_val) {
        init_val = LLVMConstNull(llvm_type);
    }
    
    // 设置全局变量的初始值
    LLVMSetInitializer(global_var, init_val);
    
    // 添加到全局变量映射表
    if (add_global_var(codegen, var_name, global_var, llvm_type, struct_name) != 0) {
        return -1;
    }
    
    return 0;
}

// 生成函数代码（从函数声明AST节点生成LLVM函数）
// 参数：codegen - 代码生成器指针
//       fn_decl - 函数声明AST节点
// 返回：成功返回0，失败返回非0
int codegen_gen_function(CodeGenerator *codegen, ASTNode *fn_decl) {
    if (!codegen || !fn_decl || fn_decl->type != AST_FN_DECL) {
        fprintf(stderr, "错误: codegen_gen_function 参数检查失败\n");
        return -1;
    }
    
    const char *func_name = fn_decl->data.fn_decl.name;
    ASTNode *return_type_node = fn_decl->data.fn_decl.return_type;
    ASTNode *body = fn_decl->data.fn_decl.body;
    int param_count = fn_decl->data.fn_decl.param_count;
    ASTNode **params = fn_decl->data.fn_decl.params;
    

    
    if (!func_name || !return_type_node) {
        fprintf(stderr, "错误: codegen_gen_function 函数名或返回类型为空: %s\n", func_name ? func_name : "(null)");
        return -1;
    }
    
    // 检查参数数组：如果 param_count > 0，params 必须不为 NULL
    if (param_count > 0 && !params) {
        fprintf(stderr, "错误: codegen_gen_function 参数数量 > 0 但参数数组为 NULL: %s\n", func_name);
        return -1;
    }
    
    // extern 函数没有函数体，只生成声明
    int is_extern = (body == NULL) ? 1 : 0;
    
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
    
    // 获取函数（应该已经在声明阶段创建）
    LLVMValueRef func = lookup_func(codegen, func_name, NULL);
    if (!func) {
        fprintf(stderr, "错误: codegen_gen_function 函数未声明: %s\n", func_name);
        return -1;
    }
    
    // 检查函数体是否已经定义
    if (LLVMGetFirstBasicBlock(func) != NULL) {
        // 函数体已存在，跳过函数体生成
        return 0;
    }
    
    // extern 函数只生成声明，不生成函数体
    if (is_extern) {
        return 0;  // extern 函数处理完成
    }
    
    // 普通函数需要生成函数体
    // 确保函数体不为 NULL
    if (!body) {
        fprintf(stderr, "错误: codegen_gen_function 非 extern 函数但函数体为 NULL: %s\n", func_name);
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
        
        // 提取结构体名称（如果类型是结构体类型或指针指向结构体类型）
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
        } else if (param_type_node->type == AST_TYPE_POINTER) {
            // 指针类型：检查指向的类型是否为结构体类型
            ASTNode *pointed_type = param_type_node->data.type_pointer.pointed_type;
            if (pointed_type && pointed_type->type == AST_TYPE_NAMED) {
                const char *type_name = pointed_type->data.type_named.name;
                if (type_name && strcmp(type_name, "i32") != 0 && 
                    strcmp(type_name, "bool") != 0 && strcmp(type_name, "byte") != 0 && 
                    strcmp(type_name, "void") != 0) {
                    // 可能是结构体类型
                    if (codegen_get_struct_type(codegen, type_name) != NULL) {
                        struct_name = type_name;  // 名称已经在 Arena 中
                    }
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
        if (add_var(codegen, param_name, param_ptr, param_type, struct_name, param_type_node) != 0) {
            return -1;
        }
    }
    
    // 生成函数体代码
    int stmt_result = codegen_gen_stmt(codegen, body);
    if (stmt_result != 0) {
        fprintf(stderr, "错误: 函数体生成失败: %s (返回值: %d)\n", func_name, stmt_result);
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
    
    // 第零步：初始化目标并设置模块的 DataLayout（需要在生成函数体之前设置，以便 sizeof 可以使用）
    // 初始化LLVM目标（只需要初始化一次，但重复初始化是安全的）
    LLVMInitializeNativeTarget();
    LLVMInitializeNativeAsmPrinter();
    LLVMInitializeNativeAsmParser();
    
    // 获取默认目标三元组（例如："x86_64-pc-linux-gnu"）
    char *init_target_triple = LLVMGetDefaultTargetTriple();
    if (!init_target_triple) {
        return -1;
    }
    
    // 查找目标
    char *init_error_msg = NULL;
    LLVMTargetRef init_target = NULL;
    if (LLVMGetTargetFromTriple(init_target_triple, &init_target, &init_error_msg) != 0) {
        // 错误处理：释放错误消息
        if (init_error_msg) {
            LLVMDisposeMessage(init_error_msg);
        }
        LLVMDisposeMessage(init_target_triple);
        return -1;
    }
    
    // 创建目标机器（使用默认的CPU和特性）
    LLVMCodeGenOptLevel init_opt_level = LLVMCodeGenLevelDefault;
    LLVMRelocMode init_reloc_mode = LLVMRelocDefault;
    LLVMCodeModel init_code_model = LLVMCodeModelDefault;
    
    LLVMTargetMachineRef init_target_machine = LLVMCreateTargetMachine(
        init_target,
        init_target_triple,
        "",  // CPU（空字符串表示默认）
        "",  // Features（空字符串表示默认）
        init_opt_level,
        init_reloc_mode,
        init_code_model
    );
    
    if (!init_target_machine) {
        LLVMDisposeMessage(init_target_triple);
        return -1;
    }
    
    // 配置模块的目标数据布局（需要在生成函数体之前设置）
    LLVMSetTarget(codegen->module, init_target_triple);
    LLVMTargetDataRef init_target_data = LLVMCreateTargetDataLayout(init_target_machine);
    if (init_target_data) {
        // LLVM 18中，LLVMSetModuleDataLayout 直接接受 LLVMTargetDataRef 类型
        LLVMSetModuleDataLayout(codegen->module, init_target_data);
        LLVMDisposeTargetData(init_target_data);
    }
    
    // 释放资源（第零步创建的 target_machine 和 target_triple）
    LLVMDisposeTargetMachine(init_target_machine);
    LLVMDisposeMessage(init_target_triple);
    
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
    
    // 第二步：生成所有全局变量（在函数声明之前，这样函数可以访问全局变量）
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) {
            continue;
        }
        
        if (decl->type == AST_VAR_DECL) {
            // 生成全局变量
            const char *var_name = decl->data.var_decl.name;
            int result = codegen_gen_global_var(codegen, decl);
            if (result != 0) {
                fprintf(stderr, "错误: 全局变量生成失败: %s\n", var_name ? var_name : "(null)");
                return -1;
            }
        }
    }
    
    // 第三步：声明所有函数（创建函数声明并添加到函数表，但不生成函数体）
    // 这样在生成函数体时，所有函数都已被声明，可以相互调用
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) {
            continue;
        }
        
        if (decl->type == AST_FN_DECL) {
            // 声明函数（不生成函数体）
            const char *func_name = decl->data.fn_decl.name;
            int result = codegen_declare_function(codegen, decl);
            if (result != 0) {
                fprintf(stderr, "错误: 函数声明失败: %s\n", func_name ? func_name : "(null)");
                return -1;
            }
        }
    }
    
    // 第四步：生成所有函数的函数体
    // 此时所有函数都已被声明，可以相互调用
    for (int i = 0; i < decl_count; i++) {
        ASTNode *decl = decls[i];
        if (!decl) {
            continue;
        }
        
        if (decl->type == AST_FN_DECL) {
            // extern 函数没有函数体，跳过
            if (decl->data.fn_decl.body == NULL) {
                continue;
            }
            
            // 生成函数体
            const char *func_name = decl->data.fn_decl.name;
            int result = codegen_gen_function(codegen, decl);
            if (result != 0) {
                fprintf(stderr, "错误: 函数代码生成失败: %s\n", func_name ? func_name : "(null)");
                return -1;  // 函数代码生成失败
            }
        }
    }
    

    
    // 第五步：生成目标代码
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
    
    // 配置模块的目标数据布局（如果还没有设置）
    // 注意：在第零步可能已经设置了 DataLayout，但重复设置是安全的
    LLVMSetTarget(codegen->module, target_triple);
    LLVMTargetDataRef layout_data = LLVMCreateTargetDataLayout(target_machine);
    if (layout_data) {
        // LLVM 18中，LLVMSetModuleDataLayout 直接接受 LLVMTargetDataRef 类型
        LLVMSetModuleDataLayout(codegen->module, layout_data);
        LLVMDisposeTargetData(layout_data);
    }
    
    // 生成LLVM IR文本到文件，用于调试
    // 基于输出文件名生成 .ll 文件路径（将 .o 替换为 .ll）
    char ir_file[512];  // 足够大的缓冲区
    size_t max_len = sizeof(ir_file) - 4;  // 保留空间给 ".ll\0"
    size_t output_len = strlen(output_file);
    if (output_len > max_len) {
        output_len = max_len;
    }
    strncpy(ir_file, output_file, output_len);
    ir_file[output_len] = '\0';
    
    // 查找最后一个点号，如果以 .o 结尾则替换，否则追加 .ll
    char *last_dot = strrchr(ir_file, '.');
    if (last_dot && strcmp(last_dot, ".o") == 0) {
        strcpy(last_dot, ".ll");
    } else {
        strcat(ir_file, ".ll");
    }
    
    char *ir_error = NULL;
    LLVMPrintModuleToFile(codegen->module, ir_file, &ir_error);
    if (ir_error) {
        LLVMDisposeMessage(ir_error);
        ir_error = NULL;
    }
    
    // 生成目标代码到文件
    char *error = NULL;
    if (LLVMTargetMachineEmitToFile(target_machine, codegen->module, (char *)output_file,
                                     LLVMObjectFile, &error) != 0) {
        // 生成失败
        if (error) {
            fprintf(stderr, "错误: LLVM 代码生成失败: %s\n", error);
            LLVMDisposeMessage(error);
        } else {
            fprintf(stderr, "错误: LLVM 代码生成失败（未知错误）\n");
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

