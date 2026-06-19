# common RTL uarch

## com_fifo

### com_sync_fifo_ram_1p1bank

![com_sync_fifo_ram_1p1bank uarch](assets/com_sync_fifo_ram_1p1bank_uarch.png)

* 概述
    1. 使用 1 个单口 SRAM 作为 FIFO 的主要存储体，SRAM 数据位宽为 `2*DW`，物理深度为 `RAM_DEPTH/2`，对外 FIFO 仍按 `DW` 为一笔数据计数。
    2. 和基础 reg FIFO 相比，该模块用 SRAM 降低大深度 FIFO 面积；代价是需要 out_fifo、pack buffer、SRAM 预取/回填控制。
    3. 读路径不再等 out_fifo 凑够两个空位才读 SRAM，而是在 out_fifo 出现空位后尽早发起 read，去掉额外攒一拍数据的延时。
    4. 关键限制是 external SRAM 读延时固定、请求与返回顺序一致、单口 SRAM 冲突时写优先，且 `OUT_DEPTH >= RAM_RD_DELAY + 3`。

* 模块框图
    1. 框图见本节开头图片。
    2. write path：port write 优先尝试 direct fast hit；不能 direct 时进入 pack；pack 满且新写到来时拼成 `2*DW` row 写 SRAM。
    3. read path：out_fifo 释放空位后尽早发 SRAM read，并通过 fast miss 预留返回 entry；SRAM low half 直接 slow fill，high half 先进入 `ack_hi_dff` 再填 out_fifo。
    4. bypass/drain path：direct write 和 pack drain 都作为 out_fifo fast hit；pack drain 可与 pack store 同拍，支持旧 pack 进 out_fifo、新 port write 留 pack。

* 设计细节
    1. `out_fifo` 使用 `com_sync_fifo_reg_2w1r`，fast 口负责 port direct、pack drain、SRAM 返回占位，slow 口负责 SRAM 返回数据填入，并维持最终读出顺序。
    2. `pack buffer` 使用 `r_pack_vld/r_pack_data` 缓存单笔未配对的 `DW` 写数据，下一笔到来后拼成 `2*DW` row 写入 SRAM，也可在 out_fifo 有空间时 drain 到 fast 口。
    3. `ram queue` 由 1P SRAM 承担主存储体，每个 row 保存两笔 `DW` 数据；`r_ram_wr_addr/r_ram_rd_addr` 按 row 粒度维护 FIFO tail/head，只有实际 SRAM write/read 才推进。
    4. `return buffer` 只用 `r_ram_rd_data_hi_vld/r_ram_rd_data_hi` 暂存 SRAM 返回 high half；low half 直接通过 slow 口填入已占位 entry。
    5. `r_tol_water_level/r_wr_full` 是对外总容量 reg_out 状态，按 `DW` 粒度统计，只根据外部 `wr_hs/rd_hs` 更新。
    6. `ram_otf_cnt` 表示 SRAM read 已发起但还没完成 slow fill 的 `DW` 数据量；这些 entry 已通过 fast miss 预留。
    7. `rd_req_hi` 表示上一笔 SRAM read 的 high half 请求/占位阶段未收尾，用来限制读请求节奏并保持 low/high 顺序。
    8. `direct_order_avl` 表示顺序上允许 port write/pack drain 直接进入 out_fifo；等价条件是 RAM FIFO 为空且没有 high half 等待占位。
    9. 参数约束：`RAM_DEPTH>=2` 且为偶数；`RAM_RD_DELAY` 范围 `[1:16]`；`OUT_DEPTH >= RAM_RD_DELAY + 3`。
    10. 不支持 SRAM 返回乱序或可变延时；不增加返回 FIFO，只用 1 个 `DW` high-half DFF 缓存。

