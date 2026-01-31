#include "internal.h"

// 前向声明（在enums.c中定义）
ASTNode *find_enum_decl(CodeGenerator *codegen, const char *enum_name);

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
            // i32 类型映射到 LLVM Int32 类型（使用当前上下文）
            return LLVMInt32TypeInContext(codegen->context);
            
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
                        return LLVMInt32TypeInContext(codegen->context);
                    } else if (pointer_size == 8) {
                        // 64位平台：usize = u64
                        return LLVMInt64TypeInContext(codegen->context);
                    }
                }
            }
            // 如果无法获取目标平台信息，默认使用 64 位（大多数现代平台）
            return LLVMInt64TypeInContext(codegen->context);
            
        case TYPE_BOOL:
            // bool 类型映射到 LLVM Int1 类型（1位整数，更精确，使用当前上下文）
            return LLVMInt1TypeInContext(codegen->context);
            
        case TYPE_BYTE:
            // byte 类型映射到 LLVM Int8 类型（8位无符号整数，使用当前上下文）
            return LLVMInt8TypeInContext(codegen->context);
            
        case TYPE_F32:
            return LLVMFloatTypeInContext(codegen->context);
            
        case TYPE_F64:
            return LLVMDoubleTypeInContext(codegen->context);
            
        case TYPE_VOID:
            // void 类型映射到 LLVM Void 类型（使用当前上下文）
            return LLVMVoidTypeInContext(codegen->context);
            
        case TYPE_STRUCT:
            // 结构体类型不能使用此函数，应使用其他函数
            return NULL;
            
        default:
            return NULL;
    }
}

