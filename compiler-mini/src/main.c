#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include "arena.h"
#include "lexer.h"
#include "parser.h"
#include "checker.h"
#include "codegen.h"
#include "codegen_c99.h"

// 后端类型
typedef enum {
    BACKEND_LLVM,
    BACKEND_C99
} BackendType;


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
    fprintf(stderr, "用法: %s [输入文件...] -o <输出文件> [选项]\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program\n", program_name);
    fprintf(stderr, "示例: %s file1.uya file2.uya file3.uya -o output\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program -exec  # 直接生成可执行文件\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program.c --c99  # 生成 C99 代码\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program.c --c99 --line-directives  # 生成 C99 代码（包含 #line 指令）\n", program_name);
    fprintf(stderr, "\n选项:\n");
    fprintf(stderr, "  -exec                生成可执行文件（自动链接目标文件）\n");
    fprintf(stderr, "  --c99                使用 C99 后端生成 C 代码（默认根据输出文件后缀检测）\n");
    fprintf(stderr, "  --no-line-directives 禁用 #line 指令生成（C99 后端，默认禁用）\n");
    fprintf(stderr, "  --line-directives    启用 #line 指令生成（C99 后端，默认禁用）\n");
    fprintf(stderr, "\n说明:\n");
    fprintf(stderr, "  - 输出文件后缀为 .c 时自动使用 C99 后端\n");
    fprintf(stderr, "  - 输出文件后缀为 .o 或无后缀时使用 LLVM 后端\n");
}

// 解析命令行参数
// 参数：argc - 参数数量
//       argv - 参数数组
//       input_files - 输出参数：输入文件名数组（由调用者分配，大小至少为 MAX_INPUT_FILES）
//       input_file_count - 输出参数：输入文件数量
//       output_file - 输出参数：输出文件名
//       generate_executable - 输出参数：是否生成可执行文件（1 表示是，0 表示否）
//       backend_type - 输出参数：后端类型（LLVM 或 C99）
//       emit_line_directives - 输出参数：是否生成 #line 指令（1 表示是，0 表示否）
// 返回：成功返回0，失败返回-1
static int parse_args(int argc, char *argv[], const char *input_files[], int *input_file_count, const char **output_file, int *generate_executable, BackendType *backend_type, int *emit_line_directives) {
    if (argc < 4) {
        print_usage(argv[0]);
        return -1;
    }
    
    // 简单的参数解析：程序名 [输入文件...] -o <输出文件> [选项]
    *input_file_count = 0;
    *output_file = NULL;
    *generate_executable = 0;
    *backend_type = BACKEND_LLVM;  // 默认使用 LLVM 后端
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
        } else if (strcmp(argv[i], "--c99") == 0) {
            *backend_type = BACKEND_C99;
        } else if (strcmp(argv[i], "--no-line-directives") == 0) {
            *emit_line_directives = 0;  // 禁用 #line 指令生成
        } else if (strcmp(argv[i], "--line-directives") == 0) {
            *emit_line_directives = 1;  // 启用 #line 指令生成（默认）
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
    
    // 如果没有显式指定后端类型，根据输出文件后缀自动检测
    if (*backend_type == BACKEND_LLVM) {
        const char *ext = strrchr(*output_file, '.');
        if (ext && strcmp(ext, ".c") == 0) {
            *backend_type = BACKEND_C99;
        }
    }
    
    return 0;
}

    // 主编译函数
    // 协调所有编译阶段：词法分析 → 语法分析 → AST 合并 → 类型检查 → 代码生成
    // 参数：input_files - 输入文件名数组
    //       input_file_count - 输入文件数量
    //       output_file - 输出文件名
    //       backend - 后端类型
    //       emit_line_directives - 是否生成 #line 指令（C99 后端）
    // 返回：成功返回0，失败返回非0
    static int compile_files(const char *input_files[], int input_file_count, const char *output_file, BackendType backend, int emit_line_directives) {
        fprintf(stderr, "=== 开始编译 ===\n");
        fprintf(stderr, "输入文件数量: %d\n", input_file_count);
        for (int i = 0; i < input_file_count; i++) {
            fprintf(stderr, "  %d: %s\n", i, input_files[i]);
        }
        fprintf(stderr, "输出文件: %s\n", output_file);
        fprintf(stderr, "后端类型: %s\n", backend == BACKEND_C99 ? "C99" : "LLVM");
        
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
    
    if (backend == BACKEND_C99) {
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
        fprintf(stderr, "C99 源代码已生成: %s\n", output_file);
    } else {
        // LLVM 后端：生成目标文件
        CodeGenerator codegen;
        if (codegen_new(&codegen, &arena, module_name) != 0) {
            fprintf(stderr, "错误: CodeGenerator 初始化失败\n");
            return 1;
        }
        
        if (codegen_generate(&codegen, merged_ast, output_file) != 0) {
            fprintf(stderr, "错误: 代码生成失败\n");
            return 1;
        }
    }
    
    return 0;
}

