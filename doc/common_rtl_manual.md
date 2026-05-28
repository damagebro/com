# 概述

| module                   | function                                                |
| ------------------------ | ------------------------------------------------------- |
| `com_arbiter_rr`         | 多路请求的轮询仲裁，输出 onehot 和 index 形式的授权结果 |
| `com_find_lsb_first_one` | 在输入位图中选择最低位的有效项                          |
| `com_reg`                | 基础数据寄存器                                          |
| `com_reg_e`              | 带写使能的数据寄存器                                    |
| `com_reg_ce`             | 带同步清除和写使能的数据寄存器                          |
| `com_pipe_vld_single`    | 单级 valid 控制管线，输出数据更新使能                   |
| `com_pipe_vld`           | 多级 valid 控制管线，输出各级数据更新使能               |
| `com_pipe_rdy`           | 单级 ready 管线，带一拍反压缓存                         |
| `com_pipe_vld_rdy`       | 可配置 valid/ready 单级数据管线                         |
| `com_pipe_regslice`      | 多级 valid/ready 数据寄存切片                           |
| `com_simo_no_delay`      | 单输入多输出无延迟广播握手                              |
| `com_edge_detect`        | 输入电平边沿检测并输出单周期脉冲                        |
| `com_counter`            | 可启动、自动停止的参数化计数器                          |

# common_ip

## com_arbiter_rr

* 功能

  `com_arbiter_rr` 对 `REQ_N` 路请求执行 round-robin 仲裁。复位或 `clear` 后从低编号请求开始选择；每次授权握手成功后，下一次仲裁优先从本次授权的下一路开始，并在需要时回绕到低编号请求。模块使用 `com_find_lsb_first_one` 从当前候选请求位图中生成 onehot 授权与授权索引。轮询位置仅在授权握手成功时更新，不会因请求出现但尚未被接受而移动。

* 接口时序

  下图以 `REQ_N=4` 展示请求等待接受、握手推进轮询位置和回绕选择。

  ![com_arbiter_rr 接口时序](assets/com_arbiter_rr_wavedrom.png)

* 参数

  | param_name | range   | default_value                  | description                     |
  | ---------- | ------- | ------------------------------ | ------------------------------- |
  | `REQ_N`    | `[1::]` | `2`                            | 请求通道数量                    |
  | `REQ_N_L2` | derived | `$clog2(REQ_N>2 ? REQ_N : 2)` | 授权索引位宽，派生 `localparam` |

* 接口

  | signal_name    | bit_width  | I/O | description                              |
  | -------------- | ---------- | --- | ---------------------------------------- |
  | `i_req_vld`    | `REQ_N`    | I   | 各请求通道有效指示                       |
  | `o_req_rdy`    | `REQ_N`    | O   | 各请求通道接受指示，仅成功授权的通道置位 |
  | `o_gnt_onehot` | `REQ_N`    | O   | onehot 形式的授权结果                    |
  | `o_gnt_idx`    | `REQ_N_L2` | O   | 授权通道索引，`o_gnt_vld=1` 时有效       |
  | `o_gnt_vld`    | `1`        | O   | 授权结果有效指示                         |
  | `i_gnt_rdy`    | `1`        | I   | 授权结果接收就绪指示                     |

* 实现说明

  1. `r_avl_bitmap` 记录当前轮询窗口中可以优先参与仲裁的请求范围。
  2. 如果 `i_req_vld & r_avl_bitmap` 中存在请求，则在该范围内选取最低位请求。
  3. 如果当前优先范围内没有请求，则使用完整 `i_req_vld` 重新选择，实现回绕仲裁。
  4. 授权通道握手后，`r_avl_bitmap` 被更新为从下一通道到最高编号通道有效的掩码。

## com_find_lsb_first_one

* 功能

  `com_find_lsb_first_one` 是纯组合优先选择模块，从 `i_req_val` 中寻找最低编号的有效位，并同时给出 onehot 结果、索引结果以及无有效位指示。

* 接口时序

  下图以 `N=8` 展示输入位图变化对应的组合输出；`o_res_idx` 仅在 `o_res_none_flag=0` 时有效。

  ![com_find_lsb_first_one 接口时序](assets/com_find_lsb_first_one_wavedrom.png)

## com_pipe_vld_single

* 功能

  `com_pipe_vld_single` 是一项深度的 valid 控制管线，只寄存传输项是否有效，不存储 payload 数据。配套的数据寄存器应使用 `o_rx_pipe_upen` 作为更新使能：当输入项被本级真正接收时，同拍更新 payload；本模块负责保持对应的 `o_tx_vld`，直到下游接受该项或同拍以新项替换。

