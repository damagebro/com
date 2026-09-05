# common RTL CSR Manual

## 概述

| module             | function                                      |
| ------------------ | --------------------------------------------- |
| `com_csr_apb2csr`  | APB slave 转 CSR request/response             |
| `com_csr_ahb2csr`  | AHB-Lite slave 转 CSR request/response        |
| `com_csr_axil2csr` | AXI-Lite slave 转 CSR，支持读请求与读数据超发 |
| `com_csr2apb`      | CSR request/response 转 APB master            |
| `com_csr_regslice` | CSR request、response 双向同步流水            |
| `com_csr_cdc`      | CSR request、response 双向跨时钟域            |
| `com_csr_arbiter`  | 多路 CSR master 轮询仲裁到一路 CSR slave      |
| `com_csr_timeout`  | CSR request/response 超时检测与超时响应接管   |
| `com_csr_pkg_wr`   | 从外存读取配置包，批量写CSR并支持JUMP预取     |
| `com_csr_pkg_rd`   | 按配置包批量读CSR，将地址和数据写回外存       |

CSR 总线面向低带宽寄存器访问，request 使用 valid/ready 握手，read response 使用
`rvalid+rdata` 返回。write request 在 request 握手后即完成，不单独返回 write response；read response
必须按照 read request 的下发顺序返回，且下游 response 没有 ready 反压信号。

## 集成框图

![AMBA2CSR与csr_tool集成](assets/csr_amba_integration.png)

* 集成边界
    1. `com_csr_apb2csr/com_csr_ahb2csr/com_csr_axil2csr` 是手写公共 RTL，负责把 AMBA
       channel/phase 转换为统一 CSR request/response，不负责寄存器地址定义。
    2. `csr_tool` 根据 CSR 描述生成 address decode、register bank、sub-block route 与非法地址
       默认响应。register bank、sub-block route、default response 是 decode 后的并行目标选择，
       每笔 request 只进入其中一个目标。
    3. register bank 输出 `cfg` 控制信号并采集 `sta/irq`；sub-block route 可以连接 user CSR slave，
       也可以连接下一级 `csr_tool` generated tree，形成层次化 CSR 地址空间。

* 推荐拓扑
    1. 同时钟单入口：`AMBA2CSR -> csr_tool tree`，面积和访问 latency 最小。
    2. 时序较紧：`AMBA2CSR -> com_csr_regslice -> csr_tool tree`，request/response 双向打拍。
    3. 跨时钟：`AMBA2CSR -> com_csr_cdc -> csr_tool tree`，source/destination 分别使用各自时钟复位。
    4. 多 AMBA 入口：各入口先独立转换为 CSR，再经 `com_csr_arbiter` 汇聚；需要错误隔离时可在
       入口或汇聚出口增加 `com_csr_timeout`。

## CSR接口

| signal           | bit_width  | direction | description                                     |
| ---------------- | ---------- | --------- | ----------------------------------------------- |
| `csr_req_write`  | `1`        | request   | `1` 为 write，`0` 为 read                       |
| `csr_req_addr`   | `CSR_AW`   | request   | byte address，桥接模块按低 `CSR_AW` 位连接      |
| `csr_req_wdata`  | `CSR_DW`   | request   | write data                                      |
| `csr_req_wstrb`  | `CSR_DW/8` | request   | byte write enable                               |
| `csr_req_valid`  | `1`        | request   | request valid，未握手时 payload 必须保持        |
| `csr_req_ready`  | `1`        | request   | request ready，与 valid 同拍为一次 request 握手 |
| `csr_rsp_rdata`  | `CSR_DW`   | response  | read response data                              |
| `csr_rsp_rvalid` | `1`        | response  | read response valid，无 response ready 反压     |

共同参数 `CSR_AW` 表示 CSR 地址位宽，`CSR_DW` 表示 CSR 数据位宽。`CSR_DW` 必须按 byte
对齐；AMBA bridge 的数据位宽必须与 CSR 数据位宽一致。

## AMBA Bridge

