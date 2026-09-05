# sim_csr_pkg

CSR package writer/reader基础自检环境。

- writer：覆盖`LIST_WRITE`、`BURST_WRITE`、`JUMP`和扩展`EXIT`。
- writer使用64-bit EBUS，检查LIST跨beat和BURST data阶段均可连续每拍完成一次CSR write。
- reader：覆盖`LIST_READ`、扩展header的`BURST_READ`、`JUMP`和`EXIT`。
- EBUS package与result地址均为4B对齐但不与`EBUS_DW`对齐，检查首尾有效word处理。
- read result固定比较连续的`{reg_addr,reg_data}` entry。
- jump protection：首次jump编码`jump_max_num_m1=15`，检查第17条jump返回`JUMP_LIMIT`并停止读取后续block。
- JUMP预取：读写两侧各12组用例，覆盖首部/中部/尾部JUMP、扩展header、重复JUMP、EXIT冲突、
  非法opcode/地址、缺少结束指令、次数上限、目标last错误和RA反压期间abort；每组结束后继续启动下一组。
- 预取性能：EBUS响应增加8拍延迟，写侧加入CSR反压，读侧保留result反压，检查下一block RA
  早于当前CSR write/result完成。统计的提前周期包含刻意加入的反压时间，不代表无反压吞吐提升。
- error pulse出现后等待`busy=0`，确认当前读流及预取排空，错误情况下不执行目标block的CSR操作。
- `top.EBUS_DW`可覆盖64/128/256-bit回归；默认64-bit波形与保存的wave配置一致。

```bash
source ENV.sh
make vlt
make vlt_wave
```

## JUMP预取回归记录

64/128/256-bit EBUS均通过原有功能比较和新增JUMP测试，每种位宽包含读写两侧共24组JUMP用例。
所有配置均检查result SRAM发生实际读写；256-bit配置使用12笔BURST_READ及60拍写数据反压，
避免结果全部停留在打包寄存器和FIFO前端、未覆盖SRAM路径。

| EBUS_DW | JUMP用例 | 结果 | 日志             |
| ------- | -------- | ---- | ---------------- |
| 64      | 24       | PASS | `bin/run64.log`  |
| 128     | 24       | PASS | `bin/run128.log` |
| 256     | 24       | PASS | `bin/run256.log` |

编译仅保留memory shell中已有的`$psprintf` NONSTD告警。默认64-bit波形保留在`bin/run.fst`，
GTKWave和Verdi配置已增加读写两侧JUMP预取信号组。
