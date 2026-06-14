# common RTL uarch

## com_fifo

### com_sync_fifo_ram_1p1bank

* 设计目标
    1. 使用 1 个单口 SRAM 作为 FIFO 的主要存储体，SRAM 数据位宽为 `2*DW`，物理深度为 `RAM_DEPTH/2`，对外 FIFO 仍按 `DW` 为一笔数据计数。
    2. 单口 SRAM 同一拍不能同时读写，冲突时写优先，读侧通过预取和 out_fifo 缓冲来隐藏冲突。
    3. `o_ram_ce_n` 发起 SRAM 读之后，`i_ram_rd_data_vld` 至少隔 1 拍返回；同一个实例内读延时固定，如果是 3 拍则一直是 3 拍，如果是 5 拍则一直是 5 拍。
    4. 对外保持普通同步 FIFO 语义：写当拍写入，读当拍读出；`o_rd_data/o_rd_empty` 只来自 out_fifo，SRAM 内的数据需要先搬到 out_fifo 才能被读侧看到。
    5. `OUT_DEPTH` 用来覆盖 SRAM 读延时，最小深度约束为 `OUT_DEPTH_MIN >= 2 + MAX_RAM_RD_DELAY`。
    6. 性能更新：旧方案需要等 out_fifo 连续出现两个空位，分别预留低半/高半后才发 SRAM read；新方案只要 out_fifo 出现空位，RAM FIFO 就尽早发 SRAM read，去掉额外攒一拍数据的延时。

* 存储层次
    1. `out_fifo`：需要支持 2w1r 写入能力，fast 写口负责 port/direct/pack drain，slow 写口负责 SRAM 返回数据填入。
    2. `pack buffer`：`r_pack_vld/r_pack_data` 暂存一笔未配对的 `DW` 写数据，用于和下一笔写数据拼成一个 `2*DW` SRAM 写入。
    3. `sram queue`：SRAM 每一行保存两笔逻辑 FIFO 数据，低半拍先出，高半拍后出。
    4. `ram_rd_data_hi_vld/ram_rd_data_hi`：SRAM 返回时低半填入已占位的 out_fifo entry，高半暂存在 DFF 中，等 out_fifo 有空位后立刻填入。

* 地址与计数
    1. `r_ram_wr_addr/r_ram_rd_addr` 按 SRAM row 粒度计数，每个 row 保存 `2*DW` 数据。
    2. `ram_rd_en` 发起物理 SRAM 读时，`r_ram_rd_addr + 1` 推进到下一个 SRAM row。
    3. RAM FIFO 的 entry 按 `2*DW` row 统计；对外总容量和 water/full 仍按 `DW` 粒度折算。
    4. `r_tol_water_level/r_wr_full` 是对外总容量的 reg_out 状态，只根据外部 `wr_hs/rd_hs` 更新。
    5. `out_wl` 表示 out_fifo 可写空位数；port read 释放空位，fast 写消耗空位。
    6. `ram_rd_data_hi_vld` 表示 SRAM 返回的高半数据正在等待写入 out_fifo。
    7. `ram_otf_cnt` 表示 SRAM read 产生、但还没完成 slow fill 的 `DW` 数据量；这些 slow fill 的 out_fifo entry 已经由 fast miss 预留，因此不能再从 `out_wl` 中扣减。
    8. `rd_req_hi` 表示上一笔 SRAM read 的 high half 请求/占位阶段还没收尾，用于观察/限制读请求流水，避免下一笔读请求过早进入而打乱占位节奏。
    9. `out_real_free = out_wl - ram_rd_en*2 - ram_req_hi` 表示扣除当前 fast miss 请求后的真实剩余空位；table 中的 `req_hi` 即 `ram_req_hi`。

