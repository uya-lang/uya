#!/usr/bin/env python3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def require_absent(path: str, needle: str) -> None:
    text = (ROOT / path).read_text(encoding="utf-8")
    if needle in text:
        raise SystemExit(f"{path}: fixed async compiler limit remains: {needle}")


def main() -> None:
    require_absent("src/codegen/c99/async_transform.uya", "MAX_SEGMENTS")
    require_absent("src/codegen/c99/async_transform.uya", "MAX_LOCALS")
    require_absent("src/checker/async_frame_meta.uya", "MAX_ASYNC_FRAME_METAS")
    require_absent("src/checker/types.uya", "async_frame_metas: [AsyncFrameMeta:")
    require_absent("src/codegen/c99/main.uya", "if count > MAX_ASYNC_FRAME_METAS")
    require_absent("src/codegen/c99/main.uya", "entries[1024]")
    require_absent("lib/std/async_frame.uya", "entries: [AsyncFrameDescriptor: 1024]")


if __name__ == "__main__":
    main()
