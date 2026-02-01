#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "arena.h"
#include "lexer.h"
#include "parser.h"
#include "checker.h"
#include "codegen_c99.h"

// 文件读取缓冲区大小（与Lexer的缓冲区大小相同）
#define FILE_BUFFER_SIZE (1024 * 1024)  // 1MB

// Arena 分配器缓冲区大小
// 注意：编译大型文件和多文件编译需要更大的缓冲区
// 多文件编译时，所有文件的 AST 节点都存储在同一个 Arena 中
// 使用 16MB 以支持大型函数和多文件编译（gen_expr 等函数很大，需要更多内存）
#define ARENA_BUFFER_SIZE (16 * 1024 * 1024)  // 16MB（增加缓冲区以支持大型函数和多文件编译）

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
    fprintf(stderr, "用法: %s [输入文件...] -o <输出文件> [选项]\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program.c\n", program_name);
    fprintf(stderr, "示例: %s file1.uya file2.uya file3.uya -o output.c\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program.c -exec  # 直接生成可执行文件\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program.c --line-directives  # 生成 C99 代码（包含 #line 指令）\n", program_name);
    fprintf(stderr, "\n选项:\n");
    fprintf(stderr, "  -exec                生成可执行文件（编译并链接 C 代码）\n");
    fprintf(stderr, "  --no-line-directives 禁用 #line 指令生成（默认禁用）\n");
    fprintf(stderr, "  --line-directives    启用 #line 指令生成（默认禁用）\n");
    fprintf(stderr, "\n说明:\n");
    fprintf(stderr, "  - 输出 C99 源代码，输出文件建议使用 .c 后缀\n");
}

