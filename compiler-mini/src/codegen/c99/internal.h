#ifndef CODEGEN_C99_INTERNAL_H
#define CODEGEN_C99_INTERNAL_H

#include "codegen_c99.h"
#include "lexer.h"
#include <stdio.h>

// 工具函数（utils.c）
const char *arena_strdup(Arena *arena, const char *src);
unsigned get_or_add_error_id(C99CodeGenerator *codegen, const char *name);
int is_c_keyword(const char *name);
const char *get_safe_c_identifier(C99CodeGenerator *codegen, const char *name);
void escape_string_for_c(FILE *output, const char *str);
int eval_const_expr(C99CodeGenerator *codegen, ASTNode *expr);
void emit_line_directive(C99CodeGenerator *codegen, int line, const char *filename);

// 字符串常量（utils.c）
const char *add_string_constant(C99CodeGenerator *codegen, const char *value);
const char *find_string_constant(C99CodeGenerator *codegen, const char *value);
void emit_string_constants(C99CodeGenerator *codegen);
void collect_string_constants_from_expr(C99CodeGenerator *codegen, ASTNode *expr);
/* 从插值构建 printf 格式串常量并添加，用于 printf(interp) 脱糖；返回常量名 */
const char *build_and_add_printf_fmt_from_interp(C99CodeGenerator *codegen, ASTNode *interp);
/* 将插值格式串直接输出到 output（内联，不依赖常量表），用于避免 collect/emit 顺序问题 */
void emit_printf_fmt_inline(C99CodeGenerator *codegen, ASTNode *interp);
void collect_string_constants_from_stmt(C99CodeGenerator *codegen, ASTNode *stmt);
void collect_string_constants_from_decl(C99CodeGenerator *codegen, ASTNode *decl);

// 类型系统（types.c）
const char *c99_type_to_c(C99CodeGenerator *codegen, ASTNode *type_node);
const char *c99_type_to_c_with_self(C99CodeGenerator *codegen, ASTNode *type_node, const char *self_struct_name);
const char *c99_type_to_c_with_self_opt(C99CodeGenerator *codegen, ASTNode *type_node, const char *self_struct_name, int const_self);
void emit_pending_slice_structs(C99CodeGenerator *codegen);
const char *convert_array_return_type(C99CodeGenerator *codegen, ASTNode *return_type);
const char *get_array_element_type(C99CodeGenerator *codegen, ASTNode *array_expr);
const char *get_array_wrapper_struct_name(C99CodeGenerator *codegen, ASTNode *array_type);
void gen_array_wrapper_struct(C99CodeGenerator *codegen, ASTNode *array_type, const char *struct_name);

// 类型检查（types.c）
int is_identifier_pointer_type(C99CodeGenerator *codegen, const char *name);
int is_identifier_pointer_to_array_type(C99CodeGenerator *codegen, const char *name);
int is_identifier_struct_type(C99CodeGenerator *codegen, const char *name);
const char *get_identifier_type_c(C99CodeGenerator *codegen, const char *name);
/* 从表达式推断 C 类型字符串（用于元组字面量复合字面量），尽力而为 */
const char *get_c_type_of_expr(C99CodeGenerator *codegen, ASTNode *expr);
int is_member_access_pointer_type(C99CodeGenerator *codegen, ASTNode *member_access);
int is_array_access_pointer_type(C99CodeGenerator *codegen, ASTNode *array_access);
int calculate_struct_size(C99CodeGenerator *codegen, ASTNode *type_node);

// 结构体相关（structs.c）
int is_struct_in_table(C99CodeGenerator *codegen, const char *struct_name);
int is_struct_defined(C99CodeGenerator *codegen, const char *struct_name);
void mark_struct_defined(C99CodeGenerator *codegen, const char *struct_name);
void add_struct_definition(C99CodeGenerator *codegen, const char *struct_name);
int struct_implements_interface_c99(C99CodeGenerator *codegen, const char *struct_name, const char *interface_name);
ASTNode *find_interface_decl_c99(C99CodeGenerator *codegen, const char *interface_name);
ASTNode *find_struct_decl_c99(C99CodeGenerator *codegen, const char *struct_name);
ASTNode *find_union_decl_c99(C99CodeGenerator *codegen, const char *union_name);
ASTNode *find_union_decl_by_variant_c99(C99CodeGenerator *codegen, const char *variant_name);
/* 根据 C 类型后缀（如 "uya_tagged_IntOrFloat"）查找联合体声明，用于方法调用代码生成 */
ASTNode *find_union_decl_by_tagged_c99(C99CodeGenerator *codegen, const char *tagged_suffix);
int find_union_variant_index(ASTNode *union_decl, const char *variant_name);
/* 根据 C 类型字符串（如 "struct Data"）查找结构体声明，用于按字段比较 */
ASTNode *find_struct_decl_from_type_c(C99CodeGenerator *codegen, const char *type_c);
int gen_union_definition(C99CodeGenerator *codegen, ASTNode *union_decl);
ASTNode *find_struct_field_type(C99CodeGenerator *codegen, ASTNode *struct_decl, const char *field_name);
int gen_struct_definition(C99CodeGenerator *codegen, ASTNode *struct_decl);
void emit_interface_structs_and_vtables(C99CodeGenerator *codegen);
void emit_vtable_constants(C99CodeGenerator *codegen);
/* 收集泛型结构体实例化（用于单态化） */
void collect_generic_struct_instance(C99CodeGenerator *codegen, ASTNode *type_node);
/* 从 AST 节点递归收集所有泛型结构体实例化 */
void collect_generic_struct_instances_from_node(C99CodeGenerator *codegen, ASTNode *node);
/* 生成泛型结构体实例化的结构体定义（单态化） */
void gen_generic_struct_instance(C99CodeGenerator *codegen, ASTNode *generic_struct_decl, ASTNode **type_args, int type_arg_count, const char *instance_name);

