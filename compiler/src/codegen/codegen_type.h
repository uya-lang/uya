#ifndef CODEGEN_TYPE_H
#define CODEGEN_TYPE_H

#include "../ir/ir.h"
#include "codegen.h"
#include <stdint.h>

// Type handling functions
char *codegen_get_type_name(IRType type);
const char *codegen_convert_uya_type_to_c(const char *uya_type_name);
void codegen_write_type(CodeGenerator *codegen, IRType type);
void codegen_write_type_with_name(CodeGenerator *codegen, IRType type, const char *original_type_name);
void codegen_write_error_union_type_name(CodeGenerator *codegen, IRType base_type);
void codegen_write_error_union_type_def(CodeGenerator *codegen, IRType base_type);
void codegen_write_type_with_atomic(CodeGenerator *codegen, IRInst *var_inst);
const char *codegen_find_struct_name_from_return_type(CodeGenerator *codegen, IRInst *func_inst);
int find_function_return_type(IRGenerator *ir, const char *func_name, IRType *base_type, int *is_error_union);

#endif