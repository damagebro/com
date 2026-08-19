/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/10/21-11:35:24
*
*  Description:
*  - Synchronous FIFO with one-clock true dual-port SRAM.
*  - The external SRAM has independent write/read ports.
*  - The output FIFO reserves slots before SRAM read data returns.
*
*  Modify:
*  2026/07/30, rewrite with current coding style.
*
******************************************************************************/

module com_sync_fifo_ram_2p1ck #( parameter
    DW           = 8,
    RAM_DEPTH    = 4, //range=[1::], external SRAM depth in DW unit
    IN_DEPTH     = 0, //deprecated, must be 0
    OUT_DEPTH    = 4, //range=[2::], output fifo depth
    RAM_RD_DELAY = 1, //range=[1:16:], fixed SRAM read data latency
    localparam TOL_DEPTH = RAM_DEPTH+OUT_DEPTH,
    localparam TOL_CW    = $clog2(TOL_DEPTH+1),
    localparam RAM_AW    = $clog2(RAM_DEPTH>2?RAM_DEPTH:2)//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     i_wr_en             ,
input  wire [DW-1:0]            i_wr_data           ,
output wire                     o_wr_full           ,
input  wire                     i_rd_en             ,
output wire [DW-1:0]            o_rd_data           ,
output wire                     o_rd_empty          ,
output wire [TOL_CW-1:0]        o_water_level       ,

output wire                     o_ram_wr_en         ,
output wire [RAM_AW-1:0]        o_ram_wr_addr       ,
output wire [DW-1:0]            o_ram_wr_data       ,
output wire                     o_ram_rd_en         ,
output wire [RAM_AW-1:0]        o_ram_rd_addr       ,
input  wire [DW-1:0]            i_ram_rd_data       //,
);
//localparam-----------------------------------------------------------------
localparam RAM_CW = $clog2(RAM_DEPTH+1);
localparam OUT_CW = $clog2(OUT_DEPTH+1);
//signal declare-------------------------------------------------------------
reg  [RAM_AW-1:0]          r_ram_wr_addr;
reg  [RAM_AW-1:0]          r_ram_rd_addr;
reg                        r_ram_wr_full;
reg                        r_ram_rd_empty;
reg  [RAM_CW-1:0]          r_ram_water_level;
reg  [RAM_CW-1:0]          r_ram_otf_cnt;
reg                        r_wr_full;
reg  [TOL_CW-1:0]          r_tol_water_level;
reg  [RAM_RD_DELAY-1:0]    r_ram_rd_vld_pipe;

wire                       wr_hs;
wire                       rd_hs;
wire                       wr_full_nxt;
wire [TOL_CW-1:0]          tol_water_level_nxt;
wire                       direct_order_avl;
wire                       out_direct_wr_en;
wire                       ram_wr_req;
wire                       ram_wr_space_avl;
wire                       ram_wr_en;
wire                       rd_prefill_en;
wire                       ram_rd_en;
wire                       ram_rd_ack;
wire [RAM_AW-0:0]          ram_wr_addr_p1;
wire [RAM_AW-0:0]          ram_rd_addr_p1;
wire [RAM_AW-1:0]          ram_wr_addr_nxt;
wire [RAM_AW-1:0]          ram_rd_addr_nxt;
wire [RAM_CW-1:0]          ram_water_level_nxt;
wire [RAM_CW-1:0]          ram_otf_cnt_nxt;
wire                       wr_path_miss;
wire                       ram_otf_underflow_ilgl;
wire                       ram_otf_status_mismatch_ilgl;

//instance signal--
wire                       u_out_i_wr_fast_en;
wire                       u_out_i_wr_fast_data_vld;
wire [DW-1:0]              u_out_i_wr_fast_data;
wire                       u_out_o_wr_full;
wire                       u_out_i_wr_slow_en;
wire [DW-1:0]              u_out_i_wr_slow_data;
wire                       u_out_o_wr_slow_avl_flag;
wire                       u_out_i_rd_en;
wire [DW-1:0]              u_out_o_rd_data;
wire                       u_out_o_rd_empty;
wire [OUT_CW-1:0]          u_out_o_water_level;

