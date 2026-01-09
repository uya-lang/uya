#include "codegen_type.h"
#include "codegen.h"
#include "../ir/ir.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

char *codegen_get_type_name(IRType type) {
    switch (type) {
        case IR_TYPE_I8: return "int8_t";
        case IR_TYPE_I16: return "int16_t";
        case IR_TYPE_I32: return "int32_t";
        case IR_TYPE_I64: return "int64_t";
        case IR_TYPE_U8: return "uint8_t";
        case IR_TYPE_U16: return "uint16_t";
        case IR_TYPE_U32: return "uint32_t";
        case IR_TYPE_U64: return "uint64_t";
        case IR_TYPE_F32: return "float";
        case IR_TYPE_F64: return "double";
        case IR_TYPE_BOOL: return "_Bool";  // Use _Bool for C99 bool
        case IR_TYPE_BYTE: return "uint8_t";
        case IR_TYPE_VOID: return "void";
        case IR_TYPE_PTR: return "void*";
        case IR_TYPE_ARRAY: return "int32_t*";  // For now, use pointer for arrays
        case IR_TYPE_STRUCT: return "struct_type"; // 需要特殊处理，使用 original_type_name
        case IR_TYPE_FN: return "void(*)()";     // 函数指针类型（通用函数指针，后续需要完善支持具体签名）
        case IR_TYPE_ERROR_UNION: return "error_union"; // 需要特殊处理
        default: return "unknown_type";
    }
}

// Convert Uya type name to C type name
const char *codegen_convert_uya_type_to_c(const char *uya_type_name) {
    if (!uya_type_name) return NULL;
    
    if (strcmp(uya_type_name, "i8") == 0) return "int8_t";
    if (strcmp(uya_type_name, "i16") == 0) return "int16_t";
    if (strcmp(uya_type_name, "i32") == 0) return "int32_t";
    if (strcmp(uya_type_name, "i64") == 0) return "int64_t";
    if (strcmp(uya_type_name, "u8") == 0) return "uint8_t";
    if (strcmp(uya_type_name, "u16") == 0) return "uint16_t";
    if (strcmp(uya_type_name, "u32") == 0) return "uint32_t";
    if (strcmp(uya_type_name, "u64") == 0) return "uint64_t";
    if (strcmp(uya_type_name, "f32") == 0) return "float";
    if (strcmp(uya_type_name, "f64") == 0) return "double";
    if (strcmp(uya_type_name, "bool") == 0) return "_Bool";
    if (strcmp(uya_type_name, "byte") == 0) return "uint8_t";
    if (strcmp(uya_type_name, "void") == 0) return "void";
    
    // For user-defined types, return as-is (they should match C struct names)
    return uya_type_name;
}

// Helper function to find struct name from return type
// For struct return types, we need to find the struct name from IR
// This is a workaround since IR doesn't store return_type_original_name
const char *codegen_find_struct_name_from_return_type(CodeGenerator *codegen, IRInst *func_inst) {
    if (!codegen || !codegen->ir || !func_inst || func_inst->data.func.return_type != IR_TYPE_STRUCT) {
        return NULL;
    }

    // Try to find struct name by looking at all struct declarations in IR
    // This is a simple heuristic: if there's only one struct, use it
    // Otherwise, we can't determine which struct it is
    if (codegen->ir && codegen->ir->instructions) {
        const char *found_struct_name = NULL;
        int struct_count = 0;
        for (int i = 0; i < codegen->ir->inst_count; i++) {
            if (codegen->ir->instructions[i] && codegen->ir->instructions[i]->type == IR_STRUCT_DECL) {
                struct_count++;
                if (!found_struct_name) {
                    found_struct_name = codegen->ir->instructions[i]->data.struct_decl.name;
                }
            }
        }
        // If there's exactly one struct, use it (common case)
        if (struct_count == 1 && found_struct_name) {
            return found_struct_name;
        }
    }

    return NULL;
}

void codegen_write_type(CodeGenerator *codegen, IRType type) {
    fprintf(codegen->output_file, "%s", codegen_get_type_name(type));
}

// Write type with optional original type name (for struct types and function pointer types)
void codegen_write_type_with_name(CodeGenerator *codegen, IRType type, const char *original_type_name) {
    if (type == IR_TYPE_STRUCT && original_type_name) {
        fprintf(codegen->output_file, "%s", original_type_name);
    } else if (type == IR_TYPE_FN) {
        // 函数指针类型：使用通用函数指针类型 void(*)()
        // 后续可以完善支持具体的函数指针类型签名
        fprintf(codegen->output_file, "void(*)()");
    } else {
        codegen_write_type(codegen, type);
    }
}

// Generate error union type name (struct error_union_T)
void codegen_write_error_union_type_name(CodeGenerator *codegen, IRType base_type) {
    const char *base_name = codegen_get_type_name(base_type);
    fprintf(codegen->output_file, "struct error_union_%s", base_name);
}

// Generate error union type definition
// According to uya.md: struct error_union_T { uint32_t error_id; T value; }
// error_id == 0: success (use value field)
// error_id != 0: error (error_id contains error code, value field undefined)
void codegen_write_error_union_type_def(CodeGenerator *codegen, IRType base_type) {
    const char *base_name = codegen_get_type_name(base_type);
    fprintf(codegen->output_file, "struct error_union_%s {\n", base_name);
    fprintf(codegen->output_file, "    uint32_t error_id; // 0 = success (use value), non-zero = error (use error_id)\n");
    if (base_type == IR_TYPE_VOID) {
        // For !void, only error_id field, no value field
        fprintf(codegen->output_file, "};\n\n");
    } else {
        fprintf(codegen->output_file, "    %s value; // success value (only valid when error_id == 0)\n", base_name);
        fprintf(codegen->output_file, "};\n\n");
    }
}

// Write type with atomic support (for struct fields and variable declarations)
void codegen_write_type_with_atomic(CodeGenerator *codegen, IRInst *var_inst) {
    if (!var_inst) {
        codegen_write_type(codegen, IR_TYPE_VOID);
        return;
    }

    if (var_inst->data.var.is_atomic) {
        // Generate C11 atomic type: _Atomic(type)
        fprintf(codegen->output_file, "_Atomic(");
        codegen_write_type(codegen, var_inst->data.var.type);
        fprintf(codegen->output_file, ")");
    } else {
        codegen_write_type(codegen, var_inst->data.var.type);
    }
}

// Helper function to find function return type from IR
// Returns the base type (not error union type) and whether it's an error union
int find_function_return_type(IRGenerator *ir, const char *func_name, IRType *base_type, int *is_error_union) {
    if (!ir || !ir->instructions || !func_name) {
        return 0;
    }

    for (int i = 0; i < ir->inst_count; i++) {
        if (ir->instructions[i] && ir->instructions[i]->type == IR_FUNC_DEF) {
            IRInst *func = ir->instructions[i];
            if (func->data.func.name && strcmp(func->data.func.name, func_name) == 0) {
                *base_type = func->data.func.return_type;
                *is_error_union = func->data.func.return_type_is_error_union;
                return 1;
            }
        }
    }

    return 0;
}