* 接口时序

  下图展示空管线接收输入、下游阻塞时保持 valid，以及下游消费与上游送入同拍发生时无气泡替换的过程。

  ![com_pipe_vld_single 接口时序](assets/com_pipe_vld_single_wavedrom.png)

* 参数

  无可配置参数。

* 接口

  | signal_name       | bit_width | I/O | description                                                   |
  | ----------------- | --------- | --- | ------------------------------------------------------------- |
  | `i_rx_vld`        | `1`       | I   | 上游输入有效指示                                              |
  | `o_rx_rdy`        | `1`       | O   | 上游输入接收就绪；本级为空或当前输出可被下游接受时为 `1`      |
  | `o_tx_vld`        | `1`       | O   | 本级输出有效指示                                              |
  | `i_tx_rdy`        | `1`       | I   | 下游接收就绪指示                                              |
  | `o_rx_pipe_upen`  | `1`       | O   | 输入 payload 更新使能，等于输入握手 `i_rx_vld && o_rx_rdy`    |

* 实现说明

  1. `r_vld_flag` 表示本级是否持有有效项；复位或 `clear` 时清零。
  2. `o_rx_rdy = i_tx_rdy || !r_vld_flag`，因此空槽可以立即接收输入，满槽仅在下游可接受时开放上游。
  3. 输入握手优先于输出握手更新状态：如果同拍既消费当前项又接收新项，`r_vld_flag` 保持为 `1`，形成无气泡替换。
  4. 模块不保存 payload，实例外的数据通路必须在 `o_rx_pipe_upen=1` 时锁存输入数据，并与该 valid 状态保持一致。

## com_pipe_vld

* 功能

  `com_pipe_vld` 是由 `PIPE_NUM` 个 `com_pipe_vld_single` 串联组成的多级 valid 控制管线。模块只负责 valid/ready 控制流，不保存 payload；每一级的 payload 寄存器应使用对应位的 `o_rx_pipe_upen` 更新。它适用于已有独立数据寄存器阵列、只需要统一生成各级更新使能的场景。

* 接口时序

  下图以 `PIPE_NUM=2` 展示输入项进入两级管线、下游反压导致整条管线暂停、反压解除后各级同时更新，以及尾级先排空的过程。

  ![com_pipe_vld 接口时序](assets/com_pipe_vld_wavedrom.png)

* 参数

  | param_name | range   | default_value | description |
  | ---------- | ------- | ------------- | ----------- |
  | `PIPE_NUM` | `[1::]` | `2`           | 管线级数    |

* 接口

  | signal_name      | bit_width  | I/O | description                                            |
  | ---------------- | ---------- | --- | ------------------------------------------------------ |
  | `i_rx_vld`       | `1`        | I   | 上游输入有效指示                                       |
  | `o_rx_rdy`       | `1`        | O   | 第 `0` 级接收就绪，即整条管线对上游的 ready            |
  | `o_tx_vld`       | `1`        | O   | 最后一级输出有效指示                                   |
  | `i_tx_rdy`       | `1`        | I   | 下游接收就绪指示                                       |
  | `o_rx_pipe_upen` | `PIPE_NUM` | O   | 各级 payload 更新使能，bit `0` 对应输入侧第 `0` 级      |

* 实现说明

  1. 第 `0` 级输入连接模块输入 `i_rx_vld`，最后一级输出 ready 连接模块输入 `i_tx_rdy`。
  2. 当 `PIPE_NUM>1` 时，前一级 `o_tx_vld` 连接后一级 `i_rx_vld`，后一级 `o_rx_rdy` 反向连接前一级 `i_tx_rdy`。
  3. `o_rx_rdy` 取第 `0` 级 ready，`o_tx_vld` 取最后一级 valid，`o_rx_pipe_upen` 直接汇总每一级 `com_pipe_vld_single` 的输入握手。
  4. `clear` 会同步清空所有级的 valid 状态；payload 寄存器若需要同步丢弃，也应由外部数据通路配合处理。

## com_pipe_rdy

* 功能

  `com_pipe_rdy` 是带 payload 的单级 ready 管线，用一项 skid buffer 寄存反压。未发生阻塞时，输入数据和 valid 组合直通到输出，`o_rx_rdy` 保持为 `1`；下游突然拉低 ready 时，本模块仍可接收并缓存当前输入项，随后拉低上游 ready，直到缓存项被下游接收。

* 接口时序

  下图以 `DW=8` 展示 A1/C3 的直通传输，以及 B2/D4 在反压到来时被缓存并在下游恢复 ready 后输出的过程。

  ![com_pipe_rdy 接口时序](assets/com_pipe_rdy_wavedrom.png)

