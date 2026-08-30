## AI工作记录

本文档用于按时间线记录项目开发过程中的重要事情。记录粒度约为每周一次，也可以在关键决策、关键修改完成后补充。记录内容要能帮助以后复现当时的修改背景、范围、规则和检查结果。

当前阶段重点: 增量开发 RTL。上一阶段 RTL 风格统一与 common RTL 文档模板/简单模块功能描述已结束。

### 记录原则

- 按时间线记录，优先使用具体日期或周范围。
- 每条记录包含背景、修改范围、关键规则、重要反馈、验证方式。
- 尽量精简，不限制固定字数；只记录对后续复现有帮助的信息，避免流水账。
- 用户反馈形成的新规则，要同步写入本文档。
- 代码中仍遵守 RTL 风格要求：注释使用英文，RTL 代码中不出现中文。

## 时间线

### 2026-05-24: 启动 RTL 风格统一化

- 启动 RTL 风格统一，顺序为 `common/*.sv`、`common/fifo/*.sv`、`axi/*.sv`，其他目录暂不动。
- 确认派生参数保持 `localparam`，局部临时变量允许就地 `wire xxx = expr;`，例化连接信号集中声明并用 `u_*` 命名。
- 统一 `com_find_lsb_first_one`、`com_arbiter_rr`、`com_reg*`、`com_pipe*`、`common/fifo/*` 的声明区、端口前缀、例化命名、always/generate 格式。
- `com_reg*` 数据/使能/输出端口补 `i_`、`o_` 前缀，`clk/rst_n/clear` 保持原约定；模块外层 `ifndef/define/endif` 删除。
- `com_simo_no_delay` 端口为 `i_rx_vld/o_rx_rdy/o_tx_vld/i_tx_rdy`，参数 `OCH` 改为 `CH_NUM`。
- `com_pipe_vld`、`com_pipe_regslice` 保留 `gen_pipe_chain` 显式级联，不在实例端口里使用 `[gi+1]`；`com_pipe_vld_rdy` 的 unused pipe upen 端口保持悬空。
- `com_counter` 端口改为 `i_cnt_start/o_cnt_en`，start 仅采样并置起下一拍 `r_cnt_en`，`o_cnt_en` 只等于 `r_cnt_en`。
- 重点问题：output assign 不能引用尚未声明的信号；这类信号必须提前在 signal declare 区域声明，再在 body 区域 `assign` 赋值。该问题已在 `out_all_hs`、`cnt_nxt` 出现，后续必须重点检查。
- 暂不处理 common 外部集成，已跑 `git diff --check`。

### 2026-05-26 至 2026-05-29: common RTL 文档编写阶段收尾

- 编写 `common_rtl_manual.md`，概述表统一放在最前面；模块细节按 `common_ip`、`com_fifo` 等分组展开。
- `com_arbiter_rr`、`com_find_lsb_first_one` 已补文档和 WaveDrom 时序图；默认只写“功能/接口时序”，明确要求时再补“参数/接口/实现说明”。
- `com_pipe*` 已完整说明并补时序图；图中不体现 `rst_n/clear`。`com_reg*` 只说明功能，不写时序、参数和接口。
- `com_simo_no_delay`、`com_edge_detect`、`com_counter` 已完整说明；`com_edge_detect` 的 dual edge 图需同时体现上升沿和下降沿 pulse。
- `com_sync_fifo_reg`、`com_dp_buffer`、`com_dp_ram` 已放到 `## com_fifo` 分组下完整说明；后续 FIFO 系列都按该分组方式记录。
- FIFO 重要规则：`o_wr_full/o_rd_empty/o_water_level` 都是寄存输出。`com_sync_fifo_reg` 时序图使用 `DEPTH=2` 展示 full；当 `o_wr_full=1` 且本拍 `rd_en=1` 时，本拍仍不能写，下一拍 full 拉低后才能写。
- `com_dp_buffer` 时序图要求上游在 `o_rx_rdy=0` 时保持 `i_rx_vld` 和当前 payload，直到重新握手。
- 本地使用 `doc/tools/wavedrom_json_to_png.py` 调用 `wavedrom-cli` 将 WaveDrom JSON 转 PNG；生成资产放在 `doc/assets`。
- Git 记录：文档阶段已提交 `36e30e1 docs: expand common RTL manual` 并 push；随后 FIFO 文档提交 `d7b7ba1 docs: add fifo common manual sections`，仅本地提交未 push。
- 当前阶段结论：已给出文档模板和一批简单模块功能描述，后续文档按该模板增量补充。

