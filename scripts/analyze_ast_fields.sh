#!/bin/bash
# 分析 ASTNode 字段分组

echo "=== ASTNode 字段分组分析 ==="
echo ""

# 读取 ast.uya，提取字段分组
grep -n "// [a-z_]*（\|^\s\+[a-z_]*:" /home/winger/uya/src/ast.uya | head -200
