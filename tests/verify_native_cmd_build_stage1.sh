#!/usr/bin/env bash

# Phase 10 stage1：统一验证 build-only --native 的真实成功子集，
# 并固定 native cmd/build 尚未自举时不能静默回落 C99。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

bash "$SCRIPT_DIR/verify_native_build_minimal_program.sh"
bash "$SCRIPT_DIR/verify_native_cmd_build_compiler_regressions.sh"
bash "$SCRIPT_DIR/verify_native_cmd_build_c99_output_parity.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_first_slice_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_first_arg_contract.sh"
bash "$SCRIPT_DIR/verify_native_parse_build_args_option_loop_contract.sh"
bash "$SCRIPT_DIR/verify_native_cmd_build_regression_boundary.sh"
bash "$SCRIPT_DIR/verify_native_cmd_build_no_silent_c99.sh"

echo "verify_native_cmd_build_stage1: ok"
