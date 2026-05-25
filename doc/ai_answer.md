## AI工作记录

本文档用于按时间线记录项目开发过程中的重要事情。记录粒度约为每周一次，也可以在关键决策、关键修改完成后补充。记录内容要能帮助以后复现当时的修改背景、范围、规则和检查结果。

当前阶段重点: RTL代码风格统一。

### 记录原则

- 按时间线记录，优先使用具体日期或周范围。
- 每条记录包含背景、修改范围、关键规则、重要反馈、验证方式。
- 只记录对后续复现有帮助的信息，避免流水账。
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