* 讨论记录
    0. 记号说明：`wr_fast_mis` 表示 `i_wr_fast_en & i_wr_fast_data_vld=0`，`wr_fast_hit` 表示 `i_wr_fast_en & i_wr_fast_data_vld=1`。
    1. Q：为什么要把 SRAM read 提前？
       A：避免额外等两个 out_fifo 空位；low 直接填回，high 只用 1DW DFF 暂存。
    2. Q：out_fifo full 时，t0 同拍 `i_rd_en` 是否能马上发 `ram_rd_en`？
       A：不能。t0 只释放 reg_out 空位，t1 才发 `ram_rd_en` 并占 low。
    3. Q：情景1：port读4次(t0/t2/t3/t4)，ram填out，out_fifo最后仍然是满的。
       假设：`OUT_DEPTH=5`；`RAM_RD_DELAY=2`；t0 前 out_fifo full；ram_fifo used 2 row。

       | cycle | port      | out_fifo                                 | out_wl | ram_otf_cnt | sram_req                 | sram_ack                   | result           |
       | ----- | --------- | ---------------------------------------- | ------ | ----------- | ------------------------ | -------------------------- | ---------------- |
       | t0    | `i_rd_en` | `i_rd_en`                                | 0->1   | 0           | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=0`    | free slot        |
       | t1    |           | `wr_fast_mis`                            | 1->0   | 0->2        | `rd_en=1`, `req_hi=0->1` | `ack_vld=0`, `ack_hi=0`    | rd req, low resv |
       | t2    | `i_rd_en` | `i_rd_en`                                | 0->1   | 2           | `rd_en=0`, `req_hi=1`    | `ack_vld=0`, `ack_hi=0`    |                  |
       | t3    | `i_rd_en` | `i_rd_en`, `wr_fast_mis`, `i_wr_slow_en` | 1->1   | 2->1        | `rd_en=0`, `req_hi=1->0` | `ack_vld=1`, `ack_hi=0->1` | low fill         |
       | t4    | `i_rd_en` | `i_rd_en`, `wr_fast_mis`, `i_wr_slow_en` | 1->1   | 1->2        | `rd_en=1`, `req_hi=0->1` | `ack_vld=0`, `ack_hi=1->0` | high fill        |
       | t5    |           | `wr_fast_mis`                            | 1->0   | 2           | `rd_en=0`, `req_hi=1`    | `ack_vld=0`, `ack_hi=0`    | high resv        |
       | t6    |           | `i_wr_slow_en`                           | 0      | 2->1        | `rd_en=0`, `req_hi=1->0` | `ack_vld=1`, `ack_hi=0->1` | low fill         |
       | t7    |           | `i_wr_slow_en`                           | 0      | 1->0        | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=1->0` | high fill        |

       A：`rd_req_hi` 跟踪 high 占位；t4 复用读释放空位提前发下一笔 low，少等一拍。

    4. Q：情景2：在情景1基础上增加两次 `port.i_wr_en`，读写 SRAM 不冲突。
       假设：新增写入在 t1/t2；t1 进 pack，t2 拼成 SRAM row。

       | cycle | port                | out_fifo                                 | out_wl | ram_otf_cnt | sram_req                 | sram_ack                   | result    |
       | ----- | ------------------- | ---------------------------------------- | ------ | ----------- | ------------------------ | -------------------------- | --------- |
       | t0    | `i_rd_en`           | `i_rd_en`                                | 0->1   | 0           | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=0`    | free slot |
       | t1    | `i_wr_en`           |                                          | 1      | 0->2        | `rd_en=1`, `req_hi=0->1` | `ack_vld=0`, `ack_hi=0`    | rd req    |
       | t2    | `i_rd_en`,`i_wr_en` | `i_rd_en`                                | 1->2   | 2           | `wr_en=1`, `req_hi=1`    | `ack_vld=0`, `ack_hi=0`    | sram wr   |
       | t3    | `i_rd_en`           | `i_rd_en`, `wr_fast_mis`, `i_wr_slow_en` | 2->1   | 2->1        | `rd_en=0`, `req_hi=1->0` | `ack_vld=1`, `ack_hi=0->1` | low fill  |
       | t4    | `i_rd_en`           | `i_rd_en`, `wr_fast_mis`, `i_wr_slow_en` | 1->1   | 1->2        | `rd_en=1`, `req_hi=0->1` | `ack_vld=0`, `ack_hi=1->0` | high fill |
       | t5    |                     | `wr_fast_mis`                            | 1->0   | 2           | `rd_en=0`, `req_hi=1`    | `ack_vld=0`, `ack_hi=0`    | high resv |
       | t6    |                     | `i_wr_slow_en`                           | 0      | 2->1        | `rd_en=0`, `req_hi=1->0` | `ack_vld=1`, `ack_hi=0->1` | low fill  |
       | t7    |                     | `i_wr_slow_en`                           | 0      | 1->0        | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=1->0` | high fill |

       A：t1 `direct_order_avl=0`，write 只能进 pack；t2 写 SRAM，和 t4 read 不冲突。

    5. Q：情景3：在情景1基础上增加两次 `port.i_wr_en`，读写 SRAM 有冲突。
       假设：新增写入在 t3/t4；t4 write 与下一次 read request 冲突。

       | cycle | port                | out_fifo                                 | out_wl | ram_otf_cnt | sram_req                 | sram_ack                   | result            |
       | ----- | ------------------- | ---------------------------------------- | ------ | ----------- | ------------------------ | -------------------------- | ----------------- |
       | t0    | `i_rd_en`           | `i_rd_en`                                | 0->1   | 0           | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=0`    | free slot         |
       | t1    |                     | `wr_fast_mis`                            | 1->0   | 0->2        | `rd_en=1`, `req_hi=0->1` | `ack_vld=0`, `ack_hi=0`    | rd req, low resv  |
       | t2    | `i_rd_en`           | `i_rd_en`                                | 0->1   | 2           | `rd_en=0`, `req_hi=1`    | `ack_vld=0`, `ack_hi=0`    |                   |
       | t3    | `i_rd_en`,`i_wr_en` | `i_rd_en`, `wr_fast_mis`, `i_wr_slow_en` | 1->1   | 2->1        | `rd_en=0`, `req_hi=1->0` | `ack_vld=1`, `ack_hi=0->1` | low fill          |
       | t4    | `i_rd_en`,`i_wr_en` | `i_rd_en`, `i_wr_slow_en`                | 1->2   | 1->0        | `wr_en=1`, `req_hi=0`    | `ack_vld=0`, `ack_hi=1->0` | high fill, wr win |
       | t5    |                     | `wr_fast_mis`                            | 2->1   | 0->2        | `rd_en=1`, `req_hi=0->1` | `ack_vld=0`, `ack_hi=0`    | rd req, low resv  |
       | t6    |                     | `wr_fast_mis`                            | 1->0   | 2           | `rd_en=0`, `req_hi=1`    | `ack_vld=0`, `ack_hi=0`    | high resv         |
       | t7    |                     | `i_wr_slow_en`                           | 0      | 2->1        | `rd_en=0`, `req_hi=1->0` | `ack_vld=1`, `ack_hi=0->1` | low fill          |
       | t8    |                     | `i_wr_slow_en`                           | 0      | 1->0        | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=1->0` | high fill         |

       A：t4 写优先，read 延到 t5；t5/t6 再分别占 low/high。

    6. Q：情景4：8 次 `port.i_rd_en`，2 次 `port.i_wr_en`；第一次写在 t1，第二次写在 t5。

       | cycle | port                | out_fifo                                     | out_wl | ram_otf_cnt | sram_req                 | sram_ack                   | result              |
       | ----- | ------------------- | -------------------------------------------- | ------ | ----------- | ------------------------ | -------------------------- | ------------------- |
       | t0    | `i_rd_en`           | `i_rd_en`                                    | 0->1   | 0           | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=0`    | free slot           |
       | t1    | `i_rd_en`,`i_wr_en` | `i_rd_en`, `wr_fast_mis`                     | 1->1   | 0->2        | `rd_en=1`, `req_hi=0->1` | `ack_vld=0`, `ack_hi=0`    | rd req, pack        |
       | t2    | `i_rd_en`           | `i_rd_en`, `wr_fast_mis`                     | 1->1   | 2           | `rd_en=0`, `req_hi=1->0` | `ack_vld=0`, `ack_hi=0`    | high resv           |
       | t3    | `i_rd_en`           | `i_rd_en`, `wr_fast_mis`, `i_wr_slow_en`     | 1->1   | 2->3        | `rd_en=1`, `req_hi=0->1` | `ack_vld=1`, `ack_hi=0->1` | low fill, rd req    |
       | t4    | `i_rd_en`           | `i_rd_en`, `wr_fast_mis`, `i_wr_slow_en`     | 1->1   | 3->2        | `rd_en=0`, `req_hi=1->0` | `ack_vld=0`, `ack_hi=1->0` | high fill/resv      |
       | t5    | `i_rd_en`,`i_wr_en` | `i_rd_en`, `wr_fast_hit`, `i_wr_slow_en`     | 1->1   | 2->1        | `rd_en=0`, `req_hi=0`    | `ack_vld=1`, `ack_hi=0->1` | low fill, drain     |
       | t6    | `i_rd_en`           | `i_rd_en`, `wr_fast_hit`, `i_wr_slow_en`     | 1->1   | 1->0        | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=1->0` | high fill, drain    |
       | t7    | `i_rd_en`           | `i_rd_en`                                    | 1->2   | 0           | `rd_en=0`, `req_hi=0`    | `ack_vld=0`, `ack_hi=0`    | free slot           |

       A：t1 写进 pack；t2 占 high。t5/t6 利用 2w1r 同拍 slow fill 和 pack drain，新写数据留 pack。