### 2026-05-30: 增量开发 RTL（计划）

- FIFO 增量模块：开发 `com_sync_fifo_reg_v2`、`com_sync_fifo_reg_pfetch`、`com_sync_fifo_reg_rwfull`、`com_sync_fifo_reg_2w1r` 的 RTL 和文档，并比较它们与 `com_sync_fifo_reg` 的差异。
- CDC 相关：开发 `pulse/async_fifo`。
- 仲裁相关：开发 `com_arbiter_wrr`、`com_ram_arbiter`。

### 2026-05-30 至 2026-06-19: FIFO 增量 RTL 与微架构文档

- 已完成/推进 FIFO 增量模块：`com_sync_fifo_reg_v2`、`com_sync_fifo_reg_pfetch`、`com_sync_fifo_reg_fullbyp`、`com_sync_fifo_reg_2w1r`、`com_sync_fifo_ram_1p1bank`、`com_sync_fifo_ram_1p2bank`。
- `com_sync_fifo_reg_v2` 与基础 `com_sync_fifo_reg` 功能一致，重写指针和 water level 逻辑，只保留一个剩余可写计数语义。
- `com_sync_fifo_reg_pfetch` 使用输出数据预取，让 `o_rd_data` 成为寄存输出；限制 `DEPTH>=2`，代价是多数数据会多一次搬运。
- `com_sync_fifo_reg_fullbyp` 命名从 rwfull 收敛为 full bypass 语义：full 且同拍读出时允许写入，能减少使用深度，但读写时序路径存在耦合。
- `com_sync_fifo_reg_2w1r` 支持 fast reserve / slow fill：fast miss 先占位，slow 后填真实数据；empty 使用真实数据尾指针判断。关键命名包括 `r_slow_avl_flag`、`o_wr_slow_avl_flag`、`r_wr_fast_hit_again_flag`。
- `com_sync_fifo_ram_1p1bank` 使用 1 个 `2*DW` 单口 SRAM row 存两笔数据；读返回 low half 直接 slow fill，high half 用 1DW DFF 暂存。SRAM 读延时改为参数 `RAM_RD_DELAY`，范围 `[1:16]`，不再依赖外部 `i_ram_rd_data_vld`。
- `com_sync_fifo_ram_1p2bank` 使用两个 `DW` 单口 bank，去掉 ibuf 思路，冲突时写优先、read hold 一拍，通过加深 out_fifo 吸收，不再做额外 data move。
- 统一结论：`com_sync_fifo_ram_1p1bank` 与 `com_sync_fifo_ram_1p2bank` 的输出 FIFO 最小深度都使用 `OUT_DEPTH >= RAM_RD_DELAY + 3`，覆盖 SRAM 固定读延时、返回/预留节奏以及一次写优先 read hold。
- `common_rtl_uarch.md` 只记录复杂模块，模板调整为“概述 / 模块框图 / 设计细节 / 讨论记录”。`fifo_ram` 两个模块已按新模板整理；讨论表格保留在可选“讨论记录”。
- `common_rtl_manual.md` 已补 `com_sync_fifo_ram_1p1bank` 说明，包含功能、接口时序、参数、接口和实现说明；`1p2bank` 后续需要继续与最新 RTL/uarch 对齐。
- 复杂框图统一放到 `doc/assets/common_ip_uarch.drawio`，按模块页面维护；已导出 `com_sync_fifo_ram_1p1bank_uarch.png`，`1p2bank` 导出时曾遇到 draw.io 页面索引不稳定，需要后续确认导出页是否正确。
- 文档编码注意：曾因 PowerShell 默认编码读写导致 `common_rtl_uarch.md` 中文变成乱码；后续中文 Markdown 优先用 UTF-8 严格读写，并检查是否残留常见乱码字符。
- 权限/流程注意：若删除文件、draw.io 导出或 git index lock 处理超过 1 分钟，应暂停并提示用户，不继续绕权限问题耗时。

### 2026-06-19 至 2026-06-28: Async FIFO 与 CDC 开发

