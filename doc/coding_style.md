
# rtl代码风格

1. 模块名全小写, 信号名全小写, 参数名全大写, enum名字全大写且带"e"小写的前缀。
2. 模块端口名, 每行文本只声明1个信号,  带着i_xxx, o_xxx前缀, 表示端口方向。
3. 模块例化:
    - 例化名全小写, `u_{module_name}_{inst_name}`形式;
    - 例化端口连线的信号名, 以`u_{inst_name}_[i|o_]{original_port_name}`形式;  其中i|o要看original_port_name是否已存在i/o标记。
    - 每行文本只例化1个端口, 只用.port (wire_name)显式例化。
    - 在模块例化代码块位置, 上面用assign, 对所有例化模块的input信号进行赋值。
4. 信号声明, 常规只使用wire/reg声明, 如果是struct/union/enum用logic类型。 如果是reg是dff类型, 带着r_xx前缀; 如果reg是wire类型, 带着w_xx前缀;
5. 时序逻辑用always@(posedge clk)赋值,  组合逻辑用always@*或assign赋值,  局部临时变量直接用wire a = xx声明并赋值;
6. 单时钟域设计, 时钟信号名=clk,  复位信号名=rst_n,  偶尔出现同步复位的信号名=clear(电平信号, 高有效);
7. 每个模块中代码块划分: (1) 模块参数/端口声明,  (2) 本地参数声明(localpram), 本地enum/typedef声明;  (3) 本地信号声明, 先声明常规信号再例化信号;  (4) 输出信号赋值, 都用assign;  (5) 所有时序逻辑/组合逻辑; (6) 所有模块例化; (7) assert/debug等;
8. 一个文件只写一个模块, 且文件名=模块名;
9. 代码注释都用英文注释, 代码中不出现中文;
10. always_dff中, 把控制流/数据流放在不同的always_dff编写,  相似的控制逻辑, 才写到同一个always_dff块中。
11. 一些推荐的信号前缀标记, 不强制约束
    - r_xx, 表示dff信号;
    - b_xx, 表示单bit组合逻辑信号;
    - w_xx, 表示一定是组合逻辑信号, 一般reg作为组合逻辑，在always_comb赋值中使用;
    - arr_xx, a1_xx, a2_xx, a3_xx, a4_xx;  arr=多维数组, a1=一维数组, a2=二维数组, a3=三维数组, a4=四维数组;   如果数组是dff类型, 加上r_前缀, r_arr_xx, r_a2_xx, r_a3_xx;
    - pls_xx, 表示单周期脉冲信号;
    - tie_xx, 表示是一个常数值, 是内部tie的值;
    - cfg_xx是CSR的配置寄存器, sta_xx是CSR的状态寄存器, irq_xx是中断状态寄存器;
    - u_xx, 表示是例化模块的端口信号名,  最好格式是 `u_${tag_name}_[i|o]_${port_name};` 通过"tag"标识哪个例化模块名, 通过i|o知道子模块端口方向, 通过port_name知道子模块原始端口名;
12. 数值范围描述; `range=[start:end:step]`(借用python数组表达方式， 不过end可以取到, step扩展支持2^n,表示只能按2的幂次方递增);  举例axi数据位宽, AXI_DW range=[8:2048:2^n];
13. 多时钟域设计,
    - 时钟信号名: `xx_clk`,  复位信号名: `xx_rst_n`, 异步设计暂不需要`clear`信号;
    - 内部信号声明: 比如有a/b两个时钟,  a时钟信号都是: `cka_xx`,  b时钟信号都是: `ckb_xx`;
    - 内部模块例化名: a时钟例化信号: `u_cka_<inst_name>_[i|o]_xxx`,  b时钟例化信号: `u_ckb_<inst_name>_[i|o]_xxx`;
    - 单bit信号cdc统一调用`cdc req/ack`协议封装的模块, 多bit信号cdc统一调用`async_fifo`, cdc底层统一封装`sync_cell`模块和后端对接;
    - 一般来说, 自研代码**禁止**自己开发cdc逻辑, 统一用上述封装。


## rtl代码模板

```systemverilog
module abc_xyz #(
    parameter PIPE_NUM = 1,  //range=[1::]
    parameter DW = 8 //,
)
(
    input  logic                    clk          ,
    input  logic                    rst_n        ,

    input  logic [DW-1:0]           i_rx_payload ,
    output logic [DW-1:0]           o_tx_payload //,
);

//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
logic [PIPE_NUM-1:0] r_flag;
logic [PIPE_NUM-1:0][DW-1:0] r_payload;
//body-----------------------------------------------------------------------
//output assign---
assign o_tx_payload = r_payload[NUM_STG-1];

//statement----
always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        r_flag <= '0;
    else if( xx )
        r_flag <= '0;
end

//instance----
assign u_xx_i_port1 = i_rx_payload;
abc #(
    .DW  (XX_DW)   //default: 16
)u_abc_xx
(
    .i_port1   (u_xx_i_port1), //i
    .o_port2   (u_xx_o_port2), //o
    ...
);

endmodule
```