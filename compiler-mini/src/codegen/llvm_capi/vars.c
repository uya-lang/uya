#include "internal.h"

// 前向声明（在其他模块中定义）
ASTNode *find_enum_decl(CodeGenerator *codegen, const char *enum_name);
ASTNode *find_struct_decl(CodeGenerator *codegen, const char *struct_name);
int find_struct_field_index(ASTNode *struct_decl, const char *field_name);
const char *find_struct_name_from_type(CodeGenerator *codegen, LLVMTypeRef struct_type);
LLVMValueRef codegen_gen_expr(CodeGenerator *codegen, ASTNode *expr);
LLVMTypeRef get_llvm_type_from_ast(CodeGenerator *codegen, ASTNode *type_node);

// 辅助函数：在变量表中查找变量（先查找局部变量，再查找全局变量）
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：LLVM值引用（变量指针），未找到返回NULL
LLVMValueRef lookup_var(CodeGenerator *codegen, const char *var_name) {
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

// 在函数入口基本块分配 alloca，确保支配所有使用（避免 dominator/terminator 验证错误）
LLVMValueRef build_entry_alloca(CodeGenerator *codegen, LLVMTypeRef type, const char *name) {
    if (!codegen || !codegen->builder || !codegen->context || !type) {
        return NULL;
    }

    LLVMBasicBlockRef current_bb = LLVMGetInsertBlock(codegen->builder);
    if (!current_bb) {
        return NULL;
    }
    LLVMValueRef func = LLVMGetBasicBlockParent(current_bb);
    if (!func) {
        return NULL;
    }
    LLVMBasicBlockRef entry_bb = LLVMGetEntryBasicBlock(func);
    if (!entry_bb) {
        return NULL;
    }

    LLVMBuilderRef tmp_builder = LLVMCreateBuilderInContext(codegen->context);
    if (!tmp_builder) {
        return NULL;
    }

    LLVMValueRef first_inst = LLVMGetFirstInstruction(entry_bb);
    if (first_inst) {
        LLVMPositionBuilderBefore(tmp_builder, first_inst);
    } else {
        LLVMPositionBuilderAtEnd(tmp_builder, entry_bb);
    }

    LLVMValueRef alloca_inst = LLVMBuildAlloca(tmp_builder, type, name ? name : "");
    LLVMDisposeBuilder(tmp_builder);
    return alloca_inst;
}

// 辅助函数：生成左值表达式的地址
// 参数：codegen - 代码生成器指针
//       expr - 左值表达式节点
// 返回：LLVM值引用（地址），失败返回NULL
LLVMValueRef codegen_gen_lvalue_address(CodeGenerator *codegen, ASTNode *expr) {
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
            LLVMTypeRef operand_type = safe_LLVMTypeOf(operand_val);
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
                    
                    // 检查变量类型是否是指针类型
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
            
            // 如果对象不是标识符或 struct_name 仍然为空，尝试从 AST 获取
            if (!struct_name && object->type == AST_IDENTIFIER) {
                const char *var_name = object->data.identifier.name;
                if (var_name) {
                    ASTNode *var_ast_type = lookup_var_ast_type(codegen, var_name);
                    if (var_ast_type) {
                        if (var_ast_type->type == AST_TYPE_POINTER) {
                            // 指针类型：获取指向的类型
                            ASTNode *pointed_type = var_ast_type->data.type_pointer.pointed_type;
                            if (pointed_type && pointed_type->type == AST_TYPE_NAMED) {
                                struct_name = pointed_type->data.type_named.name;
                            }
                        } else if (var_ast_type->type == AST_TYPE_NAMED) {
                            // 直接是命名类型（如结构体）
                            struct_name = var_ast_type->data.type_named.name;
                        }
                    }
                }
            }
            
            // 如果对象是数组访问（如 ptr[i]），尝试从数组表达式的类型获取结构体名称
            if (!struct_name && object->type == AST_ARRAY_ACCESS) {
                ASTNode *array_expr = object->data.array_access.array;
                if (array_expr && array_expr->type == AST_IDENTIFIER) {
                    const char *array_var_name = array_expr->data.identifier.name;
                    if (array_var_name) {
                        ASTNode *array_ast_type = lookup_var_ast_type(codegen, array_var_name);
                        if (array_ast_type) {
                            // 处理数组类型：[T: N]
                            if (array_ast_type->type == AST_TYPE_ARRAY) {
                                ASTNode *element_type = array_ast_type->data.type_array.element_type;
                                if (element_type) {
                                    if (element_type->type == AST_TYPE_NAMED) {
                                        struct_name = element_type->data.type_named.name;
                                    } else if (element_type->type == AST_TYPE_POINTER) {
                                        ASTNode *pt = element_type->data.type_pointer.pointed_type;
                                        if (pt && pt->type == AST_TYPE_NAMED) {
                                            struct_name = pt->data.type_named.name;
                                        }
                                    }
                                }
                            }
                            // 处理指针类型：&T（ptr[i] 其中 ptr 是 &T 类型）
                            else if (array_ast_type->type == AST_TYPE_POINTER) {
                                ASTNode *pointed_type = array_ast_type->data.type_pointer.pointed_type;
                                if (pointed_type && pointed_type->type == AST_TYPE_NAMED) {
                                    struct_name = pointed_type->data.type_named.name;
                                }
                            }
                        }
                    }
                }
            }
            
            // 如果对象不是变量，检查是否是枚举类型名称（枚举值访问，如 Mixed.FIRST）
            // 注意：枚举值访问是右值，不是左值，所以不应该在这里处理
            // 但我们需要检查，如果是枚举值访问，返回 NULL（表示不是左值）
            if (!object_ptr && object->type == AST_IDENTIFIER) {
                const char *enum_name = object->data.identifier.name;
                if (enum_name) {
                    ASTNode *enum_decl = find_enum_decl(codegen, enum_name);
                    if (enum_decl) {
                        // 是枚举类型，这是枚举值访问（右值），不是左值
                        // 返回 NULL，让调用者知道这不是左值
                        return NULL;
                    }
                }
            }
            
            // 扩展：支持嵌套字段访问作为左值（如 a.b.c = ... 或 &p.x）
            // 目标是拿到 "指向结构体的指针" (object_ptr) 和结构体名 (struct_name)
            if (!object_ptr || !struct_name) {
                // 0) 如果已经有 object_ptr，但 struct_name 缺失，优先从 LLVM 类型推断
                if (object_ptr && !struct_name) {
                    LLVMTypeRef obj_ptr_ty = safe_LLVMTypeOf(object_ptr);
                    if (obj_ptr_ty && obj_ptr_ty != (LLVMTypeRef)1 &&
                        LLVMGetTypeKind(obj_ptr_ty) == LLVMPointerTypeKind) {
                        LLVMTypeRef obj_elem_ty = safe_LLVMGetElementType(obj_ptr_ty);
                        if (obj_elem_ty && obj_elem_ty != (LLVMTypeRef)1) {
                            // 如果拿到的是指向指针的指针，load 一次再判断
                            if (LLVMGetTypeKind(obj_elem_ty) == LLVMPointerTypeKind) {
                                LLVMValueRef loaded = LLVMBuildLoad2(codegen->builder, obj_elem_ty, object_ptr, "");
                                if (loaded && loaded != (LLVMValueRef)1) {
                                    object_ptr = loaded;
                                    obj_ptr_ty = safe_LLVMTypeOf(object_ptr);
                                    if (obj_ptr_ty && obj_ptr_ty != (LLVMTypeRef)1 &&
                                        LLVMGetTypeKind(obj_ptr_ty) == LLVMPointerTypeKind) {
                                        obj_elem_ty = safe_LLVMGetElementType(obj_ptr_ty);
                                    }
                                }
                            }
                            if (obj_elem_ty && obj_elem_ty != (LLVMTypeRef)1 &&
                                LLVMGetTypeKind(obj_elem_ty) == LLVMStructTypeKind) {
                                struct_name = find_struct_name_from_type(codegen, obj_elem_ty);
                            }
                        }
                    }
                }

                // 1) 优先尝试从左值地址获取（适用于 object 是 member_access / identifier / *ptr 等）
                if (!object_ptr) {
                    LLVMValueRef maybe_addr = codegen_gen_lvalue_address(codegen, object);
                    if (maybe_addr && maybe_addr != (LLVMValueRef)1) {
                        LLVMTypeRef addr_ty = safe_LLVMTypeOf(maybe_addr);
                        if (addr_ty && addr_ty != (LLVMTypeRef)1 && LLVMGetTypeKind(addr_ty) == LLVMPointerTypeKind) {
                            LLVMTypeRef elem_ty = safe_LLVMGetElementType(addr_ty);
                            if (elem_ty && elem_ty != (LLVMTypeRef)1) {
                                // 如果拿到的是"指向指针的指针"（比如 identifier 的 alloca），先 load 一次
                                if (LLVMGetTypeKind(elem_ty) == LLVMPointerTypeKind) {
                                    LLVMValueRef loaded = LLVMBuildLoad2(codegen->builder, elem_ty, maybe_addr, "");
                                    if (loaded && loaded != (LLVMValueRef)1) {
                                        object_ptr = loaded;
                                    }
                                } else {
                                    object_ptr = maybe_addr;
                                }

                                // 尝试从 object_ptr 的指向类型推断结构体名
                                if (!struct_name && object_ptr) {
                                    LLVMTypeRef obj_ptr_ty = safe_LLVMTypeOf(object_ptr);
                                    if (obj_ptr_ty && obj_ptr_ty != (LLVMTypeRef)1 &&
                                        LLVMGetTypeKind(obj_ptr_ty) == LLVMPointerTypeKind) {
                                        LLVMTypeRef obj_elem_ty = safe_LLVMGetElementType(obj_ptr_ty);
                                        if (obj_elem_ty && obj_elem_ty != (LLVMTypeRef)1 &&
                                            LLVMGetTypeKind(obj_elem_ty) == LLVMStructTypeKind) {
                                            struct_name = find_struct_name_from_type(codegen, obj_elem_ty);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // 2) 如果仍然不行，尝试生成 object 的值（适用于 object 是表达式）
                if (!object_ptr) {
                    LLVMValueRef object_val = codegen_gen_expr(codegen, object);
                    if (object_val && object_val != (LLVMValueRef)1) {
                        LLVMTypeRef object_ty = safe_LLVMTypeOf(object_val);
                        if (object_ty && object_ty != (LLVMTypeRef)1) {
                            if (LLVMGetTypeKind(object_ty) == LLVMPointerTypeKind) {
                                // object_val 本身就是指针（期望指向结构体）
                                object_ptr = object_val;
                            } else if (LLVMGetTypeKind(object_ty) == LLVMStructTypeKind) {
                                // object_val 是结构体值：落到栈上取地址
                                LLVMValueRef tmp = LLVMBuildAlloca(codegen->builder, object_ty, "");
                                if (tmp) {
                                    LLVMBuildStore(codegen->builder, object_val, tmp);
                                    object_ptr = tmp;
                                }
                            }

                            // 从 LLVM 类型推断结构体名
                            if (!struct_name && object_ptr) {
                                LLVMTypeRef obj_ptr_ty = safe_LLVMTypeOf(object_ptr);
                                if (obj_ptr_ty && obj_ptr_ty != (LLVMTypeRef)1 &&
                                    LLVMGetTypeKind(obj_ptr_ty) == LLVMPointerTypeKind) {
                                    LLVMTypeRef obj_elem_ty = safe_LLVMGetElementType(obj_ptr_ty);
                                    if (obj_elem_ty && obj_elem_ty != (LLVMTypeRef)1 &&
                                        LLVMGetTypeKind(obj_elem_ty) == LLVMStructTypeKind) {
                                        struct_name = find_struct_name_from_type(codegen, obj_elem_ty);
                                    }
                                }
                            }
                        }
                    }
                }

                if (!object_ptr || !struct_name) {
                    return NULL;
                }
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
            
            // 检查字段类型是否是数组类型
            LLVMTypeKind field_type_kind = LLVMGetTypeKind(field_type);
            if (field_type_kind == LLVMArrayTypeKind) {
                // 对于数组类型，需要返回指向数组的指针
                // field_ptr 的类型是 struct_type*，指向整个结构体
                // 使用索引 0 的 GEP 获取第一个字段的地址（即数组的地址）
                LLVMValueRef indices[1];
                indices[0] = LLVMConstInt(LLVMInt32TypeInContext(codegen->context), 0ULL, 0);
                LLVMValueRef array_ptr = LLVMBuildGEP2(codegen->builder, field_type, field_ptr, indices, 1, "");
                if (array_ptr) {
                    return array_ptr;
                }
            }
            
            // 返回字段地址（不需要加载值）
            return field_ptr;
        }
        
        case AST_ARRAY_ACCESS: {
            // 数组访问：使用 GEP 获取元素地址（用于赋值语句如 arr[i] = value 或 &arr[i]）
            ASTNode *array_expr = expr->data.array_access.array;
            ASTNode *index_expr = expr->data.array_access.index;
            
            if (!array_expr || !index_expr) {
                const char *filename = expr->filename ? expr->filename : "<unknown>";
                fprintf(stderr, "错误: 数组访问表达式参数无效 (%s:%d:%d)\n",
                        filename, expr->line, expr->column);
                fprintf(stderr, "  错误原因: 数组访问表达式的数组部分或索引部分为 NULL\n");
                fprintf(stderr, "  可能原因:\n");
                fprintf(stderr, "    - 语法解析错误，数组访问表达式不完整\n");
                fprintf(stderr, "    - 数组表达式或索引表达式解析失败\n");
                fprintf(stderr, "  修改建议:\n");
                fprintf(stderr, "    - 检查数组访问语法是否正确，例如: arr[index]\n");
                fprintf(stderr, "    - 确保数组表达式和索引表达式都已正确解析\n");
                return NULL;
            }
            
            // 获取数组指针
            // 如果数组表达式是标识符（变量），尝试从变量表获取指针
            LLVMValueRef array_ptr = NULL;
            LLVMTypeRef array_type = NULL;
            
            if (array_expr->type == AST_IDENTIFIER) {
                const char *var_name = array_expr->data.identifier.name;
                if (var_name) {
                    array_ptr = lookup_var(codegen, var_name);
                    if (array_ptr) {
                        // 检查 array_ptr 是否是标记值
                        if (array_ptr == (LLVMValueRef)1) {
                            return NULL;
                        }
                        
                        // 首先尝试从变量表获取类型（变量表中存储的是数组类型，不是指针类型）
                        LLVMTypeRef var_type = lookup_var_type(codegen, var_name);
                        if (var_type) {
                            LLVMTypeKind var_type_kind = LLVMGetTypeKind(var_type);
                            if (var_type_kind == LLVMArrayTypeKind) {
                                // 变量类型是数组类型，array_ptr 是指向数组的指针
                                array_type = var_type;
                                // array_ptr 已经是正确的指针，不需要加载
                            } else if (var_type_kind == LLVMPointerTypeKind) {
                                // 变量类型是指针类型，获取指向的类型
                                // 注意：对于栈上数组变量，变量表中存储的类型应该已经是数组类型
                                // 如果存储的是指针类型，说明变量本身是指针类型（如 &byte），不是数组变量
                                // 在这种情况下，我们需要加载指针值
                                LLVMTypeRef pointed_type = safe_LLVMGetElementType(var_type);
                                // 如果 safe_LLVMGetElementType 失败，尝试从 AST 获取类型
                                if (!pointed_type || pointed_type == (LLVMTypeRef)1) {
                                    ASTNode *var_ast_type = lookup_var_ast_type(codegen, var_name);
                                    if (var_ast_type && var_ast_type->type == AST_TYPE_POINTER) {
                                        ASTNode *pointed_type_node = var_ast_type->data.type_pointer.pointed_type;
                                        if (pointed_type_node) {
                                            pointed_type = get_llvm_type_from_ast(codegen, pointed_type_node);
                                        }
                                    }
                                }
                                if (pointed_type && pointed_type != (LLVMTypeRef)1) {
                                    // 对于指针类型变量，需要加载指针值
                                    array_type = pointed_type;
                                    // 检查 array_ptr 和 var_type 是否有效
                                    if (array_ptr && array_ptr != (LLVMValueRef)1 && 
                                        var_type && var_type != (LLVMTypeRef)1 &&
                                        codegen && codegen->builder) {
                                        // 验证 builder 是否有效
                                        LLVMValueRef loaded_ptr = LLVMBuildLoad2(codegen->builder, var_type, array_ptr, var_name);
                                        if (!loaded_ptr || loaded_ptr == (LLVMValueRef)1) {
                                            fprintf(stderr, "错误: codegen_gen_lvalue_address LLVMBuildLoad2 返回无效值 (变量: %s)\n", var_name);
                                            return NULL;
                                        }
                                        array_ptr = loaded_ptr;
                                    } else {
                                        fprintf(stderr, "错误: codegen_gen_lvalue_address 无效的 array_ptr、var_type 或 builder (变量: %s, array_ptr=%p, var_type=%p, builder=%p)\n", 
                                                var_name, (void*)array_ptr, (void*)var_type, (void*)(codegen ? codegen->builder : NULL));
                                        return NULL;
                                    }
                                } else {
                                    fprintf(stderr, "错误: codegen_gen_lvalue_address 无法获取指针指向的类型 (变量: %s)\n", var_name);
                                    return NULL;
                                }
                            }
                        } else {
                            // 如果从变量表获取类型失败，尝试从指针类型推导
                            LLVMTypeRef var_ptr_type = safe_LLVMTypeOf(array_ptr);
                            if (var_ptr_type) {
                                LLVMTypeKind var_ptr_type_kind = LLVMGetTypeKind(var_ptr_type);
                                if (var_ptr_type_kind == LLVMPointerTypeKind) {
                                    // 变量指针是指针类型，获取指向的类型
                                    LLVMTypeRef pointed_type = safe_LLVMGetElementType(var_ptr_type);
                                    // 如果 safe_LLVMGetElementType 失败，尝试从 AST 获取类型
                                    if (!pointed_type || pointed_type == (LLVMTypeRef)1) {
                                        ASTNode *var_ast_type = lookup_var_ast_type(codegen, var_name);
                                        if (var_ast_type && var_ast_type->type == AST_TYPE_POINTER) {
                                            ASTNode *pointed_type_node = var_ast_type->data.type_pointer.pointed_type;
                                            if (pointed_type_node) {
                                                pointed_type = get_llvm_type_from_ast(codegen, pointed_type_node);
                                            }
                                        }
                                    }
                                    if (pointed_type && pointed_type != (LLVMTypeRef)1) {
                                        LLVMTypeKind pointed_type_kind = LLVMGetTypeKind(pointed_type);
                                        if (pointed_type_kind == LLVMArrayTypeKind) {
                                            // 指针指向数组（栈上数组变量），array_ptr 已经是地址，直接使用
                                            array_type = pointed_type;
                                            // array_ptr 已经是正确的指针，不需要加载
                                        } else {
                                            // 指针指向单个元素（如 &byte），需要加载指针值
                                            array_type = pointed_type;
                                            // 检查 array_ptr 和 var_ptr_type 是否有效
                                            if (array_ptr && array_ptr != (LLVMValueRef)1 && 
                                                var_ptr_type && var_ptr_type != (LLVMTypeRef)1) {
                                                array_ptr = LLVMBuildLoad2(codegen->builder, var_ptr_type, array_ptr, var_name);
                                                if (!array_ptr) {
                                                    fprintf(stderr, "错误: codegen_gen_lvalue_address LLVMBuildLoad2 失败 (变量: %s, 路径2)\n", var_name ? var_name : "(null)");
                                                    return NULL;
                                                }
                                            } else {
                                                fprintf(stderr, "错误: codegen_gen_lvalue_address 无效的 array_ptr 或 var_ptr_type (变量: %s, 路径2)\n", var_name ? var_name : "(null)");
                                                return NULL;
                                            }
                                            // 对于单个元素指针，我们将在后面使用元素类型和单个索引进行 GEP
                                            // 不需要创建数组类型
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 如果数组表达式是字段访问（如 data.values），从字段类型获取数组类型
            if ((!array_ptr || !array_type) && array_expr->type == AST_MEMBER_ACCESS) {
                // 字段访问：先获取字段的地址
                array_ptr = codegen_gen_lvalue_address(codegen, array_expr);
                if (!array_ptr || array_ptr == (LLVMValueRef)1) {
                    // 不立即失败：字段访问作为数组基址有时可以通过 rvalue 路径拿到指针/数组值
                    // 让后面的"通用方法"继续尝试（避免级联失败）
                    array_ptr = NULL;
                }
                
                // 从 AST 获取字段类型
                ASTNode *object = array_expr->data.member_access.object;
                const char *field_name = array_expr->data.member_access.field_name;
                if (object && field_name) {
                    const char *struct_name = NULL;
                    if (object->type == AST_IDENTIFIER) {
                        struct_name = lookup_var_struct_name(codegen, object->data.identifier.name);
                    }
                    if (struct_name) {
                        ASTNode *struct_decl = find_struct_decl(codegen, struct_name);
                        if (struct_decl) {
                            int field_index = find_struct_field_index(struct_decl, field_name);
                            if (field_index >= 0 && field_index < struct_decl->data.struct_decl.field_count) {
                                ASTNode *field = struct_decl->data.struct_decl.fields[field_index];
                                if (field && field->type == AST_VAR_DECL) {
                                    ASTNode *field_type_node = field->data.var_decl.type;
                                    if (field_type_node) {
                                        array_type = get_llvm_type_from_ast(codegen, field_type_node);
                                        // array_ptr 是指向数组的指针，array_type 应该是数组类型
                                        // 验证 array_type 是数组类型
                                        if (array_type && LLVMGetTypeKind(array_type) == LLVMArrayTypeKind) {
                                            // 正确：array_type 是数组类型，array_ptr 是指向数组的指针
                                        } else {
                                            // 如果从 AST 获取的类型不是数组类型，尝试从指针类型获取
                                            LLVMTypeRef array_ptr_type = safe_LLVMTypeOf(array_ptr);
                                            if (array_ptr_type && LLVMGetTypeKind(array_ptr_type) == LLVMPointerTypeKind) {
                                                array_type = safe_LLVMGetElementType(array_ptr_type);
                                                // 如果 safe_LLVMGetElementType 失败，使用从 AST 获取的类型
                                                if (!array_type || array_type == (LLVMTypeRef)1) {
                                                    array_type = get_llvm_type_from_ast(codegen, field_type_node);
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            // 如果通过标识符路径失败，使用通用方法生成数组表达式
            if (!array_ptr || !array_type) {
                // 如果数组表达式是另一个数组访问，递归获取地址并从 AST 获取类型
                if (array_expr->type == AST_ARRAY_ACCESS) {
                    // 递归获取数组的地址（这会返回指向数组的指针）
                    array_ptr = codegen_gen_lvalue_address(codegen, array_expr);
                    if (!array_ptr || array_ptr == (LLVMValueRef)1) {
                        const char *filename = array_expr->filename ? array_expr->filename : "<unknown>";
                        fprintf(stderr, "错误: 嵌套数组访问地址生成失败 (%s:%d:%d)\n",
                                filename, array_expr->line, array_expr->column);
                        fprintf(stderr, "  错误原因: 多维数组访问中，内层数组访问表达式生成失败\n");
                        fprintf(stderr, "  可能原因:\n");
                        fprintf(stderr, "    - 内层数组表达式不是有效的数组或指针类型\n");
                        fprintf(stderr, "    - 内层数组访问的索引表达式生成失败\n");
                        fprintf(stderr, "    - 数组变量未定义或类型不正确\n");
                        fprintf(stderr, "  修改建议:\n");
                        fprintf(stderr, "    - 检查多维数组的声明是否正确，例如: var arr: [[i32: 2]: 3]\n");
                        fprintf(stderr, "    - 确保内层数组访问的索引是有效的整数表达式\n");
                        fprintf(stderr, "    - 检查数组变量是否已正确声明和初始化\n");
                        return NULL;
                    }
                    
                    // 优先从指针类型获取数组类型（这是最可靠的方法）
                    LLVMTypeRef array_ptr_type = safe_LLVMTypeOf(array_ptr);
                    if (array_ptr_type && LLVMGetTypeKind(array_ptr_type) == LLVMPointerTypeKind) {
                        array_type = safe_LLVMGetElementType(array_ptr_type);
                        // 验证获取的类型是否是数组类型
                        if (array_type && array_type != (LLVMTypeRef)1 && 
                            LLVMGetTypeKind(array_type) == LLVMArrayTypeKind) {
                            // 成功从指针类型获取数组类型
                        } else {
                            array_type = NULL;  // 重置，尝试其他方法
                        }
                    }
                    
                    // 如果从指针类型获取失败，尝试从 AST 获取
                    if (!array_type) {
                        ASTNode *nested_array_expr = array_expr->data.array_access.array;
                        if (nested_array_expr && nested_array_expr->type == AST_IDENTIFIER) {
                            const char *nested_var_name = nested_array_expr->data.identifier.name;
                            if (nested_var_name) {
                                LLVMTypeRef nested_var_type = lookup_var_type(codegen, nested_var_name);
                                if (nested_var_type && LLVMGetTypeKind(nested_var_type) == LLVMArrayTypeKind) {
                                    // 获取数组的元素类型（对于多维数组，这是内层数组类型）
                                    array_type = LLVMGetElementType(nested_var_type);
                                    if (!array_type || array_type == (LLVMTypeRef)1) {
                                        // 如果 LLVMGetElementType 失败，尝试从 AST 获取
                                        ASTNode *var_ast_type = lookup_var_ast_type(codegen, nested_var_name);
                                        if (var_ast_type && var_ast_type->type == AST_TYPE_ARRAY) {
                                            ASTNode *element_type_node = var_ast_type->data.type_array.element_type;
                                            if (element_type_node) {
                                                array_type = get_llvm_type_from_ast(codegen, element_type_node);
                                            }
                                        }
                                    }
                                }
                            }
                        } else if (nested_array_expr && nested_array_expr->type == AST_ARRAY_ACCESS) {
                            // 嵌套数组访问：递归获取类型
                            // 对于 arr2d[0][0]，nested_array_expr 是 arr2d[0]
                            // 我们需要获取 arr2d[0] 的类型，即 [i32: 2]
                            // 从 arr2d 的类型获取元素类型
                            ASTNode *base_array_expr = nested_array_expr->data.array_access.array;
                            if (base_array_expr && base_array_expr->type == AST_IDENTIFIER) {
                                ASTNode *var_ast_type = lookup_var_ast_type(codegen, base_array_expr->data.identifier.name);
                                if (var_ast_type && var_ast_type->type == AST_TYPE_ARRAY) {
                                    ASTNode *element_type_node = var_ast_type->data.type_array.element_type;
                                    if (element_type_node) {
                                        // element_type_node 是 [i32: 2]，这就是我们需要的类型
                                        array_type = get_llvm_type_from_ast(codegen, element_type_node);
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // 生成数组表达式值
                    LLVMValueRef array_val = codegen_gen_expr(codegen, array_expr);
                    if (!array_val) {
                        const char *filename = array_expr->filename ? array_expr->filename : "<unknown>";
                        fprintf(stderr, "错误: 数组表达式生成失败 (%s:%d:%d)\n",
                                filename, array_expr->line, array_expr->column);
                        fprintf(stderr, "  错误原因: 无法生成数组表达式的值\n");
                        fprintf(stderr, "  可能原因:\n");
                        fprintf(stderr, "    - 数组变量未定义\n");
                        fprintf(stderr, "    - 数组表达式包含未定义的变量或函数调用\n");
                        fprintf(stderr, "    - 数组类型不匹配或无效\n");
                        fprintf(stderr, "  修改建议:\n");
                        fprintf(stderr, "    - 检查数组变量是否已声明，例如: var arr: [i32: 10]\n");
                        fprintf(stderr, "    - 确保数组表达式中使用的变量都已定义\n");
                        fprintf(stderr, "    - 检查数组类型声明是否正确\n");
                        return NULL;
                    }
                    
                    // 检查 array_val 是否是标记值
                    if (array_val == (LLVMValueRef)1) {
                        fprintf(stderr, "警告: codegen_gen_lvalue_address 数组值是标记值，跳过生成\n");
                        return NULL;
                    }
                    
                    LLVMTypeRef array_val_type = safe_LLVMTypeOf(array_val);
                    if (!array_val_type) {
                        fprintf(stderr, "警告: codegen_gen_lvalue_address 无法获取数组值类型，跳过生成\n");
                        return NULL;
                    }
                    
                    LLVMTypeKind array_val_kind = LLVMGetTypeKind(array_val_type);
                    if (array_val_kind == LLVMArrayTypeKind) {
                        // 数组值类型，需要分配临时空间存储数组值
                        array_type = array_val_type;
                        array_ptr = LLVMBuildAlloca(codegen->builder, array_type, "");
                        if (!array_ptr) {
                            return NULL;
                        }
                        LLVMBuildStore(codegen->builder, array_val, array_ptr);
                    } else if (array_val_kind == LLVMPointerTypeKind) {
                        // 指针类型（如 &byte 或指向数组的指针）
                        array_ptr = array_val;
                        array_type = safe_LLVMGetElementType(array_val_type);
                        if (!array_type) {
                            fprintf(stderr, "错误: codegen_gen_lvalue_address 无法获取指针指向的类型\n");
                            return NULL;
                        }
                        // 检查指向的类型是否是数组类型
                        // 如果不是数组类型，是指向单个元素的指针（如 &byte）
                        // 对于这种情况，我们将在后面使用元素类型和单个索引进行 GEP
                        // 参考 clang 生成的 IR: getelementptr inbounds i8, ptr %buffer_ptr, i64 0
                        // 验证 array_type 是否有效
                        if (array_type == (LLVMTypeRef)1) {
                            fprintf(stderr, "错误: codegen_gen_lvalue_address array_type 是标记值\n");
                            return NULL;
                        }
                    } else {
                        fprintf(stderr, "错误: codegen_gen_lvalue_address 数组值类型不是数组或指针类型 (kind=%d)\n", (int)array_val_kind);
                        return NULL;  // 不是数组类型或指针类型
                    }
                }
            }
            
            // 生成索引表达式值
            LLVMValueRef index_val = codegen_gen_expr(codegen, index_expr);
            if (!index_val || index_val == (LLVMValueRef)1) {
                // 添加源码位置信息
                const char *filename = index_expr->filename ? index_expr->filename : "<unknown>";
                fprintf(stderr, "错误: 数组访问索引表达式生成失败 (%s:%d:%d)\n", 
                        filename, index_expr->line, index_expr->column);
                return NULL;
            }
            
            // 确保索引值是整数类型（i32）
            LLVMTypeRef index_type = safe_LLVMTypeOf(index_val);
            if (!index_type) {
                const char *filename = index_expr->filename ? index_expr->filename : "<unknown>";
                fprintf(stderr, "错误: 数组访问索引类型无效 (%s:%d:%d)\n", 
                        filename, index_expr->line, index_expr->column);
                return NULL;
            }
            
            LLVMTypeRef i32_type = LLVMInt32TypeInContext(codegen->context);
            if (index_type != i32_type) {
                // 索引类型不是 i32，需要进行类型转换
                LLVMTypeKind index_kind = LLVMGetTypeKind(index_type);
                if (index_kind == LLVMIntegerTypeKind) {
                    // 整数类型：进行符号扩展或截断
                    unsigned index_width = LLVMGetIntTypeWidth(index_type);
                    if (index_width < 32) {
                        // 零扩展到 i32
                        index_val = LLVMBuildZExt(codegen->builder, index_val, i32_type, "");
                    } else if (index_width > 32) {
                        // 截断到 i32
                        index_val = LLVMBuildTrunc(codegen->builder, index_val, i32_type, "");
                    }
                } else {
                    // 非整数类型：错误
                    const char *filename = index_expr->filename ? index_expr->filename : "<unknown>";
                    fprintf(stderr, "错误: 数组访问索引必须是整数类型 (%s:%d:%d)\n", 
                            filename, index_expr->line, index_expr->column);
                    return NULL;
                }
            }
            
            // 使用 GEP 获取元素地址
            if (!array_ptr || !array_type) {
                fprintf(stderr, "错误: codegen_gen_lvalue_address 数组指针或类型为空\n");
                return NULL;
            }
            
            // 检查 array_type 是否有效（避免段错误）
            // 注意：LLVMGetTypeKind 可能对无效类型崩溃
            // 如果 array_type 是通过 safe_LLVMTypeOf 获取的，它可能是 NULL 或标记值
            // 但我们已经检查了 array_type 不为 NULL，所以问题可能是类型本身无效
            // 为了安全，我们尝试使用 try-catch 机制，但 C 不支持异常
            // 所以我们需要在调用前进行更严格的检查
            
            // 尝试获取类型种类
            // 如果 array_type 是无效指针，LLVMGetTypeKind 会崩溃
            // 我们无法在 C 中捕获这种崩溃，所以只能跳过这个操作
            // 放宽检查：如果类型获取失败，跳过数组访问
            // 首先验证 array_type 不是 NULL 且不是标记值
            if (!array_type || array_type == (LLVMTypeRef)1) {
                return NULL;
            }
            
            // 验证 array_ptr 不是 NULL 且不是标记值
            if (!array_ptr || array_ptr == (LLVMValueRef)1) {
                return NULL;
            }
            
            LLVMTypeKind array_type_kind;
            // 注意：这里我们假设 array_type 是有效的，但如果它无效，程序会崩溃
            // 为了安全，我们应该在更早的地方检查 array_val 是否是标记值
            array_type_kind = LLVMGetTypeKind(array_type);
            if (array_type_kind == LLVMVoidTypeKind || array_type_kind == LLVMLabelTypeKind) {
                // 无效类型
                fprintf(stderr, "警告: codegen_gen_lvalue_address 数组类型无效，跳过生成\n");
                return NULL;
            }
            
            LLVMValueRef element_ptr = NULL;
            
            // 检查是否是数组类型还是指针类型
            if (array_type_kind == LLVMArrayTypeKind) {
                // 数组类型：使用两个索引的 GEP
                // 注意：array_ptr 应该是指向数组的指针类型，array_type 是数组类型
                // 验证 array_ptr 的类型是指向 array_type 的指针
                LLVMTypeRef array_ptr_type = safe_LLVMTypeOf(array_ptr);
                if (!array_ptr_type || LLVMGetTypeKind(array_ptr_type) != LLVMPointerTypeKind) {
                    fprintf(stderr, "错误: codegen_gen_lvalue_address array_ptr 不是指针类型\n");
                    return NULL;
                }
                
                // 验证 array_ptr 的类型是指向数组的指针
                // 注意：我们不需要严格比较类型，只需要确保 array_type 是数组类型即可
                // array_ptr 的类型应该是指向 array_type 的指针，这在逻辑上已经满足
                
                LLVMValueRef indices[2];
                indices[0] = LLVMConstInt(LLVMInt32TypeInContext(codegen->context), 0ULL, 0);  // 数组指针本身
                indices[1] = index_val;  // 元素索引（运行时值）
                
                element_ptr = LLVMBuildGEP2(codegen->builder, array_type, array_ptr, indices, 2, "");
            } else {
                // 指针类型（指向单个元素）：直接使用元素类型和单个索引
                // 参考 clang 生成的 IR: getelementptr inbounds i8, ptr %buffer_ptr, i64 0
                LLVMTypeRef element_type = array_type;  // array_type 已经是元素类型（如 i8）
                
                LLVMValueRef indices[1];
                indices[0] = index_val;  // 单个索引
                
                element_ptr = LLVMBuildGEP2(codegen->builder, element_type, array_ptr, indices, 1, "");
            }
            
            if (!element_ptr) {
                // 添加源码位置信息
                const char *filename = index_expr->filename ? index_expr->filename : "<unknown>";
                fprintf(stderr, "错误: 数组访问地址生成失败 (%s:%d:%d) (array_type kind: %d)\n", 
                        filename, index_expr->line, index_expr->column, (int)array_type_kind);
                // 验证索引类型
                if (index_val) {
                    LLVMTypeRef index_type_check = safe_LLVMTypeOf(index_val);
                    if (index_type_check) {
                        LLVMTypeKind index_kind = LLVMGetTypeKind(index_type_check);
                        fprintf(stderr, "调试: 索引值类型 kind=%d, 宽度=%u\n", 
                                (int)index_kind, 
                                (index_kind == LLVMIntegerTypeKind) ? LLVMGetIntTypeWidth(index_type_check) : 0);
                    }
                }
                return NULL;
            }
            
            // 返回元素地址（不需要加载值）
            return element_ptr;
        }
        
        default:
            // 暂不支持其他类型的左值
            return NULL;
    }
}

// 辅助函数：在变量表中查找变量类型（先查找局部变量，再查找全局变量）
// 参数：codegen - 代码生成器指针
//       var_name - 变量名称
// 返回：LLVM类型引用，未找到返回NULL
LLVMTypeRef lookup_var_type(CodeGenerator *codegen, const char *var_name) {
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
ASTNode *lookup_var_ast_type(CodeGenerator *codegen, const char *var_name) {
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
int add_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef value, LLVMTypeRef type, const char *struct_name, ASTNode *ast_type) {
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
const char *lookup_var_struct_name(CodeGenerator *codegen, const char *var_name) {
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
int add_global_var(CodeGenerator *codegen, const char *var_name, LLVMValueRef global_var, LLVMTypeRef type, const char *struct_name) {
    if (!codegen || !var_name || !global_var || !type) {
        // 调试信息
        if (var_name) {
            fprintf(stderr, "调试: add_global_var 参数检查失败: %s (codegen=%p, var_name=%p, global_var=%p, type=%p)\n", 
                    var_name, (void*)codegen, (void*)var_name, (void*)global_var, (void*)type);
        }
        return -1;
    }
    
    // 检查映射表是否已满
    if (codegen->global_var_map_count >= 128) {
        // 调试信息
        fprintf(stderr, "调试: 全局变量映射表已满: %s (count=%d)\n", var_name, codegen->global_var_map_count);
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
