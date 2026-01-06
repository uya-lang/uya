#ifndef CODEGEN_H
#define CODEGEN_H

#include "../ir/ir.h"
#include <stdio.h>
#include <stdint.h>

// 错误名称映射表结构
typedef struct ErrorNameMap {
    char *error_name;
    uint32_t error_code;
} ErrorNameMap;

// 代码生成器结构
typedef struct CodeGenerator {
    FILE *output_file;
    char *output_filename;
    int label_counter;
    int temp_counter;
    IRInst *current_function;  // Current function context for member access type checking
    IRGenerator *ir;  // IR generator for looking up function signatures
    ErrorNameMap *error_map;  // 错误名称到错误码的映射表
    int error_map_size;       // 映射表大小
    int error_map_capacity;   // 映射表容量
} CodeGenerator;

// 代码生成器函数
CodeGenerator *codegen_new();
void codegen_free(CodeGenerator *codegen);
int codegen_generate(CodeGenerator *codegen, IRGenerator *ir, const char *output_file);

#endif