// 泛型结构体单态化（structs.c）
int is_generic_struct_c99(ASTNode *struct_decl);
int has_unresolved_mono_type_args(ASTNode *generic_decl, ASTNode **type_args, int type_arg_count);
const char *get_mono_struct_name(C99CodeGenerator *codegen, const char *generic_name, ASTNode **type_args, int type_arg_count);
int gen_mono_struct_definition(C99CodeGenerator *codegen, ASTNode *struct_decl, ASTNode **type_args, int type_arg_count);

// 枚举相关（enums.c）
int is_enum_in_table(C99CodeGenerator *codegen, const char *enum_name);
int is_enum_defined(C99CodeGenerator *codegen, const char *enum_name);
void mark_enum_defined(C99CodeGenerator *codegen, const char *enum_name);
void add_enum_definition(C99CodeGenerator *codegen, const char *enum_name);
ASTNode *find_enum_decl_c99(C99CodeGenerator *codegen, const char *enum_name);
int find_enum_variant_value(C99CodeGenerator *codegen, ASTNode *enum_decl, const char *variant_name);
int gen_enum_definition(C99CodeGenerator *codegen, ASTNode *enum_decl);

// 函数查找（function.c）
ASTNode *find_function_decl_c99(C99CodeGenerator *codegen, const char *func_name);
ASTNode *find_method_block_for_struct_c99(C99CodeGenerator *codegen, const char *struct_name);
ASTNode *find_method_block_for_union_c99(C99CodeGenerator *codegen, const char *union_name);
ASTNode *find_method_in_block(ASTNode *method_block, const char *method_name);
ASTNode *find_method_in_struct_c99(C99CodeGenerator *codegen, const char *struct_name, const char *method_name);
ASTNode *find_method_in_union_c99(C99CodeGenerator *codegen, const char *union_name, const char *method_name);
const char *get_method_c_name(C99CodeGenerator *codegen, const char *struct_name, const char *method_name);
int type_has_drop_c99(C99CodeGenerator *codegen, const char *struct_name);
void gen_method_prototype(C99CodeGenerator *codegen, ASTNode *fn_decl, const char *struct_name);
void gen_method_function(C99CodeGenerator *codegen, ASTNode *fn_decl, const char *struct_name);
int is_stdlib_function(const char *func_name);
void format_param_type(C99CodeGenerator *codegen, const char *type_c, const char *param_name, FILE *output);
void gen_function_prototype(C99CodeGenerator *codegen, ASTNode *fn_decl);
void gen_function(C99CodeGenerator *codegen, ASTNode *fn_decl);
/* 替换类型节点中的类型参数为具体类型（递归） */
ASTNode *replace_type_params_in_type(C99CodeGenerator *codegen, ASTNode *type_node, TypeParam *type_params, int type_param_count, ASTNode **type_args);
/* 生成泛型函数实例化的函数定义（单态化） */
void gen_generic_function_instance(C99CodeGenerator *codegen, ASTNode *generic_fn_decl, ASTNode **type_args, int type_arg_count, const char *instance_name);

// 泛型单态化函数生成（function.c）
int is_generic_function_c99(ASTNode *fn_decl);
const char *get_mono_function_name(C99CodeGenerator *codegen, const char *generic_name, ASTNode **type_args, int type_arg_count);
void gen_mono_function_prototype(C99CodeGenerator *codegen, ASTNode *fn_decl, ASTNode **type_args, int type_arg_count);
void gen_mono_function(C99CodeGenerator *codegen, ASTNode *fn_decl, ASTNode **type_args, int type_arg_count);

// 表达式生成（expr.c）
void gen_expr(C99CodeGenerator *codegen, ASTNode *expr);
/* 将字符串插值填充到指定缓冲区，生成 memcpy/sprintf 等语句；buf_name 为缓冲区变量名 */
void c99_emit_string_interp_fill(C99CodeGenerator *codegen, ASTNode *expr, const char *buf_name);
/* 收集泛型函数实例化（用于单态化） */
void collect_generic_instance(C99CodeGenerator *codegen, ASTNode *call_expr, const char *instance_name);
/* 从 AST 节点递归收集所有泛型函数实例化 */
void collect_generic_instances_from_node(C99CodeGenerator *codegen, ASTNode *node);

// 语句生成（stmt.c）
void gen_stmt(C99CodeGenerator *codegen, ASTNode *stmt);

// 全局变量生成（global.c）
void gen_global_init_expr(C99CodeGenerator *codegen, ASTNode *expr);
void gen_global_var(C99CodeGenerator *codegen, ASTNode *var_decl);

#endif // CODEGEN_C99_INTERNAL_H