// 解析命令行参数
// 参数：argc - 参数数量
//       argv - 参数数组
//       input_files - 输出参数：输入文件名数组（由调用者分配，大小至少为 MAX_INPUT_FILES）
//       input_file_count - 输出参数：输入文件数量
//       output_file - 输出参数：输出文件名
//       generate_executable - 输出参数：是否生成可执行文件（1 表示是，0 表示否）
//       emit_line_directives - 输出参数：是否生成 #line 指令（1 表示是，0 表示否）
// 返回：成功返回0，失败返回-1
static int parse_args(int argc, char *argv[], const char *input_files[], int *input_file_count, const char **output_file, int *generate_executable, int *emit_line_directives) {
    if (argc < 4) {
        print_usage(argv[0]);
        return -1;
    }

    // 简单的参数解析：程序名 [输入文件...] -o <输出文件> [选项]
    *input_file_count = 0;
    *output_file = NULL;
    *generate_executable = 0;
    *emit_line_directives = 0;     // 默认不生成 #line 指令

    for (int i = 1; i < argc; i++) {
        if (strcmp(argv[i], "-o") == 0) {
            if (i + 1 < argc) {
                *output_file = argv[i + 1];
                i++;  // 跳过输出文件名
            } else {
                fprintf(stderr, "错误: -o 选项需要指定输出文件名\n");
                return -1;
            }
        } else if (strcmp(argv[i], "-exec") == 0) {
            *generate_executable = 1;
        } else if (strcmp(argv[i], "--no-line-directives") == 0) {
            *emit_line_directives = 0;  // 禁用 #line 指令生成
        } else if (strcmp(argv[i], "--line-directives") == 0) {
            *emit_line_directives = 1;  // 启用 #line 指令生成
        } else if (strcmp(argv[i], "--c99") == 0) {
            // 保留 --c99 选项以兼容旧脚本，忽略
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

    // 若输出文件以 .o 结尾，提示 LLVM 已移除
    {
        const char *ext = strrchr(*output_file, '.');
        if (ext && strcmp(ext, ".o") == 0) {
            fprintf(stderr, "错误: LLVM 后端已移除，请使用 -o <输出>.c 生成 C99 代码\n");
            return -1;
        }
    }

    return 0;
}

// 主编译函数
// 协调所有编译阶段：词法分析 → 语法分析 → AST 合并 → 类型检查 → C99 代码生成
// 参数：input_files - 输入文件名数组
//       input_file_count - 输入文件数量
//       output_file - 输出文件名
//       emit_line_directives - 是否生成 #line 指令（C99 后端）
// 返回：成功返回0，失败返回非0
static int compile_files(const char *input_files[], int input_file_count, const char *output_file, int emit_line_directives) {
    fprintf(stderr, "=== 开始编译 ===\n");
    fprintf(stderr, "输入文件数量: %d\n", input_file_count);
    for (int i = 0; i < input_file_count; i++) {
        fprintf(stderr, "  %d: %s\n", i, input_files[i]);
    }
    fprintf(stderr, "输出文件: %s\n", output_file);
    fprintf(stderr, "=== 词法/语法分析 ===\n");

    // 初始化 Arena 分配器（所有文件共享同一个 Arena）
    Arena arena;
    arena_init(&arena, arena_buffer, ARENA_BUFFER_SIZE);

    // 存储每个文件的 AST_PROGRAM 节点（栈上分配，只存储指针）
    ASTNode *programs[MAX_INPUT_FILES];

    // 解析每个文件
    for (int i = 0; i < input_file_count; i++) {
        const char *input_file = input_files[i];

        int file_size = read_file_content(input_file, file_buffer, FILE_BUFFER_SIZE);
        if (file_size < 0) {
            fprintf(stderr, "错误: 无法读取文件 '%s' (可能文件太大或不存在)\n", input_file);
            return 1;
        }

        Lexer lexer;
        if (lexer_init(&lexer, file_buffer, (size_t)file_size, input_file, &arena) != 0) {
            fprintf(stderr, "错误: Lexer 初始化失败: %s (可能 Arena 内存不足或文件太大)\n", input_file);
            return 1;
        }

        Parser parser;
        if (parser_init(&parser, &lexer, &arena) != 0) {
            fprintf(stderr, "错误: Parser 初始化失败: %s (可能 Arena 内存不足)\n", input_file);
            return 1;
        }

        ASTNode *ast = parser_parse(&parser);
        if (ast == NULL) {
            fprintf(stderr, "错误: 语法分析失败: %s\n", input_file);
            return 1;
        }

        if (ast->type != AST_PROGRAM) {
            fprintf(stderr, "错误: 解析结果不是程序节点: %s\n", input_file);
            return 1;
        }

        programs[i] = ast;
        fprintf(stderr, "  解析完成: %s\n", input_file);
    }
    fprintf(stderr, "=== 词法/语法分析完成，共 %d 个文件 ===\n", input_file_count);

    fprintf(stderr, "=== AST 合并阶段 ===\n");
    ASTNode *merged_ast = ast_merge_programs(programs, input_file_count, &arena);
    if (merged_ast == NULL) {
        fprintf(stderr, "错误: AST 合并失败\n");
        return 1;
    }
    fprintf(stderr, "AST 合并完成，共 %d 个声明\n", merged_ast->data.program.decl_count);

    fprintf(stderr, "=== 类型检查阶段 ===\n");
    TypeChecker checker;
    const char *default_filename = input_file_count > 0 ? input_files[0] : "(unknown)";
    if (checker_init(&checker, &arena, default_filename) != 0) {
        fprintf(stderr, "错误: TypeChecker 初始化失败\n");
        return 1;
    }

    if (checker_check(&checker, merged_ast) != 0) {
        fprintf(stderr, "错误: 类型检查失败（错误数量: %d）\n", checker_get_error_count(&checker));
        return 1;
    }

    if (checker_get_error_count(&checker) > 0) {
        fprintf(stderr, "错误: 类型检查失败（错误数量: %d）\n", checker_get_error_count(&checker));
        return 1;
    }
    fprintf(stderr, "类型检查通过\n");

    fprintf(stderr, "=== 代码生成阶段 ===\n");
    const char *module_name = input_files[0];
    fprintf(stderr, "模块名: %s\n", module_name);

    // C99 后端：生成 C 源代码
    FILE *out_file = fopen(output_file, "w");
    if (!out_file) {
        fprintf(stderr, "错误: 无法打开输出文件 '%s'\n", output_file);
        return 1;
    }

    C99CodeGenerator c99_codegen;
    if (c99_codegen_new(&c99_codegen, &arena, out_file, module_name, emit_line_directives) != 0) {
        fprintf(stderr, "错误: C99CodeGenerator 初始化失败\n");
        fclose(out_file);
        return 1;
    }

    if (c99_codegen_generate(&c99_codegen, merged_ast, output_file) != 0) {
        fprintf(stderr, "错误: C99 代码生成失败\n");
        c99_codegen_free(&c99_codegen);
        fclose(out_file);
        return 1;
    }

    c99_codegen_free(&c99_codegen);
    fclose(out_file);
    fprintf(stderr, "代码生成完成: %s\n", output_file);

    return 0;
}

// 主函数
int main(int argc, char *argv[]) {
    const char *input_files[MAX_INPUT_FILES];
    int input_file_count = 0;
    const char *output_file = NULL;
    int generate_executable = 0;
    int emit_line_directives = 0;

    if (parse_args(argc, argv, input_files, &input_file_count, &output_file, &generate_executable, &emit_line_directives) != 0) {
        return 1;
    }

    int result = compile_files(input_files, input_file_count, output_file, emit_line_directives);
    if (result != 0) {
        return result;
    }

    // 如果指定了 -exec 选项，编译并链接生成可执行文件
    if (generate_executable) {
        char executable_file[512];
        size_t len = strlen(output_file);
        if (len >= 2 && output_file[len - 2] == '.' && output_file[len - 1] == 'c') {
            // 去掉 .c 作为可执行文件名
            strncpy(executable_file, output_file, len - 2);
            executable_file[len - 2] = '\0';
        } else {
            snprintf(executable_file, sizeof(executable_file), "%s_exec", output_file);
        }

        // 查找 bridge.c（提供 main 和 get_argc/get_argv）
        char bridge_c_path[512];
        char *last_slash = strrchr(output_file, '/');
        if (last_slash) {
            size_t dir_len = last_slash - output_file;
            snprintf(bridge_c_path, sizeof(bridge_c_path), "%.*s/bridge.c", (int)dir_len, output_file);
        } else {
            snprintf(bridge_c_path, sizeof(bridge_c_path), "bridge.c");
        }

        FILE *bridge_check = fopen(bridge_c_path, "r");
        const char *bridge_file = NULL;
        if (bridge_check) {
            fclose(bridge_check);
            bridge_file = bridge_c_path;
        } else if (fopen("tests/bridge.c", "r")) {
            fclose(fopen("tests/bridge.c", "r"));
            bridge_file = "tests/bridge.c";
        }

        char cmd[2048];
        int cmd_len;
        if (bridge_file) {
            cmd_len = snprintf(cmd, sizeof(cmd), "gcc --std=c99 -o \"%s\" \"%s\" \"%s\"", executable_file, output_file, bridge_file);
        } else {
            cmd_len = snprintf(cmd, sizeof(cmd), "gcc --std=c99 -o \"%s\" \"%s\"", executable_file, output_file);
        }

        if (cmd_len >= (int)sizeof(cmd)) {
            fprintf(stderr, "错误: 编译命令过长\n");
            return 1;
        }

        fprintf(stderr, "执行编译命令: %s\n", cmd);
        if (system(cmd) != 0) {
            fprintf(stderr, "错误: 编译 C99 代码失败\n");
            fprintf(stderr, "提示: 可执行程序需要 bridge.c 提供运行时支持（main、get_argc、get_argv）\n");
            return 1;
        }

        fprintf(stderr, "可执行文件已生成: %s\n", executable_file);
    }

    return 0;
}
