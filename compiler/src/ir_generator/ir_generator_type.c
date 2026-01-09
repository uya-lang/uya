#include "ir_generator_internal.h"
#include "../checker/const_eval.h"

IRType get_ir_type(struct ASTNode *ast_type) {
    if (!ast_type) return IR_TYPE_VOID;

    switch (ast_type->type) {
        case AST_TYPE_NAMED:
            {
                const char *name = ast_type->data.type_named.name;
                if (strcmp(name, "i32") == 0) return IR_TYPE_I32;
                if (strcmp(name, "i64") == 0) return IR_TYPE_I64;
                if (strcmp(name, "i8") == 0) return IR_TYPE_I8;
                if (strcmp(name, "i16") == 0) return IR_TYPE_I16;
                if (strcmp(name, "u32") == 0) return IR_TYPE_U32;
                if (strcmp(name, "u64") == 0) return IR_TYPE_U64;
                if (strcmp(name, "u8") == 0) return IR_TYPE_U8;
                if (strcmp(name, "u16") == 0) return IR_TYPE_U16;
                if (strcmp(name, "f32") == 0) return IR_TYPE_F32;
                if (strcmp(name, "f64") == 0) return IR_TYPE_F64;
                if (strcmp(name, "bool") == 0) return IR_TYPE_BOOL;
                if (strcmp(name, "void") == 0) return IR_TYPE_VOID;
                if (strcmp(name, "byte") == 0) return IR_TYPE_BYTE;

                // Handle generic type parameter T (temporarily treat as i32 until generics are fully implemented)
                if (strcmp(name, "T") == 0) return IR_TYPE_I32;

                // For user-defined types like Point, Vec3, etc., return STRUCT type
                return IR_TYPE_STRUCT;
            }
        case AST_TYPE_ARRAY:
            return IR_TYPE_ARRAY;
        case AST_TYPE_POINTER:
            return IR_TYPE_PTR;
        case AST_TYPE_ERROR_UNION:
            // For error union types, temporarily return the base type
            // Full error handling implementation will be added later
            return get_ir_type(ast_type->data.type_error_union.base_type);
        case AST_TYPE_ATOMIC:
            // For atomic types, return the base type
            // The atomic flag will be set separately
            return get_ir_type(ast_type->data.type_atomic.base_type);
        case AST_TYPE_FN:
            // 函数指针类型：fn(param_types) return_type
            return IR_TYPE_FN;
        case AST_TYPE_TUPLE:
            // 元组类型使用 IR_TYPE_STRUCT 作为占位符
            return IR_TYPE_STRUCT;
        default:
            return IR_TYPE_VOID;
    }
}

// 从表达式节点推断 IR 类型（简化版）
IRType infer_ir_type_from_expr(struct ASTNode *expr) {
    if (!expr) return IR_TYPE_VOID;
    
    switch (expr->type) {
        case AST_NUMBER: {
            // 检查是否是浮点数字面量
            const char *value = expr->data.number.value;
            if (value && (strchr(value, '.') || strchr(value, 'e') || strchr(value, 'E'))) {
                return IR_TYPE_F64;
            }
            return IR_TYPE_I32;
        }
        case AST_BOOL:
            return IR_TYPE_BOOL;
        case AST_IDENTIFIER:
            // 对于标识符，默认返回 i32（实际类型应该在类型检查阶段确定）
            return IR_TYPE_I32;
        case AST_BINARY_EXPR:
            // 对于二元表达式，返回左操作数的类型
            return infer_ir_type_from_expr(expr->data.binary_expr.left);
        case AST_UNARY_EXPR:
            // 对于一元表达式，返回操作数的类型
            return infer_ir_type_from_expr(expr->data.unary_expr.operand);
        default:
            return IR_TYPE_I32;  // 默认返回 i32
    }
}

