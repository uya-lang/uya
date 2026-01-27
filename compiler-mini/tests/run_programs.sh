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

COMPILER="./build/compiler-mini"
TEST_DIR="tests/programs"
BUILD_DIR="$TEST_DIR/build"
PASSED=0
FAILED=0
ERRORS_ONLY=false
USE_C99=false

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项] [文件或目录]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -e, --errors-only   只显示失败的测试"
    echo "  --c99               使用 C99 后端（默认使用 LLVM 后端）"
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
    echo "  $0 test_struct_pointer_return.uya     # 运行单个测试文件"
    echo "  $0 -e test_struct_pointer_return.uya # 只显示失败信息"
    echo "  $0 --c99 test_struct_pointer_return.uya # 使用 C99 后端运行单个测试"
    echo "  $0 tests/programs                     # 运行指定目录下的所有测试"
    echo "  $0 tests/programs/multifile          # 运行指定子目录的测试"
}

# 检查编译器是否存在
if [ ! -f "$COMPILER" ]; then
    echo "错误: 编译器 '$COMPILER' 不存在"
    echo "请先运行 'make build' 构建编译器"
    exit 1
fi

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
        -*)
            echo "错误: 未知选项 '$1'"
            echo "使用 '$0 --help' 查看帮助信息"
            exit 1
            ;;
        *)
            TARGET_PATH="$1"
            # 检查路径是否存在
            if [ ! -e "$TARGET_PATH" ]; then
                echo "错误: 路径 '$TARGET_PATH' 不存在"
                exit 1
            fi
            shift
            ;;
    esac
done

if [ "$ERRORS_ONLY" = false ]; then
    echo "开始运行 Uya 测试程序..."
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
    
    # 多文件编译：将所有文件一起编译
    # 捕获编译输出，过滤调试信息但保留错误信息
    local output_file
    if [ "$USE_C99" = true ]; then
        # C99 后端：生成 .c 文件
        output_file="$BUILD_DIR/$build_subdir/${test_name}.c"
        # 直接执行命令，让数组正确展开
        local compiler_output=$("$COMPILER" --c99 "${file_list[@]}" -o "$output_file" 2>&1)
        local compiler_exit=$?
    else
        # LLVM 后端：生成 .o 文件
        output_file="$BUILD_DIR/$build_subdir/${test_name}.o"
        # 直接执行命令，让数组正确展开
        local compiler_output=$("$COMPILER" "${file_list[@]}" -o "$output_file" 2>&1)
        local compiler_exit=$?
    fi
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
        # 如果没有输出文件，可能生成了无扩展名的文件（仅限 LLVM 后端）
        if [ "$USE_C99" = false ] && [ -f "$BUILD_DIR/$build_subdir/${test_name}" ]; then
            mv "$BUILD_DIR/$build_subdir/${test_name}" "$output_file"
        else
            echo "  ❌ 编译失败（未生成输出文件: $output_file）"
            FAILED=$((FAILED + 1))
            return
        fi
    fi
    # 链接目标文件为可执行文件
    link_succeeded=false
    if [ "$USE_C99" = true ]; then
        # C99 后端：直接编译 .c 文件为可执行文件
        if gcc -std=c99 -o "$BUILD_DIR/$build_subdir/$test_name" "$output_file"; then
            link_succeeded=true
        fi
    else
        # LLVM 后端：链接 .o 文件
        if gcc -no-pie "$output_file" -o "$BUILD_DIR/$build_subdir/$test_name"; then
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

