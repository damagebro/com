# sim_axi

统一维护 `com_axi_extd_wr`、`com_axi_extd_rd` 和 `com_axi_dma` 的基础仿真环境。

## 运行

```bash
make all TARGET=extd_wr
make all TARGET=extd_rd
make all TARGET=dma
```

`TARGET` 默认值为 `dma`。每个目标拥有独立的 RTL filelist 和 DUT top，共用 `axi_if.sv`、`axi_drv.sv`、`axi_case.sv` 以及相同的编译运行入口。

| TARGET | DUT | TOP |
| ------ | --- | --- |
| `extd_wr` | `com_axi_extd_wr` | `top_extd_wr` |
| `extd_rd` | `com_axi_extd_rd` | `top_extd_rd` |
| `dma` | `com_axi_dma` | `top_dma` |

testbench 使用 `interface + clocking block + class driver + program`。`CASE_KIND` 选择 write、read 或 DMA 组合场景，clocking block 统一采用 `input #1step output #0`。
