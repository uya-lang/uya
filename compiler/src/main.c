/* uyac - Uya to C99 Compiler */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <dirent.h>
#include <sys/stat.h>
#include <unistd.h>

#include "lexer/lexer.h"
#include "parser/parser.h"
#include "parser/ast.h"
#include "checker/typechecker.h"
#include "ir/ir.h"
#include "codegen/codegen.h"

// 测试块信息
typedef struct {
    char *name;
    char *filename;
    int line;
    ASTNode *body;
} TestBlockInfo;

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
        // 类型检查器已经打印了错误信息
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

// 检查文件是否是 .uya 文件
static int is_uya_file(const char *filename) {
    size_t len = strlen(filename);
    if (len < 4) return 0;
    return strcmp(filename + len - 4, ".uya") == 0;
}

// 递归扫描目录中的 .uya 文件（简化版：仅扫描当前目录）
static int collect_uya_files(const char *dir_path, char ***files, int *count, int *capacity) {
    DIR *dir = opendir(dir_path ? dir_path : ".");
    if (!dir) {
        return 0;
    }

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        if (entry->d_type == DT_REG && is_uya_file(entry->d_name)) {
            // 扩容
            if (*count >= *capacity) {
                *capacity = *capacity == 0 ? 8 : *capacity * 2;
                *files = realloc(*files, *capacity * sizeof(char*));
                if (!*files) {
                    closedir(dir);
                    return 0;
                }
            }

            // 分配并存储文件路径
            char *filepath = malloc(strlen(dir_path ? dir_path : ".") + strlen(entry->d_name) + 2);
            if (!filepath) {
                closedir(dir);
                return 0;
            }
            if (dir_path && strcmp(dir_path, ".") != 0) {
                sprintf(filepath, "%s/%s", dir_path, entry->d_name);
            } else {
                strcpy(filepath, entry->d_name);
            }
            (*files)[(*count)++] = filepath;
        }
    }

    closedir(dir);
    return 1;
}

// 从 AST 中收集所有 test 块
static void collect_test_blocks(ASTNode *ast, TestBlockInfo **tests, int *count, int *capacity) {
    if (!ast || ast->type != AST_PROGRAM) return;

    for (int i = 0; i < ast->data.program.decl_count; i++) {
        ASTNode *decl = ast->data.program.decls[i];
        if (decl && decl->type == AST_TEST_BLOCK) {
            // 扩容
            if (*count >= *capacity) {
                *capacity = *capacity == 0 ? 8 : *capacity * 2;
                *tests = realloc(*tests, *capacity * sizeof(TestBlockInfo));
                if (!*tests) return;
            }

            // 保存测试块信息
            TestBlockInfo *test = &(*tests)[(*count)++];
            test->name = malloc(strlen(decl->data.test_block.name) + 1);
            if (test->name) {
                strcpy(test->name, decl->data.test_block.name);
            }
            test->filename = decl->filename ? strdup(decl->filename) : NULL;
            test->line = decl->line;
            test->body = decl->data.test_block.body;
        }
    }
}

// 运行测试模式
static int run_test_mode(void) {
    char **files = NULL;
    int file_count = 0;
    int file_capacity = 0;

    // 收集所有 .uya 文件
    if (!collect_uya_files(".", &files, &file_count, &file_capacity)) {
        fprintf(stderr, "错误: 无法扫描 .uya 文件\n");
        return 1;
    }

    if (file_count == 0) {
        fprintf(stderr, "未找到 .uya 文件\n");
        return 1;
    }

    // 收集所有 test 块
    TestBlockInfo *tests = NULL;
    int test_count = 0;
    int test_capacity = 0;

    for (int i = 0; i < file_count; i++) {
        // 解析文件
        Lexer *lexer = lexer_new(files[i]);
        if (!lexer) continue;

        Parser *parser = parser_new(lexer);
        if (!parser) {
            lexer_free(lexer);
            continue;
        }

        ASTNode *ast = parser_parse(parser);
        if (ast) {
            collect_test_blocks(ast, &tests, &test_count, &test_capacity);
        }

        // 注意：这里不释放 AST，因为我们需要保留 test 块的 body
        // 实际实现中应该更仔细地管理内存
        parser_free(parser);
        lexer_free(lexer);
    }

    // 清理文件列表
    for (int i = 0; i < file_count; i++) {
        free(files[i]);
    }
    free(files);

    if (test_count == 0) {
        printf("未找到测试\n");
        return 0;
    }

    printf("找到 %d 个测试\n", test_count);
    // TODO: 生成临时 main 函数，运行测试
    
    // 清理测试信息
    for (int i = 0; i < test_count; i++) {
        free(tests[i].name);
        if (tests[i].filename) free(tests[i].filename);
    }
    free(tests);

    return 0;
}

int main(int argc, char *argv[]) {
    // 检查是否是 test 子命令
    if (argc == 2 && strcmp(argv[1], "test") == 0) {
        return run_test_mode();
    }

    if (argc != 3) {
        fprintf(stderr, "用法: %s <输入文件.uya> <输出文件.c>\n", argv[0]);
        fprintf(stderr, "  或: %s test\n", argv[0]);
        return 1;
    }

    return compile_file(argv[1], argv[2]);
}