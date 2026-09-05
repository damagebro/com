# CSR Package Engine 开发计划

## 目标

新增两个 CSR package engine，用于寄存器数量较多的批量配置与状态快照，减少 CPU 逐寄存器访问。

| module           | function                                                                                  |
| ---------------- | ----------------------------------------------------------------------------------------- |
| `com_csr_pkg_wr` | 通过 EBUS 读取 CSR package，执行 `list_write/burst_write/jump/exit`                     |
| `com_csr_pkg_rd` | 通过 EBUS 读取 CSR package，执行 `list_read/burst_read/jump/exit`，并将结果写回外部存储 |

两个模块都是 CSR bus master。CPU 只负责在外存构造 package block、配置首个 block 的
`pkg_addr/pkg_bytelen` 并触发 `start`。模块的控制和状态寄存器由 `csr_tool` 生成。

## 指令流模型

CSR package 由若干变长指令顺序组成。

```text
package block 0
    instruction 0
    instruction 1
    ...
    jump -> package block 1

package block 1
    instruction 0
    ...
    exit
```

1. 每条指令以一个 32-bit header 开始，package 使用 little-endian byte order。
2. `header_wordsize` 给出 header 与扩展 header 的总 32-bit word 数；payload 从
   `instruction_addr + header_wordsize*4` 开始。
3. 普通指令执行完成后，根据 opcode 和 `reg_num` 计算下一条顺序指令地址。
4. `jump` 转移到另一个 EBUS address，形成单向链表；不保存返回地址。
5. `exit` 结束整个 CSR package。没有遇到 `exit` 就耗尽当前 block 属于格式错误。

## 32-bit Header

### 位域

| bit       | field             | description                                                          |
| --------- | ----------------- | -------------------------------------------------------------------- |
| `[31:28]` | `opcode`          | 指令类型，定义见下表                                                 |
| `[27:24]` | `header_wordsize` | header 总 32-bit word 数；payload offset 为 `header_wordsize*4` byte |
| `[23:16]` | `rsv`             | 写 0                                                                 |
| `[15:0]`  | `reg_num`         | 数据指令的寄存器数量；JUMP指令复用低8-bit配置jump上限                |

`header_wordsize` 的单位是 32-bit word，有效范围为 `[1:15]`。硬件只解析当前 opcode 已定义的
扩展字段；若 `header_wordsize` 更大，剩余扩展 header word 作为 reserved 跳过，由此保留格式扩展能力。

### Opcode

| opcode | name           | description                                                           |
| ------ | -------------- | --------------------------------------------------------------------- |
| `0`    | `LIST_WRITE`   | `reg_num` 组独立 `{reg_addr,reg_data}`，地址不要求连续                |
| `1`    | `BURST_WRITE`  | 一个 `reg_addr_base` 加 `reg_num` 个连续递增地址的 `reg_data`         |
| `2`    | `LIST_READ`    | 读取 `reg_num` 个独立 `reg_addr`，结果按序连续写到 EBUS              |
| `3`    | `BURST_READ`   | 从 `reg_addr_base` 开始读取 `reg_num` 个连续寄存器，结果连续写到 EBUS |
| `4`    | `JUMP`         | 跳转到下一block；首次JUMP的`reg_num[7:0]`配置整个package的jump上限     |
| `5~14` | reserved       | 第一版检测到后报错，不通过 `header_wordsize` 静默跳过                 |
| `15`   | `EXIT`         | CSR package 全部执行完成                                              |

## 指令格式

所有 CSR 地址和数据在 v1 中均为 32 bit，固定支持 `CSR_DW=32`、`CSR_AW<=32`。寄存器地址为
byte address；burst 的地址步长固定为 `CSR_DW/8=4B`。

### LIST_WRITE：4H+8N B

其中 `H=header_wordsize`，默认 `H=1`；`reg_num=N`，要求 `N>=1`。基础 header 固定占
第一个 32-bit word，整个 header 区域占 `4H` byte。一个 header 管理 N 个 list-write
entry，每个 entry 都包含独立地址和数据，地址可以离散、倒序或重复。

