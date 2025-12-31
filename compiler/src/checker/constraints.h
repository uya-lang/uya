#ifndef CONSTRAINTS_H
#define CONSTRAINTS_H

#include <stdlib.h>
#include <string.h>

// 约束类型
typedef enum {
    CONSTRAINT_RANGE,      // x >= min && x < max
    CONSTRAINT_NONZERO,     // x != 0
    CONSTRAINT_NOT_NULL,    // ptr != null
    CONSTRAINT_INITIALIZED // var is initialized
} ConstraintType;

// 约束条件
typedef struct Constraint {
    ConstraintType type;
    char *var_name;
    
    // 根据类型存储相应数据
    union {
        struct {
            long long min;  // 范围最小值
            long long max;  // 范围最大值（不包含）
        } range;
        // 其他约束类型不需要额外数据
    } data;
} Constraint;

// 约束集合
typedef struct ConstraintSet {
    Constraint **constraints;
    int count;
    int capacity;
} ConstraintSet;

// 约束集合操作
ConstraintSet *constraint_set_new();
void constraint_set_free(ConstraintSet *set);
int constraint_set_add(ConstraintSet *set, Constraint *constraint);
Constraint *constraint_set_find(ConstraintSet *set, const char *var_name, ConstraintType type);
ConstraintSet *constraint_set_copy(ConstraintSet *set);
void constraint_set_merge(ConstraintSet *dest, ConstraintSet *src);

// 约束创建函数
Constraint *constraint_new_range(const char *var_name, long long min, long long max);
Constraint *constraint_new_nonzero(const char *var_name);
Constraint *constraint_new_not_null(const char *var_name);
Constraint *constraint_new_initialized(const char *var_name);
void constraint_free(Constraint *constraint);

#endif // CONSTRAINTS_H


