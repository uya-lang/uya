/* uyac - Uya to C99 Compiler */

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

// 跨平台目录操作支持
#ifdef _WIN32
    #include <windows.h>
    #include <io.h>
    #define access _access
    #define R_OK 04
    // snprintf 兼容性（MSVC 2015+ 支持，但为了兼容性添加）
    #ifndef _MSC_VER
        #include <stdio.h>
    #elif _MSC_VER < 1900
        #define snprintf _snprintf
    #endif
#else
    #include <dirent.h>
    #include <sys/stat.h>
    #include <unistd.h>
    #include <limits.h>
#endif

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

// 错误处理（打印错误信息，但不退出）
static void print_error(const char *format, ...) {
    va_list args;
    va_start(args, format);
    fprintf(stderr, "错误: ");
    vfprintf(stderr, format, args);
    fprintf(stderr, "\n");
    va_end(args);
}

// 主编译函数（使用 goto 进行统一的资源清理）
int compile_file(const char *input_file, const char *output_file) {
    // 将输入文件路径转换为绝对路径
    char *absolute_input_file = realpath(input_file, NULL);
    const char *file_to_use = absolute_input_file ? absolute_input_file : input_file;
    
    printf("编译 %s -> %s\n", file_to_use, output_file);

    // 初始化所有资源为 NULL，方便统一清理
    Lexer *lexer = NULL;
    Parser *parser = NULL;
    ASTNode *ast = NULL;
    TypeChecker *checker = NULL;
    IRGenerator *ir_gen = NULL;
    IRGenerator *ir_result = NULL;
    CodeGenerator *codegen = NULL;
    int result = 0;

    // 1. 词法分析
    lexer = lexer_new(file_to_use);
    if (!lexer) {
        print_error("无法创建词法分析器");
        result = 1;
        goto cleanup;
    }

    // 2. 语法分析
    parser = parser_new(lexer);
    if (!parser) {
        print_error("无法创建语法分析器");
        result = 1;
        goto cleanup;
    }

    ast = parser_parse(parser);
    if (!ast) {
        print_error("语法分析失败");
        result = 1;
        goto cleanup;
    }

    // 3. 类型检查
    checker = typechecker_new();
    if (!checker) {
        print_error("无法创建类型检查器");
        result = 1;
        goto cleanup;
    }

    if (!typechecker_check(checker, ast)) {
        // 类型检查器已经打印了错误信息
        result = 1;
        goto cleanup;
    }

    // 4. IR 生成
    ir_gen = irgenerator_new();
    if (!ir_gen) {
        print_error("无法创建 IR 生成器");
        result = 1;
        goto cleanup;
    }

    ir_result = irgenerator_generate(ir_gen, ast);
    if (!ir_result) {
        print_error("IR 生成失败");
        result = 1;
        goto cleanup;
    }

    // 5. 代码生成
    codegen = codegen_new();
    if (!codegen) {
        print_error("无法创建代码生成器");
        result = 1;
        goto cleanup;
    }

    if (!codegen_generate(codegen, ir_result, ast, output_file)) {
        print_error("代码生成失败");
        result = 1;
        goto cleanup;
    }

    printf("编译成功完成\n");

cleanup:
    // 释放绝对路径内存（lexer已经复制了文件名，所以可以安全释放）
    if (absolute_input_file) {
        free(absolute_input_file);
    }
    
    // 统一清理资源（按相反顺序）
    if (codegen) codegen_free(codegen);
    // ir_result 和 ir_gen 是同一个对象（irgenerator_generate 返回传入的 ir_gen）
    // 所以只需要释放 ir_gen 一次
    if (ir_gen) irgenerator_free(ir_gen);
    if (checker) typechecker_free(checker);
    if (ast) ast_free(ast);
    if (parser) parser_free(parser);
    if (lexer) lexer_free(lexer);

    return result;
}

// 检查文件是否是 .uya 文件
static int is_uya_file(const char *filename) {
    size_t len = strlen(filename);
    if (len < 4) return 0;
    return strcmp(filename + len - 4, ".uya") == 0;
}

// 递归扫描目录中的 .uya 文件（简化版：仅扫描当前目录）
static int collect_uya_files(const char *dir_path, char ***files, int *count, int *capacity) {
#ifdef _WIN32
    WIN32_FIND_DATA find_data;
    HANDLE find_handle;
    char search_path[MAX_PATH];
    const char *search_dir = dir_path ? dir_path : ".";
    
    // 构造搜索路径 "dir_path\*.uya"
    snprintf(search_path, sizeof(search_path), "%s\\*.uya", search_dir);
    
    find_handle = FindFirstFileA(search_path, &find_data);
    if (find_handle == INVALID_HANDLE_VALUE) {
        return 0;
    }
    
    do {
        // 跳过目录
        if (find_data.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) {
            continue;
        }
        
        // 构造完整路径
        size_t path_len = strlen(search_dir) + strlen(find_data.cFileName) + 2;
        char *full_path = malloc(path_len);
        if (!full_path) {
            FindClose(find_handle);
            return 0;
        }
        snprintf(full_path, path_len, "%s\\%s", search_dir, find_data.cFileName);
        
        // 扩容
        if (*count >= *capacity) {
            *capacity = *capacity == 0 ? 8 : *capacity * 2;
            *files = realloc(*files, *capacity * sizeof(char*));
            if (!*files) {
                free(full_path);
                FindClose(find_handle);
                return 0;
            }
        }
        
        (*files)[(*count)++] = full_path;
    } while (FindNextFileA(find_handle, &find_data));
    
    FindClose(find_handle);
    return 1;
#else
    DIR *dir = opendir(dir_path ? dir_path : ".");
    if (!dir) {
        return 0;
    }

    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL) {
        // Skip directories . and ..
        if (strcmp(entry->d_name, ".") == 0 || strcmp(entry->d_name, "..") == 0) {
            continue;
        }
        
        // Check if it's a .uya file
        if (is_uya_file(entry->d_name)) {
            // Construct full file path
            char *full_path;
            if (dir_path && strcmp(dir_path, ".") != 0) {
                size_t path_len = strlen(dir_path) + strlen(entry->d_name) + 2;
                full_path = malloc(path_len);
                if (!full_path) {
                    closedir(dir);
                    return 0;
                }
                snprintf(full_path, path_len, "%s/%s", dir_path, entry->d_name);
            } else {
                full_path = strdup(entry->d_name);
                if (!full_path) {
                    closedir(dir);
                    return 0;
                }
            }
            
            // Check if it's a regular file using stat
            struct stat file_stat;
            if (stat(full_path, &file_stat) == 0 && S_ISREG(file_stat.st_mode)) {
                // It's a regular .uya file, add to collection
                // 扩容
                if (*count >= *capacity) {
                    *capacity = *capacity == 0 ? 8 : *capacity * 2;
                    *files = realloc(*files, *capacity * sizeof(char*));
                    if (!*files) {
                        free(full_path);
                        closedir(dir);
                        return 0;
                    }
                }
                
                (*files)[(*count)++] = full_path;
            } else {
                // Not a regular file, free the path
                free(full_path);
            }
        }
    }

    closedir(dir);
    return 1;
#endif
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
            // 注意：body 暂时设置为 NULL，因为当前未使用
            // TODO: 当实现测试运行功能时，需要实现 AST 深度复制来保存 body
            test->body = NULL;
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
            // 收集完成后立即释放 AST（因为 body 当前未使用，已设置为 NULL）
            ast_free(ast);
        }

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