- 完成 `com_async_fifo_reg`：register array 保存数据，读侧用 `out_dff` 隔离 CDC 路径；指针采用完整 binary-to-Gray 编码并选取 Gray code 头尾两段，支持任意 `DEPTH>=1`。
- 基础 AFIFO 的 `out_dff` 提供额外一项弹性，最大暂存量为 `DEPTH+1`；`o_wr_full/o_water_level` 是写域基于同步后读指针得到的保守状态，空间释放存在 CDC 延时，water level 不表示严格总容量。
- 新增 `com_async_fifo_reg_exactwl`，使用 `fetch_ptr/rd_ptr` 双读指针：预取只推进 `fetch_ptr`，用户读出才推进 `rd_ptr`，因此逻辑容量严格为 `DEPTH`，代价是写侧空间释放更晚且少一项弹性。
- 多时钟域代码统一使用 `cksrc_/ckdst_`、`ckwr_/ckrd_` 区分内部信号，并通过 `SYNC_S` 配置 `com_cdc_sig` 同步级数；异步设计不增加 `clear`，两侧直接使用各自复位。
- 完成 `com_cdc_handshake`：使用 toggle req/ack 传递单 bit 请求脉冲，目标侧产生单拍请求后自动应答，只允许一个请求在途；`busy` 保持为 req/ack toggle 不一致的组合判断，不额外增加 DFF。
- 重写 `com_cdc_rstn`，实现复位异步拉低、按目标时钟同步释放；新增 `com_cdc_rstn_pair`，合并 src/dst 两侧原始复位源，任一来源复位都会让两侧立即复位，两侧随后按各自时钟独立同步释放。
- `common_rtl_uarch.md` 已补两个 AFIFO 的框图和设计说明；`common_rtl_manual.md` 新增 `## com_cdc`，补齐 AFIFO、`com_cdc_sig`、handshake、reset 模块的功能、参数和接口，并为 handshake 生成 WaveDrom 时序图。
- CDC RTL 核心功能基本完成；后续仍需清理 filelist 中失效的 `com_cdc_pulse/com_async_fifo_ctrl`，对接真实 synchronizer stdcell、增加 Gray bus skew/max-delay 约束，并补异步随机仿真或 formal 检查。

### 2026-06-28 至 2026-06-30: common_ip 仲裁与 RAM 适配模块收尾

- 完成 `com_arbiter_wrr/com_arbiter_iwrr`。weight 固定 4 bit、零基编码，实际配额为 `weight+1`；WRR 连续服务配额，IWRR 按 sub-round 交织配额。`i_cfg_weight`作为准静态 CSR 配置，活跃仲裁期间使用 shadow weight。
- 统一 RAM valid/ready 接口：write valid 同时作为分段 strobe，read 使用 request `vld/rdy`和无反压返回 `ack/data`；`RAM_RD_DELAY`包含 SRAM、ECC 和 regslice 的固定总延时。
- 完成 `com_ram_arbiter`：写、读通道分别 round-robin 仲裁，读 grant onehot 按固定延时保存并路由返回；模块不处理最终单口/双口优先级和同地址语义。
- 完成 `com_ram_adp_sp`：将独立 RAM 读写握手转换为单口 SRAM `ce_n/we_n`，同拍冲突按 `WR_PRIORITY`选择；strobe bit `i`控制对应连续数据分段。
- 完成 `com_ram_adp_rmw`：RX 多 bit partial write 先发 TX read，再合并旧数据并输出 1 bit full-write valid；普通 full write/read 无额外寄存延时，普通 read 禁止从内部 buffer forwarding，必须实际发起 TX read。
- RMW 功耗优化：读上下文拆为 1 bit `rdflag_fifo`和仅 partial write 活动的宽位 `rmw_info_fifo`；`rmw_wb_fifo`保存合并结果。三个 FIFO 和在途地址表深度均为 `RAM_RD_DELAY+1`，覆盖无反压 read ack；同地址请求等待旧 RMW 写回，不同地址 partial write 可背靠背访问。
- RMW TX write 固定优先级为 `rmw_wb > direct_write`，优先排空不可反压 read ack 产生的写回数据。Manual 已补 WaveDrom，标注不同地址稳态吞吐为每拍一笔 partial request 和一笔 full writeback，首笔写回延时为 `RAM_RD_DELAY+1`。
- 完成 `com_ram_adp_2sp`：`addr[0]`选择两个交织 single-port SRAM bank；不同 bank 读写同拍执行，同 bank 冲突按 `WR_PRIORITY`选择，读 bank 与 valid 延迟后选择返回数据。
- 新增代码规则：端口未使用的派生 `localparam`放到 signal declare 之前；参数参与运行时信号比较时先转换为 `tie_*`线网，便于 lint/覆盖率统一 waive；`STRB_DW`统一命名为 `SUB_DW`。
- AFIFO 增加 Gray 指针断言：仅在上一拍握手且已退出复位时，用 `$onehot(cur_gray^$past(cur_gray))`检查源时钟域指针恰好变化 1 bit；不对目标域同步后指针做该检查。
- 根据 `com_define.sv`宏展开，清理 `common/`全部 RTL 断言宏调用末尾的多余分号；property label 的冒号只由宏内部生成。`com_common.f`暂不增量修改，待 common_ip 模块全部整理后统一更新。