* 写路径
    1. port write 是否能直接进入 out_fifo，看 `out_real_free`，而不是 `out_wl - ram_otf_cnt`。
    2. 当不能 direct write 且 pack buffer 为空时，当前写数据进入 pack buffer。
    3. 当 pack buffer 已经有一笔数据，下一笔写数据与它拼成 `{i_wr_data,r_pack_data}` 写入 SRAM。
    4. 如果单口 SRAM 同拍有读写竞争，写请求优先，读请求延后。
    5. direct write 和 pack drain 都作为 out_fifo fast hit 写入，`i_wr_fast_data_vld=1`。
    6. 当只有 pack buffer 剩一笔数据，且没有新写入、没有 SRAM 返回待处理、out_fifo 有空位时，可以通过 `pack_drain_en` 把该数据直接搬到 out_fifo。

* SRAM 预取路径
    1. `ram_rd_en` 讨论模型中的发起条件为：`!ram_empty && out_wl>0`；SRAM 读写同拍冲突时再叠加写优先约束。
    2. out_fifo 当前为 full 但同拍发生 `i_rd_en` 时，t0 只释放 out_fifo 空位；t1 才发起 `ram_rd_en`，并用 `wr_fast_mis` 为低半返回占位。
    3. `wr_fast_mis` 的发起条件为：`ram_rd_en || (req_hi && out_wl>0)`。
    4. SRAM read 发起后，`rd_req_hi=1` 表示该 row 的 high half 还需要请求/占位；低半/高半按后续 `wr_fast_mis + i_wr_slow_en` 节奏填回 out_fifo。
    5. 高半数据先进入 `ram_rd_data_hi` DFF；如果 out_fifo 没有已预留 entry，需要先通过 `wr_fast_mis` 占位，再用 slow fill 填入。
    6. 新模型把 SRAM read 从“高半预留拍”提前到“out_fifo 刚出现空位的拍”，去掉旧模型里为了凑够两笔返回位置带来的额外一拍延时。

* SRAM 返回路径
    1. `i_ram_rd_data_vld` 有效时，低半数据 `i_ram_rd_data[DW-1:0]` 通过 out_fifo slow 口填入已占位 entry。
    2. 高半数据锁存到 `ram_rd_data_hi`，并置起 `ram_rd_data_hi_vld`。
    3. `ram_rd_data_hi_vld` 期间，先为高半数据占位；占位完成后通过 out_fifo slow 口填入，并清掉 `ram_rd_data_hi_vld`。
    4. 高半 DFF 的占位/填入需要优先于 port/direct/pack drain，保证 SRAM 两半数据的输出顺序。
    5. 需要保证新发起的 SRAM read 不会让返回低半与已有高半 DFF 造成输出顺序冲突。

* 读 SRAM 对齐结论
    1. 读路径采用尽早发起 SRAM read 的策略，out_fifo 一出现可预留空位就请求 SRAM，避免额外等待两笔空位凑齐。
    2. 返回低半直接填入已预留 entry；返回高半只使用 1 个 `DW` 宽度的 ack-hi DFF 暂存，后续再尽快填入 out_fifo。
    3. 该方案读性能较高，同时不需要额外的返回 FIFO，面积主要增加 1DW DFF 与少量控制逻辑。

* RTL 实现对齐点
    1. `out_fifo` 使用 `com_sync_fifo_reg_2w1r`，fast miss 负责 SRAM low/high 占位，slow write 负责 SRAM 返回数据填入。
    2. `ram_rd_en` 按 `!ram_wr_req && !rd_req_hi && ram_used!=0 && !out_full` 尽早发起；`rd_req_hi_en` 单独完成 high half 占位。
    3. pack drain/direct write 作为 out_fifo fast hit；pack drain 与 pack store 可同拍，支持旧 pack 进 out_fifo、新 port write 留 pack。
    4. 单口 SRAM 写优先仍保留；后续仿真重点覆盖 SRAM ack latency 和连续读写冲突。

