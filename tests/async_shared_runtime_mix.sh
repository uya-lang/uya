async_shared_runtime_parallel_suite_entries() {
    cat <<'EOF'
shared_runtime_gate|tests/test_async_runtime_shared_semantics.uya
http1_async_loopback|tests/test_http1_async_client.uya
dns_transport_shared_runtime|tests/test_async_runtime_shared_dns.uya
tls_async_io|tests/test_tls_async_runtime_io.uya
EOF
}

run_async_compute_resource_limit_check() {
    local compiler="$1"
    local build_dir="$2"
    local wave_label="${3:-wave}"
    local log="$build_dir/async_shared_runtime_mix/${wave_label}_async_compute_dynamic_growth.log"

    echo "==> mixed runtime ${wave_label}: tests/test_async_compute_dynamic_resource_pressure.uya"
    if ! "$compiler" test --c99 "$REPO_ROOT/tests/test_async_compute_dynamic_resource_pressure.uya" >"$log" 2>&1; then
        echo "mixed runtime suite failed: async_compute_dynamic_growth"
        tail -n 80 "$log"
        return 1
    fi
}

run_async_shared_runtime_wave() {
    local compiler="$1"
    local build_dir="$2"
    local wave_label="${3:-wave}"
    local suite_dir="$build_dir/async_shared_runtime_mix"
    local rel=""
    local label=""
    local log=""
    local pids=()
    local labels=()
    local logs=()
    local idx=0
    local status=0

    if [ -z "${REPO_ROOT:-}" ]; then
        echo "run_async_shared_runtime_wave requires REPO_ROOT"
        return 1
    fi

    mkdir -p "$suite_dir"

    while IFS='|' read -r label rel; do
        log="$suite_dir/${wave_label}_${label}.log"
        echo "==> mixed runtime ${wave_label}: $rel"
        "$compiler" test --c99 "$REPO_ROOT/$rel" >"$log" 2>&1 &
        pids+=("$!")
        labels+=("$label")
        logs+=("$log")
    done < <(async_shared_runtime_parallel_suite_entries)

    while [ "$idx" -lt "${#pids[@]}" ]; do
        if ! wait "${pids[$idx]}"; then
            echo "mixed runtime suite failed: ${labels[$idx]}"
            tail -n 80 "${logs[$idx]}"
            status=1
        fi
        idx=$((idx + 1))
    done

    if [ "$status" -ne 0 ]; then
        return 1
    fi

    run_async_compute_resource_limit_check "$compiler" "$build_dir" "$wave_label"
}

run_async_shared_runtime_smoke() {
    local compiler="$1"
    local build_dir="$2"
    local label="${3:-smoke}"

    run_async_shared_runtime_wave "$compiler" "$build_dir" "$label"
}

run_async_shared_runtime_stress() {
    local compiler="$1"
    local build_dir="$2"
    local rounds="$3"
    local prefix="${4:-stress}"
    local round=1

    while [ "$round" -le "$rounds" ]; do
        run_async_shared_runtime_wave "$compiler" "$build_dir" "${prefix}_${round}" || return 1
        round=$((round + 1))
    done
}