| byte_offset       | field                    | description                         |
| ----------------- | ------------------------ | ----------------------------------- |
| `0x00`            | header                   | `opcode=0`，`reg_num=N`             |
| `0x04 ... 4H-1`   | extended/reserved header | 仅 `H>1` 时存在，未定义的 word 写 0 |
| `4H`              | `reg_addr[0]`            | 第 0 笔 CSR byte address            |
| `4H+4`            | `reg_data[0]`            | 第 0 笔 full-write data             |
| `4H+8`            | `reg_addr[1]`            | 第 1 笔 CSR byte address            |
| `4H+12`           | `reg_data[1]`            | 第 1 笔 full-write data             |
| `4H+8*(N-1)`      | `reg_addr[N-1]`          | 第 N-1 笔 CSR byte address          |
| `4H+8*(N-1)+4`    | `reg_data[N-1]`          | 第 N-1 笔 full-write data           |

每个 entry 输出一笔 CSR full write，`wstrb='1`，并严格保持 entry 顺序。`reg_num=0`
视为 `BAD_REG_NUM`。

下一指令地址：`instruction_addr + header_wordsize*4 + reg_num*8`。

### BURST_WRITE：4H+4+4N B

其中 `H=header_wordsize`，默认 `H=1`；`reg_num=N`，要求 `N>=1`。

| byte_offset     | field                    | description                         |
| --------------- | ------------------------ | ----------------------------------- |
| `0x00`          | header                   | `opcode=1`，`reg_num=N`             |
| `0x04 ... 4H-1` | extended/reserved header | 仅 `H>1` 时存在，未定义的 word 写 0 |
| `4H`            | `reg_addr_base`          | 第一个 CSR byte address             |
| `4H+4`          | `reg_data[0]`            | 写入 `reg_addr_base`                |
| `4H+8`          | `reg_data[1]`            | 写入 `reg_addr_base+4`              |
| `4H+4+4*(N-1)`  | `reg_data[N-1]`          | 写入 `reg_addr_base+4*(N-1)`        |

每一笔都是 full write，严格按地址递增顺序发送 CSR request。下一指令地址：
`instruction_addr + header_wordsize*4 + 4 + reg_num*4`。

### LIST_READ：4H+4N B

其中 `H=header_wordsize`，默认 `H=3`；`reg_num=N`，要求 `N>=1`。read 扩展 header
紧跟在基础 header 后，用于指定结果写回地址。一个 header 管理 N 个 list-read entry，
每个 entry 包含一个独立 CSR 地址，地址可以离散、倒序或重复。

| byte_offset       | field                    | description                          |
| ----------------- | ------------------------ | ------------------------------------ |
| `0x00`            | header                   | `opcode=2`，`reg_num=N`              |
| `0x04`            | `ebus_base_addr_l`       | result destination address `[31:0]`  |
| `0x08`            | `ebus_base_addr_h`       | result destination address `[63:32]` |
| `0x0c ... 4H-1`   | extended/reserved header | 仅 `H>3` 时存在，未定义的 word 写 0  |
| `4H`              | `reg_addr[0]`            | 第 0 笔 CSR byte address             |
| `4H+4`            | `reg_addr[1]`            | 第 1 笔 CSR byte address             |
| `4H+4*(N-1)`      | `reg_addr[N-1]`          | 第 N-1 笔 CSR byte address           |

第 i 笔 CSR response 形成 `{reg_addr[i],reg_data[i]}`，按两个连续 little-endian 32-bit word
写到 `ebus_base_addr + 8*i`，总写入 byte 数为 `reg_num*8`，不附加其他 result header。
`reg_num=0` 视为 `BAD_REG_NUM`。下一指令地址：
`instruction_addr + header_wordsize*4 + reg_num*4`。

### BURST_READ：4H+4 B

其中 `H=header_wordsize`，默认 `H=3`；`reg_num=N`，要求 `N>=1`。

| byte_offset     | field                    | description                          |
| --------------- | ------------------------ | ------------------------------------ |
| `0x00`          | header                   | `opcode=3`，`reg_num=N`              |
| `0x04`          | `ebus_base_addr_l`       | result destination address `[31:0]`  |
| `0x08`          | `ebus_base_addr_h`       | result destination address `[63:32]` |
| `0x0c ... 4H-1` | extended/reserved header | 仅 `H>3` 时存在，未定义的 word 写 0  |
| `4H`            | `reg_addr_base`          | 第一个 CSR byte address              |

