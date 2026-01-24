#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "arena.h"
#include "lexer.h"
#include "parser.h"
#include "checker.h"
#include "codegen.h"

// 文件读取缓冲区大小（与Lexer的缓冲区大小相同）
#define FILE_BUFFER_SIZE (1024 * 1024)  // 1MB

// Arena 分配器缓冲区大小
// 注意：编译大型文件和多文件编译需要更大的缓冲区
// 多文件编译时，所有文件的 AST 节点都存储在同一个 Arena 中
// 使用 8MB 以支持多文件编译（10个文件，每个文件约 100-200KB）
#define ARENA_BUFFER_SIZE (8 * 1024 * 1024)  // 8MB（增加缓冲区以支持多文件编译）

// 最大输入文件数量
#define MAX_INPUT_FILES 64

// 全局缓冲区（替代 malloc）
static uint8_t arena_buffer[ARENA_BUFFER_SIZE];  // Arena 分配器缓冲区
static char file_buffer[FILE_BUFFER_SIZE];        // 文件读取缓冲区

// 读取文件内容到缓冲区
// 参数：filename - 文件名
//       buffer - 缓冲区（固定大小数组）
//       buffer_size - 缓冲区大小
// 返回：成功返回读取的字节数，失败返回-1
// 注意：文件大小不能超过缓冲区大小
static int read_file_content(const char *filename, char *buffer, size_t buffer_size) {
    FILE *file = fopen(filename, "rb");  // 二进制模式读取
    if (file == NULL) {
        return -1;
    }
    
    // 读取文件内容（保留一个字节用于'\0'）
    size_t bytes_read = fread(buffer, 1, buffer_size - 1, file);
    
    // 检查是否还有更多数据（文件太大）
    if (bytes_read >= buffer_size - 1) {
        int c = fgetc(file);
        fclose(file);
        if (c != EOF) {
            // 文件还有更多数据，文件太大
            return -1;
        }
    } else {
        fclose(file);
    }
    
    // 添加字符串结束符
    buffer[bytes_read] = '\0';
    
    return (int)bytes_read;
}

// 打印使用说明
// 参数：program_name - 程序名称
static void print_usage(const char *program_name) {
    fprintf(stderr, "用法: %s [输入文件...] -o <输出文件>\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program\n", program_name);
    fprintf(stderr, "示例: %s file1.uya file2.uya file3.uya -o output\n", program_name);
}