* Q/A
    0. 记号说明：`wr_fast_mis` 表示 `i_wr_fast_en & i_wr_fast_data_vld=0`，`wr_fast_hit` 表示 `i_wr_fast_en & i_wr_fast_data_vld=1`。
    1. Q：为什么要把 SRAM read 提前？
       A：旧模型需要先等 out_fifo 出现两个空位，低半/高半都预留后才发 SRAM read；实际读延时会变成 SRAM 固有延时再加一拍攒空位延时。新模型只要 out_fifo 有空位就读 SRAM，低半返回后填 out_fifo，高半只进 1DW ack-hi DFF，性能更好且面积更小。
    2. Q：out_fifo full 时，t0 同拍 `i_rd_en` 是否能马上发 `ram_rd_en`？
       A：不能。当前表格按 reg_out 空位处理，t0 只释放 out_fifo 空位；t1 才发 `ram_rd_en`，并同拍做低半 `wr_fast_mis` 占位。
    3. Q：情景1：port读4次(t0/t2/t3/t4)，ram填out，out_fifo最后仍然是满的。
       假设条件：`OUT_DEPTH=5`；t0 之前 out_fifo 已满；ram_fifo used 2 row，也就是 `4*DW` 数据；`o_ram_ce_n -> i_ram_rd_data_vld` delay 是 2 cycle。

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

       A：`rd_req_hi` 用来标记上一笔 SRAM read 的 high half 请求/占位阶段还没收尾。t3 的 `wr_fast_mis` 是给当前 high 提前占位；t4 处理当前 high 的同时，利用 t4 `i_rd_en` 释放出来的 out_fifo 空位提前做下一笔 low 的 `wr_fast_mis`，并发起下一笔 `ram_rd_en`。t5 再给下一笔 high 占位。这样下一笔 read 从 t5 提前到 t4，减少一拍等待，同时通过 `ram_otf_cnt` 跟踪尚未真正填回 out_fifo 的数据量。

    4. Q：情景2：在情景1基础上增加两次 `port.i_wr_en`，读写 SRAM 不冲突。
       假设条件：新增写入发生在 t1/t2；t1 第一笔进入 pack，t2 第二笔和 pack 写成一个 SRAM row；t2 没有 SRAM read request，因此读写 SRAM 不冲突。

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

       A：两次 port write 被 pack 成一个 SRAM row。t1 虽然 `out_wl=1`，但同拍 `ram_rd_en=1` 会产生 2 个 fast miss 请求，`out_real_free = out_wl - ram_rd_en*2 - ram_req_hi` 已经没有剩余空间，所以 t1 不做 direct write，第一笔 port write 只能进入 pack。因为 `wr_en=1` 发生在 t2，而下一次 `rd_en=1` 发生在 t4，所以单口 SRAM 没有读写冲突；新写入 row 留在 RAM FIFO tail，等待后续 out_fifo 再释放空间。

    5. Q：情景3：在情景1基础上增加两次 `port.i_wr_en`，读写 SRAM 有冲突。
       假设条件：新增写入发生在 t3/t4；t3 第一笔进入 pack，t4 第二笔原本要写成一个 SRAM row，同时 t4 原本也要发下一次 `rd_en=1`。

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

       A：t4 单口 SRAM 读写冲突时写优先，`wr_en=1` 先执行，原本 t4 的 `rd_en=1` 延后到 t5。由于 t4 没有为下一笔 low 占位，`i_rd_en` 释放的 out_fifo 空位会累积到 `out_wl=2`，后续 t5/t6 分别给下一笔 low/high 占位。

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

       A：t1 满足 `ram_rd_en` 条件，因此同拍发起一次 `wr_fast_mis` 给 low half 占位；第一笔 port write 只能进入 pack。t2 因 `req_hi && out_wl>0` 再发一次 `wr_fast_mis` 给 high half 占位。t5 第二笔写到来时，out_fifo 是 2w1r，所以可以同拍 slow fill SRAM low，同时用 fast 口把旧 pack 数据写入 out_fifo；新写数据留在 pack。t6 再同拍 high fill 和 drain pack。这样不增加寄存器资源，也避免两笔 port write 落 SRAM。