//statement------------------------------------------------------------------
//output assign---
assign o_wr_full = r_wr_full;
assign o_rd_data = u_out_o_rd_data;
assign o_rd_empty = u_out_o_rd_empty;
assign o_water_level = r_tol_water_level;

assign o_ram_wr_en = ram_wr_en;
assign o_ram_wr_addr = r_ram_wr_addr;
assign o_ram_wr_data = i_wr_data;
assign o_ram_rd_en = ram_rd_en;
assign o_ram_rd_addr = r_ram_rd_addr;

//body---
assign wr_hs = i_wr_en && !o_wr_full;
assign rd_hs = i_rd_en && !o_rd_empty;
assign tol_water_level_nxt = r_tol_water_level - TOL_CW'(wr_hs) + TOL_CW'(rd_hs);
assign wr_full_nxt = tol_water_level_nxt=='0;

assign direct_order_avl = r_ram_rd_empty && !u_out_o_wr_slow_avl_flag;
assign out_direct_wr_en = wr_hs && direct_order_avl && !u_out_o_wr_full;
assign ram_wr_req = wr_hs && !out_direct_wr_en;
assign rd_prefill_en = !r_ram_rd_empty && !u_out_o_wr_full;
assign ram_wr_space_avl = !r_ram_wr_full || rd_prefill_en;
assign ram_wr_en = ram_wr_req && ram_wr_space_avl;
assign ram_rd_en = rd_prefill_en;
assign ram_rd_ack = r_ram_rd_vld_pipe[RAM_RD_DELAY-1];