// 解析命令行参数
// 参数：argc - 参数数量
//       argv - 参数数组
//       input_files - 输出参数：输入文件名数组（由调用者分配，大小至少为 MAX_INPUT_FILES）
//       input_file_count - 输出参数：输入文件数量
//       output_file - 输出参数：输出文件名
// 返回：成功返回0，失败返回-1
static int parse_args(int argc, char *argv[], const char *input_files[], int *input_file_count, const char **output_file) {
    if (argc < 4) {
        print_usage(argv[0]);
        return -1;
    }
    
    // 简单的参数解析：程序名 [输入文件...] -o <输出文件>
    *input_file_count = 0;
    *output_file = NULL;
    
    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0) {
            if (i + 1 < argc) {
                *output_file = argv[i + 1];
                i++;  // 跳过输出文件名
            } else {
                fprintf(stderr, "错误: -o 选项需要指定输出文件名\n");
                return -1;
            }
        } else if (argv[i][0] != '-') {
            // 非选项参数，应该是输入文件
            if (*input_file_count >= MAX_INPUT_FILES) {
                fprintf(stderr, "错误: 输入文件数量超过最大限制 (%d)\n", MAX_INPUT_FILES);
                return -1;
            }
            input_files[*input_file_count] = argv[i];
            (*input_file_count)++;
        }
    }
    
    if (*input_file_count == 0) {
        fprintf(stderr, "错误: 未指定输入文件\n");
        print_usage(argv[0]);
        return -1;
    }
    
    if (*output_file == NULL) {
        fprintf(stderr, "错误: 未指定输出文件（使用 -o 选项）\n");
        print_usage(argv[0]);
        return -1;
    }
    
    return 0;
}

    // 主编译函数
    // 协调所有编译阶段：词法分析 → 语法分析 → AST 合并 → 类型检查 → 代码生成
    // 参数：input_files - 输入文件名数组
    //       input_file_count - 输入文件数量
    //       output_file - 输出文件名
    // 返回：成功返回0，失败返回非0
    static int compile_files(const char *input_files[], int input_file_count, const char *output_file) {
        fprintf(stderr, "=== 开始编译 ===\n");
        fprintf(stderr, "输入文件数量: %d\n", input_file_count);
        for (int i = 0; i < input_file_count; i++) {
            fprintf(stderr, "  %d: %s\n", i, input_files[i]);
        }
        fprintf(stderr, "输出文件: %s\n", output_file);
        
        // 初始化 Arena 分配器（所有文件共享同一个 Arena）
        // 使用全局缓冲区，无需动态分配
        Arena arena;
        arena_init(&arena, arena_buffer, ARENA_BUFFER_SIZE);
        
        // 存储每个文件的 AST_PROGRAM 节点（栈上分配，只存储指针）
        ASTNode *programs[MAX_INPUT_FILES];
    
    // 解析每个文件
    for (int i = 0; i < input_file_count; i++) {
        const char *input_file = input_files[i];
        
        // 读取文件内容
        int file_size = read_file_content(input_file, file_buffer, FILE_BUFFER_SIZE);
        if (file_size < 0) {
            fprintf(stderr, "错误: 无法读取文件 '%s' (可能文件太大或不存在)\n", input_file);
            return 1;
        }
        
        // 1. 词法分析
        fprintf(stderr, "=== 词法分析阶段 ===\n");
        fprintf(stderr, "文件: %s (大小: %d 字节)\n", input_file, file_size);
        Lexer lexer;
        if (lexer_init(&lexer, file_buffer, (size_t)file_size, input_file, &arena) != 0) {
            fprintf(stderr, "错误: Lexer 初始化失败: %s (可能 Arena 内存不足或文件太大)\n", input_file);
            return 1;
        }
        
        // 2. 语法分析
        fprintf(stderr, "=== 语法分析阶段 ===\n");
        Parser parser;
        if (parser_init(&parser, &lexer, &arena) != 0) {
            fprintf(stderr, "错误: Parser 初始化失败: %s (可能 Arena 内存不足)\n", input_file);
            return 1;
        }
        
        ASTNode *ast = parser_parse(&parser);
        if (ast == NULL) {
            fprintf(stderr, "错误: 语法分析失败: %s\n", input_file);
            // 错误信息已在 parser_parse 中输出
            return 1;
        }
        
        if (ast->type != AST_PROGRAM) {
            fprintf(stderr, "错误: 解析结果不是程序节点: %s\n", input_file);
            return 1;
        }
        
        programs[i] = ast;
    }
    
        // 3. 合并所有 AST_PROGRAM 节点
        fprintf(stderr, "=== AST 合并阶段 ===\n");
        ASTNode *merged_ast = ast_merge_programs(programs, input_file_count, &arena);
    if (merged_ast == NULL) {
        fprintf(stderr, "错误: AST 合并失败\n");
        return 1;
    }
    
        // 4. 类型检查
        fprintf(stderr, "=== 类型检查阶段 ===\n");
        TypeChecker checker;
        // 使用第一个输入文件名作为默认文件名（用于错误报告）
        const char *default_filename = input_file_count > 0 ? input_files[0] : "(unknown)";
        if (checker_init(&checker, &arena, default_filename) != 0) {
        fprintf(stderr, "错误: TypeChecker 初始化失败\n");
        return 1;
    }
    
    if (checker_check(&checker, merged_ast) != 0) {
        fprintf(stderr, "错误: 类型检查失败（错误数量: %d）\n", checker_get_error_count(&checker));
        return 1;
    }
    
    // 检查是否有类型检查错误
    if (checker_get_error_count(&checker) > 0) {
        fprintf(stderr, "错误: 类型检查失败（错误数量: %d）\n", checker_get_error_count(&checker));
        return 1;
    }
    
        // 5. 代码生成
        fprintf(stderr, "=== 代码生成阶段 ===\n");
        // 使用第一个输入文件名作为模块名
        const char *module_name = input_files[0];
        fprintf(stderr, "模块名: %s\n", module_name);
    
    CodeGenerator codegen;
    if (codegen_new(&codegen, &arena, module_name) != 0) {
        fprintf(stderr, "错误: CodeGenerator 初始化失败\n");
        return 1;
    }
    
    if (codegen_generate(&codegen, merged_ast, output_file) != 0) {
        fprintf(stderr, "错误: 代码生成失败\n");
        return 1;
    }
    
    return 0;
}

// 主函数
int main(int argc, char *argv[]) {
    const char *input_files[MAX_INPUT_FILES];
    int input_file_count = 0;
    const char *output_file = NULL;
    
    // 解析命令行参数
    if (parse_args(argc, argv, input_files, &input_file_count, &output_file) != 0) {
        return 1;
    }
    
    // 编译文件
    int result = compile_files(input_files, input_file_count, output_file);
    
    return result;
}