模块依次读取 `reg_addr_base + 4*i`，并将每个 `{reg_addr,reg_data}` 结果从
`ebus_base_addr + 8*i` 开始连续写入，总写入 byte 数为 `reg_num*8`。下一指令地址：
`instruction_addr + header_wordsize*4 + 4`。

### JUMP：4H B

其中 `H=header_wordsize`，默认 `H=4`。JUMP复用header的`reg_num`区域：

```text
reg_num[15:8] = reserved，必须为0
reg_num[7:0]  = jump_max_num_m1
max_jump_num  = jump_max_num_m1 + 1
```

只有当前package的第一条JUMP锁存`jump_max_num_m1`，取值`0~255`分别表示最多允许`1~256`
次jump。后续JUMP的`reg_num[7:0]`被忽略，软件建议填0或重复首次配置值；高8-bit始终必须为0。

| byte_offset | field           | description                                           |
| ----------- | --------------- | ----------------------------------------------------- |
| `0x00`      | header          | `opcode=4`；首次JUMP携带`jump_max_num_m1`             |
| `0x04`      | `jump_addr_l`   | next package block address `[31:0]`                   |
| `0x08`      | `jump_addr_h`   | next package block address `[63:32]`                  |
| `0x0c`      | `jump_bytesize` | next block 有效 byte 数，也是下一笔 EBUS `ra_bytelen` |

若 `H>4`，`0x10 ... 4H-1` 为 reserved header word，硬件跳过。

`jump`登记下一block的地址和长度，不执行CSR访问；允许位于当前block的首部、中部或末尾。
解析并校验扩展header后继续执行当前block，按`pkg_bytelen`检测block结束，当前操作全部完成后
才正式切换。每个block最多登记一次JUMP，重复时报`DUP_JUMP`。跳转后新的block offset从0开始。

`o_sta_jump_cnt`记录已经成功执行的jump数量。准备执行当前JUMP时，如果已执行次数大于首次
锁存的`jump_max_num_m1`，返回`JUMP_LIMIT`且不发起目标block的EBUS read。因此达到最大次数后，
当前目标block仍可执行普通数据指令，但必须以EXIT结束；如果再次出现JUMP则报错。

### EXIT：4H B

其中 `H=header_wordsize`，默认 `H=1`；`reg_num=0`。`exit` 不带 payload，除基础 header
之外的word均为reserved。EXIT的`4H` byte header区域必须位于当前block末尾，且本block不能
已经登记JUMP；否则报block length error。

## Block 与边界规则

1. 首个 block 的 `{pkg_addr,pkg_bytelen}` 来自控制寄存器；后续 block 来自 `jump`。
2. `pkg_addr/jump_addr` 和 block bytesize 必须 4B 对齐，bytesize 至少为 4。
3. parser 为每条指令计算 `instruction_end`，必须满足 `instruction_end<=block_bytesize`。
4. `reg_num*4`、`reg_num*8`、地址递增、指令长度和 EBUS result length 均需要做溢出检查。
5. 每个block必须包含一次JUMP或以EXIT结束，两者互斥；无JUMP且无EXIT时报block length error。
   首次JUMP配置整个package允许的最大jump次数，从而限制jump链和链表环路的最长执行次数。
6. package 在 `busy=1` 期间必须保持只读，CPU 不得修改当前 block 或尚未访问的 jump block。

## 模块接口

### 控制与状态

| signal               | width     | direction | description                                          |
| -------------------- | --------- | --------- | ---------------------------------------------------- |
| `i_cfg_pkg_addr`     | `EBUS_AW` | I         | 首个 package block address                           |
| `i_cfg_pkg_bytelen`  | `EBUS_LW` | I         | 首个 package block byte 数                           |
| `i_cfg_ebus_user`    | `EBUS_UW` | I         | package读取及result写回使用的EBUS user属性           |
| `i_cfg_start`        | `1`       | I         | 单拍启动脉冲，仅 idle 时接受                         |
| `i_cfg_abort`        | `1`       | I         | 停止发起新操作并 drain 在途 transaction              |
| `o_sta_busy`         | `1`       | O         | package 正在执行                                     |
| `o_pls_done`         | `1`       | O         | 遇到 `exit` 且所有访问完成后的单拍脉冲               |
| `o_pls_error`        | `1`       | O         | package 失败单拍脉冲                                 |
| `o_sta_error_code`   | `8`       | O         | 首个错误原因，保持到下一次 start/clear               |
| `o_sta_reg_done_cnt` | `32`      | O         | 已完成 CSR register 数量，所有指令均按每个 entry 累加 |
| `o_sta_jump_cnt`     | `16`      | O         | 已执行 jump 数量                                     |