* 参数

  | param_name | range   | default_value | description  |
  | ---------- | ------- | ------------- | ------------ |
  | `DW`       | `[1::]` | `8`           | payload 位宽 |

* 接口

  | signal_name | bit_width | I/O | description                                              |
  | ----------- | --------- | --- | -------------------------------------------------------- |
  | `i_rx_dat`  | `DW`      | I   | 上游输入 payload                                         |
  | `i_rx_vld`  | `1`       | I   | 上游输入有效指示                                         |
  | `o_rx_rdy`  | `1`       | O   | 上游输入接收就绪，由寄存的 ready 状态输出                |
  | `o_tx_dat`  | `DW`      | O   | 下游输出 payload，直通模式取输入，缓存模式取缓存寄存器   |
  | `o_tx_vld`  | `1`       | O   | 下游输出有效指示，缓存模式下保持为 `1`                   |
  | `i_tx_rdy`  | `1`       | I   | 下游接收就绪指示                                         |

* 实现说明

  1. `r_rdy_flag=1` 表示直通模式：`o_rx_rdy=1`，`o_tx_dat/o_tx_vld` 直接来自输入端。
  2. 在直通模式下，如果 `i_rx_vld=1` 且 `i_tx_rdy=0`，输入项已被上游握手接受，但不能发往下游；该项在时钟边沿锁存到 `r_rdy_buf`，并进入缓存模式。
  3. `r_rdy_flag=0` 时，上游被反压，输出持续给出 `r_rdy_buf` 中的缓存项；缓存项与下游握手后，下一拍返回直通模式。
  4. 缓存项被消费的当拍 `o_rx_rdy` 仍为 `0`，因此该结构在一次缓存阻塞释放后不会同拍接收替换项。
  5. 复位或 `clear` 将模块恢复到直通模式；若 `clear` 发生时缓存中仍有有效项，该项会被丢弃。

## com_pipe_vld_rdy

* 功能

  `com_pipe_vld_rdy` 是单级 valid/ready 数据管线，可分别打开 ready 侧 skid buffer 和 valid 侧输出寄存。`RDY_PIPE_EN=1` 时使用 `com_pipe_rdy` 隔离上游 ready 路径，并在下游反压突然到来时额外吸收一拍数据；`VLD_PIPE_EN=1` 时使用 `com_pipe_vld` 控制输出 valid，并用内部 payload 寄存器保存输出数据。

* 接口时序

  下图以 `VLD_PIPE_EN=1`、`RDY_PIPE_EN=1`、`DW=8` 展示默认结构：正常传输时输出延迟一拍，下游反压时 ready 侧缓存 D4，反压解除后继续输出。

  ![com_pipe_vld_rdy 接口时序](assets/com_pipe_vld_rdy_wavedrom.png)

* 参数

  | param_name    | range   | default_value | description                         |
  | ------------- | ------- | ------------- | ----------------------------------- |
  | `VLD_PIPE_EN` | `0/1`   | `1`           | 是否使能 valid 侧输出寄存           |
  | `RDY_PIPE_EN` | `0/1`   | `1`           | 是否使能 ready 侧 skid buffer       |
  | `DW`          | `[1::]` | `8`           | payload 位宽                        |

* 接口

  | signal_name | bit_width | I/O | description                                |
  | ----------- | --------- | --- | ------------------------------------------ |
  | `i_rx_dat`  | `DW`      | I   | 上游输入 payload                           |
  | `i_rx_vld`  | `1`       | I   | 上游输入有效指示                           |
  | `o_rx_rdy`  | `1`       | O   | 上游输入接收就绪，来自 ready 侧管线        |
  | `o_tx_dat`  | `DW`      | O   | 下游输出 payload                           |
  | `o_tx_vld`  | `1`       | O   | 下游输出有效指示，来自 valid 侧管线        |
  | `i_tx_rdy`  | `1`       | I   | 下游接收就绪指示                           |

* 实现说明

  1. ready 侧先处理输入数据和上游 ready；关闭 `RDY_PIPE_EN` 时，输入数据、valid、ready 直接透传到 valid 侧。
  2. valid 侧后处理输出 valid 和 payload；关闭 `VLD_PIPE_EN` 时，ready 侧输出直接透传到模块输出。
  3. 默认两个开关都打开时，模块提供一拍输出寄存和一拍 ready 侧缓存能力；它能隔离 valid/data 与 ready 两条常见长路径。
  4. `clear` 同时作用于内部 ready 管线和 valid 管线：ready 侧回到直通，valid 侧清空输出有效状态。