### com_csr_apb2csr

* 功能
    1. 仅在 `PSEL && PENABLE` 的 APB access phase 将 APB read/write 转换成一笔 CSR request；
       setup phase 不提前拉高 `csr_req_valid`。
    2. write request 握手后拉高 `PREADY`；read request 等待 `csr_rsp_rvalid` 后返回 `PRDATA`。
    3. CSR 接口本身没有错误响应，正常访问的 `PSLVERR` 固定为 0。

* 参数

| param_name          | default_value   | description            |
| ------------------- | --------------- | ---------------------- |
| `APB_AW` / `APB_DW` | `32` / `32`     | APB address/data width |
| `CSR_AW` / `CSR_DW` | `16` / `APB_DW` | CSR address/data width |

* 性能
    1. APB 每笔传输至少包含 setup、access 两拍，理论最大吞吐为每 2 cycle 1 request。
    2. 连续访问时 `PSEL` 可以保持为 1，access 完成后的下一拍直接进入下一笔 setup，不插入 idle。

### com_csr_ahb2csr

* 功能
    1. 接收 AHB-Lite address/control phase，并在 data phase 完成 CSR request。
    2. 支持连续无气泡访问；read data 等待 CSR response，write data 使用对应 data phase 的 `HWDATA`。
    3. CSR 接口本身没有错误响应，`HRESP` 固定为 OKAY。

* 参数

| param_name          | default_value   | description                 |
| ------------------- | --------------- | --------------------------- |
| `AHB_AW` / `AHB_DW` | `32` / `32`     | AHB-Lite address/data width |
| `CSR_AW` / `CSR_DW` | `16` / `AHB_DW` | CSR address/data width      |

* 性能
    1. 下游 CSR 不反压且 read response 连续返回时，AHB-Lite address phase 可每 cycle 接收 1 request。
    2. `HREADYOUT=0` 只用于 CSR request 或 read response 等待，不主动插入性能空泡。

### com_csr_axil2csr

* 功能
    1. 独立接收 AXI-Lite AW/W channel，二者均到齐后形成 CSR write request。
    2. AR request 写入 read-address FIFO，允许多笔 read request outstanding。
    3. AXI-Lite read 与 write 最终共用一条 CSR request channel；已接收的 read request 全部下发前，
       后到的 write 会被反压，保证 AXI-Lite 到 CSR 的读写顺序。
    4. CSR write 握手后产生 OKAY B response；CSR read response 按顺序映射为 OKAY R response。

* 参数

| param_name          | default_value   | description                                                        |
| ------------------- | --------------- | ------------------------------------------------------------------ |
| `AXI_AW` / `AXI_DW` | `32` / `32`     | AXI-Lite address/data width                                        |
| `CSR_AW` / `CSR_DW` | `16` / `AXI_DW` | CSR address/data width                                             |
| `RD_REQ_OSD`        | `1`             | read-address FIFO 深度及最大未返回 read request 数，范围 `[1:256]` |
| `RD_DATA_OSD`       | `0`             | read-data FIFO 深度，范围 `[0:256]`                                |

* `RD_DATA_OSD`
    1. `RD_DATA_OSD=0`：CSR response 直接连接 AXI R channel，不限制 read-data 超发；集成约束为
       `i_axil_rready===1'b1`，避免无 ready 的 CSR response 丢失。
    2. `RD_DATA_OSD>0`：CSR response 进入 read-data FIFO，允许 AXI R channel 反压；可接收的 read
       request 同时受 `RD_REQ_OSD` 与 read-data FIFO 剩余容量限制。

* 性能
    1. 无反压时 AR、CSR read request、R channel 均可达到每 cycle 1 transfer。
    2. AW/W 各只有一组暂存，write response 未消费时不会接受下一笔完整 write；该模块侧重 CSR
       顺序和 read outstanding，不用于高超发 write traffic。

### com_csr2apb

