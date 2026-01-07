#ifndef CODEGEN_INST_H
#define CODEGEN_INST_H

#include "../ir/ir.h"
#include "codegen.h"
#include <stdint.h>

// Instruction generation functions
void codegen_generate_inst(CodeGenerator *codegen, IRInst *inst);

#endif