assign ram_wr_addr_p1 = {1'b0,r_ram_wr_addr} + 1'b1;
assign ram_rd_addr_p1 = {1'b0,r_ram_rd_addr} + 1'b1;
assign ram_wr_addr_nxt = ram_wr_addr_p1==RAM_DEPTH[RAM_AW:0] ? '0 :
                         ram_wr_addr_p1[RAM_AW-1:0];
assign ram_rd_addr_nxt = ram_rd_addr_p1==RAM_DEPTH[RAM_AW:0] ? '0 :
                         ram_rd_addr_p1[RAM_AW-1:0];
assign ram_water_level_nxt = r_ram_water_level - RAM_CW'(ram_wr_en) +
                             RAM_CW'(rd_prefill_en);
assign ram_otf_cnt_nxt = r_ram_otf_cnt + RAM_CW'(ram_rd_en) - RAM_CW'(ram_rd_ack);

assign wr_path_miss = wr_hs && !(out_direct_wr_en || ram_wr_en);
assign ram_otf_underflow_ilgl = ram_rd_ack && (r_ram_otf_cnt=='0);
assign ram_otf_status_mismatch_ilgl = (r_ram_otf_cnt=='0) ==
                                      u_out_o_wr_slow_avl_flag;

//ram_wr_addr
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ram_wr_addr <= '0;
    else if( clear )
        r_ram_wr_addr <= '0;
    else if( ram_wr_en )
        r_ram_wr_addr <= ram_wr_addr_nxt;
end

//ram_rd_addr
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ram_rd_addr <= '0;
    else if( clear )
        r_ram_rd_addr <= '0;
    else if( ram_rd_en )
        r_ram_rd_addr <= ram_rd_addr_nxt;
end

//ram status
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_ram_wr_full <= 1'b0;
        r_ram_rd_empty <= 1'b1;
        r_ram_water_level <= RAM_DEPTH[RAM_CW-1:0];
    end
    else if( clear ) begin
        r_ram_wr_full <= 1'b0;
        r_ram_rd_empty <= 1'b1;
        r_ram_water_level <= RAM_DEPTH[RAM_CW-1:0];
    end
    else if( ram_wr_en || rd_prefill_en ) begin
        r_ram_wr_full <= ram_water_level_nxt=='0;
        r_ram_rd_empty <= ram_water_level_nxt==RAM_DEPTH[RAM_CW-1:0];
        r_ram_water_level <= ram_water_level_nxt;
    end
end

//ram_otf_cnt
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ram_otf_cnt <= '0;
    else if( clear )
        r_ram_otf_cnt <= '0;
    else if( ram_rd_en || ram_rd_ack )
        r_ram_otf_cnt <= ram_otf_cnt_nxt;
end

//tol_water_level
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_wr_full <= 1'b0;
        r_tol_water_level <= TOL_DEPTH[TOL_CW-1:0];
    end
    else if( clear ) begin
        r_wr_full <= 1'b0;
        r_tol_water_level <= TOL_DEPTH[TOL_CW-1:0];
    end
    else if( wr_hs || rd_hs ) begin
        r_wr_full <= wr_full_nxt;
        r_tol_water_level <= tol_water_level_nxt;
    end
end

//ram_rd_vld_pipe
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ram_rd_vld_pipe <= '0;
    else if( clear )
        r_ram_rd_vld_pipe <= '0;
    else begin
        r_ram_rd_vld_pipe[0] <= ram_rd_en;
        for(int i=1; i<RAM_RD_DELAY; i++)
            r_ram_rd_vld_pipe[i] <= r_ram_rd_vld_pipe[i-1];
    end
end

//instance----
assign u_out_i_wr_fast_en = out_direct_wr_en || rd_prefill_en;
assign u_out_i_wr_fast_data_vld = out_direct_wr_en;
assign u_out_i_wr_fast_data = i_wr_data;
assign u_out_i_wr_slow_en = ram_rd_ack;
assign u_out_i_wr_slow_data = i_ram_rd_data;
assign u_out_i_rd_en = rd_hs;
com_sync_fifo_reg_2w1r #(
    .DW                   ( DW                  ),
    .DEPTH                ( OUT_DEPTH           )
)u_com_sync_fifo_reg_2w1r_out
(
    .clk                  ( clk                         ), //i
    .rst_n                ( rst_n                       ), //i
    .clear                ( clear                       ), //i

    .i_wr_fast_en         ( u_out_i_wr_fast_en          ), //i
    .i_wr_fast_data_vld   ( u_out_i_wr_fast_data_vld    ), //i
    .i_wr_fast_data       ( u_out_i_wr_fast_data        ), //i
    .o_wr_full            ( u_out_o_wr_full             ), //o

    .i_wr_slow_en         ( u_out_i_wr_slow_en          ), //i
    .i_wr_slow_data       ( u_out_i_wr_slow_data        ), //i
    .o_wr_slow_avl_flag   ( u_out_o_wr_slow_avl_flag    ), //o

    .i_rd_en              ( u_out_i_rd_en               ), //i
    .o_rd_data            ( u_out_o_rd_data             ), //o
    .o_rd_empty           ( u_out_o_rd_empty            ), //o
    .o_water_level        ( u_out_o_water_level         )  //o
);

//assert--------------------------------------
`COM_PARAM_ASSERT( RAM_DEPTH>=1, "fifo ram depth must larger than 0" )
`COM_PARAM_ASSERT( IN_DEPTH==0, "IN_DEPTH is deprecated and must be 0" )
`COM_PARAM_ASSERT( OUT_DEPTH>=(RAM_RD_DELAY+2), "fifo out depth must cover ram read delay" )
`COM_PARAM_ASSERT( RAM_RD_DELAY>=1 && RAM_RD_DELAY<=16, "ram read delay range is [1:16]" )
`COM_SIGNAL_ASSERT_LITE( a0, i_wr_en,!o_wr_full , "fifo write when full" )
`COM_SIGNAL_ASSERT_LITE( a1, i_rd_en,!o_rd_empty, "fifo read when empty" )
`COM_SIGNAL_ASSERT_LITE( a2, ram_rd_ack,u_out_o_wr_slow_avl_flag, "ram read ack without out fifo slow slot" )
`COM_SIGNAL_ASSERT_LITE( a3, wr_path_miss,1'b0, "fifo ram write path unavailable" )
`COM_SIGNAL_ASSERT_LITE( a4, ram_otf_underflow_ilgl,1'b0, "ram outstanding read underflow" )
`COM_SIGNAL_ASSERT_LITE( a5, ram_otf_status_mismatch_ilgl,1'b0, "ram outstanding status mismatch" )

endmodule //end of com_sync_fifo_ram_2p1ck
