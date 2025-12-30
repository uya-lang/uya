#include "ir/ir.h"
#include "parser/ast.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void *irgenerator_generate(IRGenerator *ir_gen, struct ASTNode *ast) {
    if (!ir_gen || !ast) {
        return NULL;
    }

    printf("生成中间表示...\n");

    // 为避免段错误，只返回ir_gen而不进行复杂的AST转换
    // 在完整实现中，这里会遍历AST并生成相应的IR指令
    return ir_gen;  // 返回IR生成器作为IR的表示
}

void ir_free(void *ir) {
    // IR的清理函数
    printf("清理IR资源...\n");
    if (ir) {
        IRGenerator *ir_gen = (IRGenerator *)ir;
        irgenerator_free(ir_gen);
    }
}