* 功能
    1. 将 CSR request 缓存在 `REQ_DEPTH` FIFO 中，再产生 APB setup/access phase。
    2. APB write 完成后直接结束；APB read 完成后通过 CSR read response 返回 `PRDATA`。
    3. `PSLVERR` 通过单拍 `o_pls_err_pslverr` 上报，不改变 CSR response 数据格式。

| param_name          | default_value | description                                     |
| ------------------- | ------------- | ----------------------------------------------- |
| `CSR_AW` / `CSR_DW` | `16` / `32`   | CSR address/data width                          |
| `APB_AW`            | `32`          | APB address width，APB data width 等于 `CSR_DW` |
| `REQ_DEPTH`         | `2`           | CSR request FIFO depth，范围 `[2:256]`          |

连续请求时 `PSEL` 保持有效，setup/access 交替执行，达到 APB 的每 2 cycle 1 request 理论上限。

## CSR Fabric

### com_csr_regslice

request 与 response 分别使用一组 `com_sync_fifo_reg`，因此两条方向均被寄存器隔离并支持
valid/ready 吞吐。`REQ_DEPTH`、`RSP_DEPTH` 默认均为 2；无反压时流水建立后可达到每 cycle
1 request 和每 cycle 1 response。由于 CSR response 没有 ready，response FIFO 满不得继续收到下游 response。

### com_csr_cdc

* request 使用深度为 `REQ_DEPTH` 的 async FIFO 从 `src_clk` 跨到 `dst_clk`。
* response 使用深度为 `RD_OSD` 的 async FIFO返回 source domain；`RD_OSD` 同时限制 source
  侧未返回 read request 数量，保证 response FIFO 容量足以容纳所有已发 read。
* `SYNC_S` 指定 async FIFO 指针同步级数。两侧分别直接使用 `src_rst_n`、`dst_rst_n`，模块不处理
  两侧复位释放协议，系统集成必须保证复位期间不会遗留只有单侧可见的 transaction。
* 同一时钟域内可持续每 cycle 接收或发送一笔，CDC 会增加固定同步延迟，但稳态吞吐由较慢时钟域决定。

### com_csr_arbiter

* `REQ_N` 路 CSR request 使用 `com_arbiter_rr` 轮询仲裁为一路，grant 在 valid 未握手时保持稳定。
* 每笔 read request 的 master index 写入深度为 `RD_OSD` 的 owner FIFO；read response 到达后按 FIFO
  顺序 onehot 返回原 master。因此下游必须保持 read response 与 read request 同序。
* owner FIFO 满时，read request 会同时从仲裁 `valid` 和上游 `ready` 两侧门控，确保上游不会把
  未记录 owner 的 read 误判为握手；write 不占 owner FIFO，仍可参与仲裁。下游 ready 恒高时总输出
  可达到每 cycle 1 request，但单个 master 获得的带宽由同时请求的 master 数与轮询结果决定。

| param_name | default_value | description                                       |
| ---------- | ------------- | ------------------------------------------------- |
| `REQ_N`    | `2`           | CSR master 数量，范围 `[1:256]`                   |
| `RD_OSD`   | `8`           | outstanding read owner FIFO depth，范围 `[1:256]` |

### com_csr_timeout

* request timeout：上游 request 持续 valid、下游持续 not-ready 达到 `TIMEOUT_CYCLE` 时产生
  `o_pls_err_req_timeout`。write 被视为完成；read 返回一笔全 0 timeout response。
* response timeout：存在 pending read 且连续 `TIMEOUT_CYCLE` 没有任何下游 read response 时产生
  `o_pls_err_rsp_timeout`，进入 sticky takeover 状态。每收到一笔正常 response，response timeout
  计数都会重新开始。
* takeover 状态下，模块屏蔽所有迟到的下游 response；新 request 不被反压，也不再发送到下游。
  新 write 直接丢弃，新 read 返回全 0 response。状态仅由 `clear` 或 reset 清除，避免迟到 response
  被错误配给后续 request。
* pending read counter 为 16 bit。系统必须保证 outstanding read 不超过 65535。