// Helper function to get type name string from AST type node
char *get_type_name_string(struct ASTNode *type_node) {
    if (!type_node) {
        return NULL;
    }
    
    switch (type_node->type) {
        case AST_TYPE_NAMED:
            {
                const char *name = type_node->data.type_named.name;
                char *result = malloc(strlen(name) + 1);
                if (result) {
                    strcpy(result, name);
                }
                return result;
            }
        case AST_TYPE_ARRAY:
            {
                // For arrays: array_ElementType
                struct ASTNode *elem_type = type_node->data.type_array.element_type;
                char *elem_name = get_type_name_string(elem_type);
                if (!elem_name) {
                    return NULL;
                }
                char *result = malloc(strlen(elem_name) + 16);
                if (result) {
                    snprintf(result, strlen(elem_name) + 16, "array_%s", elem_name);
                }
                free(elem_name);
                return result;
            }
        case AST_TYPE_POINTER:
            {
                // For pointers: ptr_PointeeType
                struct ASTNode *pointee_type = type_node->data.type_pointer.pointee_type;
                char *elem_name = get_type_name_string(pointee_type);
                if (!elem_name) {
                    return NULL;
                }
                char *result = malloc(strlen(elem_name) + 16);
                if (result) {
                    snprintf(result, strlen(elem_name) + 16, "ptr_%s", elem_name);
                }
                free(elem_name);
                return result;
            }
        case AST_TYPE_TUPLE:
            {
                // For tuples: tuple_T1_T2_...
                char *result = malloc(256);  // Allocate enough space
                if (!result) {
                    return NULL;
                }
                strcpy(result, "tuple");
                for (int i = 0; i < type_node->data.type_tuple.element_count; i++) {
                    char *elem_name = get_type_name_string(type_node->data.type_tuple.element_types[i]);
                    if (!elem_name) {
                        free(result);
                        return NULL;
                    }
                    // Append underscore and element type name
                    size_t new_len = strlen(result) + strlen(elem_name) + 2;
                    char *new_result = realloc(result, new_len);
                    if (!new_result) {
                        free(result);
                        free(elem_name);
                        return NULL;
                    }
                    result = new_result;
                    strcat(result, "_");
                    strcat(result, elem_name);
                    free(elem_name);
                }
                return result;
            }
        case AST_TYPE_ERROR_UNION:
            {
                // For error unions: error_union_BaseType
                struct ASTNode *base_type = type_node->data.type_error_union.base_type;
                char *base_name = get_type_name_string(base_type);
                if (!base_name) {
                    return NULL;
                }
                char *result = malloc(strlen(base_name) + 32);
                if (result) {
                    snprintf(result, strlen(base_name) + 32, "error_union_%s", base_name);
                }
                free(base_name);
                return result;
            }
        case AST_TYPE_ATOMIC:
            {
                // For atomic: atomic_BaseType
                struct ASTNode *base_type = type_node->data.type_atomic.base_type;
                char *base_name = get_type_name_string(base_type);
                if (!base_name) {
                    return NULL;
                }
                char *result = malloc(strlen(base_name) + 32);
                if (result) {
                    snprintf(result, strlen(base_name) + 32, "atomic_%s", base_name);
                }
                free(base_name);
                return result;
            }
        case AST_TYPE_FN:
            {
                // For function pointers: fn_... (simplified)
                char *result = malloc(16);
                if (result) {
                    strcpy(result, "fn");
                }
                return result;
            }
        default:
            return NULL;
    }
}

// Generate tuple type name from AST_TYPE_TUPLE node
// Returns a unique name based on element types (e.g., "tuple_i32_bool")
char *generate_tuple_type_name(struct ASTNode *tuple_type) {
    if (!tuple_type || tuple_type->type != AST_TYPE_TUPLE) {
        return NULL;
    }
    
    return get_type_name_string(tuple_type);
}

