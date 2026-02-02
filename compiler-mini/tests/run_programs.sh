#!/bin/bash
# Uya Mini 编译器测试程序运行脚本
# 自动编译和运行所有测试程序，验证编译器生成的二进制正确性
#
# 用法:
#   ./run_programs.sh                    # 运行所有测试
#   ./run_programs.sh <文件或目录>        # 运行指定的测试文件或目录
#   ./run_programs.sh test_file.uya      # 运行单个测试文件
#   ./run_programs.sh tests/programs     # 运行指定目录下的所有测试
#   ./run_programs.sh tests/programs/multifile  # 运行指定子目录的测试
#
# 快速验证单个测试（在 compiler-mini 目录下执行）:
#   ./tests/run_programs.sh --uya -e test_global_var.uya
#   ./tests/run_programs.sh --uya tests/programs/test_global_var.uya
#   仅传文件名时会在 tests/programs/ 下查找，例如 test_global_var.uya

COMPILER="./build/compiler-mini"
TEST_DIR="tests/programs"
BUILD_DIR="$TEST_DIR/build"
PASSED=0
FAILED=0
ERRORS_ONLY=false
USE_C99=true
USE_UYA=false

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项] [文件或目录]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -e, --errors-only   只显示失败的测试"
    echo "  --c99               使用 C99 后端（默认，保留以兼容旧脚本）"
    echo "  --uya               使用 uya-src 编译的编译器（默认使用 C 版本编译器）"
    echo ""
    echo "参数:"
    echo "  无参数              运行所有测试"
    echo "  <文件>              运行指定的测试文件（.uya 文件）"
    echo "  <目录>              运行指定目录下的所有测试"
    echo ""
    echo "示例:"
    echo "  $0                                    # 运行所有测试"
    echo "  $0 -e                                 # 只显示失败的测试"
    echo "  $0 --c99                             # 使用 C99 后端运行所有测试"
    echo "  $0 --uya                              # 使用 uya-src 编译的编译器运行所有测试"
    echo "  # 指定单个文件可加快验证（文件名或相对 tests/programs 的路径均可）:"
    echo "  $0 test_global_var.uya               # 运行单个测试（在 tests/programs 下查找）"
    echo "  $0 --uya -e test_global_var.uya      # 用 uya 编译器只测该文件并仅显示失败信息"
    echo "  $0 tests/programs/test_global_var.uya # 或写完整相对路径"
    echo "  $0 tests/programs                     # 运行指定目录下的所有测试"
    echo "  $0 tests/programs/multifile          # 运行指定子目录的测试"
}

# 检查测试目录是否存在
if [ ! -d "$TEST_DIR" ]; then
    echo "错误: 测试目录 '$TEST_DIR' 不存在"
    exit 1
fi

# 创建构建输出目录
mkdir -p "$BUILD_DIR"
mkdir -p "$BUILD_DIR/multifile"
mkdir -p "$BUILD_DIR/cross_deps"

# 解析命令行参数
TARGET_PATH=""
while [ $# -gt 0 ]; do
    case "$1" in
        -h|--help)
            show_usage
            exit 0
            ;;
        -e|--errors-only)
            ERRORS_ONLY=true
            shift
            ;;
        --c99)
            USE_C99=true
            shift
            ;;
        --uya)
            USE_UYA=true
            shift
            ;;
        -*)
            echo "错误: 未知选项 '$1'"
            echo "使用 '$0 --help' 查看帮助信息"
            exit 1
            ;;
        *)
            TARGET_PATH="$1"
            # 若为相对路径且当前不存在，稍后会在 TEST_DIR 下再尝试（见下方 process_path 前）
            shift
            ;;
    esac
done

# 根据 --uya 选项设置编译器路径
if [ "$USE_UYA" = true ]; then
    # 自举编译器总是使用 C99 后端（因为它本身就是用 C99 后端编译的）
    # 所以自动启用 C99 后端
    USE_C99=true
    
    # 检查多个可能的编译器文件名（按优先级）
    # 注意：使用 --c99 后端时，compile.sh 会生成 "compiler"（去掉 .c 后缀）
    # 保留 compiler.c_exec 作为向后兼容（旧版本可能使用此名称）
    UYA_COMPILER_PATHS=(
        "./build/uya-compiler/compiler"        # 新版本（C99 后端，去掉 .c 后缀）
    )
    
    COMPILER=""
    for path in "${UYA_COMPILER_PATHS[@]}"; do
        if [ -f "$path" ] && [ -x "$path" ]; then
            COMPILER="$path"
            break
        fi
    done
    
    # 如果没找到，使用默认路径（用于错误提示）
    if [ -z "$COMPILER" ]; then
        COMPILER="./build/uya-compiler/compiler"
    fi
