#ifndef CODEGEN_C99_H
#define CODEGEN_C99_H

#include "ast.h"
#include "arena.h"
#include <stdio.h>

// C99 代码生成器常量定义（数组大小）
#define C99_MAX_STRING_CONSTANTS    512
#define C99_MAX_STRUCT_DEFINITIONS  128
#define C99_MAX_ENUM_DEFINITIONS    128
#define C99_MAX_FUNCTION_DECLS      256
#define C99_MAX_GLOBAL_VARS         256
#define C99_MAX_LOCAL_VARS          512
#define C99_MAX_LOOP_STACK          32

// C99 代码生成器结构体
typedef struct C99CodeGenerator {
    Arena *arena;                   // Arena 分配器
    FILE *output;                   // 输出文件指针
    int indent_level;               // 当前缩进级别
    const char *module_name;        // 模块名称
    
    // 字符串常量表（用于存储字符串字面量）
    struct StringConstant {
        const char *name;           // 常量名称（如 .str0）
        const char *value;          // 字符串值
    } string_constants[C99_MAX_STRING_CONSTANTS];
    int string_constant_count;
    
    // 结构体定义表（用于跟踪已定义的结构体）
    struct StructDefinition {
        const char *name;           // 结构体名称
        int defined;               // 是否已定义（1表示是，0表示否）
    } struct_definitions[C99_MAX_STRUCT_DEFINITIONS];
    int struct_definition_count;
    
    // 枚举定义表（用于跟踪已定义的枚举）
    struct EnumDefinition {
        const char *name;           // 枚举名称
        int defined;               // 是否已定义（1表示是，0表示否）
    } enum_definitions[C99_MAX_ENUM_DEFINITIONS];
    int enum_definition_count;
    
    // 函数声明表（用于跟踪已声明的函数）
    struct FunctionDeclaration {
        const char *name;           // 函数名称
        int declared;               // 是否已声明（1表示是，0表示否）
    } function_declarations[C99_MAX_FUNCTION_DECLS];
    int function_declaration_count;
    
    // 全局变量表
    struct GlobalVariable {
        const char *name;           // 变量名称
        const char *type_c;         // C 类型字符串
        int is_const;               // 是否为 const
    } global_variables[C99_MAX_GLOBAL_VARS];
    int global_variable_count;
    
    // 当前函数的局部变量表（栈式管理）
    struct LocalVariable {
        const char *name;           // 变量名称
        const char *type_c;         // C 类型字符串
        int depth;                 // 嵌套深度
    } local_variables[C99_MAX_LOCAL_VARS];
    int local_variable_count;
    int current_depth;              // 当前作用域深度
    
    // 循环栈（用于 break/continue）
    struct LoopStack {
        const char *break_label;    // break 标签
        const char *continue_label; // continue 标签
    } loop_stack[C99_MAX_LOOP_STACK];
    int loop_stack_depth;
    
    ASTNode *program_node;          // 程序节点引用
    ASTNode *current_function_return_type;  // 当前函数的返回类型（用于生成返回语句）
    ASTNode *current_function_decl;  // 当前正在生成的函数声明（用于 @params 与 ... 转发，可为 NULL）
    
    // 用于优化 #line 指令生成
    int current_line;               // 当前行号（用于避免重复的 #line 指令）
    const char *current_filename;  // 当前文件名（用于避免重复的 #line 指令）
    int emit_line_directives;      // 是否生成 #line 指令（1 表示是，0 表示否）
} C99CodeGenerator;

// 创建 C99 代码生成器
// 参数：codegen - C99CodeGenerator 结构体指针（由调用者分配）
//       arena - Arena 分配器指针
//       output - 输出文件指针（已打开的文件）
//       module_name - 模块名称
//       emit_line_directives - 是否生成 #line 指令（1 表示是，0 表示否）
// 返回：成功返回0，失败返回非0
int c99_codegen_new(C99CodeGenerator *codegen, Arena *arena, FILE *output, const char *module_name, int emit_line_directives);

// 生成 C99 代码
// 参数：codegen - C99CodeGenerator 结构体指针
//       ast - AST 根节点（程序节点）
//       output_file - 输出文件路径（用于生成辅助文件）
// 返回：成功返回0，失败返回非0
int c99_codegen_generate(C99CodeGenerator *codegen, ASTNode *ast, const char *output_file);

// 释放 C99 代码生成器资源（注意：不关闭输出文件）
// 参数：codegen - C99CodeGenerator 结构体指针
void c99_codegen_free(C99CodeGenerator *codegen);

// 工具函数：缩进输出
void c99_emit_indent(C99CodeGenerator *codegen);
void c99_emit_newline(C99CodeGenerator *codegen);
void c99_emit(C99CodeGenerator *codegen, const char *format, ...);

// 类型映射函数
const char *c99_type_to_c(C99CodeGenerator *codegen, ASTNode *type_node);

#endif // CODEGEN_C99_H