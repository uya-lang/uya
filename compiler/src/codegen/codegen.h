#ifndef CODEGEN_H
#define CODEGEN_H

#include "../ir/ir.h"
#include <stdio.h>

// 代码生成器结构
typedef struct CodeGenerator {
    FILE *output_file;
    char *output_filename;
    int label_counter;
    int temp_counter;
    IRInst *current_function;  // Current function context for member access type checking
} CodeGenerator;

// 代码生成器函数
CodeGenerator *codegen_new();
void codegen_free(CodeGenerator *codegen);
int codegen_generate(CodeGenerator *codegen, IRGenerator *ir, const char *output_file);

#endif