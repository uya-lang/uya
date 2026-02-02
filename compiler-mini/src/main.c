#define _GNU_SOURCE  // 用于 readlink
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <limits.h>
#include <dirent.h>
#include "arena.h"
#include "lexer.h"
#include "parser.h"
#include "checker.h"
#include "codegen_c99.h"

// 如果 PATH_MAX 未定义，定义它
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif

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
static uint8_t temp_arena_buffer[32 * 1024 * 1024];  // 32MB 临时缓冲区（用于依赖收集，全局变量避免栈溢出）

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

// 获取编译器程序所在目录
// 参数：argv0 - 程序路径（argv[0]）
//       buffer - 输出缓冲区
//       buffer_size - 缓冲区大小
// 返回：成功返回0，失败返回-1
static int get_compiler_dir(const char *argv0, char *buffer, size_t buffer_size) {
    if (argv0 == NULL || buffer == NULL || buffer_size == 0) {
        return -1;
    }
    
    // 如果是绝对路径，直接提取目录
    if (argv0[0] == '/') {
        const char *last_slash = strrchr(argv0, '/');
        if (last_slash != NULL) {
            size_t dir_len = last_slash - argv0;
            if (dir_len + 1 < buffer_size) {
                memcpy(buffer, argv0, dir_len);
                buffer[dir_len] = '/';
                buffer[dir_len + 1] = '\0';
                return 0;
            }
        }
    }
    
    // 尝试使用 readlink 获取真实路径（Linux）
    char resolved_path[PATH_MAX];
    ssize_t len = readlink("/proc/self/exe", resolved_path, sizeof(resolved_path) - 1);
    if (len != -1) {
        resolved_path[len] = '\0';
        const char *last_slash = strrchr(resolved_path, '/');
        if (last_slash != NULL) {
            size_t dir_len = last_slash - resolved_path;
            if (dir_len + 1 < buffer_size) {
                memcpy(buffer, resolved_path, dir_len);
                buffer[dir_len] = '/';
                buffer[dir_len + 1] = '\0';
                return 0;
            }
        }
    }
    
    // 回退：使用当前目录
    if (buffer_size > 1) {
        buffer[0] = '.';
        buffer[1] = '/';
        buffer[2] = '\0';
        return 0;
    }
    
    return -1;
}

// 获取 UYA_ROOT 环境变量或默认目录
// 参数：argv0 - 程序路径（argv[0]）
//       buffer - 输出缓冲区
//       buffer_size - 缓冲区大小
// 返回：成功返回0，失败返回-1
static int get_uya_root(const char *argv0, char *buffer, size_t buffer_size) {
    if (buffer == NULL || buffer_size == 0) {
        return -1;
    }
    
    // 首先尝试从环境变量获取
    const char *env_root = getenv("UYA_ROOT");
    if (env_root != NULL && env_root[0] != '\0') {
        size_t len = strlen(env_root);
        if (len < buffer_size) {
            strcpy(buffer, env_root);
            // 确保以 '/' 结尾
            if (len > 0 && buffer[len - 1] != '/') {
                if (len + 1 < buffer_size) {
                    buffer[len] = '/';
                    buffer[len + 1] = '\0';
                }
            }
            return 0;
        }
    }
    
    // 如果环境变量未设置，使用编译器程序所在目录
    return get_compiler_dir(argv0, buffer, buffer_size);
}

// 检查路径是否为目录
// 参数：path - 路径
// 返回：是目录返回1，否则返回0
static int is_directory(const char *path) {
    struct stat st;
    if (stat(path, &st) == 0) {
        return S_ISDIR(st.st_mode);
    }
    return 0;
}

// 检查路径是否为文件
// 参数：path - 路径
// 返回：是文件返回1，否则返回0
static int is_file(const char *path) {
    struct stat st;
    if (stat(path, &st) == 0) {
        return S_ISREG(st.st_mode);
    }
    return 0;
}