| param_name      | default_value | description                             |
| --------------- | ------------- | --------------------------------------- |
| `TIMEOUT_CYCLE` | `1000`        | request/response timeout 连续等待周期数 |

正常状态下该模块为组合 valid/ready 透传，不主动降低每 cycle 1 request/response 的吞吐。错误脉冲
`o_pls_err_req_timeout/o_pls_err_rsp_timeout` 应连接状态寄存器、interrupt 或系统错误收集模块；软件完成
错误记录和下游恢复后，再通过 `clear` 退出 takeover 状态。

## CSR Package

`com_csr_pkg_wr`从外存读取配置包并批量写CSR；`com_csr_pkg_rd`读取描述包、批量读CSR，
再将地址和读数据写回外存。两个模块都是CSR master，控制和状态寄存器由`csr_tool`生成。
CPU准备package、配置首个block地址和长度并触发start，执行期间无需逐寄存器发起访问。

package模块的CSR数据固定为32-bit，不提供`CSR_DW`参数。写侧只支持full write。
与CPU入口集成时，经CSR arbiter汇聚到`csr_tool` tree；`com_csr_arbiter`本身采用轮询，
若系统要求CPU固定优先，需要额外的优先级控制。package不提供整包原子锁，读回结果也不是同时刻快照。

```text
csr_tool cfg/sta <-> package engine <-> EBUS / DMA <-> external memory
                         |
                         +-> CSR arbiter -> csr_tool register tree
CPU AMBA2CSR ------------+
```

### 公共参数与控制接口

表中I/O方向均相对于package模块。CSR地址字段在包内始终占32-bit；输出只连接低`CSR_AW`位，
软件必须保证地址可表示且burst递增不越界，不能依赖硬件上报所有地址溢出。

| param_name | default_value | description                                             |
| ---------- | ------------- | ------------------------------------------------------- |
| `CSR_AW`   | `16`          | CSR地址位宽；写侧范围`[8:32]`，读侧范围`[1:32]`         |
| `EBUS_AW`  | `64`          | EBUS byte address位宽，范围`[8:64]`                     |
| `EBUS_DW`  | `256`         | EBUS data位宽，按2的幂配置；写侧至少64，读侧至少32      |
| `EBUS_LW`  | `32`          | EBUS byte length位宽，至少20；按参数约定不超过`EBUS_AW` |
| `EBUS_UW`  | `1`           | EBUS user属性位宽，至少1                                |

| signal               | bit_width | direction | description                                                 |
| -------------------- | --------- | --------- | ----------------------------------------------------------- |
| `clk`                | `1`       | I         | 模块及CSR/EBUS接口时钟                                      |
| `rst_n`              | `1`       | I         | 低有效异步复位                                              |
| `clear`              | `1`       | I         | 同步清除内部状态；使用前需处理外部在途事务                  |
| `i_cfg_pkg_addr`     | `EBUS_AW` | I         | 首个block的byte address，要求4B对齐                         |
| `i_cfg_pkg_bytelen`  | `EBUS_LW` | I         | 首个block的有效byte数，至少4且为4的整数倍                   |
| `i_cfg_ebus_user`    | `EBUS_UW` | I         | EBUS请求的user属性，执行期间保持稳定                        |
| `i_cfg_start`        | `1`       | I         | 单拍启动；idle时接受并锁存首个block地址/长度                |
| `i_cfg_abort`        | `1`       | I         | 请求进入错误排空流程，不等于撤销已经发出的总线事务          |
| `o_sta_busy`         | `1`       | O         | 执行或排空中；清零后才允许重新启动                          |
| `o_pls_done`         | `1`       | O         | 正常执行EXIT后的完成脉冲                                    |
| `o_pls_error`        | `1`       | O         | 错误诊断脉冲；不代表排空已经完成                            |
| `o_sta_error_code`   | `8`       | O         | 首个错误码，保持至idle启动、clear或reset                    |
| `o_sta_reg_done_cnt` | `32`      | O         | 写侧按CSR request握手累加，读侧按CSR response累加；满后饱和 |
| `o_sta_jump_cnt`     | `16`      | O         | 已正式切换到目标block的次数，不包含仅发起预取的JUMP         |

