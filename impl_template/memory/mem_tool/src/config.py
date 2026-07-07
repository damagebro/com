from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
from typing import Sequence

from model import InputFormatError, parse_int, validate_identifier


MODES = ("init", "inst", "excel", "rpt_by_run_sim")


@dataclass(frozen=True, slots=True)
class ToolConfig:
    mode: str
    subsys_prefix: str
    work_path: Path
    excel_filename: str | None
    default_wr_clk_mhz: int
    default_rd_clk_mhz: int

    @property
    def excel_path(self) -> Path | None:
        if not self.excel_filename:
            return None
        return self.work_path / self.excel_filename


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate memory shells, reports and integration RTL."
    )
    parser.add_argument(
        "-p",
        "--subsys_prefix",
        dest="subsys_prefix",
        required=True,
        help="subsystem prefix, such as cpu, npu or pcie",
    )
    parser.add_argument("-m", "--mode", choices=MODES, default="init")
    parser.add_argument("-w", "--work_path", type=Path, default=Path("./"))
    parser.add_argument(
        "-x",
        "--excel_name",
        help="memory requirement workbook filename",
    )
    parser.add_argument(
        "-xcka",
        "--clk_a",
        type=int,
        default=1500,
        help=(
            "clock A in MHz: all single-clock memory accesses and "
            "tpram2ck writes"
        ),
    )
    parser.add_argument(
        "-xckb",
        "--clk_b",
        type=int,
        help="clock B in MHz: tpram2ck reads only",
    )
    return parser


def parse_config(argv: Sequence[str] | None = None) -> ToolConfig:
    parser = build_argument_parser()
    args = parser.parse_args(argv)
    try:
        validate_identifier(args.subsys_prefix, "subsys_prefix")
    except InputFormatError as exc:
        parser.error(str(exc))

    work_path = args.work_path.expanduser().resolve()
    excel_filename = (
        str(args.excel_name).strip() if args.excel_name is not None else None
    )
    if excel_filename:
        if Path(excel_filename).name != excel_filename:
            parser.error("excel_name must be a filename, not a directory path")
    if args.mode == "excel" and not excel_filename:
        parser.error("excel mode requires --excel_name")

    try:
        wr_clock = parse_int(args.clk_a, "clk_a", 1)
        rd_clock = parse_int(
            args.clk_b if args.clk_b is not None else wr_clock,
            "clk_b",
            1,
        )
    except InputFormatError as exc:
        parser.error(str(exc))

    return ToolConfig(
        mode=args.mode,
        subsys_prefix=args.subsys_prefix,
        work_path=work_path,
        excel_filename=excel_filename,
        default_wr_clk_mhz=wr_clock,
        default_rd_clk_mhz=rd_clock,
    )
