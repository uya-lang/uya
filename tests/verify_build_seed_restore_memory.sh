#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
PROC_ROOT="${UYA_BENCH_PROC_ROOT:-/proc}"
BASELINE_RSS_KB="${UYA_BUILD_SEED_RSS_BASELINE_KB:-2103824}"
SAMPLE_INTERVAL="${UYA_BUILD_SEED_RSS_SAMPLE_INTERVAL:-0.05}"
TMP_DIR="$(mktemp -d /tmp/uya-build-seed-restore-memory.XXXXXX)"
trap 'rm -rf "$TMP_DIR"' EXIT

if [[ ! "$BASELINE_RSS_KB" =~ ^[0-9]+$ ]] || [[ "$BASELINE_RSS_KB" -le 0 ]]; then
    echo "错误: UYA_BUILD_SEED_RSS_BASELINE_KB 必须是正整数" >&2
    exit 1
fi
if [[ ! -d "$PROC_ROOT" || ! -r "$PROC_ROOT/self/status" ]]; then
    echo "错误: 缺少可读 $PROC_ROOT，无法采样 restore peak RSS" >&2
    exit 1
fi
if [[ ! -s "$ROOT_DIR/backup/cmd-build.c" ]]; then
    echo "错误: 缺少 backup/cmd-build.c" >&2
    exit 1
fi

rss_kb_for_pid() {
    local pid="$1"
    local status_file="$PROC_ROOT/$pid/status"
    if [[ ! -r "$status_file" ]]; then
        echo 0
        return
    fi
    awk '/^VmRSS:/ { print $2; found = 1; exit } END { if (!found) print 0 }' "$status_file"
}

children_of_pid() {
    local parent="$1"
    local status_file pid ppid
    for status_file in "$PROC_ROOT"/[0-9]*/status; do
        [[ -r "$status_file" ]] || continue
        pid="${status_file%/status}"
        pid="${pid##*/}"
        ppid="$(awk '/^PPid:/ { print $2; exit }' "$status_file")"
        if [[ "$ppid" == "$parent" ]]; then
            printf '%s\n' "$pid"
        fi
    done
}

sample_process_tree_rss_kb() {
    local root_pid="$1"
    local queue=("$root_pid")
    local seen=" $root_pid "
    local total=0
    local idx=0
    local pid child rss
    while [[ "$idx" -lt "${#queue[@]}" ]]; do
        pid="${queue[$idx]}"
        idx=$((idx + 1))
        rss="$(rss_kb_for_pid "$pid")"
        if [[ "$rss" =~ ^[0-9]+$ ]]; then
            total=$((total + rss))
        fi
        while IFS= read -r child; do
            [[ -n "$child" ]] || continue
            if [[ "$seen" != *" $child "* ]]; then
                seen="${seen}${child} "
                queue+=("$child")
            fi
        done < <(children_of_pid "$pid")
    done
    echo "$total"
}

rm -f "$ROOT_DIR/bin/cmd/build"
(
    make -C "$ROOT_DIR" restore-cmd-build-seed
) >"$TMP_DIR/restore.out" 2>"$TMP_DIR/restore.err" &
restore_pid=$!

peak_rss_kb=0
while kill -0 "$restore_pid" 2>/dev/null; do
    sample_rss="$(sample_process_tree_rss_kb "$restore_pid")"
    if [[ "$sample_rss" =~ ^[0-9]+$ && "$sample_rss" -gt "$peak_rss_kb" ]]; then
        peak_rss_kb="$sample_rss"
    fi
    sleep "$SAMPLE_INTERVAL"
done

set +e
wait "$restore_pid"
restore_status=$?
set -e

sample_rss="$(sample_process_tree_rss_kb "$restore_pid")"
if [[ "$sample_rss" =~ ^[0-9]+$ && "$sample_rss" -gt "$peak_rss_kb" ]]; then
    peak_rss_kb="$sample_rss"
fi

if [[ "$restore_status" -ne 0 ]]; then
    echo "错误: restore-cmd-build-seed 失败" >&2
    cat "$TMP_DIR/restore.out" >&2
    cat "$TMP_DIR/restore.err" >&2
    exit "$restore_status"
fi
if [[ ! -x "$ROOT_DIR/bin/cmd/build" ]]; then
    echo "错误: restore-cmd-build-seed 未生成 bin/cmd/build" >&2
    cat "$TMP_DIR/restore.out" >&2
    cat "$TMP_DIR/restore.err" >&2
    exit 1
fi

threshold_kb=$((BASELINE_RSS_KB / 2))
if [[ "$peak_rss_kb" -gt "$threshold_kb" ]]; then
    echo "错误: build seed restore peak RSS 未低于 Phase 0 baseline 50%: peak=${peak_rss_kb}KiB threshold=${threshold_kb}KiB baseline=${BASELINE_RSS_KB}KiB" >&2
    exit 1
fi

echo "verify_build_seed_restore_memory: ok (peak_rss_kb=$peak_rss_kb baseline_rss_kb=$BASELINE_RSS_KB threshold_kb=$threshold_kb)"