// 链接目标文件生成可执行文件
// 参数：object_file - 目标文件路径
//       executable_file - 可执行文件路径
// 返回：成功返回0，失败返回-1
// 注意：优先尝试使用 LLVM lld（如果可用），否则使用 gcc/clang
static int link_executable(const char *object_file, const char *executable_file) {
    if (!object_file || !executable_file) {
        return -1;
    }
    
    // 检查目标文件是否存在
    FILE *f = fopen(object_file, "rb");
    if (!f) {
        fprintf(stderr, "错误: 目标文件 '%s' 不存在\n", object_file);
        return -1;
    }
    fclose(f);
    
    // 获取 LLVM 链接选项
    const char *llvm_ldflags = "";
    const char *llvm_libs = "-lLLVM-17";  // 默认使用 LLVM-17
    char llvm_ldflags_buf[256] = "";
    char llvm_libs_buf[256] = "";
    
    // 尝试使用 llvm-config 获取链接选项
    FILE *llvm_config = popen("llvm-config --ldflags 2>/dev/null", "r");
    if (llvm_config) {
        if (fgets(llvm_ldflags_buf, sizeof(llvm_ldflags_buf), llvm_config)) {
            // 移除换行符
            size_t len = strlen(llvm_ldflags_buf);
            if (len > 0 && llvm_ldflags_buf[len - 1] == '\n') {
                llvm_ldflags_buf[len - 1] = '\0';
            }
            llvm_ldflags = llvm_ldflags_buf;
        }
        pclose(llvm_config);
    }
    
    FILE *llvm_libs_cmd = popen("llvm-config --libs core target 2>/dev/null", "r");
    if (llvm_libs_cmd) {
        if (fgets(llvm_libs_buf, sizeof(llvm_libs_buf), llvm_libs_cmd)) {
            // 移除换行符
            size_t len = strlen(llvm_libs_buf);
            if (len > 0 && llvm_libs_buf[len - 1] == '\n') {
                llvm_libs_buf[len - 1] = '\0';
            }
            llvm_libs = llvm_libs_buf;
        }
        pclose(llvm_libs_cmd);
    }
    
    // 尝试使用不同的链接器（按优先级）
    const char *linkers[] = {
        "clang -no-pie",    // Clang（通常可用）
        "gcc -no-pie"       // GCC（最常用）
    };
    const int num_linkers = sizeof(linkers) / sizeof(linkers[0]);
    
    char link_cmd[2048];
    int result = -1;
    
    // 检查是否存在 bridge.c 文件（用于提供 get_argc/get_argv 和 LLVM 初始化函数）
    char bridge_c_path[512];
    char renamed_object_file[512];
    
    // 尝试在目标文件目录中查找 bridge.c
    char *last_slash = strrchr(object_file, '/');
    if (last_slash) {
        size_t dir_len = last_slash - object_file;
        snprintf(bridge_c_path, sizeof(bridge_c_path), "%.*s/bridge.c", (int)dir_len, object_file);
        snprintf(renamed_object_file, sizeof(renamed_object_file), "%.*s/compiler_renamed.o", (int)dir_len, object_file);
    } else {
        snprintf(bridge_c_path, sizeof(bridge_c_path), "bridge.c");
        snprintf(renamed_object_file, sizeof(renamed_object_file), "compiler_renamed.o");
    }
    
    // 检查 bridge.c 是否存在
    FILE *bridge_check = fopen(bridge_c_path, "r");
    const char *bridge_file = NULL;
    const char *object_file_to_link = object_file;
    
    if (bridge_check) {
        fclose(bridge_check);
        bridge_file = bridge_c_path;
        
        // 使用 objcopy 将 main 函数重命名为 uya_main（避免与 bridge.c 的 main 冲突）
        char objcopy_cmd[1024];
        snprintf(objcopy_cmd, sizeof(objcopy_cmd), "objcopy --redefine-sym main=uya_main \"%s\" \"%s\"", 
                 object_file, renamed_object_file);
        if (system(objcopy_cmd) == 0) {
            object_file_to_link = renamed_object_file;
        } else {
            // objcopy 失败，尝试不使用重命名（可能会失败）
            fprintf(stderr, "警告: objcopy 失败，尝试直接链接（可能会失败）\n");
        }
    }
    
    for (int i = 0; i < num_linkers; i++) {
        // 构建链接命令（包含 LLVM 库和 bridge.c）
        if (bridge_file) {
            int len = snprintf(link_cmd, sizeof(link_cmd), "%s %s \"%s\" \"%s\" -o \"%s\" %s", 
                              linkers[i], llvm_ldflags, bridge_file, object_file_to_link, executable_file, llvm_libs);
            if (len >= (int)sizeof(link_cmd)) {
                continue;  // 命令过长，尝试下一个
            }
        } else {
            int len = snprintf(link_cmd, sizeof(link_cmd), "%s %s \"%s\" -o \"%s\" %s", 
                              linkers[i], llvm_ldflags, object_file_to_link, executable_file, llvm_libs);
            if (len >= (int)sizeof(link_cmd)) {
                continue;  // 命令过长，尝试下一个
            }
        }
        
        // 执行链接命令
        result = system(link_cmd);
        if (result == 0) {
            // 链接成功
            return 0;
        }
    }
    
    // 所有链接器都失败
    fprintf(stderr, "错误: 链接失败（尝试了 %d 种链接器）\n", num_linkers);
    fprintf(stderr, "提示: 请确保系统安装了 gcc、clang 或 lld 之一\n");
    return -1;
}