### com_sync_fifo_ram_1p2bank

![com_sync_fifo_ram_1p2bank uarch](assets/com_sync_fifo_ram_1p2bank_uarch.png)

* 概述
    1. 使用 2 个单口 SRAM bank 作为 FIFO 主存储体，每个 bank 数据位宽为 `DW`，逻辑地址按 ping/pong bank 交替分布。
    2. 和 1p1bank 相比，1p2bank 不需要 `2*DW` 宽 SRAM，也没有 high half 返回路径；代价是同 bank 读写冲突时一次 SRAM read 只会返回 1 笔数据。
    3. 新方向去掉 ibuf：冲突写数据直接写 SRAM，不再经历 `port -> ibuf -> SRAM` 的额外 data move，用更深 out_fifo 吸收 read hold。
    4. out_fifo 最小深度同样统一为 `OUT_DEPTH >= RAM_RD_DELAY + 3`，覆盖 SRAM latency 与同 bank write-priority read hold。

* 模块框图
    1. 框图见本节开头图片。
    2. write path：port write 优先 direct 到 out_fifo；如果 RAM FIFO 非空或 out_fifo 无 direct 条件，则写入 SRAM tail。
    3. read reserve path：out_fifo 出现空位且 RAM FIFO 有数据时，先发 `wr_fast_mis` 预留返回位置。
    4. read issue path：若本拍 SRAM read 与 port write 同 bank 冲突，则写优先，read 进入 `rd_hold`；下一拍优先 issue hold read。
    5. return/fill path：`RAM_RD_DELAY` 后 SRAM ack 通过 out_fifo slow 口填入已预留 entry。
    6. bypass path：当 RAM FIFO 为空且没有 hold read 时，port write 可通过 out_fifo fast hit 直接写出。