// 比较两个路径是否指向同一个文件（考虑路径格式差异）
// 参数：path1 - 第一个路径
//       path2 - 第二个路径
// 返回：相同返回1，不同返回0
static int paths_equal(const char *path1, const char *path2) {
    if (path1 == NULL || path2 == NULL) {
        return 0;
    }
    
    // 首先尝试直接比较（最常见的情况）
    if (strcmp(path1, path2) == 0) {
        return 1;
    }
    
    // 如果直接比较失败，提取文件名进行比较
    // 如果文件名相同，使用 stat 检查是否是同一个文件（相同的 inode）
    const char *name1 = strrchr(path1, '/');
    const char *name2 = strrchr(path2, '/');
    if (name1 == NULL) name1 = path1;
    else name1++;
    if (name2 == NULL) name2 = path2;
    else name2++;
    
    // 如果文件名不同，肯定不是同一个文件
    if (strcmp(name1, name2) != 0) {
        return 0;
    }
    
    // 文件名相同，使用 stat 检查是否是同一个文件
    struct stat st1, st2;
    if (stat(path1, &st1) == 0 && stat(path2, &st2) == 0) {
        // 检查是否是同一个文件（相同的设备和 inode）
        return (st1.st_dev == st2.st_dev && st1.st_ino == st2.st_ino);
    }
    
    // stat 失败，回退到字符串比较（已经比较过了，返回0）
    return 0;
}

// 根据模块路径查找文件
// 参数：module_path - 模块路径（如 "std.io"）
//       project_root - 项目根目录（包含 main 的目录）
//       uya_root - UYA_ROOT 目录（标准库位置）
//       buffer - 输出缓冲区（存储找到的文件路径）
//       buffer_size - 缓冲区大小
// 返回：成功返回0，失败返回-1
static int find_module_file(const char *module_path, const char *project_root, const char *uya_root, char *buffer, size_t buffer_size) {
    if (module_path == NULL || buffer == NULL || buffer_size == 0) {
        return -1;
    }
    
    // 将模块路径转换为文件路径（std.io -> std/io/）
    char file_path[PATH_MAX];
    size_t path_len = strlen(module_path);
    if (path_len >= sizeof(file_path)) {
        return -1;
    }
    
    strcpy(file_path, module_path);
    // 将 '.' 替换为 '/'
    for (size_t i = 0; i < path_len; i++) {
        if (file_path[i] == '.') {
            file_path[i] = '/';
        }
    }
    
    // 尝试在项目根目录查找
    if (project_root != NULL && project_root[0] != '\0') {
        char full_path[PATH_MAX];
        int len = snprintf(full_path, sizeof(full_path), "%s%s", project_root, file_path);
        if (len > 0 && len < (int)sizeof(full_path)) {
            // 检查是否为目录
            if (is_directory(full_path)) {
                // 在目录中查找 .uya 文件
                DIR *dir = opendir(full_path);
                if (dir != NULL) {
                    struct dirent *entry;
                    while ((entry = readdir(dir)) != NULL) {
                        if (entry->d_type == DT_REG) {
                            const char *name = entry->d_name;
                            size_t name_len = strlen(name);
                            if (name_len > 4 && strcmp(name + name_len - 4, ".uya") == 0) {
                                // 找到 .uya 文件
                                closedir(dir);
                                len = snprintf(buffer, buffer_size, "%s%s/%s", project_root, file_path, name);
                                if (len > 0 && len < (int)buffer_size) {
                                    return 0;
                                }
                            }
                        }
                    }
                    closedir(dir);
                }
            }
        }
    }
    
    // 尝试在 UYA_ROOT 目录查找
    if (uya_root != NULL && uya_root[0] != '\0') {
        char full_path[PATH_MAX];
        int len = snprintf(full_path, sizeof(full_path), "%s%s", uya_root, file_path);
        if (len > 0 && len < (int)sizeof(full_path)) {
            // 检查是否为目录
            if (is_directory(full_path)) {
                // 在目录中查找 .uya 文件
                DIR *dir = opendir(full_path);
                if (dir != NULL) {
                    struct dirent *entry;
                    while ((entry = readdir(dir)) != NULL) {
                        if (entry->d_type == DT_REG) {
                            const char *name = entry->d_name;
                            size_t name_len = strlen(name);
                            if (name_len > 4 && strcmp(name + name_len - 4, ".uya") == 0) {
                                // 找到 .uya 文件
                                closedir(dir);
                                len = snprintf(buffer, buffer_size, "%s%s/%s", uya_root, file_path, name);
                                if (len > 0 && len < (int)buffer_size) {
                                    return 0;
                                }
                            }
                        }
                    }
                    closedir(dir);
                }
            }
        }
    }
    
    return -1;
}