控制信号由 `csr_tool` generated register 输出。`start` 到来时若 `busy=1`，忽略新 start 并产生
`START_WHILE_BUSY` error，不排队第二个 package。首个block的`pkg_addr/pkg_bytelen`在接受
`start`时锁存；busy期间CSR配置值变化不影响当前package。

`o_sta_reg_done_cnt`在每次有效start时清零。write entry在CSR request握手时累加，read entry
在CSR response到达时累加；32-bit计数器溢出后保持全1，不回绕。

`o_sta_jump_cnt`记录当前package已成功执行的jump数量。jump上限由首次JUMP header中的
`jump_max_num_m1`配置；计数跨jump block累计，在新start、clear或reset时清零。

### EBUS

两个模块都使用 EBUS read channel 获取 package block：

| signal_group       | direction | description                                              |
| ------------------ | --------- | -------------------------------------------------------- |
| `o/i_tx_ebus_ra_*` | O/I       | `user/addr/bytelen/valid/ready`，读取当前 package block  |
| `i/o_tx_ebus_rd_*` | I/O       | `data/last/valid/ready`，接收 package instruction stream |

EBUS擅长大长度访问，并在下层自动完成burst和address boundary拆分，package engine不重复拆分。
EBUS address支持任意byte address，但`rd_data/wd_data` beat按`EBUS_DW`边界对齐。package reader
根据请求起始地址低位与`bytelen`提取首拍至末拍的有效byte，并将其重新组合为连续32-bit word。

`com_csr_pkg_rd` 额外使用 EBUS write channel返回 read data：

| signal_group         | direction | description                                           |
| -------------------- | --------- | ----------------------------------------------------- |
| `o/i_tx_ebus_wa_*`   | O/I       | result base、byte length、valid/ready                 |
| `o/i_tx_ebus_wd_*`   | O/I       | 连续 `{reg_addr,reg_data}`，对齐到 EBUS data beat 后发送 |
| `i_tx_ebus_wb_valid` | I         | 当前 single/burst read 的整笔 result write completion |

result writer同样根据`ebus_base_addr`低位放置首个有效byte；首尾有效范围由write address和
`bytelen=reg_num*8`确定，EBUS下层据此生成最终memory byte enable。

### CSR master

两个模块均输出标准 `csr_req_write/addr/wdata/wstrb/valid` 并接收 `csr_req_ready`；
`com_csr_pkg_rd` 额外接收 `csr_rsp_rdata/rvalid`。与 CPU 的 AMBA2CSR 入口并存时，通过
`com_csr_arbiter` 汇聚，不能直接 wire-OR。

### Read result SRAM

`com_csr_pkg_rd`的metadata FIFO保持`com_sync_fifo_reg`实现，深度为`RD_OSD`且不超过32；
result FIFO使用`com_sync_fifo_ram_1p1bank`，其容量独立配置，以吸收EBUS write backpressure。

| parameter      | description                                              |
| -------------- | -------------------------------------------------------- |
| `RD_OSD`       | CSR read最大在途数量，同时也是metadata FIFO深度          |
| `RESULT_DEPTH` | result SRAM逻辑深度，必须为偶数、至少为4且不小于`RD_OSD` |
| `RAM_RD_DELAY` | result SRAM固定读延迟；需与外部SRAM实现一致              |

| signal_group           | direction | description                                   |
| ---------------------- | --------- | --------------------------------------------- |
| `o_result_ram_ce_n`    | O         | result FIFO SRAM片选，低有效                  |
| `o_result_ram_we_n`    | O         | result FIFO SRAM读写选择，0为写、1为读        |
| `o_result_ram_addr`    | O         | result SRAM地址，物理深度为`RESULT_DEPTH/2`   |
| `o_result_ram_wr_data` | O         | 128-bit SRAM写数据，一行保存两个64-bit result |
| `i_result_ram_rd_data` | I         | 128-bit SRAM读数据                            |