* 设计细节
    1. `out_fifo` 继续使用 `com_sync_fifo_reg_2w1r`；fast hit 给 port direct write，fast miss 给 SRAM read 返回预留 entry，slow write 填 SRAM ack 数据。
    2. `r_ram_wr_addr/r_ram_rd_addr` 分别表示 SRAM FIFO tail/head，按 `DW` 粒度递增，`addr[0]` 选择 ping/pong bank。
    3. `rd_hold_vld/rd_hold_addr` 记录已经完成 fast miss 预留、但还没真正发起 SRAM read 的 pending read。
    4. `ram_otf_cnt` 表示已经发出 SRAM read、但还没 slow fill 完成的 entry 数量，主要用于检查 outstanding/underflow。
    5. `direct_order_avl` 表示 RAM FIFO 为空且没有 `rd_hold`，此时 port write 才能 direct 到 out_fifo。
    6. 同 bank SRAM 读写冲突时写优先，read 最多 hold 1 拍；该 1 拍不靠 ibuf 吸收，靠 out_fifo 深度吸收。
    7. 参数约束：`RAM_DEPTH>=2` 且为偶数；`RAM_RD_DELAY` 固定且至少 1；`OUT_DEPTH >= RAM_RD_DELAY + 3`。
    8. 2w1r out_fifo 仍然必要：SRAM ack slow fill 和 port direct fast hit 可能同拍发生，不能退化为普通 1w FIFO。

* 讨论记录
    1. Q：为什么去掉 ibuf？
       A：冲突写数据直接进入 SRAM，少一次 `port -> ibuf -> SRAM` 搬运，功耗和控制复杂度更低。
    2. Q：`OUT_DEPTH=3`、`RAM_RD_DELAY=1` 时，为什么同 bank 冲突会导致读断流？
       假设：t0 前 out_fifo full 且有 3 笔可读数据；ping/pong SRAM 各 1 笔；t1 有一次 port write，且与当前 read 同 bank 冲突。

       | cycle | port                | out_fifo                    | out_wl | sram_req                     | sram_ack       | result              |
       | ----- | ------------------- | --------------------------- | ------ | ---------------------------- | -------------- | ------------------- |
       | t0    | `i_rd_en`           | `i_rd_en`                   | 0->1   | `rd_en=0`, `rd_hold=0`       | `ack_vld=0`    | free slot           |
       | t1    | `i_rd_en`,`i_wr_en` | `i_rd_en`, `wr_fast_mis`    | 1->1   | `wr_en=ping`, `rd_hold=ping` | `ack_vld=0`    | wr wins, reserve d0 |
       | t2    | `i_rd_en`           | `i_rd_en`, `wr_fast_mis`    | 1->1   | `rd_en=ping`, `rd_hold=pong` | `ack_vld=0`    | read d0, reserve d1 |
       | t3    | `i_rd_en`           | `rd_empty`, `i_wr_slow_en`, `wr_fast_mis` | 1->0 | `rd_en=pong`, `rd_hold=ping` | `ack_vld=ping` | rd break, fill d0   |

       A：t0/t1/t2 已经读完 3 笔可读数据；t3 的 slow fill 不能给 t3 同拍 read 使用，所以 `OUT_DEPTH=3` 会断流。`OUT_DEPTH=4` 才能覆盖这 1 拍 read hold。

## 附录

### 复杂模块 uarch 文档模板

```md
### module_name

![module_name uarch](assets/module_name_uarch.png)

* 概述

* 模块框图
    1. 先给出框图
    2. 简要控制流/数据流

* 设计细节

* 讨论记录(可选章节, 已形成的内容，可以放在设计细节里)
    1. Q：为什么这样设计？
       A：记录讨论结论。
    2. Q：某个极端场景会怎样？
       A：用表格或短推导说明。
```
