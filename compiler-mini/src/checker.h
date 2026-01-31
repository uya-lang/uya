#ifndef CHECKER_H
#define CHECKER_H

#include "ast.h"
#include "arena.h"
#include <stddef.h>
#include <stdint.h>

// 类型枚举（Uya Mini 支持的类型）
typedef enum {
    TYPE_I8,       // 8位有符号整数
    TYPE_I16,      // 16位有符号整数
    TYPE_I32,      // 32位有符号整数
    TYPE_I64,      // 64位有符号整数
    TYPE_U8,       // 8位无符号整数
    TYPE_U16,      // 16位无符号整数
    TYPE_U32,      // 32位无符号整数
    TYPE_USIZE,    // 平台相关的无符号大小类型（32位平台=u32，64位平台=u64）
    TYPE_U64,      // 64位无符号整数
    TYPE_BOOL,     // 布尔类型
    TYPE_BYTE,     // 无符号字节（1 字节）
    TYPE_F32,      // 32位浮点数（IEEE 754 单精度）
    TYPE_F64,      // 64位浮点数（IEEE 754 双精度）
    TYPE_VOID,     // void 类型（仅用于函数返回类型）
    TYPE_ENUM,     // 枚举类型（通过名称引用）
    TYPE_STRUCT,   // 结构体类型（通过名称引用）
    TYPE_POINTER,  // 指针类型（&T 或 *T）
    TYPE_ARRAY,    // 数组类型（[T: N]）
    TYPE_TUPLE,    // 元组类型（(T1, T2, ...)）
    TYPE_ERROR_UNION, // 错误联合类型 !T
    TYPE_ERROR,    // 错误值类型（仅用于 return error.X、catch |err| 等，error_id 非 0）
    TYPE_INT_LIMIT,// 未解析的 max/min 极值（需从上下文推断整数类型）
} TypeKind;

// 类型结构
// 使用 union 存储不同类型的数据
typedef struct Type {
    TypeKind kind;              // 类型种类
    union {
        const char *enum_name;      // 枚举名称（仅当 kind == TYPE_ENUM 时有效）
        const char *struct_name;    // 结构体名称（仅当 kind == TYPE_STRUCT 时有效）
        struct {
            struct Type *pointer_to;  // 指向的类型（仅当 kind == TYPE_POINTER 时有效，从 Arena 分配）
            int is_ffi_pointer;       // 是否为 FFI 指针（1 表示 *T，0 表示 &T，仅当 kind == TYPE_POINTER 时有效）
        } pointer;
        struct {
            struct Type *element_type; // 元素类型（仅当 kind == TYPE_ARRAY 时有效，从 Arena 分配）
            int array_size;            // 数组大小（编译期常量，仅当 kind == TYPE_ARRAY 时有效）
        } array;
        struct {
            struct Type *element_types; // 元素类型数组（仅当 kind == TYPE_TUPLE 时有效，从 Arena 分配，连续存储 count 个 Type）
            int count;                  // 元组元素个数
        } tuple;
        struct {
            struct Type *payload_type;  // 载荷类型 T（仅当 kind == TYPE_ERROR_UNION 时有效，从 Arena 分配）
        } error_union;
        struct {
            uint32_t error_id;          // 错误码（仅当 kind == TYPE_ERROR 时有效，0 表示无效）
        } error;
    } data;
} Type;

// 符号信息（变量、函数参数等）
typedef struct Symbol {
    const char *name;           // 符号名称（存储在 Arena 中）
    Type type;                  // 符号类型
    int is_const;               // 1 表示 const，0 表示 var
    int scope_level;            // 作用域级别
    int line;                   // 行号
    int column;                 // 列号
} Symbol;

// 函数签名信息
typedef struct FunctionSignature {
    const char *name;           // 函数名称（存储在 Arena 中）
    Type *param_types;          // 参数类型数组（从 Arena 分配）
    int param_count;            // 参数数量（固定参数数量，不包括可变参数）
    Type return_type;           // 返回类型
    int is_extern;              // 是否为 extern 函数
    int is_varargs;             // 是否为可变参数函数（1 表示是，0 表示否，仅用于 extern 函数）
    int line;                   // 行号
    int column;                 // 列号
} FunctionSignature;

// 符号表（固定大小哈希表，使用开放寻址）
#define SYMBOL_TABLE_SIZE 256   // 固定大小（必须是2的幂）

typedef struct SymbolTable {
    Symbol *slots[SYMBOL_TABLE_SIZE];  // 符号槽位数组（固定大小）
    int count;                          // 当前符号数量
} SymbolTable;

// 函数表（固定大小哈希表，使用开放寻址）
#define FUNCTION_TABLE_SIZE 256  // 固定大小（必须是2的幂）

typedef struct FunctionTable {
    FunctionSignature *slots[FUNCTION_TABLE_SIZE];  // 函数槽位数组（固定大小）
    int count;                                       // 当前函数数量
} FunctionTable;

// 类型检查器结构
typedef struct TypeChecker {
    Arena *arena;               // Arena 分配器（用于分配类型、符号等）
    SymbolTable symbol_table;   // 符号表
    FunctionTable function_table; // 函数表
    int scope_level;            // 当前作用域级别
    int loop_depth;             // 循环深度（用于检查 break/continue 是否在循环中）
    ASTNode *program_node;      // 程序节点（用于查找结构体声明等）
    int error_count;            // 错误计数（简化版本，暂不存储错误消息）
    const char *default_filename; // 默认文件名（用于错误报告，可为 NULL）
    Type current_return_type;   // 当前函数的返回类型（用于检查 return 语句）
    int in_function;            // 是否在函数中（1 表示是，0 表示否）
    int in_defer_or_errdefer;   // 是否在 defer/errdefer 块中（1 表示是，禁止 return/break/continue）
    ASTNode *current_function_decl;  // 当前正在检查的函数声明（用于 @params 类型推断，可为 NULL）
    // 错误集：收集所有使用的错误名称，分配 error_id（1-based）
    const char *error_names[128];  // 错误名称（Arena 存储）
    int error_name_count;           // 已注册错误数量（与 error_count 区分：error_count 为类型检查错误数）
} TypeChecker;

// 初始化 TypeChecker
// 参数：checker - TypeChecker 结构体指针（由调用者提供），arena - Arena 分配器，default_filename - 默认文件名（用于错误报告，可为 NULL）
// 返回：成功返回 0，失败返回 -1
// 注意：TypeChecker 结构体由调用者在栈上或静态分配，此函数只负责初始化
int checker_init(TypeChecker *checker, Arena *arena, const char *default_filename);

// 类型检查主函数
// 参数：checker - TypeChecker 指针，ast - AST 根节点
// 返回：成功返回 0，失败返回 -1
int checker_check(TypeChecker *checker, ASTNode *ast);

// 获取错误计数
// 参数：checker - TypeChecker 指针
// 返回：错误数量
int checker_get_error_count(TypeChecker *checker);

#endif // CHECKER_H

