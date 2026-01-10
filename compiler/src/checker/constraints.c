#include "constraints.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// 创建新的约束集合
ConstraintSet *constraint_set_new() {
    ConstraintSet *set = malloc(sizeof(ConstraintSet));
    if (!set) return NULL;
    
    set->capacity = 16;
    set->count = 0;
    set->constraints = malloc(set->capacity * sizeof(Constraint*));
    if (!set->constraints) {
        free(set);
        return NULL;
    }
    
    return set;
}

// 释放约束集合
void constraint_set_free(ConstraintSet *set) {
    if (!set) return;
    
    // 释放约束数组中的每个约束，但只释放一次
    if (set->constraints) {
        for (int i = 0; i < set->count; i++) {
            if (set->constraints[i]) {
                constraint_free(set->constraints[i]);
                set->constraints[i] = NULL;  // 标记为已释放
            }
        }
        free(set->constraints);
        set->constraints = NULL;
    }
    
    free(set);
}

// 添加约束到集合
int constraint_set_add(ConstraintSet *set, Constraint *constraint) {
    if (!set || !constraint) return 0;
    
    // 检查是否已存在相同约束
    Constraint *existing = constraint_set_find(set, constraint->var_name, constraint->type);
    if (existing) {
        // 如果已存在，可能需要合并（对于范围约束）
        if (constraint->type == CONSTRAINT_RANGE) {
            // 取更严格的约束（更小的范围）
            if (constraint->data.range.min > existing->data.range.min) {
                existing->data.range.min = constraint->data.range.min;
            }
            if (constraint->data.range.max < existing->data.range.max) {
                existing->data.range.max = constraint->data.range.max;
            }
        }
        // 释放新约束，无论是否合并
        constraint_free(constraint);
        return 1;
    }
    
    // 扩展容量
    if (set->count >= set->capacity) {
        int new_capacity = set->capacity * 2;
        Constraint **new_constraints = realloc(set->constraints, new_capacity * sizeof(Constraint*));
        if (!new_constraints) {
            // 扩容失败时，释放传入的约束，避免内存泄漏
            constraint_free(constraint);
            return 0;
        }
        set->constraints = new_constraints;
        set->capacity = new_capacity;
    }
    
    set->constraints[set->count++] = constraint;
    return 1;
}

// 查找约束
Constraint *constraint_set_find(ConstraintSet *set, const char *var_name, ConstraintType type) {
    if (!set || !var_name) return NULL;
    
    for (int i = 0; i < set->count; i++) {
        if (set->constraints[i]->type == type &&
            strcmp(set->constraints[i]->var_name, var_name) == 0) {
            return set->constraints[i];
        }
    }
    
    return NULL;
}

// 复制约束集合
ConstraintSet *constraint_set_copy(ConstraintSet *set) {
    if (!set) return NULL;
    
    ConstraintSet *copy = constraint_set_new();
    if (!copy) return NULL;
    
    for (int i = 0; i < set->count; i++) {
        Constraint *c = set->constraints[i];
        Constraint *new_constraint = NULL;
        
        switch (c->type) {
            case CONSTRAINT_RANGE:
                new_constraint = constraint_new_range(c->var_name, 
                                                     c->data.range.min, 
                                                     c->data.range.max);
                break;
            case CONSTRAINT_NONZERO:
                new_constraint = constraint_new_nonzero(c->var_name);
                break;
            case CONSTRAINT_NOT_NULL:
                new_constraint = constraint_new_not_null(c->var_name);
                break;
            case CONSTRAINT_INITIALIZED:
                new_constraint = constraint_new_initialized(c->var_name);
                break;
        }
        
        if (new_constraint) {
            constraint_set_add(copy, new_constraint);
        }
    }
    
    return copy;
}

// 合并约束集合
void constraint_set_merge(ConstraintSet *dest, ConstraintSet *src) {
    if (!dest || !src) return;
    
    for (int i = 0; i < src->count; i++) {
        Constraint *c = src->constraints[i];
        Constraint *new_constraint = NULL;
        
        switch (c->type) {
            case CONSTRAINT_RANGE:
                new_constraint = constraint_new_range(c->var_name, 
                                                     c->data.range.min, 
                                                     c->data.range.max);
                break;
            case CONSTRAINT_NONZERO:
                new_constraint = constraint_new_nonzero(c->var_name);
                break;
            case CONSTRAINT_NOT_NULL:
                new_constraint = constraint_new_not_null(c->var_name);
                break;
            case CONSTRAINT_INITIALIZED:
                new_constraint = constraint_new_initialized(c->var_name);
                break;
        }
        
        if (new_constraint) {
            constraint_set_add(dest, new_constraint);
        }
    }
}

// 创建范围约束
Constraint *constraint_new_range(const char *var_name, long long min, long long max) {
    Constraint *c = malloc(sizeof(Constraint));
    if (!c) return NULL;
    
    c->type = CONSTRAINT_RANGE;
    c->var_name = malloc(strlen(var_name) + 1);
    if (!c->var_name) {
        free(c);
        return NULL;
    }
    strcpy(c->var_name, var_name);
    c->data.range.min = min;
    c->data.range.max = max;
    
    return c;
}

// 创建非零约束
Constraint *constraint_new_nonzero(const char *var_name) {
    Constraint *c = malloc(sizeof(Constraint));
    if (!c) return NULL;
    
    c->type = CONSTRAINT_NONZERO;
    c->var_name = malloc(strlen(var_name) + 1);
    if (!c->var_name) {
        free(c);
        return NULL;
    }
    strcpy(c->var_name, var_name);
    
    return c;
}

// 创建非空指针约束
Constraint *constraint_new_not_null(const char *var_name) {
    Constraint *c = malloc(sizeof(Constraint));
    if (!c) return NULL;
    
    c->type = CONSTRAINT_NOT_NULL;
    c->var_name = malloc(strlen(var_name) + 1);
    if (!c->var_name) {
        free(c);
        return NULL;
    }
    strcpy(c->var_name, var_name);
    
    return c;
}

// 创建已初始化约束
Constraint *constraint_new_initialized(const char *var_name) {
    Constraint *c = malloc(sizeof(Constraint));
    if (!c) return NULL;
    
    c->type = CONSTRAINT_INITIALIZED;
    c->var_name = malloc(strlen(var_name) + 1);
    if (!c->var_name) {
        free(c);
        return NULL;
    }
    strcpy(c->var_name, var_name);
    
    return c;
}

// 释放约束
void constraint_free(Constraint *constraint) {
    if (!constraint) return;
    if (constraint->var_name) {
        free(constraint->var_name);
    }
    free(constraint);
}