### 2026-07-01 至 2026-07-17: memory template 与 mem_tool 开发

- 整理 `impl_template/memory` 结构：`rtl/shell` 保存可人工维护的 shell RTL，`mem_tool/src` 保存生成脚本，`templates/rtl` 保存独立 sim 所需的最小 RTL 副本，`templates/sim` 保存可手工运行的独立仿真模板，`templates/py_sim/gen_tb.py` 用于脚本化生成同结构 sandbox。
- 新增/调整 `com_ecc_secded`，默认走 Synopsys `DW_ecc`，定义自研宏时使用项目内 SECDED 实现；控制信号改为 `i_correct_n`，低有效关闭纠错。`COM_MEM_CTRL_W/COM_ECC_CTRL_W/COM_SRAM_W` 等项目实现相关宏移到 `impl_define`，不再放入 `com_define.sv`。
- 按当前 RTL 风格重构 memory shell：`com_spram_shell`、`com_tpram1ck_shell`、`com_tpram2ck_shell`、`com_sprom_shell` 及 ECC 版本统一端口、例化对齐和 report 逻辑；`COM_REPORT_OFF` 控制 report 关闭，report 区域用 `synopsys translate_off/on` 隔离。
- ECC shell 保持 `{lst_ecc_data,nrm_ecc_data*n,ori_ram_data}` 存储顺序；每个 row 额外记录 partial-write flag，partial write 后不做 ECC decode，避免旧 ECC 与部分写数据不一致导致误报。
- `COM_RAM_NFOUND_CHK` 语义改为严格检查：未定义时未命中 PHY 默认回退 RTL model；定义后若存在未被 SRAM PHY 实现的 shape，故意例化 `*_not_found` 触发编译失败。
- Python 脚本重构为 CLI 驱动：`main.py` 统一 `init/sim/excel/inst/all` 模式；配置可来自 CLI 或 JSON，CLI 显式参数覆盖 JSON。`--gen_config_json` 默认生成 `all` 配置，也可指定 `init/excel/inst/sim/all`。
- JSON 最小配置已定义：`excel/all` 模板包含 `clk_a/clk_b`，对应 CLI 短参数 `-cka/-ckb`；旧 `-xcka/-xckb` 已移除。`all` 模式按 `init -> sim -> excel -> inst` 顺序执行，不包含后端生成 SRAM PHY 和最终 PHY 覆盖检查。
- `sim` 模式基于 `templates/py_sim + templates/rtl` 生成 `build/sim`，每次安全重建目录，`rtl.f` 分为 `define / implement(stdcell/sram) / project` 三段；生成目录不依赖 `COM_ROOT`、不包含 `com_define.sv`，也不拷贝 `check_sync.py`。
- `sim_no_run=true` 时只生成 sandbox，filelist 缺失或格式问题降级为 warning；默认运行时严格检查 filelist，随后固定执行 `make com` 和 `make run`，不再支持 `sim_target`。
- `templates/rtl/check_sync.py` 仅在存在 `COM_ROOT` 时检查内置 RTL 副本是否与源文件同步；没有 `COM_ROOT` 时跳过，保证 mem_tool 独立目录也可运行。
- README 已按“简介 / 用户指南 / RTL集成说明 / 脚本开发者”重写，补充前后端交互流程、`subsys_prefix/MEM_USER` 隔离规则、cfg_mem/ecc_ctrl 来源、ECC shell 集成、JSON 配置和 sim sandbox 用法。
- 验证方式以 `python .\src\main.py --gen_config_json ...`、`python .\src\main.py -c ...`、`python .\src\main.py -m sim --sim_no_run` 等命令为主；部分 `unittest` 在 Windows sandbox 下因 `tempfile.TemporaryDirectory()` 清理权限失败，属于当前环境限制，失败后需清理残留 `build/tmp*`。

