## AI工作记录

本文档用于按时间线记录项目开发过程中的重要事情。记录粒度约为每周一次，也可以在关键决策、关键修改完成后补充。记录内容要能帮助以后复现当时的修改背景、范围、规则和检查结果。

当前阶段重点: 增量开发 RTL。上一阶段 RTL 风格统一与 common RTL 文档模板/简单模块功能描述已结束。

### 记录原则

- 按时间线记录，优先使用具体日期或周范围。
- 每条记录包含背景、修改范围、关键规则、重要反馈、验证方式。
- 尽量精简，不限制固定字数；只记录对后续复现有帮助的信息，避免流水账。
- 用户反馈形成的新规则，要同步写入本文档。
- 代码中仍遵守 RTL 风格要求：注释使用英文，RTL 代码中不出现中文。

## 时间线

### 2026-05-24: 启动 RTL 风格统一化

- 启动 RTL 风格统一，顺序为 `common/*.sv`、`common/fifo/*.sv`、`axi/*.sv`，其他目录暂不动。
- 确认派生参数保持 `localparam`，局部临时变量允许就地 `wire xxx = expr;`，例化连接信号集中声明并用 `u_*` 命名。
- 统一 `com_find_lsb_first_one`、`com_arbiter_rr`、`com_reg*`、`com_pipe*`、`common/fifo/*` 的声明区、端口前缀、例化命名、always/generate 格式。
- `com_reg*` 数据/使能/输出端口补 `i_`、`o_` 前缀，`clk/rst_n/clear` 保持原约定；模块外层 `ifndef/define/endif` 删除。
- `com_simo_no_delay` 端口为 `i_rx_vld/o_rx_rdy/o_tx_vld/i_tx_rdy`，参数 `OCH` 改为 `CH_NUM`。
- `com_pipe_vld`、`com_pipe_regslice` 保留 `gen_pipe_chain` 显式级联，不在实例端口里使用 `[gi+1]`；`com_pipe_vld_rdy` 的 unused pipe upen 端口保持悬空。
- `com_counter` 端口改为 `i_cnt_start/o_cnt_en`，start 仅采样并置起下一拍 `r_cnt_en`，`o_cnt_en` 只等于 `r_cnt_en`。
- 重点问题：output assign 不能引用尚未声明的信号；这类信号必须提前在 signal declare 区域声明，再在 body 区域 `assign` 赋值。该问题已在 `out_all_hs`、`cnt_nxt` 出现，后续必须重点检查。
- 暂不处理 common 外部集成，已跑 `git diff --check`。

### 2026-05-26 至 2026-05-29: common RTL 文档编写阶段收尾

- 编写 `common_rtl_manual.md`，概述表统一放在最前面；模块细节按 `common_ip`、`com_fifo` 等分组展开。
- `com_arbiter_rr`、`com_find_lsb_first_one` 已补文档和 WaveDrom 时序图；默认只写“功能/接口时序”，明确要求时再补“参数/接口/实现说明”。
- `com_pipe*` 已完整说明并补时序图；图中不体现 `rst_n/clear`。`com_reg*` 只说明功能，不写时序、参数和接口。
- `com_simo_no_delay`、`com_edge_detect`、`com_counter` 已完整说明；`com_edge_detect` 的 dual edge 图需同时体现上升沿和下降沿 pulse。
- `com_sync_fifo_reg`、`com_dp_buffer`、`com_dp_ram` 已放到 `## com_fifo` 分组下完整说明；后续 FIFO 系列都按该分组方式记录。
- FIFO 重要规则：`o_wr_full/o_rd_empty/o_water_level` 都是寄存输出。`com_sync_fifo_reg` 时序图使用 `DEPTH=2` 展示 full；当 `o_wr_full=1` 且本拍 `rd_en=1` 时，本拍仍不能写，下一拍 full 拉低后才能写。
- `com_dp_buffer` 时序图要求上游在 `o_rx_rdy=0` 时保持 `i_rx_vld` 和当前 payload，直到重新握手。
- 本地使用 `doc/tools/wavedrom_json_to_png.py` 调用 `wavedrom-cli` 将 WaveDrom JSON 转 PNG；生成资产放在 `doc/assets`。
- Git 记录：文档阶段已提交 `36e30e1 docs: expand common RTL manual` 并 push；随后 FIFO 文档提交 `d7b7ba1 docs: add fifo common manual sections`，仅本地提交未 push。
- 当前阶段结论：已给出文档模板和一批简单模块功能描述，后续文档按该模板增量补充。

### 2026-05-30: 增量开发 RTL（计划）

- FIFO 增量模块：开发 `com_sync_fifo_reg_v2`、`com_sync_fifo_reg_pfetch`、`com_sync_fifo_reg_rwfull`、`com_sync_fifo_reg_2w1r` 的 RTL 和文档，并比较它们与 `com_sync_fifo_reg` 的差异。
- CDC 相关：开发 `pulse/async_fifo`。
- 仲裁相关：开发 `com_arbiter_wrr`、`com_ram_arbiter`。
