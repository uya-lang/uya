#include "ir/ir.h"
#include "ir_generator/ir_generator_internal.h"
#include <stdio.h>
#include <stdlib.h>

void *irgenerator_generate(IRGenerator *ir_gen, struct ASTNode *ast) {
    if (!ir_gen || !ast) {
        return NULL;
    }

    printf("生成中间表示...\n");

    // Reset counters
    ir_gen->current_id = 0;
    ir_gen->inst_count = 0;

    // Generate IR from AST
    generate_program(ir_gen, ast);

    printf("生成了 %d 条IR指令\n", ir_gen->inst_count);

    return ir_gen;
}

void ir_free(void *ir) {
    // IR的清理函数
    printf("清理IR资源...\n");
    if (ir) {
        IRGenerator *ir_gen = (IRGenerator *)ir;
        irgenerator_free(ir_gen);
    }
}
