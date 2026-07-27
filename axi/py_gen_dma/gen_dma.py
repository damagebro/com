from __future__ import annotations

import argparse
import json
import re
from pathlib import Path


DEFAULT_CFG = {
    "prefix": "cpu",
    "out_dir": "build",
    "rch_buf_depth": [0, 32, 0, 64, 128],
}


def check_name(name: str, label: str) -> str:
    if not re.fullmatch(r"[a-z][a-z0-9_]*", name):
        raise SystemExit(f"ERROR: {label} must match [a-z][a-z0-9_]*: {name}")
    return name


def word_replace(text: str, old: str, new: str) -> str:
    return re.sub(r"\b" + re.escape(old) + r"\b", new, text)


def load_cfg(path: Path) -> dict:
    if not path.exists():
        raise SystemExit(f"ERROR: cfg json not found: {path}")
    with path.open("r", encoding="utf-8") as f:
        cfg = json.load(f)
    if not isinstance(cfg, dict):
        raise SystemExit("ERROR: cfg json root must be an object")
    return cfg


def write_cfg_template(path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as f:
        json.dump(DEFAULT_CFG, f, indent=4)
        f.write("\n")
    print(f"generate cfg: {path}")


def cfg_path(value: str | None, cfg_dir: Path, default: Path) -> Path:
    if value is None:
        return default
    path = Path(value)
    if path.is_absolute():
        return path
    return cfg_dir / path


def check_rch_buf_depth(value: object) -> list[int] | None:
    if value is None:
        return None
    if not isinstance(value, list) or not value:
        raise SystemExit("ERROR: rch_buf_depth must be a non-empty integer list")
    depth_list = []
    for item in value:
        if not isinstance(item, int) or item < 0:
            raise SystemExit("ERROR: rch_buf_depth items must be non-negative integers")
        depth_list.append(item)
    return depth_list


def update_rch_buf_depth(text: str, depth_list: list[int] | None) -> str:
    if depth_list is None:
        return text
    value = "'{" + ", ".join(str(item) for item in depth_list) + "}"
    pattern = r"(parameter\s+int\s+RCH_BUF_DEPTH\s*\[0:RCH-1\]\s*=\s*)'\{[^}]*\}(\s*;)"
    text, num = re.subn(pattern, r"\1" + value + r"\2", text, count=1)
    if num != 1:
        raise SystemExit("ERROR: cannot update RCH_BUF_DEPTH in DMA template")
    return text


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate a subsystem/project DMA wrapper from com_axi_dma."
    )
    parser.add_argument(
        "-c",
        "--cfg",
        type=Path,
        default=None,
        help="generation config json",
    )
    parser.add_argument(
        "--gen-cfg",
        type=Path,
        default=None,
        help="write an example config json and exit",
    )
    parser.add_argument(
        "-p",
        "--prefix",
        default=None,
        help="subsystem/project prefix, for example cpu or npu0",
    )
    parser.add_argument(
        "-s",
        "--src",
        type=Path,
        default=None,
        help="source DMA template, default: ../com_axi_dma.sv",
    )
    parser.add_argument(
        "-o",
        "--out-dir",
        type=Path,
        default=None,
        help="output directory, default: ./build",
    )
    parser.add_argument(
        "--dma-module",
        default=None,
        help="generated DMA module name, default: <prefix>_axi_dma",
    )
    parser.add_argument(
        "--spram-shell",
        default=None,
        help="generated single-port SRAM shell name, default: <prefix>_spram_shell",
    )
    args = parser.parse_args()

    if args.gen_cfg:
        write_cfg_template(args.gen_cfg)
        return

    cfg = load_cfg(args.cfg) if args.cfg else {}
    cfg_dir = args.cfg.resolve().parent if args.cfg else Path.cwd()

    prefix_value = args.prefix or cfg.get("prefix")
    if prefix_value is None:
        raise SystemExit("ERROR: prefix is required, use -p/--prefix or cfg.prefix")

    prefix = check_name(prefix_value, "prefix")
    dma_module = check_name(args.dma_module or f"{prefix}_axi_dma", "dma module")
    spram_shell = check_name(args.spram_shell or f"{prefix}_spram_shell", "spram shell")
    rch_buf_depth = check_rch_buf_depth(cfg.get("rch_buf_depth"))

    default_src = Path(__file__).resolve().parents[1] / "com_axi_dma.sv"
    src = cfg_path(str(args.src) if args.src else cfg.get("src"), cfg_dir, default_src).resolve()
    if not src.exists():
        raise SystemExit(f"ERROR: source DMA template not found: {src}")

    text = src.read_text(encoding="utf-8")
    text = word_replace(text, "com_axi_dma", dma_module)
    text = word_replace(text, "com_spram_shell", spram_shell)
    text = update_rch_buf_depth(text, rch_buf_depth)

    out_dir = cfg_path(str(args.out_dir) if args.out_dir else cfg.get("out_dir"), cfg_dir, Path("build"))
    out_dir.mkdir(parents=True, exist_ok=True)
    out_file = out_dir / f"{dma_module}.sv"
    out_file.write_text(text, encoding="utf-8", newline="")

    print(f"generate: {out_file}")
    print(f"dma_module: {dma_module}")
    print(f"spram_shell: {spram_shell}")
    if rch_buf_depth is not None:
        print(f"rch_buf_depth: {rch_buf_depth}")
    print("NOTE: DMA read-buffer SRAM shell prefix must match mem_tool generated shell prefix.")


if __name__ == "__main__":
    main()
