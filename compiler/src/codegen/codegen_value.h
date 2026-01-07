#ifndef CODEGEN_VALUE_H
#define CODEGEN_VALUE_H

#include "../ir/ir.h"
#include "codegen.h"
#include <stdint.h>

// Value writing functions
void codegen_write_value(CodeGenerator *codegen, IRInst *inst);

#endif