fi

# 检查编译器是否存在
if [ -z "$COMPILER" ] || [ ! -f "$COMPILER" ] || [ ! -x "$COMPILER" ]; then
    if [ "$USE_UYA" = true ]; then
        echo "错误: Uya 编译器不存在"
        echo "已检查以下路径："
        for path in "${UYA_COMPILER_PATHS[@]}"; do
            if [ -f "$path" ]; then
                if [ -x "$path" ]; then
                    echo "  $path (存在且可执行)"
                else
                    echo "  $path (存在但不可执行)"
                fi
            else
                echo "  $path (不存在)"
            fi
        done
        echo ""
        echo "请先运行 'cd uya-src && ./compile.sh -e --c99' 构建 Uya 编译器"
    else
        echo "错误: 编译器 '$COMPILER' 不存在"
        echo "请先运行 'make build' 构建编译器"
    fi
    exit 1
fi

if [ "$ERRORS_ONLY" = false ]; then
    echo "开始运行 Uya 测试程序..."
    echo "使用编译器: $COMPILER"
    if [ "$USE_UYA" = true ]; then
        echo "（Uya 版本编译器）"
    else
        echo "（C99 后端）"
    fi
    if [ -n "$TARGET_PATH" ]; then
        echo "目标: $TARGET_PATH"
    fi
    echo ""
fi