## com_csr_pkg_wr 微架构

```text
EBUS block reader -> byte/word aligner -> instruction parser
                                      -> write data FIFO
                                      -> CSR write sequencer
```

1. block reader 按 `pkg_bytelen/jump_bytesize` 发起 EBUS read，并检查 `rd_last` 与 block 末尾一致。
2. parser 解析 32-bit header；`header_wordsize` 允许跳过未知的扩展 header word。
3. `LIST_WRITE` 依次解析 N 组独立 `{addr,data}`；`BURST_WRITE` 只保存一个 base address，
   并为后续每个 data 自动 `addr+4`。
4. CSR write 始终为 full write，`csr_req_wstrb='1`，按 package 顺序执行。
5. 小型 instruction/data FIFO 用于隔离 EBUS 与 CSR backpressure，不缓存整个链表。
6. 遇到JUMP先登记后继block；当前EBUS读返回全部接收后，允许提前发送下一block的RA。
   剩余CSR操作继续执行，正式切换前反压下一block的读返回，切换后进入现有beat buffer。

## com_csr_pkg_rd 微架构

```text
EBUS block reader -> instruction parser -> CSR read issuer -> metadata FIFO
                                                    CSR response -> result FIFO
result FIFO -> 32-bit to EBUS packer -> EBUS write
```

1. `LIST_READ` 依次读取 N 个独立 CSR 地址；`BURST_READ` 从一个 base address 开始自动
   `addr+4`。两者的 result EBUS length 均为 `reg_num*8`。
2. 两种 read 指令最多允许 `RD_OSD` 笔 CSR read outstanding，以覆盖 CSR read latency。
3. metadata FIFO为每笔在途请求保存`reg_addr`；CSR response按序返回时，与对应地址组成
   `{reg_addr,reg_data}`并写入基于SRAM的result FIFO。
4. 每发一笔 CSR read 前必须为 response 预留 result FIFO 空间。CSR response 没有 ready，不能等
   response 到达后才检查存储容量。
5. metadata FIFO由`RD_OSD`限制CSR在途数量；result reserve从request发出保持到result被EBUS
   packer取走，上限为独立的`RESULT_DEPTH`，因此可覆盖EBUS write长期反压。
6. 第一版同一时刻只允许一个 read 指令的 EBUS result write 在途；收到 `wb_valid` 后才执行
   下一条指令或 jump/exit，简化 completion 与指令归属。

## 顺序、仲裁与性能

1. package engine 严格保持指令顺序和 burst 内地址顺序。
2. `com_csr_pkg_wr`限制`EBUS_DW>=64`且为2的幂。写侧使用2-entry EBUS beat FIFO和跨beat
   双word解析窗口；`LIST_WRITE`每拍消费一组`{reg_addr,reg_data}`，`BURST_WRITE`数据阶段
   每拍消费一个data，CSR与EBUS均无反压时可连续每cycle完成1次CSR write。
3. `com_csr_pkg_rd` 在 `RD_OSD` 足够覆盖 read latency 时，目标为每 cycle 1 CSR read request、
   每 cycle 1 response，并以 EBUS data width连续打包`{reg_addr,reg_data}`。
4. CPU 与 package engine 同时访问 CSR tree 时使用`com_csr_arbiter`，固定由CPU优先；不增加
   package atomic/arbiter lock。CPU穿插或长期占用时，不保证package读写值的一致性或完成延迟。
5. 系统软件负责避免CPU在package执行期间访问相关CSR；硬件只保证单个master内部顺序。

## 错误处理

