#!/bin/bash
# 从 ast_data_structs.txt 添加结构体到 ast.uya（跳过已存在的）

STRUCTS_FILE="/home/winger/uya/scripts/ast_data_structs.txt"
AST_FILE="/home/winger/uya/src/ast.uya"

# 读取已有结构体名称（已存在的）
existing=$(grep -oP 'struct \K[A-Za-z0-9_]+' "$AST_FILE" | sort -u)

# 处理每个结构体定义
while IFS= read -r line; do
    # 跳过注释行和空行
    if [[ "$line" =~ ^[[:space:]]*// ]] || [[ -z "${line// }" ]]; then
        continue
    fi
    
    # 提取结构体名称
    if [[ "$line" =~ ^struct\ ([A-Za-z0-9_]+) ]]; then
        name="${BASH_REMATCH[1]}"
        
        # 检查是否已存在
        if echo "$existing" | grep -q "^${name}$"; then
            echo "跳过已存在: $name"
        else
            echo "添加: $name"
            echo "$line" >> "$AST_FILE"
        fi
    fi
done < "$STRUCTS_FILE"

echo "完成！"