## com_pipe_regslice

* 功能

  `com_pipe_regslice` 是多级 valid/ready 数据寄存切片，由 `PIPE_NUM` 个 `com_pipe_vld_rdy` 串联构成，并固定每级 `VLD_PIPE_EN=1`、`RDY_PIPE_EN=1`。它用于在长数据通路或握手通路上插入多级寄存，改善时序，同时保持标准 valid/ready 反压语义。

* 接口时序

  下图以 `PIPE_NUM=2`、`DW=8` 展示两级 regslice 的外部行为：无反压时 payload 经过两级寄存后输出；下游反压会逐级回传到上游。

  ![com_pipe_regslice 接口时序](assets/com_pipe_regslice_wavedrom.png)

* 参数

  | param_name | range   | default_value | description |
  | ---------- | ------- | ------------- | ----------- |
  | `PIPE_NUM` | `[1::]` | `2`           | regslice 级数 |
  | `DW`       | `[1::]` | `8`           | payload 位宽 |

* 接口

  | signal_name | bit_width | I/O | description                         |
  | ----------- | --------- | --- | ----------------------------------- |
  | `i_rx_dat`  | `DW`      | I   | 上游输入 payload                    |
  | `i_rx_vld`  | `1`       | I   | 上游输入有效指示                    |
  | `o_rx_rdy`  | `1`       | O   | 第 `0` 级对上游给出的接收就绪       |
  | `o_tx_dat`  | `DW`      | O   | 最后一级输出 payload                |
  | `o_tx_vld`  | `1`       | O   | 最后一级输出有效指示                |
  | `i_tx_rdy`  | `1`       | I   | 下游接收就绪指示                    |

* 实现说明

  1. 第 `0` 级输入连接模块输入，最后一级输出连接模块输出；相邻级之间数据、valid 正向连接，ready 反向连接。
  2. `o_rx_rdy` 取第 `0` 级 ready，`o_tx_dat/o_tx_vld` 取最后一级输出。
  3. 当 `PIPE_NUM=1` 时，模块等价于一个默认配置的 `com_pipe_vld_rdy`。
  4. 当 `PIPE_NUM>1` 时，每级都包含 valid 输出寄存和 ready 侧 skid buffer；无反压情况下输出延迟约为 `PIPE_NUM` 拍。
  5. `clear` 会清空所有级的 valid 状态，正在各级中传递但未完成输出握手的数据会被丢弃。

## com_simo_no_delay

* 功能

  `com_simo_no_delay` 是单输入、多输出的无延迟广播握手控制模块。输入 `i_rx_vld` 直接组合生成各输出通道的 `o_tx_vld`，某个输出通道完成握手后会被内部标记为已接收，后续不再重复向该通道拉高 valid。只有全部输出通道都已接收当前输入项，或者在同一拍可以接收当前输入项时，模块才向上游给出 `o_rx_rdy`。模块不包含 payload 数据端口，使用者需要在 `i_rx_vld=1` 且 `o_rx_rdy=0` 期间保持外部 payload 稳定。

* 接口时序

  下图以 `CH_NUM=3` 展示输出通道依次接收同一输入项，以及全部通道完成后输入侧握手推进到下一项的过程。

  ![com_simo_no_delay 接口时序](assets/com_simo_no_delay_wavedrom.png)

* 参数

  | param_name | range   | default_value | description  |
  | ---------- | ------- | ------------- | ------------ |
  | `CH_NUM`   | `[1::]` | `1`           | 输出通道数量 |

* 接口

  | signal_name | bit_width | I/O | description                                                |
  | ----------- | --------- | --- | ---------------------------------------------------------- |
  | `i_rx_vld`  | `1`       | I   | 上游输入有效指示                                           |
  | `o_rx_rdy`  | `1`       | O   | 上游输入接收就绪，所有输出通道完成当前项接收时为 `1`       |
  | `o_tx_vld`  | `CH_NUM`  | O   | 各输出通道有效指示；已接收当前项的通道会被屏蔽             |
  | `i_tx_rdy`  | `CH_NUM`  | I   | 各输出通道接收就绪指示                                     |

* 实现说明

  1. `r_outed_flag` 记录每个输出通道是否已经接收当前输入项。
  2. `o_tx_vld = {CH_NUM{i_rx_vld}} & ~r_outed_flag`，因此 valid 只发给尚未接收当前项的输出通道。
  3. `out_all_hs` 汇总已接收通道和本拍可握手通道；当所有 bit 都为 `1` 时，`o_rx_rdy` 拉高。
  4. 输出通道握手会置位对应 `r_outed_flag`；输入侧握手完成后，所有 flag 清零并开始处理下一项。
  5. 模块只负责握手广播，不保存数据；若外部 payload 不能自然保持稳定，需要在上游或外围增加保持逻辑。