### 2026-07-18 至 2026-08-24: AXI/DMA、FIFO RAM 与开源仿真环境

- 按 `coding_style.md` 整理 `axi/` RTL；`com_axi_extd_wr/com_axi_extd_rd` 尽量只改必要端口，DMA 内 SRAM shell 更新为新的 `impl_template/memory` 接口。
- 新增 `axi/py_gen_dma`：通过 JSON 配置生成 `${prefix}_axi_dma`，同步替换 subsystem 专属 SRAM shell 名称，并配置各 read data buffer 的深度、宽度和 SRAM 尺寸。README 使用中文说明生成流程和配置项。
- 新增 `common_rtl_dma_manual.md`，补充 DMA 微架构框图、EBUS/AXI 接口、读写 burst 拆分、读 buffer 和超发限制。以 `DW=256bit`、非对齐地址和跨多次 AXI burst 的例子说明 `ebus_bytelen`、`axi_wstrb`、多次 AXI response 合并为一次 EBUS response 的过程。
- 修复 `com_arbiter_rr` 在 grant 未 ready 时新请求到来导致 `gnt_idx`变化的问题；grant 必须保持到握手。同步检查 WRR/IWRR，没有保留同类不稳定选择路径。
- `com_sync_fifo_ram_1p2bank` 增加按需 ibuf：仅在 SRAM full、out_fifo 有预留空间且读写 bank 冲突时暂存写数据，下一拍写入刚释放的位置；常规路径不做额外 data move，优先功耗和面积。
- FIFO RAM 读控制命名由 `rd_resv`统一为 `rd_prefill`，表达“提前为 SRAM 返回数据预留 out_fifo 空间”；读冲突使用 `r_rd_hold_vld`保持请求，读请求被 hold 时不推进 RAM read pointer。
- 对齐 `com_sync_fifo_ram_1p1bank/1p2bank/2p1ck` 的 direct write判断：除 `ram_otf_cnt`外，还必须考虑 `com_sync_fifo_reg_2w1r` 的 slow-fill 待完成范围，避免 fast reserve 已满时直接写入破坏顺序。
- 建立 `com/sim` 验证环境：`sim_fifo`覆盖寄存 FIFO和三类 RAM FIFO，`sim_afifo`覆盖基础/精确水线 AFIFO；另有 `sim_arbiter/sim_axi/sim_cdc/sim_pipe/sim_ram/sim_simo`。波形文件统一放在各目录的 `wave/*.gtkw`和 `wave/*.rc`。
- `sim_fifo`支持 `CASE`选择，完整矩阵覆盖 RAM FIFO 的 `RAM_RD_DELAY=1~8`；本轮定位并修复 FIFO RAM 的 full、prefill、slow reserve 和 bank conflict 边界问题，最终30组用例全部通过。
- `py_tools_for_hw/py_rtl_sim`统一为 `gen_tb_demo`模板及 AXI/APB/AHB VIP；生成环境包含 `ENV.sh/Makefile/rtl.f/testbench.f/tb/`，运行产物固定放在 `bin/`。AXI VIP默认 1 master to 1 slave，先连续写、再连续读并检查数据。
- 安装并验证 WSL2 Ubuntu 下的 OSS CAD Suite/开源工具链，主要使用 Verilator编译仿真、GTKWave查看 FST、Yosys综合；Windows OSS工具不再作为主要环境。Makefile统一提供 `vlt/vlt_com/vlt_run/vlt_wave`。
- 所有 `com/sim/sim_*` TB 已统一为 clocking block上升沿驱动，去掉下降沿激励和 `#1ps`。单时钟使用 `drv_cb`，CDC/AFIFO按写域和读域分别使用 clocking block；普通接口采用 `input #1step/output #0`。
- FIFO driver为保持背靠背性能，使用双采样视图：`mon_cb input #1step`结算本拍握手，`drv_cb input #0/output #0`读取边沿后 `full/empty/data`并产生下一拍命令，避免 RAM FIFO预取期间使用旧 empty继续发读。
- Verilator 5.032支持 clocking block和 `vif.drv_cb`，但不支持 `modport drv(clocking drv_cb)`；AXI TB改用完整 virtual interface。最终 `SIM_SIMO/PIPE/ARBITER/RAM/CDC/AFIFO/FIFO`及 AXI `extd_wr/extd_rd/dma`全部通过。
