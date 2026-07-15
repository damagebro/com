from __future__ import annotations

from pathlib import Path
import os
import sys


SYNC_FILES = (
    ("dw/com_ecc_secded.sv", "impl_template/dw/com_ecc_secded.sv"),
    (
        "model/com_tpram_reg.sv",
        "impl_template/memory/rtl/model/com_tpram_reg.sv",
    ),
)


def find_com_root(start: Path) -> Path | None:
    env_root = os.environ.get("COM_ROOT")
    if env_root:
        root = Path(env_root).expanduser().resolve()
        if (root / "com_define.sv").is_file():
            return root
        print(f"WARNING: COM_ROOT is set but invalid: {root}", file=sys.stderr)
        return None

    for path in (start, *start.parents):
        if (path / "com" / "com_define.sv").is_file():
            return path / "com"
    return None


def main() -> int:
    rtl_dir = Path(__file__).resolve().parent
    com_root = find_com_root(rtl_dir)
    if com_root is None:
        print("COM_ROOT not found, skip sim RTL sync check")
        return 0

    errors = 0
    for local_rel, source_rel in SYNC_FILES:
        local_path = rtl_dir / local_rel
        source_path = com_root / source_rel
        if not local_path.is_file():
            print(f"ERROR: local file missing: {local_path}", file=sys.stderr)
            errors += 1
            continue
        if not source_path.is_file():
            print(f"ERROR: source file missing: {source_path}", file=sys.stderr)
            errors += 1
            continue
        local_text = local_path.read_text(encoding="utf-8")
        source_text = source_path.read_text(encoding="utf-8")
        if local_text != source_text:
            print(
                f"ERROR: sim RTL template is out of sync: {local_rel}",
                file=sys.stderr,
            )
            print(f"       source: {source_path}", file=sys.stderr)
            errors += 1

    if errors:
        return 1
    print(f"sim RTL template is synchronized with {com_root}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