| error_code            | condition                                                        |
| --------------------- | ---------------------------------------------------------------- |
| `BAD_OPCODE`          | opcode 为 `5~14`，或模块收到不支持的 read/write opcode           |
| `BAD_HEADER_WORDSIZE` | `header_wordsize=0`，或小于当前 opcode 的必需 header word 数     |
| `BAD_REG_NUM`         | list-write/list-read/burst的reg_num为0、JUMP高8-bit非0或EXIT的reg_num非0 |
| `BAD_BLOCK_SIZE`      | 指令越界、EXIT非末尾、JUMP与EXIT同块、缺少结束指令或EBUS `last`不匹配 |
| `DUP_JUMP`            | 同一block出现第二条JUMP；RTL error code为`8'd9`                  |
| `BAD_ALIGN`           | package、jump、result 或 CSR address 不满足 4B 对齐              |
| `ADDR_OVERFLOW`       | CSR/EBUS 地址递增或长度计算溢出                                  |
| `START_WHILE_BUSY`    | busy 期间再次 start                                              |
| `CSR_TIMEOUT`         | 外部 `com_csr_timeout` 报告 request/response timeout             |
| `ABORTED`             | 软件主动 abort，模块完成 drain 后停止                            |
| `JUMP_LIMIT`          | 准备执行的jump数量将超过首次JUMP配置的`jump_max_num_m1+1`        |

CSR bus 没有 error sideband，package engine 无法天然识别 csr_tool tree 内的非法地址。package 生成工具
应根据 CSR map 预检查地址；若需要运行期识别，应由 generated tree 提供独立 illegal-address pulse。

EBUS 当前也没有显式 error response，只能依赖 completion 和外围 timeout。若系统需要区分
DECERR/SLVERR，应扩展 EBUS 或外围 wrapper，而不是让 package engine 伪造成功。

## csr_tool 与软件配套

1. `csr_tool` 根据 CSR map 和配置值生成 write package binary，以及便于 review 的 JSON/text dump。
2. 大量连续地址自动合并为 `BURST_WRITE/BURST_READ`；多个离散地址合并到同一条
   `LIST_WRITE/LIST_READ`，由 `reg_num` 表示 entry 数量。
3. package超过单block限制时生成多个block，每个非最终block插入一次JUMP；推荐放在block前部，
   为下一block的EBUS读请求提供提前量。
4. 最后一个 block 必须以 exit 结束；生成器检查所有 block size、header size 和 jump address。
5. write package 生成器检查 RO 字段、地址范围和 full-write 对 reserved bit 的影响。
6. C header 提供 opcode/header pack macro、block descriptor 和 error code。
7. 软件流程说明 cache clean/invalidate、memory barrier、start/busy/done/error 和 timeout recovery。

## 验证计划

在 `sim/sim_csr_pkg` 建立独立环境，使用 memory model 模拟 EBUS source/destination。

1. 每种 opcode 的最小合法指令及连续混合指令。
2. list write/read 和 burst 的 `reg_num=1/2/最大值`；离散、倒序、重复 CSR 地址；
   连续 CSR ready 与随机 backpressure。
3. `RD_OSD=1/2/8`、固定/随机 CSR latency、连续 response 和 EBUS write backpressure。
4. 单jump、多jump、不同block size、首次jump上限配置、后续jump低8-bit忽略及链表环路限制。
5. reserved opcode、错误 header size/reg_num、指令越界、地址溢出、提前/延后 `rd_last`。
6. busy 重复 start、不同阶段 abort、reset/clear、error drain 后重新启动。
7. scoreboard 比较write后的CSR model，以及read result memory中连续的
   `{reg_addr,reg_data}` 64-bit entry。
8. 覆盖4B对齐但非`EBUS_DW`对齐的首地址，检查首尾beat的有效byte提取与放置。
9. 性能检查：无反压时CSR request/response和EBUS data stream不插入额外空拍。

## 开发阶段

1. **P0 指令格式冻结**：确认 opcode、header_wordsize、各 opcode payload 与 block 结束规则。
2. **P1 package writer**：实现 list/burst write、jump、exit 和最小 binary generator。
3. **P2 package reader**：实现 list/burst read、result reserve、EBUS writer。
4. **P3 系统集成**：接入 csr_tool register、`com_csr_arbiter/timeout` 和 subsystem EBUS。
5. **P4 文档工具**：补 package disassembler、manual、框图、性能和错误恢复说明。

## 已确认约束

1. `header_wordsize`包含基础32-bit header，表示整个header区域的word数；允许大于opcode所需
   的最小值，多出的reserved word由硬件跳过。
