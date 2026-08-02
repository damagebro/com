# sim_ram

`sim_ram` 覆盖 common RAM valid/ready 适配与仲裁模块。

| 模块                  | 说明 |
| --------------------- | ---- |
| `com_ram_arbiter`     | 多 write/read channel 到单 RAM 接口仲裁 |
| `com_ram_adp_sp`      | vld/rdy RAM 接口到单口 SRAM 访问 |
| `com_ram_adp_rmw`     | partial write 转 read-modify-write |
| `com_ram_adp_2sp`     | 一个逻辑 RAM 接口到两个单口 SRAM bank |

## 运行

```bash
source ENV.sh
make com
make run
```

当前 testbench 是 smoke/self-check 框架，重点检查握手路径不会卡死，后续可继续增加精确 memory scoreboard。
