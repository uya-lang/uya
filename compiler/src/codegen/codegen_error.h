#ifndef CODEGEN_ERROR_H
#define CODEGEN_ERROR_H

#include "../ir/ir.h"
#include "../parser/ast.h"
#include "codegen.h"
#include <stdint.h>

// Error handling functions
int collect_error_names(CodeGenerator *codegen, IRGenerator *ir, ASTNode *ast);
int is_error_return_value(IRInst *inst);

#endif