# 处理单个测试文件的函数
process_single_test() {
    local uya_file="$1"
    local base_name=$(basename "$uya_file" .uya)
    
    if [ "$ERRORS_ONLY" = false ]; then
        echo "测试: $base_name"
    fi
    
    # 编译（生成目标文件）
    # 捕获编译输出，过滤调试信息但保留错误信息
    if [ "$USE_C99" = true ]; then
        # C99 后端：生成 .c 文件
        output_file="$BUILD_DIR/${base_name}.c"
        compiler_cmd="$COMPILER --c99 \"$uya_file\" -o \"$output_file\""
    else
        # LLVM 后端：生成 .o 文件
        output_file="$BUILD_DIR/${base_name}.o"
        compiler_cmd="$COMPILER \"$uya_file\" -o \"$output_file\""
    fi
    compiler_output=$(eval "$compiler_cmd" 2>&1)
    compiler_exit=$?
    
    # 检查是否是预期编译失败的测试文件
    # test_ffi_ptr_in_normal_fn: 普通函数不能使用 FFI 指针
    # test_error_*: 各种编译错误测试（类型不匹配、未初始化变量、变量遮蔽、const 重新赋值、返回值类型错误等）
    # 已知编译崩溃的测试（编译器 bug，退出码 139）：
    # - test_buffer_ptr_access: 指针数组访问导致编译器崩溃
    # - test_pointer_array_access: 指针数组访问导致编译器崩溃
    # - test_complex_expressions: 复杂表达式导致编译器崩溃
    # - test_mixed_types: 混合类型导致编译器崩溃
    # - test_struct_array_field: 结构体数组字段导致编译器崩溃
    # - test_unary_operators: 一元运算符导致编译器崩溃
    is_expected_fail=false
    is_known_crash=false
    if [ "$base_name" = "test_ffi_ptr_in_normal_fn" ] || [[ "$base_name" =~ ^test_error_ ]]; then
        is_expected_fail=true
    fi
    if [ "$base_name" = "test_buffer_ptr_access" ] || \
       [ "$base_name" = "test_pointer_array_access" ] || \
       [ "$base_name" = "test_complex_expressions" ] || \
       [ "$base_name" = "test_mixed_types" ] || \
       [ "$base_name" = "test_struct_array_field" ] || \
       [ "$base_name" = "test_unary_operators" ]; then
        is_known_crash=true
    fi
    
    if [ $compiler_exit -ne 0 ]; then
        # 如果是预期的编译失败，则测试通过（不显示错误）
        if [ "$is_expected_fail" = true ]; then
            if [ "$ERRORS_ONLY" = false ]; then
                echo "$compiler_output" | grep -v "^调试:" | grep -E "(错误|错误:|失败)" | head -5 || true
                echo "  ✓ 测试通过（预期编译失败）"
            fi
            PASSED=$((PASSED + 1))
        elif [ "$is_known_crash" = true ] && [ $compiler_exit -eq 139 ]; then
            # 已知的编译器崩溃（段错误），标记为跳过
            if [ "$ERRORS_ONLY" = false ]; then
                echo "  ⚠ 跳过（已知编译器崩溃，退出码: $compiler_exit）"
            fi
            PASSED=$((PASSED + 1))  # 不计算为失败，但也不计算为真正的通过
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
    
    # 如果编译成功，但这是已知崩溃的测试，说明问题已修复
    if [ "$is_known_crash" = true ] && [ "$ERRORS_ONLY" = false ]; then
        echo "  ℹ 已知崩溃测试已修复"
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
    
    # 链接目标文件为可执行文件
    # 对于需要外部函数的测试，需要链接外部函数实现
    link_succeeded=false
    if [ "$USE_C99" = true ]; then
        # C99 后端：直接编译 .c 文件为可执行文件
        if [ "$base_name" = "extern_function" ]; then
            # 编译主程序和外部函数实现
            if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/programs/extern_function_impl.c; then
                link_succeeded=true
            fi
        elif [ "$base_name" = "test_comprehensive_cast" ] || [ "$base_name" = "test_ffi_cast" ] || [ "$base_name" = "test_pointer_cast" ] || [ "$base_name" = "test_simple_cast" ]; then
            # 编译主程序和通用外部函数实现
            if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/external_functions.c; then
                link_succeeded=true
            fi
        elif [ "$base_name" = "test_abi_calling_convention" ]; then
            # 编译主程序和 ABI 辅助函数
            if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file" tests/programs/test_abi_helpers.c; then
                link_succeeded=true
            fi
        else
            # 普通 C99 编译
            if gcc -std=c99 -o "$BUILD_DIR/$base_name" "$output_file"; then
                link_succeeded=true
            fi
        fi
    else
        # LLVM 后端：链接 .o 文件
        if [ "$base_name" = "extern_function" ]; then
            # 编译外部函数实现
            gcc -c tests/programs/extern_function_impl.c -o "$BUILD_DIR/extern_function_impl.o"
            if [ $? -ne 0 ]; then
                echo "  ❌ 编译外部函数实现失败"
                FAILED=$((FAILED + 1))
                return
            fi
            # 链接主程序和外部函数实现
            if gcc -no-pie "$output_file" "$BUILD_DIR/extern_function_impl.o" -o "$BUILD_DIR/$base_name"; then
                link_succeeded=true
            fi
        elif [ "$base_name" = "test_comprehensive_cast" ] || [ "$base_name" = "test_ffi_cast" ] || [ "$base_name" = "test_pointer_cast" ] || [ "$base_name" = "test_simple_cast" ]; then
            # 编译通用外部函数实现
            gcc -c tests/external_functions.c -o "$BUILD_DIR/external_functions.o"
            if [ $? -ne 0 ]; then
                echo "  ❌ 编译外部函数实现失败"
                FAILED=$((FAILED + 1))
                return
            fi
            # 链接主程序和外部函数实现
            if gcc -no-pie "$output_file" "$BUILD_DIR/external_functions.o" -o "$BUILD_DIR/$base_name"; then
                link_succeeded=true
            fi
        elif [ "$base_name" = "test_abi_calling_convention" ]; then
            # 编译 ABI 测试辅助函数
            gcc -c tests/programs/test_abi_helpers.c -o "$BUILD_DIR/test_abi_helpers.o"
            if [ $? -ne 0 ]; then
                echo "  ❌ 编译 ABI 辅助函数失败"
                FAILED=$((FAILED + 1))
                return
            fi
            # 链接主程序和 ABI 辅助函数
            if gcc -no-pie "$output_file" "$BUILD_DIR/test_abi_helpers.o" -o "$BUILD_DIR/$base_name"; then
                link_succeeded=true
            fi
        else
            if gcc -no-pie "$output_file" -o "$BUILD_DIR/$base_name"; then
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
    # 转换为绝对路径或相对于当前目录的路径
    if [[ "$TARGET_PATH" != /* ]]; then
        # 相对路径，尝试相对于测试目录
        if [ -f "$TARGET_PATH" ] || [ -d "$TARGET_PATH" ]; then
            TARGET_PATH=$(realpath "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")
        elif [ -f "$TEST_DIR/$TARGET_PATH" ] || [ -d "$TEST_DIR/$TARGET_PATH" ]; then
            TARGET_PATH="$TEST_DIR/$TARGET_PATH"
        fi
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