// 主函数
int main(int argc, char *argv[]) {
    const char *input_files[MAX_INPUT_FILES];
    int input_file_count = 0;
    const char *output_file = NULL;
    int generate_executable = 0;
    BackendType backend = BACKEND_LLVM;
    int emit_line_directives = 0;  // 默认不生成 #line 指令
    
    // 解析命令行参数
    if (parse_args(argc, argv, input_files, &input_file_count, &output_file, &generate_executable, &backend, &emit_line_directives) != 0) {
        return 1;
    }
    
    // 编译文件
    int result = compile_files(input_files, input_file_count, output_file, backend, emit_line_directives);
    if (result != 0) {
        return result;
    }
    
    // 如果指定了 -exec 选项，自动链接生成可执行文件
    if (generate_executable) {
        // 确定目标文件和可执行文件路径
        // 如果输出文件以 .o 结尾，则目标文件就是输出文件，可执行文件去掉 .o
        // 否则，目标文件是输出文件，可执行文件添加 _exec 后缀
        char object_file[512];
        char executable_file[512];
        
        strncpy(object_file, output_file, sizeof(object_file) - 1);
        object_file[sizeof(object_file) - 1] = '\0';
        
        size_t len = strlen(output_file);
        if (len >= 2 && output_file[len - 2] == '.' && output_file[len - 1] == 'o') {
            // 以 .o 结尾，去掉 .o 作为可执行文件名
            strncpy(executable_file, output_file, len - 2);
            executable_file[len - 2] = '\0';
        } else {
            // 不以 .o 结尾，添加 _exec 后缀
            snprintf(executable_file, sizeof(executable_file), "%s_exec", output_file);
        }
        
        // 根据后端类型选择合适的链接方式
        if (backend == BACKEND_C99) {
            // 对于 C99 后端，需要链接 bridge.c 和生成的 C 源代码
            // 首先检查是否存在 bridge.c
            char bridge_c_path[512];
            char *last_slash = strrchr(output_file, '/');
            if (last_slash) {
                size_t dir_len = last_slash - output_file;
                snprintf(bridge_c_path, sizeof(bridge_c_path), "%.*s/bridge.c", (int)dir_len, output_file);
            } else {
                snprintf(bridge_c_path, sizeof(bridge_c_path), "bridge.c");
            }
            
            // 检查 bridge.c 是否存在
            FILE *bridge_check = fopen(bridge_c_path, "r");
            const char *bridge_file = NULL;
            if (bridge_check) {
                fclose(bridge_check);
                bridge_file = bridge_c_path;
            }
            
            // 构建编译命令
            char cmd[2048];
            int cmd_len;
            
            // 检测 LLVM 路径
            const char *llvm_include = "";
            const char *llvm_libdir = "";
            const char *llvm_libs = "-lLLVM-17";
            
            // 检查 LLVM 头文件路径
            FILE *llvm_include_check = fopen("/usr/include/llvm-c/Target.h", "r");
            if (llvm_include_check) {
                fclose(llvm_include_check);
                llvm_include = "-I/usr/include/llvm-c";
            }
            
            // 检查 LLVM 库路径
            FILE *llvm_lib_check = fopen("/usr/lib/llvm-17/lib/libLLVM-17.so", "r");
            if (llvm_lib_check) {
                fclose(llvm_lib_check);
                llvm_libdir = "-L/usr/lib/llvm-17/lib";
            } else {
                llvm_lib_check = fopen("/usr/lib/llvm-17/libLLVM-17.so", "r");
                if (llvm_lib_check) {
                    fclose(llvm_lib_check);
                    llvm_libdir = "-L/usr/lib/llvm-17";
                }
            }
            
            if (bridge_file) {
                // 使用 bridge.c 链接
                // 需要先将 main 重命名为 uya_main
                // 方法1：使用 objcopy（如果可用）
                char renamed_object[512];
                char objcopy_cmd[1024];
                const char *link_object = output_file;
                
                if (last_slash) {
                    size_t dir_len = last_slash - output_file;
                    snprintf(renamed_object, sizeof(renamed_object), "%.*s/compiler_renamed.o", (int)dir_len, output_file);
                } else {
                    snprintf(renamed_object, sizeof(renamed_object), "compiler_renamed.o");
                }
                
                // 先编译为对象文件
                char compile_cmd[1024];
                char object_file[512];
                if (last_slash) {
                    size_t dir_len = last_slash - output_file;
                    snprintf(object_file, sizeof(object_file), "%.*s/compiler_temp.o", (int)dir_len, output_file);
                } else {
                    snprintf(object_file, sizeof(object_file), "compiler_temp.o");
                }
                
                snprintf(compile_cmd, sizeof(compile_cmd), "gcc --std=c99 -c \"%s\" -o \"%s\" %s", 
                         output_file, object_file, llvm_include);
                int compile_obj_result = system(compile_cmd);
                
                if (compile_obj_result == 0) {
                    // 尝试使用 objcopy 重命名 main 为 uya_main
                    snprintf(objcopy_cmd, sizeof(objcopy_cmd), "objcopy --redefine-sym main=uya_main \"%s\" \"%s\"", 
                             object_file, renamed_object);
                    if (system(objcopy_cmd) == 0) {
                        link_object = renamed_object;
                    } else {
                        link_object = object_file;
                    }
                }
                
                // 构建链接命令
                cmd_len = snprintf(cmd, sizeof(cmd), 
                    "gcc --std=c99 -no-pie %s %s \"%s\" \"%s\" -o \"%s\" %s -lstdc++ -lm -ldl -lpthread",
                    llvm_include, llvm_libdir, link_object, bridge_file, executable_file, llvm_libs);
            } else {
                // 没有 bridge.c，直接编译（可能会失败，因为缺少运行时函数）
                cmd_len = snprintf(cmd, sizeof(cmd), "gcc --std=c99 -o \"%s\" \"%s\"", executable_file, output_file);
            }
            
            if (cmd_len >= (int)sizeof(cmd)) {
                fprintf(stderr, "错误: 编译命令过长\n");
                return 1;
            }
            
            fprintf(stderr, "执行编译命令: %s\n", cmd);
            int compile_result = system(cmd);
            if (compile_result != 0) {
                fprintf(stderr, "错误: 编译 C99 代码失败\n");
                // 清理临时文件
                if (bridge_file) {
                    char temp_files[3][512];
                    int temp_count = 0;
                    if (last_slash) {
                        size_t dir_len = last_slash - output_file;
                        snprintf(temp_files[temp_count++], sizeof(temp_files[0]), "%.*s/compiler_temp.o", (int)dir_len, output_file);
                        snprintf(temp_files[temp_count++], sizeof(temp_files[0]), "%.*s/compiler_renamed.o", (int)dir_len, output_file);
                    } else {
                        snprintf(temp_files[temp_count++], sizeof(temp_files[0]), "compiler_temp.o");
                        snprintf(temp_files[temp_count++], sizeof(temp_files[0]), "compiler_renamed.o");
                    }
                    for (int i = 0; i < temp_count; i++) {
                        unlink(temp_files[i]);
                    }
                }
                return 1;
            }
            
            // 清理临时文件
            if (bridge_file) {
                char temp_files[3][512];
                int temp_count = 0;
                if (last_slash) {
                    size_t dir_len = last_slash - output_file;
                    snprintf(temp_files[temp_count++], sizeof(temp_files[0]), "%.*s/compiler_temp.o", (int)dir_len, output_file);
                    snprintf(temp_files[temp_count++], sizeof(temp_files[0]), "%.*s/compiler_renamed.o", (int)dir_len, output_file);
                } else {
                    snprintf(temp_files[temp_count++], sizeof(temp_files[0]), "compiler_temp.o");
                    snprintf(temp_files[temp_count++], sizeof(temp_files[0]), "compiler_renamed.o");
                }
                for (int i = 0; i < temp_count; i++) {
                    unlink(temp_files[i]);
                }
            }
            
            fprintf(stderr, "C99 可执行文件已生成: %s\n", executable_file);
        } else {
            // LLVM 后端：使用现有的链接逻辑
            if (link_executable(object_file, executable_file) != 0) {
                return 1;
            }
            fprintf(stderr, "可执行文件已生成: %s\n", executable_file);
        }
    }
    
    return 0;
}

