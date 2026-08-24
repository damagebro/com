# sim_afifo

`sim_afifo` 独立验证两个寄存器异步 FIFO。

| case | DUT                            | DEPTH | clock ratio            |
| ---- | ------------------------------ | ----: | ---------------------- |
| 0    | `com_async_fifo_reg`           |     5 | write fast / read slow |
| 1    | `com_async_fifo_reg_exactwl`   |     5 | write fast / read slow |
| 2    | `com_async_fifo_reg`           |     8 | write slow / read fast |
| 3    | `com_async_fifo_reg_exactwl`   |     8 | write slow / read fast |

测试分阶段制造写侧拥塞、随机并发和读侧排空，通过 scoreboard 检查数据顺序。
两个时钟的有效边沿不会重合，避免 testbench 共享 scoreboard 的仿真竞争。
所有 DUT 输入激励均在所属时钟的上升沿使用非阻塞赋值更新。

```bash
source ENV.sh
make clean vlt          # 运行全部 case
make clean vlt CASE=1   # 仅运行一个 case
make vlt_wave           # 打开波形
```
