from __future__ import annotations

import argparse
from dataclasses import dataclass
from pathlib import Path
import re
from typing import Sequence

from model import InputFormatError, parse_int, validate_identifier


MODES = ("init", "sim", "inst", "excel")
_SIM_TARGET_RE = re.compile(r"^[A-Za-z0-9_.-]+$")


@dataclass(frozen=True, slots=True)
class ToolConfig:
    mode: str
    subsys_prefix: str
    work_path: Path
    excel_filename: str | None
    default_wr_clk_mhz: int
    default_rd_clk_mhz: int
    top_module: str | None = None
    filelist: str | None = None
    sim_env: tuple[str, ...] = ()
    sim_target: str = "all"
    sim_no_run: bool = False

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
    parser.add_argument(
        "-t",
        "--top_module",
        help="top module instantiated by sim/tb/top.sv in sim mode",
    )
    parser.add_argument(
        "-f",
        "--filelist",
        help="project RTL filelist used by sim mode",
    )
    parser.add_argument(
        "-e",
        "--sim_env",
        action="append",
        default=[],
        metavar="NAME=VALUE",
        help="environment variable exported when running sim; can be repeated",
    )
    parser.add_argument(
        "--sim_target",
        default="all",
        help="make target used by sim mode",
    )
    parser.add_argument(
        "--sim_no_run",
        action="store_true",
        help="only generate build/sim sandbox without invoking make",
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
    top_module = str(args.top_module).strip() if args.top_module else None
    if top_module:
        try:
            validate_identifier(top_module, "top_module")
        except InputFormatError as exc:
            parser.error(str(exc))
    sim_env = tuple(str(item).strip() for item in args.sim_env)
    for item in sim_env:
        if "=" not in item or not item.split("=", 1)[0]:
            parser.error("sim_env must use NAME=VALUE format")
        name = item.split("=", 1)[0]
        try:
            validate_identifier(name, "sim_env name")
        except InputFormatError as exc:
            parser.error(str(exc))
    filelist = str(args.filelist).strip() if args.filelist else None
    if args.mode == "sim":
        if top_module is None:
            parser.error("sim mode requires --top_module")
        if filelist is None:
            parser.error("sim mode requires --filelist")
    sim_target = str(args.sim_target).strip()
    if not sim_target:
        parser.error("sim_target must not be empty")
    if not _SIM_TARGET_RE.fullmatch(sim_target):
        parser.error("sim_target contains unsupported characters")

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
        top_module=top_module,
        filelist=filelist,
        sim_env=sim_env,
        sim_target=sim_target,
        sim_no_run=args.sim_no_run,
    )
