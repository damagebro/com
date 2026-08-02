# sim_cdc

`sim_cdc` 覆盖 async FIFO 与 CDC 基础封装。

| 模块                         | 说明 |
| ---------------------------- | ---- |
| `com_async_fifo_reg`         | 普通异步 FIFO |
| `com_async_fifo_reg_exactwl` | 精确水线异步 FIFO |
| `com_cdc_handshake`          | 单 bit req/ack CDC |
| `com_cdc_rstn`               | 异步复位同步释放 |
| `com_cdc_rstn_pair`          | 双域复位合并分发 |

当前 testbench 使用两个不同时钟，做基础 push/pop 与握手 smoke。
