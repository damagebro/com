# sim_arbiter

| 模块              | 说明 |
| ----------------- | ---- |
| `com_arbiter_rr`  | round-robin 仲裁 |
| `com_arbiter_wrr` | 连续 quota WRR |
| `com_arbiter_iwrr`| interleaved WRR |

当前 testbench 覆盖基础多请求、backpressure lock、权重配置 smoke。
