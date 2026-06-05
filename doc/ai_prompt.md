# 计划

1. 给common_ip统一代码风格+写文档, com_xx/com_fifo/com_cdc;
2. 给csr_tool和配套rtl模块写文档;
3. 给com_axi统一代码风格+写文档;
4. gen_testbench, win_os仿真/lint检查/开源后端工具, linux仿真;
5. 给com_img统一代码风格+写文档;  //TBD


# 工作约定

- Git默认只进行本地提交；仅在明确要求时执行`git push`。
- `ai_answer.md`时间线尽量精简但不限制固定字数，保留可复现的重要规则和结果。


# 文档模板

* 参数

| param_name | range | default_value | descrition |
| ---------- | ----- | ------------- | ---------- |

* 接口

| signal_name | bit_width | I/O | descrition |
| ----------- | --------- | --- | ---------- |


# 临时记录

2026/5/24 rtl代码风格修改:
- com_simo_no_delay, (1)i_vld改成i_rx_vld, o_vld改成o_tx_vld,  rdy信号同理; (2)out_all_hs在out赋值的地方有语法错误，因为还没声明。  out_all_hs属于重要的信号，可以在signal_declare区域先声明，后面用assign赋值。 只有"局部临时变量"用wire声明并赋值精简代码量。
- com_reg_*已符合要求
- com_pipe_vld,  u_pipe_o_tx_vld信号，保留[gi+1]的写法, 删除if( PIPE_NUM > 1 ) begin:gen_pipe_chain;
- com_pipe_vld_rdy, u_vld_o_rx_pipe_upen信号删除, 原始端口悬空就让他悬空;
- com_pipe_regslice, 同com_pipe_vld,  保留[gi+1]的写法, 删除if( PIPE_NUM > 1 ) begin:gen_pipe_chain;
- com_simo_no_delay, OCH改名CH_NUM
- com_pipe_vld/com_pipe_regslice, 还是用gen_pipe_chain，不要[gi+1]的写法
- com_pipe*已符合要求
- com_counter, cnt_nxt有语法问题, 提前声明;  这个问题出现了2次以上了，重点记录;
- ai_answer, ### 2026-05-24: 当天的更新， 用"列表"即可， 不用多次###三级标题
- com_counter端口变化:改成i_cnt_start + o_cnt_en, (1) i_cnt_max_m1只在i_cnt_start的时候有效， 内部用一个无复位dff锁存下来,  (2) 在cnt_done的时候来了cnt_start, 可马上重新开始计数;

2026/5/24 fifo:
- com_sync_fifo_ram_2p1ck + com_async_fifo_ctrl + com_async_fifo_reg + com_sync_fifo_ram_1p2bank这几个模块功能未更新，暂时不修改，还原以前git版本(我已完成);
- fifo剩余:
  - (1) 只保留com_async_fifo_reg, 不需要com_async_fifo_ctrl, ckwr_xx, ckrd_xx区分读写侧各自的时钟信号;  (2) com_sync_fifo_ram_2p1ck + com_sync_fifo_ram_1p1bank(位宽翻倍, 深度减半)
  - com_sync_fifo_reg_2w1r, 为了 com_sync_fifo_ram_*;
  - com_sync_fifo_reg_pfetch, 读数据也reg_out输出, 但数据搬运了两次, 功耗表现不好;
  - com_sync_fifo_reg_fullbyp; 当fifo full但有读的时候，也可以写入数据; 这样fifo深度可以减少1个, 节省面积; 但导致读写两侧时序路径有耦合, 时序不干净; 取决于使用场景;
- 检查修改:
  - com_sync_fifo_reg, rd_addr要在前面声明;
  - 强调signal_decalre区域的信号: (1) 全部dff, (2) 重要的wire类型或用来赋值输出信号的变量, 只声明不赋值, 后续用assign赋值; (3) 所有instance_signal;  (4) 原有代码body区域, wire声明并赋值的局部变量, 看情况一般不用调整.


2026/5/26 doc:
- 每个模块文档， 总共有"功能/接口时序/参数/接口/实现说明"几个章节, 一般只有""功能/接口时序"章节已足够， 明确要求的模块， 增加"参数/接口/实现说明"章节;
- com_find_lsb_first_one删除"参数/接口/实现说明"， 精简篇幅， 仅在明确要求的时候才产生"参数/接口/实现说明"章节。
- 用wavedrom画时序图， 本地PC的vscode有wavedrom插件， 可以直接wavedrom.json->png, 不用联网。
- wavedrom插件， gpt做json->png耗时太长， 生成一个python脚本来完成json->png的事情;
- 完善文档:
    1. 后续完善com_pipe*所有模块，
    2. 再简单说明com_reg*
    3. 完整说明com_simo_no_delay,  com_edge_detect, com_counter;
    4. 完整说明 com_sync_fifo_reg,  概述都在最前面， 细节放到 ## com_fifo 标题中
    5. 以后编写 com_sync_fifo_reg_pfetch + com_sync_fifo_reg_fullbyp + com_sync_fifo_reg_2w1r的rtl+文档, 比较和 com_sync_fifo_reg 的差异
    6. 完整说明 com_dp_buffer + com_dp_ram
    7. 时序不对: com_edge_detect在dual_edge的时候,  com_sync_fifo_reg在rd_en下一拍才empty,   com_dp_buffer输入的vld/rdy不对


2026/5/30 增量开发rtl:
1. com_sync_fifo_reg_v2 + com_sync_fifo_reg_pfetch + com_sync_fifo_reg_fullbyp + com_sync_fifo_reg_2w1r 的rtl+文档, 比较和 com_sync_fifo_reg 的差异
2. cdc  pulse/async_fifo开发;
3. com_arbiter_wrr, com_ram_arbiter

2026/? 修改axi/dma模块:

2026/? 配套testbench:


2026/? csr_tool开发:


2026/? rtl集成脚本开发 + module_load/vscode_plugin发布方式:
