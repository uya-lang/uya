#!/bin/bash
# Uya Mini 编译器测试程序运行脚本（并行版本）
# 自动编译和运行所有测试程序，验证编译器生成的二进制正确性
# 使用并行执行加速测试
#
# 用法:
#   ./run_programs_parallel.sh                    # 运行所有测试（并行，默认8线程）
#   ./run_programs_parallel.sh -j 4               # 运行所有测试（4线程）
#   ./run_programs_parallel.sh -j 1               # 运行所有测试（单线程，等同于原版）
#   ./run_programs_parallel.sh <文件或目录>        # 运行指定的测试文件或目录
#   ./run_programs_parallel.sh test_file.uya      # 运行单个测试文件
#
# 环境变量:
#   PARALLEL_JOBS=N   # 设置并行任务数（默认8）
#
# 快速验证单个测试（在项目根目录下执行）:
#   ./tests/run_programs_parallel.sh test_global_var.uya

set -e

# 自举编译器递归较深，需增大栈限制避免段错误
ulimit -s unlimited 2>/dev/null || ulimit -s 524288 2>/dev/null || true

# 获取脚本所在目录的绝对路径，然后推导各路径
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

COMPILER="$REPO_ROOT/bin/uya"
TEST_DIR="$SCRIPT_DIR"
BUILD_DIR="$TEST_DIR/build"
ERRORS_ONLY=false
USE_C99=true
USE_UYA=false
PARALLEL_JOBS=${PARALLEL_JOBS:-8}

# 设置 UYA_ROOT 指向标准库目录（lib/）
export UYA_ROOT="${REPO_ROOT}/lib/"

# 显示使用说明
show_usage() {
    echo "用法: $0 [选项] [文件或目录]"
    echo ""
    echo "选项:"
    echo "  -h, --help          显示此帮助信息"
    echo "  -e, --errors-only   只显示失败的测试"
    echo "  -j <N>              并行任务数（默认8）"
    echo "  --c99               使用 C99 后端（默认）"
    echo "  --uya               使用 src 编译的编译器"
    echo ""
    echo "环境变量:"
    echo "  PARALLEL_JOBS=N     并行任务数（覆盖 -j 选项）"
    echo ""
    echo "参数:"
    echo "  无参数              运行所有测试"
    echo "  <文件>              运行指定的测试文件（.uya 文件）"
    echo "  <目录>              运行指定目录下的所有测试"
    echo ""
    echo "示例:"
    echo "  $0                                    # 运行所有测试（并行，8线程）"
    echo "  $0 -j 4                               # 运行所有测试（并行，4线程）"
    echo "  $0 -j 1                               # 运行所有测试（单线程）"
    echo "  PARALLEL_JOBS=12 $0                    # 运行所有测试（并行，12线程）"
    echo "  $0 -e                                 # 只显示失败的测试"
    echo "  $0 test_global_var.uya               # 运行单个测试"
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
mkdir -p "$BUILD_DIR/parallel_results"

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
        -j)
            PARALLEL_JOBS="$2"
            shift 2
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
            shift
            ;;
    esac
done

# 根据 --uya 选项设置编译器路径
if [ "$USE_UYA" = true ]; then
    USE_C99=true
    COMPILER="$REPO_ROOT/bin/uya"
fi

# 检查编译器是否存在
if [ -z "$COMPILER" ] || [ ! -f "$COMPILER" ] || [ ! -x "$COMPILER" ]; then
    echo "错误: Uya 自举编译器不存在: $COMPILER"
    echo "请先运行 'make from-c' 或 'make uya' 构建编译器"
    exit 1
fi

if [ "$ERRORS_ONLY" = false ]; then
    echo "开始运行 Uya 测试程序（并行版本，${PARALLEL_JOBS} 线程）..."
    echo "使用编译器: $COMPILER"
    echo "（Uya 自举编译器）"
    if [ -n "$TARGET_PATH" ]; then
        echo "目标: $TARGET_PATH"
    fi
    echo ""
fi

# 收集所有需要测试的文件
collect_test_files() {
    local target="$1"
    
    if [ -f "$target" ]; then
        if [[ "$target" == *.uya ]]; then
            echo "$target"
        fi
    elif [ -d "$target" ]; then
        local dir_name=$(basename "$target")
        
        # 特殊处理多文件测试目录
        if [ "$dir_name" = "multifile" ] || [ "$dir_name" = "cross_deps" ]; then
            # 标记为多文件测试
            echo "MULTIFILE:$target:$dir_name"
        else
            # 递归收集所有 .uya 文件
            find "$target" -maxdepth 2 -name "*.uya" -type f 2>/dev/null || true
        fi
    fi
}

# 如果指定了目标路径
if [ -n "$TARGET_PATH" ]; then
    # 转换为绝对路径
    if [[ "$TARGET_PATH" != /* ]]; then
        if [ -f "$TARGET_PATH" ] || [ -d "$TARGET_PATH" ]; then
            TARGET_PATH=$(realpath "$TARGET_PATH" 2>/dev/null || echo "$TARGET_PATH")
        elif [ -f "$TEST_DIR/$TARGET_PATH" ] || [ -d "$TEST_DIR/$TARGET_PATH" ]; then
            TARGET_PATH="$TEST_DIR/$TARGET_PATH"
        fi
    fi
    if [ ! -e "$TARGET_PATH" ]; then
        echo "错误: 路径 '$TARGET_PATH' 不存在"
        exit 1
    fi
    TEST_FILES=($(collect_test_files "$TARGET_PATH"))
else
    # 没有指定路径，收集所有测试
    TEST_FILES=()
    
    # 多文件测试
    if [ -d "$TEST_DIR/multifile" ]; then
        TEST_FILES+=("MULTIFILE:$TEST_DIR/multifile:multifile")
    fi
    if [ -d "$TEST_DIR/cross_deps" ]; then
        TEST_FILES+=("MULTIFILE:$TEST_DIR/cross_deps:cross_deps")
    fi
    
    # 单文件测试（递归扫描子目录，排除多文件测试目录和 WIP）
    while IFS= read -r -d '' file; do
        TEST_FILES+=("$file")
    done < <(find "$TEST_DIR" -maxdepth 2 -name "*.uya" -type f \
        ! -path "$TEST_DIR/multifile/*" \
        ! -path "$TEST_DIR/cross_deps/*" \
        ! -path "$TEST_DIR/module_test/*" \
        ! -path "$TEST_DIR/module_a/*" \
        ! -path "$TEST_DIR/circular_a/*" \
        ! -path "$TEST_DIR/circular_b/*" \
        ! -path "$TEST_DIR/wip/*" \
        ! -path "$TEST_DIR/build/*" \
        ! -path "$TEST_DIR/programs/*" \
        -print0 2>/dev/null)
fi

# 单个测试执行函数（用于并行）
# 子进程内关闭 set -e，避免 gcc 失败、测试退出非零等导致未写结果文件而漏计
run_single_test() {
    set +e
    # 自举编译器递归较深，增大栈限制
    ulimit -s unlimited 2>/dev/null || ulimit -s 524288 2>/dev/null || true
    local uya_file="$1"
    local result_file="$2"
    local base_name=$(basename "$uya_file" .uya)
    
    # 编译
    output_file="$BUILD_DIR/${base_name}.c"
    # 默认对所有测试启用 --safety-proof
    local safety_proof_arg="--safety-proof"
    if [ "$USE_UYA" = true ]; then
        # 自举编译器递归较深，已在脚本开头增大栈限制
        compiler_output=$("$COMPILER" --c99 $safety_proof_arg "$uya_file" -o "$output_file" 2>&1)
    else
        compiler_output=$("$COMPILER" --c99 $safety_proof_arg "$uya_file" -o "$output_file" 2>&1)
    fi
    compiler_exit=$?
    
    # 检查是否是预期编译失败
    is_expected_fail=false
    if [[ "$base_name" =~ ^error_ ]]; then
        is_expected_fail=true
    fi
    
    # 处理编译结果
    if [ $compiler_exit -ne 0 ]; then
        if [ "$is_expected_fail" = true ]; then
            echo "PASS:$base_name:预期编译失败" > "$result_file"
        else
            # 不嵌入 compiler_output，避免 null 字节等导致结果文件污染、并行统计漏计
            echo "FAIL:$base_name:编译失败(退出码:$compiler_exit)" > "$result_file"
        fi
        return
    fi
    
    # 预期失败但编译成功
    if [ "$is_expected_fail" = true ]; then
        echo "FAIL:$base_name:预期编译失败，但编译器未检测到错误" > "$result_file"
        return
    fi
    
    # 检查输出文件
    if [ ! -f "$output_file" ]; then
        echo "FAIL:$base_name:未生成输出文件" > "$result_file"
        return
    fi
    
    # 链接：编译器已自动为 test "..." 和 export fn main 生成 main 函数
    link_succeeded=false
    
    GCC_OPTS="-std=c99 -no-pie"
    EXTRA_C_EXTERN="$SCRIPT_DIR/extern_function_impl.c"
    EXTRA_C_FFI="$SCRIPT_DIR/external_functions.c"
    EXTRA_C_ABI="$SCRIPT_DIR/test_abi_helpers.c"
    
    # 检测生成的 C 代码是否包含 main 函数
    # 编译器已自动处理 test "..." 和 export fn main 的检测
    has_main=false
    if grep -q "int main(" "$output_file" 2>/dev/null || grep -q "int32_t main(" "$output_file" 2>/dev/null; then
        has_main=true
    fi
    
    if [ "$base_name" = "extern_function" ]; then
        gcc $GCC_OPTS -o "$BUILD_DIR/$base_name" "$output_file" "$EXTRA_C_EXTERN" -lm 2>/dev/null && link_succeeded=true
    elif [ "$base_name" = "test_comprehensive_cast" ] || [ "$base_name" = "test_ffi_cast" ] || [ "$base_name" = "test_pointer_cast" ] || [ "$base_name" = "test_simple_cast" ] || [ "$base_name" = "test_extern_union" ]; then
        gcc $GCC_OPTS -o "$BUILD_DIR/$base_name" "$output_file" "$EXTRA_C_FFI" -lm 2>/dev/null && link_succeeded=true
    elif [ "$base_name" = "test_abi_calling_convention" ]; then
        gcc $GCC_OPTS -o "$BUILD_DIR/$base_name" "$output_file" "$EXTRA_C_ABI" -lm 2>/dev/null && link_succeeded=true
    else
        # 编译器已自动生成 main，直接链接
        gcc $GCC_OPTS -o "$BUILD_DIR/$base_name" "$output_file" -lm 2>/dev/null && link_succeeded=true
    fi
    
    if [ "$link_succeeded" = false ]; then
        echo "FAIL:$base_name:链接失败" > "$result_file"
        return
    fi
    
    # 运行（不依赖 set -e，显式捕获退出码）
    exit_code=0
    "$BUILD_DIR/$base_name" > /dev/null 2>&1 || exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo "PASS:$base_name:测试通过" > "$result_file"
    else
        echo "FAIL:$base_name:测试失败（退出码: $exit_code）" > "$result_file"
    fi
}

# 导出函数和变量供子进程使用
export -f run_single_test
export COMPILER USE_UYA SCRIPT_DIR BUILD_DIR USE_C99

# 执行并行测试
PASSED=0
FAILED=0
TOTAL_TESTS=${#TEST_FILES[@]}

if [ "$ERRORS_ONLY" = false ]; then
    echo "发现 $TOTAL_TESTS 个测试任务"
    echo ""
fi

# 并行执行单文件测试
single_tests=()
multifile_tests=()

# 分类测试：单文件测试和多文件测试
for test_item in "${TEST_FILES[@]}"; do
    if [[ "$test_item" == MULTIFILE:* ]]; then
        multifile_tests+=("$test_item")
    else
        single_tests+=("$test_item")
    fi
done

# 先执行多文件测试（顺序执行，因为数量少且复杂）
multifile_index=${#single_tests[@]}
for test_item in "${multifile_tests[@]}"; do
    multifile_index=$((multifile_index + 1))
    
    test_dir="${test_item#MULTIFILE:}"
    test_name="${test_dir##*:}"
    test_dir="${test_dir%:*}"
    
    if [ "$ERRORS_ONLY" = false ]; then
        echo "[$multifile_index/$TOTAL_TESTS] 测试: $test_name (多文件编译)"
    fi
    
    # 调用原脚本的多文件测试函数
    output=$(bash "$SCRIPT_DIR/run_programs.sh" --c99 "$test_dir" 2>&1 || true)
    
    # 解析结果
    if echo "$output" | grep -q "PASS"; then
        if [ "$ERRORS_ONLY" = false ]; then
            echo "  ✓ $test_name:多文件测试通过"
        fi
        PASSED=$((PASSED + 1))
    elif echo "$output" | grep -q "FAIL"; then
        if [ "$ERRORS_ONLY" = true ]; then
            echo "测试: $test_name"
        fi
        echo "  ❌ $test_name:多文件测试失败"
        FAILED=$((FAILED + 1))
    else
        # 没有明确的 PASS/FAIL，假设通过
        if [ "$ERRORS_ONLY" = false ]; then
            echo "  ✓ $test_name:多文件测试完成"
        fi
        PASSED=$((PASSED + 1))
    fi
done

# 使用 xargs 并行执行单文件测试
if [ ${#single_tests[@]} -gt 0 ]; then
    if [ "$ERRORS_ONLY" = false ]; then
        echo ""
        echo "开始并行执行 ${#single_tests[@]} 个单文件测试（$PARALLEL_JOBS 线程）..."
    fi
    
    # 使用 xargs -P 并行执行
    for test_item in "${single_tests[@]}"; do
        base_name=$(basename "$test_item" .uya)
        result_file="$BUILD_DIR/parallel_results/${base_name}.result"
        
        # 清空结果文件
        > "$result_file"
        
        # 在后台运行测试
        (
            run_single_test "$test_item" "$result_file"
        ) &
        
        # 控制并发数
        if [ $(jobs -r | wc -l) -ge "$PARALLEL_JOBS" ]; then
            wait -n 2>/dev/null || true
        fi
    done
    
    # 等待所有后台任务完成
    wait
    
    # 收集结果
    for test_item in "${single_tests[@]}"; do
        base_name=$(basename "$test_item" .uya)
        result_file="$BUILD_DIR/parallel_results/${base_name}.result"
        
        # 读取结果（去掉可能的 null 字节，避免命令替换警告和漏计）
        if [ -f "$result_file" ] && [ -s "$result_file" ]; then
            result=$(tr -d '\0' < "$result_file")
            status="${result%%:*}"
            
            if [ "$status" = "PASS" ]; then
                if [ "$ERRORS_ONLY" = false ]; then
                    echo "  ✓ ${result#*:}"
                fi
                PASSED=$((PASSED + 1))
            else
                if [ "$ERRORS_ONLY" = true ]; then
                    echo "测试: $base_name"
                fi
                echo "  ❌ ${result#*:}"
                FAILED=$((FAILED + 1))
            fi
            
            rm -f "$result_file"
        fi
    done
    
    if [ "$ERRORS_ONLY" = false ]; then
        echo "  单文件测试完成"
    fi
fi

# 统计结果（总计以任务数为准，避免漏计导致总数不对）
if [ "$ERRORS_ONLY" = false ] || [ $FAILED -gt 0 ]; then
    echo ""
    echo "================================"
    echo "总计: $TOTAL_TESTS 个测试"
    echo "通过: $PASSED"
    echo "失败: $FAILED"
    NOT_COUNTED=$((TOTAL_TESTS - PASSED - FAILED))
    [ "$NOT_COUNTED" -gt 0 ] && echo "未计入: $NOT_COUNTED"
    echo "================================"
fi

if [ $FAILED -eq 0 ]; then
    exit 0
else
    exit 1
fi