// 从 AST 中提取 use 语句的模块路径
// 参数：ast - AST 程序节点
//       modules - 输出数组（存储模块路径，使用 Arena 分配）
//       max_modules - 最大模块数量
//       module_count - 输出参数：实际找到的模块数量
//       arena - Arena 分配器
// 返回：成功返回0，失败返回-1
static int extract_use_modules(ASTNode *ast, const char *modules[], int max_modules, int *module_count, Arena *arena) {
    if (ast == NULL || ast->type != AST_PROGRAM || modules == NULL || module_count == NULL || arena == NULL) {
        return -1;
    }
    
    *module_count = 0;
    
    for (int i = 0; i < ast->data.program.decl_count && *module_count < max_modules; i++) {
        ASTNode *decl = ast->data.program.decls[i];
        if (decl != NULL && decl->type == AST_USE_STMT) {
            // 构建模块路径（将 path_segments 用 '.' 连接）
            if (decl->data.use_stmt.path_segment_count > 0) {
                // 计算所需的总长度
                size_t total_len = 0;
                for (int j = 0; j < decl->data.use_stmt.path_segment_count; j++) {
                    if (decl->data.use_stmt.path_segments[j] != NULL) {
                        total_len += strlen(decl->data.use_stmt.path_segments[j]);
                        if (j > 0) {
                            total_len += 1;  // '.' 分隔符
                        }
                    }
                }
                
                // 使用 Arena 分配内存并构建模块路径
                char *module_name = (char *)arena_alloc(arena, total_len + 1);
                if (module_name != NULL) {
                    char *dst = module_name;
                    for (int j = 0; j < decl->data.use_stmt.path_segment_count; j++) {
                        if (decl->data.use_stmt.path_segments[j] != NULL) {
                            if (j > 0) {
                                *dst++ = '.';
                            }
                            size_t seg_len = strlen(decl->data.use_stmt.path_segments[j]);
                            memcpy(dst, decl->data.use_stmt.path_segments[j], seg_len);
                            dst += seg_len;
                        }
                    }
                    *dst = '\0';
                    modules[*module_count] = module_name;
                    (*module_count)++;
                }
            }
        }
    }
    
    return 0;
}

// 检测文件是否包含 main 函数
// 参数：filename - 文件名
// 返回：包含 main 返回1，否则返回0
static int detect_main_function(const char *filename) {
    if (filename == NULL) {
        return 0;
    }
    
    int file_size = read_file_content(filename, file_buffer, FILE_BUFFER_SIZE);
    if (file_size < 0) {
        return 0;
    }
    
    // 简单的字符串搜索（查找 "fn main("）
    const char *p = file_buffer;
    while (*p != '\0') {
        if (strncmp(p, "fn main(", 8) == 0) {
            return 1;
        }
        p++;
    }
    
    return 0;
}

// 在目录中查找包含 main 函数的文件
// 参数：dir_path - 目录路径
//       main_files - 输出数组（存储找到的文件路径，使用静态缓冲区）
//       file_paths_buffer - 缓冲区数组（存储文件路径字符串）
//       max_files - 最大文件数量
//       file_count - 输出参数：实际找到的文件数量
// 返回：成功返回0，失败返回-1
static int find_main_files_in_dir(const char *dir_path, const char *main_files[], char file_paths_buffer[][PATH_MAX], int max_files, int *file_count) {
    if (dir_path == NULL || main_files == NULL || file_count == NULL) {
        return -1;
    }
    
    *file_count = 0;
    
    DIR *dir = opendir(dir_path);
    if (dir == NULL) {
        return -1;
    }
    
    struct dirent *entry;
    while ((entry = readdir(dir)) != NULL && *file_count < max_files) {
        if (entry->d_type == DT_REG) {
            const char *name = entry->d_name;
            size_t name_len = strlen(name);
            if (name_len > 4 && strcmp(name + name_len - 4, ".uya") == 0) {
                // 构建完整路径
                int len = snprintf(file_paths_buffer[*file_count], PATH_MAX, "%s/%s", dir_path, name);
                if (len > 0 && len < PATH_MAX) {
                    if (detect_main_function(file_paths_buffer[*file_count])) {
                        main_files[*file_count] = file_paths_buffer[*file_count];
                        (*file_count)++;
                    }
                }
            }
        }
    }
    
    closedir(dir);
    return 0;
}