// Ensure tuple struct declaration exists in IR
// Returns the struct declaration IR instruction if it already exists or was created
IRInst *ensure_tuple_struct_decl(IRGenerator *ir_gen, struct ASTNode *tuple_type) {
    if (!ir_gen || !tuple_type || tuple_type->type != AST_TYPE_TUPLE) {
        return NULL;
    }
    
    // Generate tuple type name
    char *tuple_type_name = generate_tuple_type_name(tuple_type);
    if (!tuple_type_name) {
        return NULL;
    }
    
    // Check if struct declaration already exists
    for (int i = 0; i < ir_gen->inst_count; i++) {
        if (ir_gen->instructions[i] && ir_gen->instructions[i]->type == IR_STRUCT_DECL) {
            if (ir_gen->instructions[i]->data.struct_decl.name &&
                strcmp(ir_gen->instructions[i]->data.struct_decl.name, tuple_type_name) == 0) {
                // Found existing struct declaration
                free(tuple_type_name);
                return ir_gen->instructions[i];
            }
        }
    }
    
    // Struct declaration doesn't exist, create it
    IRInst *struct_ir = irinst_new(IR_STRUCT_DECL);
    if (!struct_ir) {
        free(tuple_type_name);
        return NULL;
    }
    
    // Set struct name
    struct_ir->data.struct_decl.name = tuple_type_name;
    
    // Handle fields
    struct_ir->data.struct_decl.field_count = tuple_type->data.type_tuple.element_count;
    if (tuple_type->data.type_tuple.element_count > 0) {
        struct_ir->data.struct_decl.fields = malloc(tuple_type->data.type_tuple.element_count * sizeof(IRInst*));
        if (!struct_ir->data.struct_decl.fields) {
            free(tuple_type_name);
            irinst_free(struct_ir);
            return NULL;
        }
        
        for (int i = 0; i < tuple_type->data.type_tuple.element_count; i++) {
            // Create field as variable declaration
            IRInst *field = irinst_new(IR_VAR_DECL);
            if (!field) {
                // Clean up on failure
                for (int j = 0; j < i; j++) {
                    if (struct_ir->data.struct_decl.fields[j]) {
                        irinst_free(struct_ir->data.struct_decl.fields[j]);
                    }
                }
                free(struct_ir->data.struct_decl.fields);
                free(tuple_type_name);
                irinst_free(struct_ir);
                return NULL;
            }
            
            // Field name: _0, _1, _2, etc.
            char field_name[16];
            snprintf(field_name, sizeof(field_name), "_%d", i);
            field->data.var.name = malloc(strlen(field_name) + 1);
            if (!field->data.var.name) {
                irinst_free(field);
                // Clean up on failure
                for (int j = 0; j < i; j++) {
                    if (struct_ir->data.struct_decl.fields[j]) {
                        irinst_free(struct_ir->data.struct_decl.fields[j]);
                    }
                }
                free(struct_ir->data.struct_decl.fields);
                free(tuple_type_name);
                irinst_free(struct_ir);
                return NULL;
            }
            strcpy(field->data.var.name, field_name);
            
            // Get field type from tuple element type
            struct ASTNode *element_type = tuple_type->data.type_tuple.element_types[i];
            if (!element_type) {
                irinst_free(field);
                // Clean up on failure
                for (int j = 0; j < i; j++) {
                    if (struct_ir->data.struct_decl.fields[j]) {
                        irinst_free(struct_ir->data.struct_decl.fields[j]);
                    }
                }
                free(struct_ir->data.struct_decl.fields);
                free(tuple_type_name);
                irinst_free(struct_ir);
                return NULL;
            }
            
            // Check if the type is atomic
            field->data.var.is_atomic = (element_type->type == AST_TYPE_ATOMIC) ? 1 : 0;
            
            // Handle nested tuple types: ensure their struct declarations exist
            if (element_type->type == AST_TYPE_TUPLE) {
                IRInst *nested_struct = ensure_tuple_struct_decl(ir_gen, element_type);
                if (!nested_struct) {
                    irinst_free(field);
                    // Clean up on failure
                    for (int j = 0; j < i; j++) {
                        if (struct_ir->data.struct_decl.fields[j]) {
                            irinst_free(struct_ir->data.struct_decl.fields[j]);
                        }
                    }
                    free(struct_ir->data.struct_decl.fields);
                    free(tuple_type_name);
                    irinst_free(struct_ir);
                    return NULL;
                }
            }
            
            field->data.var.type = get_ir_type(element_type);
            field->data.var.is_mut = 0;  // Tuple fields are immutable
            field->data.var.init = NULL;
            field->id = ir_gen->current_id++;
            
            // Store original type name for struct/enum types
            if (field->data.var.type == IR_TYPE_STRUCT || field->data.var.type == IR_TYPE_ENUM) {
                char *type_name = get_type_name_string(element_type);
                if (type_name) {
                    field->data.var.original_type_name = type_name;
                }
            }
            
            struct_ir->data.struct_decl.fields[i] = field;
        }
    } else {
        struct_ir->data.struct_decl.fields = NULL;
    }
    
    struct_ir->id = ir_gen->current_id++;
    
    // Add to instructions array
    if (ir_gen->inst_count >= ir_gen->inst_capacity) {
        size_t new_capacity = ir_gen->inst_capacity * 2;
        IRInst **new_instructions = realloc(ir_gen->instructions,
                                           new_capacity * sizeof(IRInst*));
        if (!new_instructions) {
            // Clean up on failure
            if (struct_ir->data.struct_decl.fields) {
                for (int i = 0; i < struct_ir->data.struct_decl.field_count; i++) {
                    if (struct_ir->data.struct_decl.fields[i]) {
                        irinst_free(struct_ir->data.struct_decl.fields[i]);
                    }
                }
                free(struct_ir->data.struct_decl.fields);
            }
            free(tuple_type_name);
            irinst_free(struct_ir);
            return NULL;
        }
        ir_gen->instructions = new_instructions;
        ir_gen->inst_capacity = new_capacity;
    }
    if (ir_gen->inst_count < ir_gen->inst_capacity) {
        ir_gen->instructions[ir_gen->inst_count++] = struct_ir;
    }
    
    return struct_ir;
}

// Find struct declaration by name in IR
IRInst *find_struct_decl(IRGenerator *ir_gen, const char *struct_name) {
    if (!ir_gen || !struct_name) {
        return NULL;
    }
    
    for (int i = 0; i < ir_gen->inst_count; i++) {
        if (ir_gen->instructions[i] && ir_gen->instructions[i]->type == IR_STRUCT_DECL) {
            if (ir_gen->instructions[i]->data.struct_decl.name &&
                strcmp(ir_gen->instructions[i]->data.struct_decl.name, struct_name) == 0) {
                return ir_gen->instructions[i];
            }
        }
    }
    
    return NULL;
}