`pkg_addr/pkg_bytelen`在启动时锁存，`i_cfg_ebus_user`直接透传到EBUS请求。
两个计数器跨block累计，在idle启动、clear或reset时清零。busy期间再次start只报告
`ERR_START_BUSY`，不会排队新package，也不自动终止当前执行。

### EBUS与CSR接口

两个模块均通过EBUS的RA/RD channel读取package。EBUS下层负责大长度传输和burst/地址边界拆分。
本模块要求package地址4B对齐，但不要求按`EBUS_DW`对齐；首尾beat中的有效word由地址和
`bytelen`决定，低地址word位于beat的低位lane。

| signal                 | bit_width | direction | description                                          |
| ---------------------- | --------- | --------- | ---------------------------------------------------- |
| `o_tx_ebus_ra_user`    | `EBUS_UW` | O         | package读取属性                                      |
| `o_tx_ebus_ra_addr`    | `EBUS_AW` | O         | 当前或预取block的byte address                        |
| `o_tx_ebus_ra_bytelen` | `EBUS_LW` | O         | block的有效byte数                                    |
| `o_tx_ebus_ra_valid`   | `1`       | O         | 读地址有效，反压时保持请求                           |
| `i_tx_ebus_ra_ready`   | `1`       | I         | 读地址接收就绪                                       |
| `i_tx_ebus_rd_data`    | `EBUS_DW` | I         | 按总线宽度对齐的package data beat                    |
| `i_tx_ebus_rd_last`    | `1`       | I         | 整个block的最后一个beat，不是底层每个AXI burst的last |
| `i_tx_ebus_rd_valid`   | `1`       | I         | 返回数据有效                                         |
| `o_tx_ebus_rd_ready`   | `1`       | O         | 返回数据接收就绪，支持反压                           |
| `o_tx_csr_req_write`   | `1`       | O         | 写模块固定1，读模块固定0                             |
| `o_tx_csr_req_addr`    | `CSR_AW`  | O         | CSR byte address，要求4B对齐                         |
| `o_tx_csr_req_wdata`   | `32`      | O         | 写模块输出配置数据；读模块固定0                      |
| `o_tx_csr_req_wstrb`   | `4`       | O         | 写模块固定`4'hf`；读模块固定0                        |
| `o_tx_csr_req_valid`   | `1`       | O         | CSR request有效                                      |
| `i_tx_csr_req_ready`   | `1`       | I         | CSR request接收就绪                                  |
| `i_tx_csr_rsp_rdata`   | `32`      | I         | 仅读模块：CSR read response数据                      |
| `i_tx_csr_rsp_rvalid`  | `1`       | I         | 仅读模块：按请求顺序返回，无response ready           |

CSR read response至少晚于对应request握手一拍。下游必须按序且每笔只返回一次，
metadata FIFO据此匹配CSR地址；写模块没有CSR response接口。

### 配置包格式

package使用little-endian byte order，每条指令以一个32-bit基础header开始。
令`H=header_wordsize`、`N=reg_num`，整个header占`4H` byte，
payload从`instruction_addr+4H`开始。扩展header中未定义的word写0，硬件跳过。

| bit       | field             | description                            |
| --------- | ----------------- | -------------------------------------- |
| `[31:28]` | `opcode`          | 指令类型                               |
| `[27:24]` | `header_wordsize` | 包含基础header的总word数，范围`[1:15]` |
| `[23:16]` | `rsv`             | 软件写0                                |
| `[15:0]`  | `reg_num`         | 普通指令的entry数；JUMP复用为次数配置  |