// 递归收集模块依赖
// 参数：filename - 当前处理的文件
//       file_list - 输出数组（存储所有需要编译的文件）
//       file_list_size - 文件列表当前大小
//       max_files - 最大文件数量
//       processed_files - 已处理的文件列表（避免循环依赖）
//       processed_count - 已处理文件数量
//       max_processed - 最大已处理文件数量
//       project_root - 项目根目录
//       uya_root - UYA_ROOT 目录
//       arena - Arena 分配器（用于临时分配）
// 返回：成功返回新的文件列表大小，失败返回-1
static int collect_module_dependencies(
    const char *filename,
    const char *file_list[],
    int file_list_size,
    int max_files,
    const char *processed_files[],
    int *processed_count,
    int max_processed,
    const char *project_root,
    const char *uya_root,
    Arena *arena
) {
    if (filename == NULL || file_list == NULL || processed_files == NULL || 
        processed_count == NULL || arena == NULL) {
        return -1;
    }
    
    // 检查是否已在文件列表中（避免重复添加）
    // 使用路径比较函数，考虑路径格式差异
    for (int i = 0; i < file_list_size; i++) {
        if (file_list[i] != NULL && paths_equal(file_list[i], filename)) {
            // 文件已在列表中，但仍需要标记为已处理以避免循环依赖
            // 检查是否已处理过
            int already_processed = 0;
            for (int j = 0; j < *processed_count; j++) {
                if (processed_files[j] != NULL && paths_equal(processed_files[j], filename)) {
                    already_processed = 1;
                    break;
                }
            }
            if (!already_processed) {
                // 标记为已处理（避免循环依赖）
                if (*processed_count < max_processed) {
                    processed_files[*processed_count] = filename;
                    (*processed_count)++;
                }
            }
            // 已在列表中，直接返回（不进行解析，避免重复定义）
            return file_list_size;
        }
    }
    
    // 检查是否已处理过（避免循环依赖）
    // 使用路径比较函数，考虑路径格式差异
    for (int i = 0; i < *processed_count; i++) {
        if (processed_files[i] != NULL && paths_equal(processed_files[i], filename)) {
            return file_list_size;  // 已处理，直接返回
        }
    }
    
    // 标记为已处理（在解析之前标记，避免重复解析）
    if (*processed_count >= max_processed) {
        return -1;
    }
    processed_files[*processed_count] = filename;
    (*processed_count)++;
    
    // 读取文件并解析 AST（只有在文件不在列表中时才解析）
    int file_size = read_file_content(filename, file_buffer, FILE_BUFFER_SIZE);
    if (file_size < 0) {
        return -1;
    }
    
    Lexer lexer;
    if (lexer_init(&lexer, file_buffer, (size_t)file_size, filename, arena) != 0) {
        return -1;
    }
    
    Parser parser;
    if (parser_init(&parser, &lexer, arena) != 0) {
        return -1;
    }
    
    ASTNode *ast = parser_parse(&parser);
    if (ast == NULL || ast->type != AST_PROGRAM) {
        return -1;
    }
    
    // 提取 use 语句中的模块路径
    const char *modules[MAX_INPUT_FILES];
    int module_count = 0;
    if (extract_use_modules(ast, modules, MAX_INPUT_FILES, &module_count, arena) != 0) {
        return -1;
    }
    
    // 对于每个模块，查找文件并递归处理
    for (int i = 0; i < module_count; i++) {
        if (modules[i] == NULL) {
            continue;
        }
        
        // 特殊处理：main 模块
        if (strcmp(modules[i], "main") == 0) {
            // main 模块在项目根目录
            // 注意：main 模块通常已经在文件列表中（作为入口文件），
            // 所以这里不需要再次添加。如果确实需要添加，应该检查是否已在列表中。
            // 为了避免重复添加，这里直接跳过 main 模块的处理。
            // 如果 main.uya 不在列表中，它应该已经作为入口文件被添加了。
            // 注意：modules[i] 是通过 Arena 分配的，不需要手动释放
            continue;
        }
        
        // 查找模块文件
        char module_file[PATH_MAX];
        if (find_module_file(modules[i], project_root, uya_root, module_file, sizeof(module_file)) == 0) {
            // 检查是否已在列表中（使用路径比较函数）
            int already_added = 0;
            for (int j = 0; j < file_list_size; j++) {
                if (file_list[j] != NULL && paths_equal(file_list[j], module_file)) {
                    already_added = 1;
                    break;
                }
            }
            if (!already_added && file_list_size < max_files) {
                // 使用 Arena 分配文件路径
                size_t path_len = strlen(module_file);
                char *path_copy = (char *)arena_alloc(arena, path_len + 1);
                if (path_copy != NULL) {
                    strcpy(path_copy, module_file);
                    file_list[file_list_size] = path_copy;
                    file_list_size++;
                    // 递归处理依赖（使用 Arena 分配的 path_copy，而不是栈上的 module_file）
                    // 注意：这里需要递归处理，因为新文件可能有自己的依赖
                    file_list_size = collect_module_dependencies(
                        path_copy, file_list, file_list_size, max_files,
                        processed_files, processed_count, max_processed,
                        project_root, uya_root, arena
                    );
                    if (file_list_size < 0) {
                        return -1;
                    }
                }
            }
        }
    }
    
    return file_list_size;
}

