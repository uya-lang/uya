/* uyac - Uya to C99 Compiler */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#include "lexer/lexer.h"
#include "parser/parser.h"
#include "parser/ast.h"
#include "checker/typechecker.h"
#include "ir/ir.h"
#include "codegen/codegen.h"

// 错误处理
void error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    fprintf(stderr, "错误: ");
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    va_end(args);
    exit(1);
}

// 主编译函数
int compile_file(const char *input_file, const char *output_file) {
    printf("编译 %s -> %s\n", input_file, output_file);

    // 1. 词法分析
    Lexer *lexer = lexer_new(input_file);
    if (!lexer) {
        error("无法创建词法分析器");
        return 1;
    }

    // 2. 语法分析
    Parser *parser = parser_new(lexer);
    if (!parser) {
        error("无法创建语法分析器");
        lexer_free(lexer);
        return 1;
    }

    ASTNode *ast = parser_parse(parser);
    if (!ast) {
        error("语法分析失败");
        parser_free(parser);
        lexer_free(lexer);
        return 1;
    }

    // 3. 类型检查
    TypeChecker *checker = typechecker_new();
    if (!checker) {
        error("无法创建类型检查器");
        ast_free(ast);
        parser_free(parser);
        lexer_free(lexer);
        return 1;
    }

    if (!typechecker_check(checker, ast)) {
        error("类型检查失败");
        typechecker_free(checker);
        ast_free(ast);
        parser_free(parser);
        lexer_free(lexer);
        return 1;
    }

    // 4. IR 生成
    IRGenerator *ir_gen = irgenerator_new();
    if (!ir_gen) {
        error("无法创建 IR 生成器");
        typechecker_free(checker);
        ast_free(ast);
        parser_free(parser);
        lexer_free(lexer);
        return 1;
    }

    IRGenerator *ir_result = irgenerator_generate(ir_gen, ast);
    if (!ir_result) {
        error("IR 生成失败");
        irgenerator_free(ir_gen);
        typechecker_free(checker);
        ast_free(ast);
        parser_free(parser);
        lexer_free(lexer);
        return 1;
    }

    // 5. 代码生成
    CodeGenerator *codegen = codegen_new();
    if (!codegen) {
        error("无法创建代码生成器");
        ir_free(ir_result);
        irgenerator_free(ir_gen);
        typechecker_free(checker);
        ast_free(ast);
        parser_free(parser);
        lexer_free(lexer);
        return 1;
    }

    if (!codegen_generate(codegen, ir_result, output_file)) {
        error("代码生成失败");
        codegen_free(codegen);
        ir_free(ir_result);
        irgenerator_free(ir_gen);
        typechecker_free(checker);
        ast_free(ast);
        parser_free(parser);
        lexer_free(lexer);
        return 1;
    }

    // 清理资源
    codegen_free(codegen);
    ir_free(ir_result);  // 清理IR资源
    typechecker_free(checker);
    ast_free(ast);
    parser_free(parser);
    lexer_free(lexer);

    printf("编译成功完成\n");
    return 0;
}

int main(int argc, char *argv[]) {
    if (argc != 3) {
        fprintf(stderr, "用法: %s <输入文件.uya> <输出文件.c>\n", argv[0]);
        return 1;
    }

    return compile_file(argv[1], argv[2]);
}