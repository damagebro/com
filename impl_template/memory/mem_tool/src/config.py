from __future__ import annotations

import argparse
from dataclasses import dataclass
import json
from pathlib import Path
from typing import Any, Sequence

from model import ConfigError, InputFormatError, parse_int, validate_identifier


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


def _read_json(path: Path | None) -> dict[str, Any]:
    if path is None:
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError as exc:
        raise ConfigError(f"cannot read config file {path}: {exc}") from exc
    except json.JSONDecodeError as exc:
        raise ConfigError(
            f"{path}:{exc.lineno}:{exc.colno}: invalid JSON: {exc.msg}"
        ) from exc
    if not isinstance(value, dict):
        raise ConfigError(f"{path}: top-level JSON value must be an object")
    return value


def _mode_from_json(raw: dict[str, Any]) -> str | None:
    direct_mode = raw.get("mode")
    if direct_mode is not None:
        if direct_mode not in MODES:
            raise ConfigError(
                f"config mode must be one of {MODES}, got {direct_mode!r}"
            )
        return direct_mode

    common = raw.get("common_opt", {})
    if not isinstance(common, dict):
        raise ConfigError("common_opt must be a JSON object")
    flags = {
        "init": common.get("gen_sram_shell", 0),
        "rpt_by_run_sim": common.get("gen_sram_list", 0),
        "excel": common.get("gen_sram_excel", 0),
        "inst": common.get("gen_sram_instance", 0),
    }
    enabled = []
    for mode, flag in flags.items():
        if flag not in (0, 1, False, True):
            raise ConfigError(
                f"legacy mode flag for {mode} must be 0 or 1, got {flag!r}"
            )
        if bool(flag):
            enabled.append(mode)
    if len(enabled) > 1:
        raise ConfigError(
            f"config enables multiple modes: {', '.join(enabled)}"
        )
    return enabled[0] if enabled else None


def _json_value(raw: dict[str, Any], *path: str, default: Any = None) -> Any:
    value: Any = raw
    for key in path:
        if not isinstance(value, dict) or key not in value:
            return default
        value = value[key]
    return value


def build_argument_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Generate memory shells, reports and integration RTL."
    )
    parser.add_argument(
        "-c",
        "--config",
        type=Path,
        help="JSON config file; explicit CLI options override config values",
    )
    parser.add_argument(
        "-p",
        "--subsys_prefix",
        "--subsys_preifx",
        dest="subsys_prefix",
        help="subsystem prefix, such as cpu, npu or pcie",
    )
    parser.add_argument("-m", "--mode", choices=MODES)
    parser.add_argument("-w", "--work_path", type=Path)
    parser.add_argument(
        "-x",
        "--excel_name",
        help="memory requirement workbook filename",
    )
    parser.add_argument(
        "-xcka",
        "--clk_a",
        type=int,
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
    raw = _read_json(args.config)
    common = raw.get("common_opt", {})
    excel_config = raw.get("gen_sram_excel", {})
    if not isinstance(common, dict) or not isinstance(excel_config, dict):
        raise ConfigError("common_opt and gen_sram_excel must be JSON objects")

    prefix = args.subsys_prefix or common.get("subsys_prefix")
    if prefix is None:
        parser.error("--subsys_prefix is required unless provided by --config")
    try:
        validate_identifier(str(prefix), "subsys_prefix")
    except InputFormatError as exc:
        parser.error(str(exc))

    mode = args.mode or _mode_from_json(raw) or "init"
    work_value = args.work_path
    if work_value is None:
        work_value = Path(
            _json_value(
                raw,
                "common_opt",
                "env_var",
                "work_path",
                default="./",
            )
        )
    work_path = work_value.expanduser().resolve()

    excel_filename = (
        args.excel_name
        if args.excel_name is not None
        else common.get("excel_filename")
    )
    if excel_filename is not None:
        excel_filename = str(excel_filename).strip() or None
        if excel_filename and Path(excel_filename).name != excel_filename:
            raise ConfigError(
                "excel_filename must be a filename, not a directory path"
            )
    if mode == "excel" and not excel_filename:
        parser.error("excel mode requires --excel_name or a config filename")

    wr_clock = (
        args.clk_a
        if args.clk_a is not None
        else excel_config.get("default_ram_wr_clk_MHz", 1500)
    )
    rd_clock = (
        args.clk_b
        if args.clk_b is not None
        else excel_config.get("default_ram_rd_clk_MHz", wr_clock)
    )
    try:
        wr_clock = parse_int(wr_clock, "default_ram_wr_clk_MHz", 1)
        rd_clock = parse_int(rd_clock, "default_ram_rd_clk_MHz", 1)
    except InputFormatError as exc:
        raise ConfigError(str(exc)) from exc

    return ToolConfig(
        mode=mode,
        subsys_prefix=str(prefix),
        work_path=work_path,
        excel_filename=excel_filename,
        default_wr_clk_mhz=wr_clock,
        default_rd_clk_mhz=rd_clock,
    )