| opcode | name          | 最小H | 扩展header / payload                                      | 指令总byte数 |
| ------ | ------------- | ----- | --------------------------------------------------------- | ------------ |
| `0`    | `LIST_WRITE`  | `1`   | payload为N组`addr,data`，每组8B，地址可离散或重复         | `4H+8N`      |
| `1`    | `BURST_WRITE` | `1`   | payload为一个`addr_base`及N个data，地址逐笔加4            | `4H+4+4N`    |
| `2`    | `LIST_READ`   | `3`   | 扩展header为result地址低/高32-bit；payload为N个addr       | `4H+4N`      |
| `3`    | `BURST_READ`  | `3`   | 扩展header为result地址低/高32-bit；payload为一个addr_base | `4H+4`       |
| `4`    | `JUMP`        | `4`   | 扩展header为next地址低/高32-bit、next byte length         | `4H`         |
| `5~14` | reserved      | ----- | 检测到后报错                                              | ------------ |
| `15`   | `EXIT`        | `1`   | 无payload，`reg_num=0`                                    | `4H`         |

LIST/BURST的`N`范围为`[1:65535]`，一个header管理N笔访问。
每条指令必须完整落在当前block长度内；普通指令执行完后顺序解析下一header。
block内有一次JUMP时按长度边界切换；没有JUMP时必须以EXIT结束。EXIT必须在block末尾，
且不能与JUMP出现在同一block。

读指令的result地址要求4B对齐，每个结果占8B，存储顺序如下；只写地址和数据，不带额外header：

| result byte offset | field                 |
| ------------------ | --------------------- |
| `8*i`              | 第i笔`reg_addr[31:0]` |
| `8*i+4`            | 第i笔`reg_data[31:0]` |