## com_edge_detect

* 功能

  `com_edge_detect` 对输入电平 `i_level` 做边沿检测，并根据 `MODE` 输出单周期脉冲。模块用 `r_level` 保存上一拍输入电平，当前输入与上一拍值比较后产生上升沿、下降沿或双边沿脉冲。`o_pulse` 是当前 `i_level` 与寄存历史值的组合结果，因此适合用于同步电平信号的边沿提取。

* 接口时序

  下图对比 `pos`、`neg`、`dual` 三种模式下同一组 `i_level` 变化对应的输出脉冲。

  ![com_edge_detect 接口时序](assets/com_edge_detect_wavedrom.png)

* 参数

  | param_name | range                                      | default_value | description      |
  | ---------- | ------------------------------------------ | ------------- | ---------------- |
  | `MODE`     | `pos/posedge/neg/negedge/dual/dualedge`    | `"pos"`       | 边沿检测模式     |

* 接口

  | signal_name | bit_width | I/O | description                                |
  | ----------- | --------- | --- | ------------------------------------------ |
  | `i_level`   | `1`       | I   | 待检测的同步输入电平                       |
  | `o_pulse`   | `1`       | O   | 检测到目标边沿时拉高一个周期的脉冲         |

* 实现说明

  1. `r_level` 在每个时钟沿锁存 `i_level`，作为上一拍电平。
  2. 上升沿检测为 `i_level && !r_level`，下降沿检测为 `!i_level && r_level`，双边沿检测为 `i_level ^ r_level`。
  3. `generate` 根据 `MODE` 选择输出逻辑，并通过 `COM_PARAM_ASSERT` 检查参数合法性。
  4. 因为 `o_pulse` 是组合输出，如果 `i_level` 来自异步域或存在毛刺，需要先在外部完成同步和滤波。

## com_counter

* 功能

  `com_counter` 是带启动控制的参数化计数器。`i_cnt_start` 有效时，模块锁存当拍 `i_cnt_max_m1`，并从下一拍开始拉高 `o_cnt_en`、由 `INIT` 开始按 `STEP` 计数。当下一次计数值将超过锁存的最大值时，`o_cnt_last` 拉高；若 `o_cnt_last` 同拍再次收到 `i_cnt_start`，新配置会立即生效并重新开始计数。

* 接口时序

  下图展示第一次启动计数到 `3`，随后在 `o_cnt_last` 同拍重新启动并改为计数到 `2` 的过程。

  ![com_counter 接口时序](assets/com_counter_wavedrom.png)

* 参数

  | param_name | range   | default_value | description  |
  | ---------- | ------- | ------------- | ------------ |
  | `CW`       | `[1::]` | `8`           | 计数位宽     |
  | `STEP`     | `[1::]` | `1`           | 每拍递增步长 |
  | `INIT`     | `[0::]` | `0`           | 启动初始值   |

* 接口

  | signal_name      | bit_width | I/O | description                                      |
  | ---------------- | --------- | --- | ------------------------------------------------ |
  | `i_cnt_max_m1`   | `CW`      | I   | 本次计数最大值减一，仅在 `i_cnt_start` 当拍有效  |
  | `i_cnt_start`    | `1`       | I   | 启动计数，并锁存本次计数终点                     |
  | `o_cnt`          | `CW`      | O   | 当前计数值                                       |
  | `o_cnt_en`       | `1`       | O   | 当前计数值有效指示，等于内部计数使能             |
  | `o_cnt_last`     | `1`       | O   | 当前有效计数项为本次计数末项                     |

* 实现说明

  1. `r_cnt_max_m1` 是无复位寄存器，只在 `i_cnt_start=1` 时锁存 `i_cnt_max_m1`。
  2. `r_cnt_en` 先响应 `i_cnt_start`，再处理 `o_cnt_last`，因此 last 同拍 start 可以马上重新进入下一轮计数。
  3. `o_cnt_en` 直接等于 `r_cnt_en`；启动脉冲后一拍才开始输出有效计数。
  4. `r_cnt` 在复位、`clear` 或 `i_cnt_start` 时回到 `INIT`；计数使能期间按 `STEP` 递增。
  5. `o_cnt_last = r_cnt_en && (cnt_nxt > {1'b0, r_cnt_max_m1})`，用下一拍候选值判断当前项是否为末项。

## com_sync_fifo

# com_axi

# com_csr