// 辅助函数：从AST类型节点获取LLVM类型（支持基础类型、结构体类型、指针类型和数组类型）
// 参数：codegen - 代码生成器指针
//       type_node - AST类型节点（AST_TYPE_NAMED、AST_TYPE_POINTER 或 AST_TYPE_ARRAY）
// 返回：LLVM类型引用，失败返回NULL
LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node) {
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
            } else if (strcmp(type_name, "f32") == 0) {
                return codegen_get_base_type(codegen, TYPE_F32);
            } else if (strcmp(type_name, "f64") == 0) {
                return codegen_get_base_type(codegen, TYPE_F64);
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
                // 如果指向的类型获取失败，检查是否是结构体类型未注册
                // 如果是命名类型，尝试查找结构体类型
                if (pointed_type->type == AST_TYPE_NAMED) {
                    const char *type_name = pointed_type->data.type_named.name;
                    if (type_name != NULL) {
                        // 尝试查找结构体类型（可能尚未注册）
                        LLVMTypeRef struct_type = codegen_get_struct_type(codegen, type_name);
                        if (struct_type != NULL) {
                            return LLVMPointerType(struct_type, 0);
                        } else {
                            // 如果结构体类型未找到，使用通用指针类型（i8*）作为后备
                            // 这在编译器自举时很常见，因为结构体类型可能尚未注册
                            // 使用通用指针类型可以确保函数声明成功，即使类型不完全匹配
                            LLVMTypeRef i8_type = LLVMInt8TypeInContext(codegen->context);
                            return LLVMPointerType(i8_type, 0);
                        }
                    }
                }
                // 如果类型获取失败且不是命名类型，使用通用指针类型（i8*）作为后备
                // 这在编译器自举时可能发生，因为结构体类型可能尚未注册
                LLVMTypeRef i8_type = LLVMInt8TypeInContext(codegen->context);
                return LLVMPointerType(i8_type, 0);
            }
            
            // 创建指针类型（地址空间 0，默认）
            // LLVM 不支持 void*，使用 i8* 作为等价表示
            if (LLVMGetTypeKind(pointed_llvm_type) == LLVMVoidTypeKind) {
                return LLVMPointerType(LLVMInt8TypeInContext(codegen->context), 0);
            }
            return LLVMPointerType(pointed_llvm_type, 0);
        }
        
        case AST_TYPE_ARRAY: {
            // 数组类型（[T: N]）
            ASTNode *element_type = type_node->data.type_array.element_type;
            ASTNode *size_expr = type_node->data.type_array.size_expr;
            if (!element_type || !size_expr) {
                return NULL;
            }
            
            // 数组大小必须是编译期常量（数字字面量或常量标识符）
            int array_size = -1;
            if (size_expr->type == AST_NUMBER) {
                // 数字字面量
                array_size = size_expr->data.number.value;
            } else if (size_expr->type == AST_IDENTIFIER) {
                // 常量标识符：从程序节点中查找常量变量的初始值
                const char *const_name = size_expr->data.identifier.name;
                if (const_name != NULL && codegen->program_node != NULL) {
                    ASTNode *program = codegen->program_node;
                    if (program->type == AST_PROGRAM) {
                        // 首先尝试从已生成的全局变量中查找（如果已经生成）
                        // 注意：这需要全局变量已经生成，但在生成全局变量类型时可能还没有生成
                        // 所以主要依赖从 AST 中查找
                        
                        // 从 AST 中查找常量变量的初始值
                        for (int i = 0; i < program->data.program.decl_count; i++) {
                            ASTNode *decl = program->data.program.decls[i];
                            if (decl != NULL && decl->type == AST_VAR_DECL) {
                                const char *var_name = decl->data.var_decl.name;
                                if (var_name != NULL && strcmp(var_name, const_name) == 0) {
                                    // 找到常量变量，检查初始值
                                    ASTNode *init_expr = decl->data.var_decl.init;
                                    if (init_expr != NULL && init_expr->type == AST_NUMBER) {
                                        array_size = init_expr->data.number.value;
                                        break;
                                    }
                                    // 如果初始值也是常量标识符，递归查找
                                    if (init_expr != NULL && init_expr->type == AST_IDENTIFIER) {
                                        const char *ref_name = init_expr->data.identifier.name;
                                        if (ref_name != NULL) {
                                            // 递归查找引用的常量
                                            for (int j = 0; j < program->data.program.decl_count; j++) {
                                                ASTNode *ref_decl = program->data.program.decls[j];
                                                if (ref_decl != NULL && ref_decl->type == AST_VAR_DECL) {
                                                    const char *ref_var_name = ref_decl->data.var_decl.name;
                                                    if (ref_var_name != NULL && strcmp(ref_var_name, ref_name) == 0) {
                                                        ASTNode *ref_init = ref_decl->data.var_decl.init;
                                                        if (ref_init != NULL && ref_init->type == AST_NUMBER) {
                                                            array_size = ref_init->data.number.value;
                                                            break;
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                        if (array_size >= 0) {
                                            break;
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            if (array_size < 0) {
                return NULL;  // 数组大小无效或无法确定
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
    LLVMTypeRef existing_type = codegen_get_struct_type(codegen, struct_name);
    if (existing_type != NULL) {
        // 如果已经注册，检查是否是占位符类型（不完整类型）
        if (!LLVMIsOpaqueStruct(existing_type)) {
            // 已经有完整定义，返回成功
            return 0;
        }
        // 占位符类型：稍后用字段填充
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
    LLVMTypeRef field_types_array[256];
    if (field_count > 0) {
        // 使用固定大小数组（栈分配，无堆分配）
        // 注意：最多支持256个字段（如果超过需要调整）
        if (field_count > 256) {
            return -1;  // 字段数过多
        }
        field_types = field_types_array;
        
    // 遍历字段，获取每个字段的LLVM类型
    for (int i = 0; i < field_count; i++) {
        ASTNode *field = struct_decl->data.struct_decl.fields[i];
        if (!field || field->type != AST_VAR_DECL) {
            return -1;
        }
        
        ASTNode *field_type_node = field->data.var_decl.type;
        LLVMTypeRef field_llvm_type = get_llvm_type_from_ast(codegen, field_type_node);
        
        // 如果字段类型是结构体类型且未找到，创建不完整类型占位符
        if (!field_llvm_type && field_type_node->type == AST_TYPE_NAMED) {
            const char *field_type_name = field_type_node->data.type_named.name;
            if (field_type_name && codegen_get_struct_type(codegen, field_type_name) == NULL) {
                // 创建不完整类型占位符（void指针作为临时占位）
                field_llvm_type = LLVMPointerType(LLVMInt8TypeInContext(codegen->context), 0);
                fprintf(stderr, "警告: 使用占位符类型处理未注册的结构体字段: %s\n", field_type_name);
            }
        }
        
        if (!field_llvm_type) {
            return -1;  // 字段类型无效
        }
        
        field_types[i] = field_llvm_type;
    }
    }
    
    // 创建或填充 LLVM 结构体类型
    LLVMTypeRef struct_type = existing_type;
    if (struct_type != NULL) {
        // 使用占位符类型填充字段
        LLVMStructSetBody(struct_type, field_count == 0 ? NULL : field_types, field_count, 0);
        return 0;
    }

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
    int idx = codegen->struct_type_count;
    codegen->struct_types[idx].name = struct_name;  // 名称已经在Arena中
    codegen->struct_types[idx].llvm_type = struct_type;
    codegen->struct_types[idx].ast_node = struct_decl;  // 存储 AST 节点引用
    codegen->struct_type_count++;
    
    return 0;
}