2. JUMP允许位于block首部、中部或末尾，每个block最多一次；EXIT必须位于末尾且与JUMP互斥。
3. `LIST_WRITE/LIST_READ/BURST_WRITE/BURST_READ`要求`reg_num>=1`；`EXIT`要求`reg_num=0`；
   `JUMP.reg_num[15:8]`要求为0，低8-bit仅在首次jump时锁存为`jump_max_num_m1`。
4. v1 burst CSR地址步长固定为4B；stride扩展以后通过extended header考虑。
5. 每个read result固定写入`{reg_addr,reg_data}`两个32-bit word。
6. 首个`pkg_addr/pkg_bytelen`由CSR配置并通过当前module port输入。
7. 不提供硬件级package atomic/arbiter lock。CPU固定优先，软件负责避免并发访问造成数据不一致。
8. EBUS负责大长度访问及底层地址边界拆分；package engine负责处理对齐EBUS data beat中的
   有效byte。
9. 首次jump通过8-bit `jump_max_num_m1`配置最多1~256次jump；超过上限的下一条jump不执行并
   返回`JUMP_LIMIT`错误。

## JUMP提前预取

写侧和读侧均已实现JUMP提前登记及RA预取，指令编码保持不变。

### 执行语义

保持现有指令编码和JUMP扩展字段格式，通过当前block的`pkg_bytelen`确定block边界。
JUMP允许放在block前部或中间的合法指令边界：解析到首次JUMP时保存下一block的地址和长度，
允许提前发起EBUS读取，随后继续执行当前block的指令。到达当前block末尾且相关访问完成后，
才正式切换到下一block。同一block内再次解析到JUMP时报错。

```text
当前block，长度由pkg_bytelen指定
    JUMP          登记next_addr/next_bytelen，允许预取
    LIST_WRITE    执行当前block的配置
    BURST_WRITE   执行当前block的配置
    block结束     当前访问完成后，切换下一block
```

JUMP必须由指令解析状态识别，不能在普通address/data中扫描opcode位。软件将JUMP放得越靠前，
越有机会用当前block剩余执行时间覆盖下一block的EBUS读取延时；实际收益受EBUS读超发能力和
缓冲空间限制。

### RTL实现

1. 保存当前block的JUMP登记标记、目标地址和长度；解析完JUMP后返回header解析状态。
   每次切换block清除登记标记，同一block第二次JUMP触发错误。
2. 区分取数完成和执行完成。EBUS `rd_last`仅表示取数完成；写侧需等最后一笔CSR write握手，
   读侧需等相关CSR响应及result写回完成，才能正式切换block。
3. 预取只读取配置包数据，不执行下一block的CSR操作。下一block预取上下文与当前block执行
   上下文分开，避免覆盖当前地址、长度和剩余word计数。
4. 首次JUMP的次数上限和累计jump次数覆盖整个package。预取前检查次数限制，正式切换时累计
   成功jump次数；block内的JUMP登记标记与package级次数保护分别管理。
5. 当前实现仅在本block的读返回全部接收后，才发送下一block RA；不要求EBUS支持多个读返回流
   同时在途。下一block数据在正式切换前由`rd_ready`反压，切换后使用原有beat buffer，
   不增加预取data DFF。`r_prefetch_req`保持RA有效直至握手，`r_prefetch_sent`记录待接管的返回流。
6. 第二次JUMP或后续指令报错时，第一次JUMP的预取可能已经发出。错误恢复必须处理已发出的
   预取响应，排空并丢弃数据，不能将预取视为已正式跳转。

### 性能与验证

1. RA可与当前block最后若干CSR操作重叠，读侧还可覆盖result写回等待时间；能够掩盖的延时
   取决于接收完成后的剩余执行时间，不保证长EBUS延时被全部掩盖。
2. 出错时先上报error pulse，`busy`保持到当前block及已发出预取排空。RA已拉高但尚未握手时，
   继续保持地址、长度和valid，握手后排空；不执行目标block的CSR操作，也不累计成功jump次数。
3. `sim_csr_pkg`增加首部/中部/尾部JUMP、重复JUMP、扩展header、非法地址、缺少终止、
   JUMP与EXIT冲突、后续非法opcode、读返回last错误、次数限制、RA反压期间abort及重新启动测试。
4. 性能用例比较下一block RA握手与当前CSR write/result完成的周期，确认预取确实提前。