详细逐字段offset可参考[配置包格式说明](plan_csr_pkg.md#指令格式)。

### com_csr_pkg_wr

写侧使用2-entry EBUS beat FIFO，`r_beat0_data/r_beat1_data`为无复位数据DFF，
有效性由控制寄存器管理。双word解析窗口允许一个LIST entry跨越两个beat。

```text
EBUS RD -> 2-entry beat FIFO -> word0/word1 window -> CSR write
                                      |
                              header / JUMP decode
```

`eHEADER`解析基础header，`eHEADER_EXTD`解析扩展字段和跳过reserved word。
LIST数据阶段同拍使用一个addr和一个data，CSR握手后消费2个word；BURST先取得base address，
后续每次握手消费1个data并将地址加4。CSR反压时保持当前entry。

在输入数据充足、CSR ready连续有效时，同一LIST或BURST数据段可达到
`1 write/cycle`，支持beat边界连续消费及FIFO同拍pop/push。
header、扩展字段、指令切换和block切换仍有控制开销，不能将该吞吐理解为任意短指令序列都无气泡。

### com_csr_pkg_rd

读侧解析LIST地址或保存BURST base，使用metadata FIFO记录已发CSR request的地址。
收到CSR response后形成64-bit `{reg_addr,reg_data}`，写入result FIFO，
再序列化为EBUS写数据。每条读指令发送一笔长度为`8N`的EBUS result write，
收到该笔`wb_valid`且数据发送完成后才执行下一条指令。

| param_name     | default_value | description                                                      |
| -------------- | ------------- | ---------------------------------------------------------------- |
| `RD_OSD`       | `8`           | metadata寄存器FIFO深度及CSR最大在途数量，范围`[1:32]`            |
| `RESULT_DEPTH` | `32`          | result SRAM逻辑深度及result预留上限；偶数、至少4且不小于`RD_OSD` |
| `RAM_RD_DELAY` | `1`           | 外部result SRAM固定读延迟，范围`[1:16]`                          |

每次发CSR read之前，同时检查metadata FIFO空间和result预留空间。
result预留从request发出保持到该entry被EBUS packer取走，上限由`RESULT_DEPTH`独立限制；
因此`RD_OSD`用于覆盖CSR响应延迟，`RESULT_DEPTH`还需要考虑EBUS write反压。
response没有ready，不能等数据到达后再判断FIFO是否有空间。

result FIFO使用`com_sync_fifo_ram_1p1bank`，内部输出FIFO深度为`RAM_RD_DELAY+3`。
SRAM接口在模块端口上，需外接单口SRAM或对应shell；每行存两个64-bit entry，
物理深度为`RESULT_DEPTH/2`，数据宽度固定128-bit。外部SRAM实际读延迟必须匹配`RAM_RD_DELAY`。

| signal                 | bit_width       | direction | description                     |
| ---------------------- | --------------- | --------- | ------------------------------- |
| `o_tx_ebus_wa_user`    | `EBUS_UW`       | O         | result写回的user属性            |
| `o_tx_ebus_wa_addr`    | `EBUS_AW`       | O         | 当前读指令的result byte address |
| `o_tx_ebus_wa_bytelen` | `EBUS_LW`       | O         | result总byte数，等于`8N`        |
| `o_tx_ebus_wa_valid`   | `1`             | O         | result写地址有效                |
| `i_tx_ebus_wa_ready`   | `1`             | I         | 写地址接收就绪                  |
| `o_tx_ebus_wd_data`    | `EBUS_DW`       | O         | 对齐后的result数据beat          |
| `o_tx_ebus_wd_valid`   | `1`             | O         | 写数据有效                      |
| `i_tx_ebus_wd_ready`   | `1`             | I         | 写数据接收就绪                  |
| `i_tx_ebus_wb_valid`   | `1`             | I         | 整笔result写完成，无wb ready    |
| `o_result_ram_ce_n`    | `1`             | O         | SRAM片选，低有效                |
| `o_result_ram_we_n`    | `1`             | O         | `0=write, 1=read`               |
| `o_result_ram_addr`    | `RESULT_RAM_AW` | O         | SRAM row address                |
| `o_result_ram_wr_data` | `128`           | O         | SRAM整行写数据                  |
| `i_result_ram_rd_data` | `128`           | I         | SRAM整行读数据                  |

`RESULT_RAM_AW=$clog2(max(RESULT_DEPTH/2,2))`由localparam计算，无需用户配置。
result的首尾有效byte由WA地址和长度限定，模块不输出独立的EBUS strobe。

BURST读请求在credit充足、下游ready连续时可每拍发出一次；LIST读还受单beat缓存补充的空拍影响。
当前result packer每拍最多消费一个32-bit word，一个结果需要两个word，且发送beat时暂停装填。
因此读请求的短时峰值可为`1 read/cycle`，持续性能还受result打包与写回速度限制；
不能按`EBUS_DW`推断每拍满宽输出。

### JUMP提前预取

JUMP扩展header顺序为`jump_addr_l`、`jump_addr_h`、`jump_bytesize`，
其中byte length字段固定32-bit。首次JUMP的`reg_num[7:0]`锁存为`jump_max_num_m1`，
允许正式跳转`jump_max_num_m1+1`次，即1至256次。后续block的JUMP低8-bit忽略，
所有JUMP的`reg_num[15:8]`必须为0。

1. JUMP可放在block首部、中部或末尾；解析并校验后登记目标信息，继续执行当前block。
2. 本block的EBUS读返回全部接收后，才提前发送下一block RA。无需同时接收两条读返回流，
   也不增加预取data DFF；下一block数据在正式切换前由RD ready反压。
3. 当前block按长度执行完成后正式切换。写侧等待最后一次CSR write握手；
   读侧还要等待当前读指令结果写回完成。只有正式切换才增加`o_sta_jump_cnt`。
4. 每个block最多一次JUMP，第二次报`ERR_DUP_JUMP`；JUMP与EXIT同块报`ERR_BAD_BLOCK`。
   次数限制在目标RA发出前检查，超限目标不会被读取。
5. 软件把JUMP放在前部可增加预取机会，收益取决于取数完成后剩余CSR执行或result写回时间；
   不保证能完全掩盖EBUS读延迟。

### 错误处理与软件流程

| code | RTL name         | condition                                                         |
| ---- | ---------------- | ----------------------------------------------------------------- |
| `0`  | `ERR_NONE`       | 无错误                                                            |
| `1`  | `ERR_BAD_OPCODE` | reserved opcode或当前模块不支持的读/写opcode                      |
| `2`  | `ERR_BAD_HEADER` | header长度小于该opcode要求                                        |
| `3`  | `ERR_BAD_REGNUM` | LIST/BURST数量为0、EXIT数量非0、JUMP高8-bit非0                    |
| `4`  | `ERR_BAD_BLOCK`  | 指令越界、EXIT非末尾、JUMP与EXIT同块、缺少结束指令或RD last不匹配 |
| `5`  | `ERR_BAD_ALIGN`  | 初始地址/长度、CSR地址、JUMP目标或result地址不满足约束            |
| `6`  | `ERR_START_BUSY` | busy期间再次start                                                 |
| `7`  | `ERR_ABORTED`    | busy期间收到abort                                                 |
| `8`  | `ERR_JUMP_LIMIT` | JUMP超过首次配置的次数上限                                        |
| `9`  | `ERR_DUP_JUMP`   | 同一block出现第二条JUMP                                           |

格式错误或abort进入排空流程；若预取RA已有效但尚未握手，保持RA直至握手，
再排空并丢弃目标数据，不执行目标CSR访问。软件不能仅根据error pulse立即重启，
需要检查busy清零；已有result write的地址、长度不能通过abort撤销。
当外部事务无法完成时，需要系统协调恢复，clear/reset本身不会清除外部总线中的旧响应。

1. 软件按CSR map生成package，校验地址范围、对齐、长度和JUMP/EXIT规则；配置包及result区避免重叠。
2. 完成外存写入及必要的cache一致性处理后，设置首个地址、长度和user，产生一次start脉冲。
3. 执行期间不修改package，避免CPU同时访问相关寄存器；错误脉冲和done脉冲由状态寄存器/中断锁存。
4. 等待完成或错误排空后读取状态；读侧正常完成后再读取result区，并按系统要求处理cache一致性。

CSR bus没有error sideband，本模块无法凭CSR response识别非法寄存器、访问权限或外围timeout。
这些错误需由`csr_tool`默认响应、错误收集及外围`com_csr_timeout`等机制配合处理，
不属于上述package错误码。

## 性能验证

`sim/sim_csr` 使用 Verilator 自动检查连续访问，任意额外空拍会触发 `$fatal`。

| path           | verified throughput   | condition                        |
| -------------- | --------------------- | -------------------------------- |
| APB2CSR        | `1 request / 2 cycle` | setup/access 背靠背，`PSEL` 连续 |
| AHB2CSR        | `1 request / cycle`   | CSR ready、read response 无停顿  |
| AXIL2CSR AR    | `1 request / cycle`   | read-address FIFO 未满           |
| AXIL2CSR CSR/R | `1 transfer / cycle`  | CSR 与 AXI R 均无反压            |
| CSR2APB        | `1 request / 2 cycle` | APB `PREADY=1`                   |

当前回归命令为：

```bash
cd sim/sim_csr
source ENV.sh
make vlt
```

回归结果为 `SIM_CSR PASS`。这里的性能结论表示稳态吞吐；regslice、CDC、bridge 状态机引入的首笔
固定 latency 不计为 steady-state bubble。

### Package回归

`sim/sim_csr_pkg`已在64/128/256-bit EBUS下通过功能自检，每种位宽包含读写两侧共24组新增
JUMP用例，三种位宽合计72组。覆盖首部/中部/尾部及扩展header JUMP、重复JUMP、次数限制、
非法目标/指令、EXIT冲突、last错误、预取RA反压期间abort及错误后的重新启动。

回归同时检查LIST/BURST写数据段连续握手、读结果地址/数据顺序、result SRAM实际读写，
并比较下一block RA与当前操作完成周期，验证预取重叠。性能用例刻意加入CSR/result反压，
统计的提前周期不等于无反压场景的固定收益。

```bash
cd sim/sim_csr_pkg
source ENV.sh
make vlt
make vlt_wave
```

默认生成64-bit波形，保存的GTKWave/Verdi配置包含JUMP预取信号组。
各位宽验证记录见[sim_csr_pkg README](../sim/sim_csr_pkg/README.md#jump预取回归记录)。
