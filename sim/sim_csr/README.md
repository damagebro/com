# sim_csr

CSR bus 配套模块的基础自检环境。

- `csr_core_case`：覆盖 arbiter、timeout、CDC 和多笔 read outstanding。
- `csr_bridge_case`：覆盖 APB/AHB-Lite 连续访问、AXI-Lite 读写顺序及 CSR2APB。
- `csr_regslice_case`：`REQ_DEPTH=2`、`RSP_DEPTH=4`，连续发送 10 拍 write、10 拍 read，
  覆盖顺序出队及 10 拍 response 连续返回。

## 性能检查

在 CSR 与总线对端不反压时，testbench 自动检查以下理论最大吞吐；出现额外空拍会触发 `$fatal`。

| 通路 | 最大吞吐 | 检查内容 |
| ---- | -------- | -------- |
| APB2CSR | 每 2 cycle 1 request | APB setup/access 背靠背，`PSEL` 保持有效 |
| AHB2CSR | 每 cycle 1 request | 连续地址相位期间 `HREADYOUT` 恒为 1 |
| AXIL2CSR read | 每 cycle 1 request/data | AR、CSR request、R 各连续 3 拍 |
| CSR2APB | 每 2 cycle 1 request | 多笔请求间 `PSEL` 不撤销，setup/access 连续切换 |

AXI-Lite 读写最终共用一条 CSR request 通道，因此总下发上限为每周期 1 request；读请求尚未下发完时，
后到的写请求按顺序被反压，这属于顺序约束而不是性能空泡。

```bash
source ENV.sh
make vlt
make vlt_wave
```
