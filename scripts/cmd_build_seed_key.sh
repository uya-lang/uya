#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="${1:-.}"

hash_stream() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum | awk '{ print $1 }'
        return
    fi
    shasum -a 256 | awk '{ print $1 }'
}

hash_file() {
    local file="$1"
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{ print $1 }'
        return
    fi
    shasum -a 256 "$file" | awk '{ print $1 }'
}

{
    printf 'cmd-build-seed-key-v1\n'
    printf 'HOST_OS=%s\n' "${HOST_OS:-}"
    printf 'HOST_ARCH=%s\n' "${HOST_ARCH:-}"
    if [[ -f "$ROOT_DIR/Makefile" ]]; then
        printf '%s  %s\n' "$(hash_file "$ROOT_DIR/Makefile")" "Makefile"
    fi
    for file in "$ROOT_DIR/scripts/cmd_build_seed_key.sh" "$ROOT_DIR/scripts/generate_cmd_build_blob_seed.sh"; do
        [[ -f "$file" ]] || continue
        rel="${file#"$ROOT_DIR"/}"
        printf '%s  %s\n' "$(hash_file "$file")" "$rel"
    done
    for dir in "$ROOT_DIR/src" "$ROOT_DIR/lib"; do
        [[ -d "$dir" ]] || continue
        find "$dir" -type f -name '*.uya' -print
    done | LC_ALL=C sort | while IFS= read -r file; do
        rel="${file#"$ROOT_DIR"/}"
        case "$rel" in
            src/build/*|src/.uyacache/*)
                continue
                ;;
        esac
        printf '%s  %s\n' "$(hash_file "$file")" "$rel"
    done
} | hash_stream