// 打印使用说明
// 参数：program_name - 程序名称
static void print_usage(const char *program_name) {
    fprintf(stderr, "用法: %s [输入文件或目录] -o <输出文件> [选项]\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program.c\n", program_name);
    fprintf(stderr, "示例: %s src/ -o program.c  # 指定包含 main 函数的目录\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program.c -exec  # 直接生成可执行文件\n", program_name);
    fprintf(stderr, "示例: %s program.uya -o program.c --line-directives  # 生成 C99 代码（包含 #line 指令）\n", program_name);
    fprintf(stderr, "\n选项:\n");
    fprintf(stderr, "  -exec                生成可执行文件（编译并链接 C 代码）\n");
    fprintf(stderr, "  --no-line-directives 禁用 #line 指令生成（默认禁用）\n");
    fprintf(stderr, "  --line-directives    启用 #line 指令生成（默认禁用）\n");
    fprintf(stderr, "\n说明:\n");
    fprintf(stderr, "  - 输出 C99 源代码，输出文件建议使用 .c 后缀\n");
    fprintf(stderr, "  - 可以指定单个文件或目录，编译器会自动解析模块依赖\n");
    fprintf(stderr, "  - 如果指定目录，目录中必须只有一个文件包含 main 函数\n");
    fprintf(stderr, "  - 使用 UYA_ROOT 环境变量指定标准库位置（默认在编译器所在目录）\n");
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

    // 简单的参数解析：程序名 [输入文件或目录] -o <输出文件> [选项]
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
            // 非选项参数，应该是输入文件或目录
            if (*input_file_count >= MAX_INPUT_FILES) {
                fprintf(stderr, "错误: 输入文件数量超过最大限制 (%d)\n", MAX_INPUT_FILES);
                return -1;
            }
            input_files[*input_file_count] = argv[i];
            (*input_file_count)++;
        }
    }

    if (*input_file_count == 0) {
        fprintf(stderr, "错误: 未指定输入文件或目录\n");
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
// 参数：input_files - 输入文件名或目录数组
//       input_file_count - 输入文件/目录数量
//       output_file - 输出文件名
//       emit_line_directives - 是否生成 #line 指令（C99 后端）
//       argv0 - 程序路径（用于获取编译器目录）
// 返回：成功返回0，失败返回非0
static int compile_files(const char *input_files[], int input_file_count, const char *output_file, int emit_line_directives, const char *argv0) {
    // 初始化 Arena（用于依赖收集，使用全局缓冲区避免栈溢出）
    Arena temp_arena;
    arena_init(&temp_arena, temp_arena_buffer, sizeof(temp_arena_buffer));
    
    // 获取 UYA_ROOT 和编译器目录
    char uya_root[PATH_MAX];
    if (get_uya_root(argv0, uya_root, sizeof(uya_root)) != 0) {
        fprintf(stderr, "错误: 无法获取 UYA_ROOT 目录\n");
        return 1;
    }
    
    // 处理输入：如果是目录，查找包含 main 的文件；如果是文件，检查是否包含 main
    const char *resolved_files[MAX_INPUT_FILES];
    int resolved_count = 0;
    char project_root_buffer[PATH_MAX];
    const char *project_root = NULL;
    
    // 用于存储目录中找到的 main 文件路径
    char main_file_paths[MAX_INPUT_FILES][PATH_MAX];
    
    for (int i = 0; i < input_file_count; i++) {
        const char *input = input_files[i];
        if (is_directory(input)) {
            // 是目录，查找包含 main 的文件
            const char *main_files[MAX_INPUT_FILES];
            int main_count = 0;
            if (find_main_files_in_dir(input, main_files, main_file_paths, MAX_INPUT_FILES, &main_count) != 0) {
                fprintf(stderr, "错误: 无法读取目录 '%s'\n", input);
                return 1;
            }
            
            if (main_count == 0) {
                fprintf(stderr, "错误: 目录 '%s' 中未找到包含 main 函数的文件\n", input);
                return 1;
            }
            
            if (main_count > 1) {
                fprintf(stderr, "错误: 目录 '%s' 中有多个文件包含 main 函数:\n", input);
                for (int j = 0; j < main_count; j++) {
                    fprintf(stderr, "  %s\n", main_files[j]);
                }
                return 1;
            }
            
            // 找到唯一的 main 文件
            resolved_files[resolved_count] = main_files[0];
            resolved_count++;
            
            // 设置项目根目录
            if (project_root == NULL) {
                // 确保目录路径以 '/' 结尾
                size_t input_len = strlen(input);
                if (input_len < PATH_MAX - 1) {
                    strcpy(project_root_buffer, input);
                    if (project_root_buffer[input_len - 1] != '/') {
                        project_root_buffer[input_len] = '/';
                        project_root_buffer[input_len + 1] = '\0';
                    }
                    project_root = project_root_buffer;
                } else {
                    project_root = input;
                }
            }
        } else if (is_file(input)) {
            // 检查是否已在 resolved_files 中（避免重复添加）
            int already_resolved = 0;
            for (int j = 0; j < resolved_count; j++) {
                if (resolved_files[j] != NULL && paths_equal(resolved_files[j], input)) {
                    already_resolved = 1;
                    break;
                }
            }
            if (already_resolved) {
                i++;
                continue;  // 跳过重复文件
            }
            
            // 是文件，检查是否包含 main
            if (detect_main_function(input)) {
                resolved_files[resolved_count] = input;
                resolved_count++;
                
                // 设置项目根目录（文件所在目录）
                if (project_root == NULL) {
                    const char *last_slash = strrchr(input, '/');
                    if (last_slash != NULL) {
                        size_t dir_len = last_slash - input + 1;
                        if (dir_len < PATH_MAX) {
                            memcpy(project_root_buffer, input, dir_len);
                            project_root_buffer[dir_len] = '\0';
                            project_root = project_root_buffer;
                        } else {
                            strcpy(project_root_buffer, "./");
                            project_root = project_root_buffer;
                        }
                    } else {
                        strcpy(project_root_buffer, "./");
                        project_root = project_root_buffer;
                    }
                }
            } else {
                // 多文件模式下，允许某些文件不包含 main（它们是库文件）
                // 但如果这是唯一输入文件，则必须包含 main
                if (input_file_count == 1) {
                    fprintf(stderr, "错误: 文件 '%s' 不包含 main 函数\n", input);
                    return 1;
                }
                // 多文件模式：将不包含 main 的文件也加入列表（作为库文件）
                resolved_files[resolved_count] = input;
                resolved_count++;
            }
        } else {
            fprintf(stderr, "错误: '%s' 既不是文件也不是目录\n", input);
            return 1;
        }
    }
    
    if (resolved_count == 0) {
        fprintf(stderr, "错误: 未找到包含 main 函数的文件\n");
        return 1;
    }
    
    // 自动收集模块依赖
    const char *all_files[MAX_INPUT_FILES];
    int all_file_count = resolved_count;
    
    // 先添加入口文件
    for (int i = 0; i < resolved_count; i++) {
        all_files[i] = resolved_files[i];
    }
    
    // 收集依赖（只对包含 main 的文件进行依赖收集）
    // 库文件已经在列表中，不需要进行依赖收集
    const char *processed_files[MAX_INPUT_FILES];
    int processed_count = 0;
    
    // 找出包含 main 的文件（入口文件）
    int main_file_count = 0;
    const char *main_files[MAX_INPUT_FILES];
    for (int i = 0; i < resolved_count; i++) {
        if (detect_main_function(resolved_files[i])) {
            main_files[main_file_count++] = resolved_files[i];
        }
    }
    
    // 只对包含 main 的文件进行依赖收集
    // 注意：在手动文件列表模式下，所有文件（包括 main.uya）已经在 all_files 中
    // 因此不需要进行依赖收集，避免重复解析导致重复定义错误
    // 只有在自动依赖收集模式下（只传递了单个入口文件），才需要进行依赖收集
    // 判断是否为手动文件列表模式：如果 resolved_count > 1，说明是手动文件列表模式
    if (resolved_count == 1) {
        // 自动依赖收集模式：只传递了单个文件，需要进行依赖收集
        for (int i = 0; i < main_file_count; i++) {
            int new_count = collect_module_dependencies(
                main_files[i],
                all_files,
                all_file_count,
                MAX_INPUT_FILES,
                processed_files,
                &processed_count,
                MAX_INPUT_FILES,
                project_root,
                uya_root,
                &temp_arena
            );
            if (new_count < 0) {
                fprintf(stderr, "错误: 收集模块依赖失败: %s\n", main_files[i]);
                return 1;
            }
            all_file_count = new_count;
        }
    }
    // 手动文件列表模式：所有文件已经在列表中，不需要进行依赖收集
    
    fprintf(stderr, "=== 开始编译 ===\n");
    fprintf(stderr, "=== 词法/语法分析 ===\n");

    // 初始化 Arena 分配器（所有文件共享同一个 Arena）
    Arena arena;
    arena_init(&arena, arena_buffer, ARENA_BUFFER_SIZE);

    // 存储每个文件的 AST_PROGRAM 节点（栈上分配，只存储指针）
    ASTNode *programs[MAX_INPUT_FILES];

    // 解析每个文件
    for (int i = 0; i < all_file_count; i++) {
        const char *input_file = all_files[i];
        

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
        fprintf(stderr, "  解析完成: %s (声明数: %d)\n", input_file, ast->data.program.decl_count);
    }
    fprintf(stderr, "=== 词法/语法分析完成，共 %d 个文件 ===\n", all_file_count);

    fprintf(stderr, "=== AST 合并阶段 ===\n");
    ASTNode *merged_ast = ast_merge_programs(programs, all_file_count, &arena);
    if (merged_ast == NULL) {
        fprintf(stderr, "错误: AST 合并失败\n");
        return 1;
    }
    fprintf(stderr, "AST 合并完成，共 %d 个声明\n", merged_ast->data.program.decl_count);
    
    // 检查合并后的 AST 中是否有重复的 collect_module_dependencies 函数
    int collect_module_count = 0;
    for (int i = 0; i < merged_ast->data.program.decl_count; i++) {
        ASTNode *decl = merged_ast->data.program.decls[i];
        if (decl != NULL && decl->type == AST_FN_DECL && decl->data.fn_decl.name != NULL) {
            if (strcmp(decl->data.fn_decl.name, "collect_module_dependencies") == 0) {
                collect_module_count++;
                fprintf(stderr, "  合并后 AST 中发现 collect_module_dependencies 函数 #%d (行: %d, 列: %d, 文件: %s)\n", 
                        collect_module_count, decl->line, decl->column, 
                        decl->filename != NULL ? decl->filename : "(unknown)");
            }
        }
    }
    if (collect_module_count > 1) {
        fprintf(stderr, "警告: 在合并后的 AST 中发现 %d 个 collect_module_dependencies 函数定义\n", collect_module_count);
    }

    fprintf(stderr, "=== 类型检查阶段 ===\n");
    TypeChecker checker;
    const char *default_filename = all_file_count > 0 ? all_files[0] : "(unknown)";
    if (checker_init(&checker, &arena, default_filename) != 0) {
        fprintf(stderr, "错误: TypeChecker 初始化失败\n");
        return 1;
    }
    
    // 设置项目根目录到 checker
    if (project_root != NULL) {
        // 这里需要修改 checker 以支持设置项目根目录
        // 暂时通过 checker_init 的 filename 参数传递（已处理）
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
    const char *module_name = all_file_count > 0 ? all_files[0] : "(unknown)";
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

    int result = compile_files(input_files, input_file_count, output_file, emit_line_directives, argv[0]);
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
