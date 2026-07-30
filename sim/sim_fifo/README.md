# sim_fifo

本目录是 common FIFO 的轻量自检仿真环境，可直接 source 环境并运行 Makefile。

## 覆盖模块

| 模块                         | 说明 |
| ---------------------------- | ---- |
| `com_sync_fifo_reg`          | 基础同步寄存器 FIFO |
| `com_sync_fifo_reg_v2`       | GPT 重写版本 |
| `com_sync_fifo_reg_pfetch`   | 读数据预取版本 |
| `com_sync_fifo_reg_fullbyp`  | full 时读写旁路版本 |
| `com_sync_fifo_ram_1p1bank`  | 1 个单口 SRAM bank 的 FIFO RAM |
| `com_sync_fifo_ram_1p2bank`  | 2 个单口 SRAM bank 的 FIFO RAM |
| `com_sync_fifo_ram_2p1ck`    | 1-clock true dual-port SRAM FIFO RAM |

## 常用命令

| 命令             | 说明 |
| ---------------- | ---- |
| `source ENV.sh`  | 初始化 `SIM_DIR` 和 `COM_PATH` |
| `make com`       | 使用 VCS 编译 |
| `make run`       | 使用 VCS 运行 |
| `make all`       | clean + com + run |
| `make verdi`     | 打开 Verdi 波形 |
| `make cdns_com`  | 使用 Xcelium elaboration |
| `make sim`       | 使用 Xcelium GUI |

## testbench 行为

1. 使用随机 write/read 激励覆盖同拍读写、full、empty、clear。
2. 内部 scoreboard 检查 data order、`o_wr_full`、`o_rd_empty`、`o_water_level`。
3. `com_sync_fifo_reg_fullbyp` 额外覆盖 full 时 `rd_en+wr_en` 同拍写入能力。
4. FIFO RAM case 使用 `impl_template/memory/rtl/shell` 下的 SRAM shell 作为 RAM 模型。