# 处理多文件编译测试的函数
process_multifile_test() {
    local test_dir="$1"
    local test_name="$2"
    local build_subdir="$3"
    
    if [ ! -d "$test_dir" ]; then
        return
    fi
    
    # 收集所有 .uya 文件
    local file_list=()
    for uya_file in "$test_dir"/*.uya; do
        if [ -f "$uya_file" ]; then
            file_list+=("$uya_file")
        fi
    done
    
    if [ ${#file_list[@]} -eq 0 ]; then
        return
    fi
    
    if [ "$ERRORS_ONLY" = false ]; then
        echo "测试: $test_name (多文件编译)"
    fi
    
    # 多文件编译：将所有文件一起编译（C99 后端生成 .c 文件）
    local output_file="$BUILD_DIR/$build_subdir/${test_name}.c"
    if [ "$USE_UYA" = true ]; then
        local compiler_output=$("$COMPILER" --c99 "${file_list[@]}" -o "$output_file" 2>&1)
    else
        local compiler_output=$("$COMPILER" --c99 "${file_list[@]}" -o "$output_file" 2>&1)
    fi
    local compiler_exit=$?
    if [ $compiler_exit -ne 0 ]; then
        # 如果有错误信息，显示它（排除调试信息）
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $test_name (多文件编译)"
        fi
        echo "$compiler_output" | grep -v "^调试:" | grep -E "(错误|错误:|失败)" | head -5
        echo "  ❌ 编译失败（退出码: $compiler_exit）"
        FAILED=$((FAILED + 1))
        if [ "$ERRORS_ONLY" = true ]; then
            echo ""
        fi
        return
    fi
    # 检查是否生成了输出文件
    if [ ! -f "$output_file" ]; then
        echo "  ❌ 编译失败（未生成输出文件: $output_file）"
        FAILED=$((FAILED + 1))
        return
    fi
    # 链接：编译 .c 文件为可执行文件（需要链接 bridge.c 提供运行时支持）
    link_succeeded=false
    BRIDGE_C="tests/bridge.c"
    if [ -f "$BRIDGE_C" ]; then
        if gcc -std=c99 -o "$BUILD_DIR/$build_subdir/$test_name" "$output_file" "$BRIDGE_C"; then
            link_succeeded=true
        fi
    else
        if gcc -std=c99 -o "$BUILD_DIR/$build_subdir/$test_name" "$output_file"; then
            link_succeeded=true
        fi
    fi
    
    if [ "$link_succeeded" = false ]; then
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $test_name (多文件编译)"
        fi
        echo "  ❌ 链接失败"
        FAILED=$((FAILED + 1))
        if [ "$ERRORS_ONLY" = true ]; then
            echo ""
        fi
        return
    fi
    
    # 运行
    if [ "$ERRORS_ONLY" = true ]; then
        # 在错误模式下，静默运行，只捕获退出码
        "$BUILD_DIR/$build_subdir/$test_name" > /dev/null 2>&1
    else
        "$BUILD_DIR/$build_subdir/$test_name"
    fi
    local exit_code=$?
    if [ $exit_code -eq 0 ]; then
        if [ "$ERRORS_ONLY" = false ]; then
            echo "  ✓ 测试通过"
        fi
        PASSED=$((PASSED + 1))
    else
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $test_name (多文件编译)"
        fi
        echo "  ❌ 测试失败（退出码: $exit_code）"
        FAILED=$((FAILED + 1))
        if [ "$ERRORS_ONLY" = true ]; then
            echo ""
        fi
    fi
}

# 收集 use 语句引用的模块文件（递归收集所有依赖）
collect_module_files() {
    local uya_file="$1"
    local -a file_list=("$uya_file")
    local -a processed_files=()  # 已处理的文件列表，避免循环（不预先添加主文件）
    
    # 递归收集依赖
    _collect_module_files_recursive "$uya_file" file_list processed_files
    
    printf '%s\n' "${file_list[@]}"
}

# 递归收集模块文件的辅助函数
_collect_module_files_recursive() {
    local uya_file="$1"
    local file_list_var="$2"  # 存储原始变量名，避免循环引用
    local processed_var="$3"  # 存储原始变量名，避免循环引用
    local -n file_list_ref="$file_list_var"
    local -n processed_ref="$processed_var"
    
    # 检查是否已处理过
    for existing in "${processed_ref[@]}"; do
        if [ "$existing" = "$uya_file" ]; then
            return  # 已处理，避免循环
        fi
    done
    
    # 标记为已处理（在处理依赖之前，避免循环依赖）
    processed_ref+=("$uya_file")
    
    # 提取所有 use 语句中的模块路径（去除项名，只保留模块路径）
    # use std.io.read_file; -> std.io
    local use_modules=$(grep -E "^\s*use\s+" "$uya_file" 2>/dev/null | sed -E 's/^\s*use\s+([^;]+);.*/\1/' | sed -E 's/\.[^.]*$//' | sort -u || true)
    
    if [ -z "$use_modules" ]; then
        return
    fi
    
    # 对于每个模块路径，查找对应的文件
    local test_dir=$(dirname "$uya_file")
    while IFS= read -r module_path; do
        if [ -z "$module_path" ]; then
            continue
        fi
        
        # 特殊处理：main 模块（项目根目录）
        if [ "$module_path" = "main" ]; then
            # main 模块的文件应该在项目根目录下（包含 main 函数的文件）
            # 对于测试用例，查找测试文件所在目录下的 .uya 文件（排除子目录）
            local found_file=""
            for f in "$test_dir"/*.uya; do
                if [ -f "$f" ]; then
                    # 检查文件是否包含 main 函数
                    if grep -q "^\s*fn\s\+main\s*(" "$f" 2>/dev/null; then
                        found_file="$f"
                        break
                    fi
                fi
            done
            
            # 如果没找到，尝试查找同目录下的所有 .uya 文件（可能是多文件项目）
            if [ -z "$found_file" ]; then
                for f in "$test_dir"/*.uya; do
                    if [ -f "$f" ]; then
                        found_file="$f"
                        break
                    fi
                done
            fi
            
            # 如果找到文件，添加到列表并递归处理
            if [ -n "$found_file" ]; then
                # 检查是否已经在列表中
                local already_added=false
                for existing in "${file_list_ref[@]}"; do
                    if [ "$existing" = "$found_file" ]; then
                        already_added=true
                        break
                    fi
                done
                if [ "$already_added" = false ]; then
                    file_list_ref+=("$found_file")
                    processed_ref+=("$found_file")
                    # 递归处理找到的文件（传递原始变量名，避免循环引用）
                    _collect_module_files_recursive "$found_file" "$file_list_var" "$processed_var"
                fi
            fi
            continue
        fi
        
        # 将模块路径转换为文件路径（std.io -> std/io/）
        local file_path=$(echo "$module_path" | sed 's/\./\//g')
        
        # 尝试多个可能的文件位置
        local found_file=""
        
        # 1. 在测试文件同目录下查找
        if [ -d "$test_dir/$file_path" ]; then
            for f in "$test_dir/$file_path"/*.uya; do
                if [ -f "$f" ]; then
                    found_file="$f"
                    break
                fi
            done
        fi
        
        # 2. 在 TEST_DIR 下查找
        if [ -z "$found_file" ] && [ -d "$TEST_DIR/$file_path" ]; then
            for f in "$TEST_DIR/$file_path"/*.uya; do
                if [ -f "$f" ]; then
                    found_file="$f"
                    break
                fi
            done
        fi
        
        # 如果找到文件，添加到列表并递归处理
        if [ -n "$found_file" ]; then
            # 检查是否已经在列表中
            local already_added=false
            for existing in "${file_list_ref[@]}"; do
                if [ "$existing" = "$found_file" ]; then
                    already_added=true
                    break
                fi
            done
            if [ "$already_added" = false ]; then
                file_list_ref+=("$found_file")
                # 递归处理找到的文件（传递原始变量名，避免循环引用）
                _collect_module_files_recursive "$found_file" "$file_list_var" "$processed_var"
            fi
        fi
    done <<< "$use_modules"
}

# 处理单个测试文件的函数
process_single_test() {
    local uya_file="$1"
    local base_name=$(basename "$uya_file" .uya)
    
    if [ "$ERRORS_ONLY" = false ]; then
        echo "测试: $base_name"
    fi
    
    # 收集所有需要编译的文件（包括 use 语句引用的模块）
    local -a file_list
    mapfile -t file_list < <(collect_module_files "$uya_file")
    
    # 编译（C99 后端生成 .c 文件）
    output_file="$BUILD_DIR/${base_name}.c"
    if [ "$USE_UYA" = true ]; then
        compiler_output=$("$COMPILER" --c99 "${file_list[@]}" -o "$output_file" 2>&1)
    else
        compiler_output=$("$COMPILER" --c99 "${file_list[@]}" -o "$output_file" 2>&1)
    fi
    compiler_exit=$?
    
    # 检查是否是预期编译失败的测试文件
    # 约定：文件名（不含后缀）以 error_ 开头表示期望编译失败
    is_expected_fail=false
    if [[ "$base_name" =~ ^error_ ]]; then
        is_expected_fail=true
    fi
    
    if [ $compiler_exit -ne 0 ]; then
        # 如果是预期的编译失败，则测试通过（不显示错误）
        if [ "$is_expected_fail" = true ]; then
            if [ "$ERRORS_ONLY" = false ]; then
                echo "$compiler_output" | grep -v "^调试:" | grep -E "(错误|错误:|失败)" | head -5 || true
                echo "  ✓ 测试通过（预期编译失败）"
            fi
            PASSED=$((PASSED + 1))
        else
            # 显示错误信息
            if [ "$ERRORS_ONLY" = true ]; then
                echo "测试: $base_name"
            fi
            echo "$compiler_output" | grep -v "^调试:" | grep -E "(错误|错误:|失败)" | head -5 || true
            echo "  ❌ 编译失败（退出码: $compiler_exit）"
            FAILED=$((FAILED + 1))
            if [ "$ERRORS_ONLY" = true ]; then
                echo ""
            fi
        fi
        return
    fi
    
    # 如果编译成功，但这是预期编译失败的测试，则测试失败
    if [ "$is_expected_fail" = true ]; then
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $base_name"
        fi
        echo "  ❌ 测试失败（预期编译失败，但编译器未检测到错误）"
        FAILED=$((FAILED + 1))
        if [ "$ERRORS_ONLY" = true ]; then
            echo ""
        fi
        return
    fi
    
    # 检查输出文件是否生成
    if [ ! -f "$output_file" ]; then
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $base_name"
        fi
        echo "  ❌ 编译失败（未生成输出文件: $output_file）"
        FAILED=$((FAILED + 1))
        if [ "$ERRORS_ONLY" = true ]; then
            echo ""
        fi
        return
    fi
    
    # 链接：编译 .c 文件为可执行文件（对于需要外部函数的测试，需链接实现）
    link_succeeded=false
    BRIDGE_C="tests/bridge.c"
    if [ "$base_name" = "extern_function" ]; then
            # 编译主程序和外部函数实现（需要链接 bridge.c）
            if [ -f "$BRIDGE_C" ]; then
                if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/programs/extern_function_impl.c "$BRIDGE_C"; then
                    link_succeeded=true
                fi
            else
                if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/programs/extern_function_impl.c; then
                    link_succeeded=true
                fi
            fi
    elif [ "$base_name" = "test_comprehensive_cast" ] || [ "$base_name" = "test_ffi_cast" ] || [ "$base_name" = "test_pointer_cast" ] || [ "$base_name" = "test_simple_cast" ] || [ "$base_name" = "test_extern_union" ]; then
            # 编译主程序和通用外部函数实现（需要链接 bridge.c）
            if [ -f "$BRIDGE_C" ]; then
                if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/external_functions.c "$BRIDGE_C"; then
                    link_succeeded=true
                fi
            else
                if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/external_functions.c; then
                    link_succeeded=true
                fi
            fi
    elif [ "$base_name" = "test_abi_calling_convention" ]; then
            # 编译主程序和 ABI 辅助函数（需要链接 bridge.c）
            if [ -f "$BRIDGE_C" ]; then
                if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/programs/test_abi_helpers.c "$BRIDGE_C"; then
                    link_succeeded=true
                fi
            else
                if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/programs/test_abi_helpers.c; then
                    link_succeeded=true
                fi
            fi
    else
            # 普通 C99 编译（需要链接 bridge.c 提供运行时支持）
            if [ -f "$BRIDGE_C" ]; then
                if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" "$BRIDGE_C"; then
                    link_succeeded=true
                fi
            else
                if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file"; then
                    link_succeeded=true
                fi
            fi
        fi
    
    if [ "$link_succeeded" = false ]; then
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $base_name"
        fi
        echo "  ❌ 链接失败"
        FAILED=$((FAILED + 1))
        if [ "$ERRORS_ONLY" = true ]; then
            echo ""
        fi
        return
    fi
    
    # 运行
    if [ "$ERRORS_ONLY" = true ]; then
        # 在错误模式下，静默运行，只捕获退出码
        "$BUILD_DIR/$base_name" > /dev/null 2>&1
    else
        "$BUILD_DIR/$base_name"
    fi
    exit_code=$?
    if [ $exit_code -eq 0 ]; then
        if [ "$ERRORS_ONLY" = false ]; then
            echo "  ✓ 测试通过"
        fi
        PASSED=$((PASSED + 1))
    else
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $base_name"
        fi
        echo "  ❌ 测试失败（退出码: $exit_code）"
        FAILED=$((FAILED + 1))
        if [ "$ERRORS_ONLY" = true ]; then
            echo ""
        fi
    fi
}

# 处理目录或文件的函数
process_path() {
    local path="$1"
    
    # 如果是文件
    if [ -f "$path" ]; then
        # 检查是否是 .uya 文件
        if [[ "$path" == *.uya ]]; then
            process_single_test "$path"
        else
            echo "警告: 跳过非 .uya 文件: $path"
        fi
        return
    fi
    
    # 如果是目录
    if [ -d "$path" ]; then
        local dir_name=$(basename "$path")
        
        # 检查是否是特殊的多文件测试目录
        if [ "$dir_name" = "multifile" ] || [ "$dir_name" = "cross_deps" ]; then
            local build_subdir="$dir_name"
            process_multifile_test "$path" "$dir_name" "$build_subdir"
            return
        fi
        
        # 处理目录下的所有 .uya 文件
        for uya_file in "$path"/*.uya; do
            if [ -f "$uya_file" ]; then
                process_single_test "$uya_file"
            fi
        done
        
        # 递归处理子目录
        for subdir in "$path"/*; do
            if [ -d "$subdir" ] && [ "$(basename "$subdir")" != "build" ]; then
                process_path "$subdir"
            fi
        done
        return
    fi
    
    echo "警告: 跳过无效路径: $path"
}

# 如果指定了目标路径，只处理该路径
if [ -n "$TARGET_PATH" ]; then
    # 转换为绝对路径或相对于当前目录的路径；支持裸文件名（在 tests/programs 下查找）
    if [[ "$TARGET_PATH" != /* ]]; then
        if [ -f "$TARGET_PATH" ] || [ -d "$TARGET_PATH" ]; then
            TARGET_PATH=$(realpath "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")
        elif [ -f "$TEST_DIR/$TARGET_PATH" ] || [ -d "$TEST_DIR/$TARGET_PATH" ]; then
            TARGET_PATH="$TEST_DIR/$TARGET_PATH"
        fi
    fi
    if [ ! -e "$TARGET_PATH" ]; then
        echo "错误: 路径 '$TARGET_PATH' 不存在（裸文件名会在 $TEST_DIR 下查找）"
        exit 1
    fi
    process_path "$TARGET_PATH"
else
    # 没有指定路径，运行所有测试
    # 处理多文件编译测试（multifile 子目录）
    process_multifile_test "$TEST_DIR/multifile" "multifile" "multifile"
    
    # 处理多文件编译测试（cross_deps 子目录）
    process_multifile_test "$TEST_DIR/cross_deps" "cross_deps" "cross_deps"
    
    # 遍历所有单文件 .uya 文件（排除 multifile 和 cross_deps 目录）
    for uya_file in "$TEST_DIR"/*.uya; do
        if [ -f "$uya_file" ]; then
            process_single_test "$uya_file"
        fi
    done
fi

if [ "$ERRORS_ONLY" = false ] || [ $FAILED -gt 0 ]; then
    echo ""
    echo "================================"
    echo "总计: $((PASSED + FAILED)) 个测试"
    echo "通过: $PASSED"
    echo "失败: $FAILED"
    echo "================================"
fi

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi

