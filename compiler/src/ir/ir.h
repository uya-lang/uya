#ifndef IR_H
#define IR_H

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// 前向声明ASTNode，避免循环依赖
struct ASTNode;
typedef struct ASTNode ASTNode;

// IR 指令类型
typedef enum {
    IR_FUNC_DECL,      // 函数声明
    IR_FUNC_DEF,       // 函数定义
    IR_VAR_DECL,       // 变量声明
    IR_ASSIGN,         // 赋值
    IR_BINARY_OP,      // 二元运算
    IR_UNARY_OP,       // 一元运算
    IR_CALL,           // 函数调用
    IR_RETURN,         // 返回
    IR_IF,             // if 语句
    IR_WHILE,          // while 循环
    IR_BLOCK,          // 代码块
    IR_LOAD,           // 加载值
    IR_STORE,          // 存储值
    IR_GOTO,           // 跳转
    IR_LABEL,          // 标签
    IR_ALLOC,          // 分配内存
    IR_STRUCT_DECL,    // 结构体声明
    IR_MEMBER_ACCESS,  // 成员访问
    IR_SUBSCRIPT,      // 数组下标访问
    IR_CAST,           // 类型转换
    IR_ERROR_UNION,    // 错误联合类型操作
    IR_TRY_CATCH,      // try/catch
    IR_SLICE,          // 数组切片操作
} IRInstType;

// 数据类型
typedef enum {
    IR_TYPE_I8,
    IR_TYPE_I16,
    IR_TYPE_I32,
    IR_TYPE_I64,
    IR_TYPE_U8,
    IR_TYPE_U16,
    IR_TYPE_U32,
    IR_TYPE_U64,
    IR_TYPE_F32,
    IR_TYPE_F64,
    IR_TYPE_BOOL,
    IR_TYPE_BYTE,
    IR_TYPE_VOID,
    IR_TYPE_PTR,
    IR_TYPE_ARRAY,
    IR_TYPE_STRUCT,
    IR_TYPE_FN,
    IR_TYPE_ERROR_UNION,  // !T 类型
} IRType;

// IR 指令操作符
typedef enum {
    IR_OP_ADD,
    IR_OP_SUB,
    IR_OP_MUL,
    IR_OP_DIV,
    IR_OP_MOD,
    IR_OP_BIT_AND,
    IR_OP_BIT_OR,
    IR_OP_BIT_XOR,
    IR_OP_BIT_NOT,
    IR_OP_LEFT_SHIFT,
    IR_OP_RIGHT_SHIFT,
    IR_OP_LOGIC_AND,
    IR_OP_LOGIC_OR,
    IR_OP_NEG,
    IR_OP_NOT,
    IR_OP_EQ,
    IR_OP_NE,
    IR_OP_LT,
    IR_OP_LE,
    IR_OP_GT,
    IR_OP_GE,
} IROp;

// IR 指令结构
typedef struct IRInst {
    IRInstType type;
    int id;  // 指令ID，用于SSA形式
    
    union {
        // 函数声明/定义
        struct {
            char *name;
            struct IRInst **params;
            int param_count;
            IRType return_type;
            struct IRInst **body;
            int body_count;
            int is_extern;
        } func;
        
        // 变量声明
        struct {
            char *name;
            IRType type;
            struct IRInst *init;
            int is_mut;
        } var;
        
        // 赋值
        struct {
            char *dest;
            struct IRInst *src;
        } assign;
        
        // 二元运算
        struct {
            char *dest;
            IROp op;
            struct IRInst *left;
            struct IRInst *right;
        } binary_op;
        
        // 一元运算
        struct {
            char *dest;
            IROp op;
            struct IRInst *operand;
        } unary_op;
        
        // 函数调用
        struct {
            char *dest;  // 可能为NULL（void函数）
            char *func_name;
            struct IRInst **args;
            int arg_count;
        } call;
        
        // 返回
        struct {
            struct IRInst *value;
        } ret;
        
        // if 语句
        struct {
            struct IRInst *condition;
            struct IRInst **then_body;
            int then_count;
            struct IRInst **else_body;
            int else_count;
        } if_stmt;
        
        // while 循环
        struct {
            struct IRInst *condition;
            struct IRInst **body;
            int body_count;
        } while_stmt;
        
        // 代码块
        struct {
            struct IRInst **insts;
            int inst_count;
        } block;
        
        // 加载/存储
        struct {
            char *dest;
            char *src;
        } load, store;
        
        // 类型转换
        struct {
            char *dest;
            struct IRInst *src;
            IRType from_type;
            IRType to_type;
        } cast;
        
        // 错误联合类型
        struct {
            char *dest;
            struct IRInst *value;
            int is_error;  // 0 = 正常值, 1 = 错误值
        } error_union;
        
        // try/catch
        struct {
            struct IRInst *try_body;
            char *error_var;  // 错误变量名
            struct IRInst *catch_body;
        } try_catch;

        // 数组切片操作
        struct {
            char *dest;      // 目标切片变量
            struct IRInst *source;  // 源数组
            struct IRInst *start;   // 起始索引
            struct IRInst *length;  // 切片长度
        } slice_op;
    } data;
} IRInst;

// IR 生成器结构
typedef struct IRGenerator {
    IRInst **instructions;
    int inst_count;
    int inst_capacity;
    int current_id;
} IRGenerator;

// IR 操作函数
IRGenerator *irgenerator_new();
void irgenerator_free(IRGenerator *gen);
IRInst *irinst_new(IRInstType type);
void irinst_free(IRInst *inst);
void ir_print(IRInst *inst, int indent);

// IR 生成器函数
void *irgenerator_generate(IRGenerator *ir_gen, ASTNode *ast);
void ir_free(void *ir);

#endif