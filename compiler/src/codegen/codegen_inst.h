#ifndef CODEGEN_INST_H
#define CODEGEN_INST_H

#include "../ir/ir.h"
#include "codegen.h"
#include <stdint.h>

// Instruction generation functions
void codegen_generate_inst(CodeGenerator *codegen, IRInst *inst);

// Split instruction generation functions
void codegen_gen_func_def(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_var_decl(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_assign(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_binary_op(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_return(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_call(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_if(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_while(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_for(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_try_catch(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_struct_decl(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_enum_decl(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_drop(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_defer(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_errdefer(CodeGenerator *codegen, IRInst *inst);
void codegen_gen_block(CodeGenerator *codegen, IRInst *inst);

#endif