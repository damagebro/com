/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/07
*
*  Description:
*  - Synchronous FIFO with one 1-port SRAM bank.
*  - SRAM width is 2*DW and depth is RAM_DEPTH/2.
*  - Read/write conflict on the 1-port SRAM is resolved by write priority.
*
*  Modify:
*
*
*
******************************************************************************/

module com_sync_fifo_ram_1p1bank #( parameter
    DW           = 8,
    RAM_DEPTH    = 4, //range=[2::2], logical fifo depth in DW unit
    OUT_DEPTH    = 4, //range=[2::], output fifo depth
    RAM_RD_DELAY = 1, //range=[1:16:], fixed SRAM read data latency
    localparam RAM_ONE_DW    = DW*2,
    localparam RAM_ONE_DEPTH = RAM_DEPTH/2,
    localparam TOL_DEPTH     = RAM_DEPTH+OUT_DEPTH,
    localparam TOL_CW        = $clog2(TOL_DEPTH+1),
    localparam RAM_ONE_AW    = $clog2(RAM_ONE_DEPTH>2?RAM_ONE_DEPTH:2)//,
)
(
input  wire                       clk               ,
input  wire                       rst_n             ,
input  wire                       clear             ,

input  wire                       i_wr_en           ,
input  wire [DW-1:0]              i_wr_data         ,
output wire                       o_wr_full         ,
input  wire                       i_rd_en           ,
output wire [DW-1:0]              o_rd_data         ,
output wire                       o_rd_empty        ,
output wire [TOL_CW-1:0]          o_water_level     ,

output wire                       o_ram_ce_n        ,
output wire                       o_ram_we_n        ,
output wire [RAM_ONE_AW-1:0]      o_ram_addr        ,
output wire [RAM_ONE_DW-1:0]      o_ram_wr_data     ,
input  wire [RAM_ONE_DW-1:0]      i_ram_rd_data     //,
);
//localparam-----------------------------------------------------------------
localparam RAM_ONE_CW = $clog2(RAM_ONE_DEPTH+1);
localparam OUT_CW     = $clog2(OUT_DEPTH+1);
//signal declare-------------------------------------------------------------
reg  [RAM_ONE_AW-1:0]    r_ram_wr_addr;
reg  [RAM_ONE_AW-1:0]    r_ram_rd_addr;
reg  [RAM_ONE_CW-1:0]    r_ram_used_cnt;
reg                      r_ram_wr_full;
reg  [OUT_CW-1:0]        r_ram_otf_cnt;
reg                      r_rd_req_hi;
reg                      r_pack_vld;
reg  [DW-1:0]            r_pack_data;
reg                      r_wr_full;
reg  [TOL_CW-1:0]        r_tol_water_level;
reg                      r_ram_rd_ack;
reg  [DW-1:0]            r_ram_rd_data_hi;
reg  [RAM_RD_DELAY-1:0]  r_ram_rd_vld_pipe;

wire                     wr_hs;
wire                     rd_hs;
wire                     wr_full_nxt;
wire [TOL_CW-1:0]        tol_water_level_nxt;
wire                     direct_order_avl;
wire                     out_direct_wr_en;
wire                     pack_drain_en;
wire                     pack_store_en;
wire                     ram_wr_req;
wire                     ram_wr_en;
wire                     ram_rd_en;
wire                     rd_req_hi_en;
wire                     out_ram_lo_wr_en;
wire                     out_ram_hi_wr_en;
wire [RAM_ONE_AW-0:0]    ram_wr_addr_p1;
wire [RAM_ONE_AW-0:0]    ram_rd_addr_p1;
wire [RAM_ONE_AW-1:0]    ram_wr_addr_nxt;
wire [RAM_ONE_AW-1:0]    ram_rd_addr_nxt;
wire [RAM_ONE_CW-1:0]    ram_used_cnt_nxt;
wire [OUT_CW-1:0]        ram_rd_otf_add;
wire [OUT_CW-1:0]        ram_otf_cnt_nxt;
wire                     ram_rd_data_vld;
wire                     ram_ack_ilgl;
wire                     ram_ack_high_ilgl;
wire                     ram_otf_underflow_ilgl;
wire                     wr_path_miss;

//instance signal--
wire                  u_out_i_wr_fast_en;
wire                  u_out_i_wr_fast_data_vld;
wire [DW-1:0]         u_out_i_wr_fast_data;
wire                  u_out_o_wr_full;
wire                  u_out_i_wr_slow_en;
wire [DW-1:0]         u_out_i_wr_slow_data;
wire                  u_out_o_wr_slow_avl_flag;
wire                  u_out_i_rd_en;
wire [DW-1:0]         u_out_o_rd_data;
wire                  u_out_o_rd_empty;
wire [OUT_CW-1:0]     u_out_o_water_level;
//statement------------------------------------------------------------------
//output assign---
assign o_wr_full = r_wr_full;
assign o_rd_data = u_out_o_rd_data;
assign o_rd_empty = u_out_o_rd_empty;
assign o_water_level = r_tol_water_level;

assign o_ram_ce_n = !(ram_wr_en || ram_rd_en);
assign o_ram_we_n = !ram_wr_en;
assign o_ram_addr = ram_wr_en ? r_ram_wr_addr : r_ram_rd_addr;
assign o_ram_wr_data = {i_wr_data,r_pack_data};

//body---
assign wr_hs = i_wr_en && !o_wr_full;
assign rd_hs = i_rd_en && !o_rd_empty;
assign tol_water_level_nxt = r_tol_water_level - TOL_CW'(wr_hs) + TOL_CW'(rd_hs);
assign wr_full_nxt = tol_water_level_nxt=='0;

assign direct_order_avl = (r_ram_used_cnt=='0) && !r_rd_req_hi && !u_out_o_wr_slow_avl_flag;
assign out_direct_wr_en = wr_hs && !r_pack_vld && direct_order_avl && !u_out_o_wr_full;
assign pack_drain_en = r_pack_vld && direct_order_avl && !u_out_o_wr_full;
assign pack_store_en = wr_hs && !out_direct_wr_en && (!r_pack_vld || pack_drain_en);
assign ram_wr_req = wr_hs && r_pack_vld && !pack_drain_en;
assign ram_wr_en = ram_wr_req && !r_ram_wr_full;

assign out_ram_lo_wr_en = ram_rd_data_vld;
assign out_ram_hi_wr_en = r_ram_rd_ack && u_out_o_wr_slow_avl_flag && !ram_rd_data_vld;
assign ram_rd_en = !ram_wr_req && !r_rd_req_hi && (r_ram_used_cnt!='0) &&
                   !u_out_o_wr_full && (!r_ram_rd_ack || out_ram_hi_wr_en);
assign rd_req_hi_en = r_rd_req_hi && !u_out_o_wr_full;

assign ram_ack_ilgl = ram_rd_data_vld && (r_ram_rd_ack || !u_out_o_wr_slow_avl_flag);
assign ram_ack_high_ilgl = r_ram_rd_ack && !r_rd_req_hi && !u_out_o_wr_slow_avl_flag;
assign ram_otf_underflow_ilgl = (out_ram_lo_wr_en || out_ram_hi_wr_en) && (r_ram_otf_cnt=='0);
assign wr_path_miss = wr_hs && !(out_direct_wr_en || pack_store_en || ram_wr_en);

assign ram_wr_addr_p1 = {1'b0,r_ram_wr_addr} + 1'b1;
assign ram_rd_addr_p1 = {1'b0,r_ram_rd_addr} + 1'b1;
assign ram_wr_addr_nxt = ram_wr_addr_p1==RAM_ONE_DEPTH[RAM_ONE_AW:0] ? '0 :
                         ram_wr_addr_p1[RAM_ONE_AW-1:0];
assign ram_rd_addr_nxt = ram_rd_addr_p1==RAM_ONE_DEPTH[RAM_ONE_AW:0] ? '0 :
                         ram_rd_addr_p1[RAM_ONE_AW-1:0];
assign ram_used_cnt_nxt = r_ram_used_cnt + RAM_ONE_CW'(ram_wr_en) - RAM_ONE_CW'(ram_rd_en);
assign ram_rd_otf_add = ram_rd_en ? OUT_CW'(2) : '0;
assign ram_otf_cnt_nxt = r_ram_otf_cnt + ram_rd_otf_add -
                         OUT_CW'(out_ram_lo_wr_en) - OUT_CW'(out_ram_hi_wr_en);
assign ram_rd_data_vld = r_ram_rd_vld_pipe[RAM_RD_DELAY-1];

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
        r_ram_used_cnt <= '0;
        r_ram_wr_full <= 1'b0;
    end
    else if( clear ) begin
        r_ram_used_cnt <= '0;
        r_ram_wr_full <= 1'b0;
    end
    else if( ram_wr_en || ram_rd_en ) begin
        r_ram_used_cnt <= ram_used_cnt_nxt;
        r_ram_wr_full <= ram_used_cnt_nxt==RAM_ONE_DEPTH[RAM_ONE_CW-1:0];
    end
end

//rd_req_hi
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_req_hi <= 1'b0;
    else if( clear )
        r_rd_req_hi <= 1'b0;
    else if( ram_rd_en )
        r_rd_req_hi <= 1'b1;
    else if( rd_req_hi_en )
        r_rd_req_hi <= 1'b0;
end

//ram_otf_cnt
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ram_otf_cnt <= '0;
    else if( clear )
        r_ram_otf_cnt <= '0;
    else if( ram_rd_en || out_ram_lo_wr_en || out_ram_hi_wr_en )
        r_ram_otf_cnt <= ram_otf_cnt_nxt;
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

//pack buffer
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_pack_vld <= 1'b0;
    else if( clear )
        r_pack_vld <= 1'b0;
    else if( pack_store_en )
        r_pack_vld <= 1'b1;
    else if( ram_wr_en || pack_drain_en )
        r_pack_vld <= 1'b0;
end

always @(posedge clk) begin
    if( pack_store_en ) begin
        r_pack_data <= i_wr_data;
    end
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

//ram read ack
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ram_rd_ack <= 1'b0;
    else if( clear )
        r_ram_rd_ack <= 1'b0;
    else if( ram_rd_data_vld )
        r_ram_rd_ack <= 1'b1;
    else if( out_ram_hi_wr_en )
        r_ram_rd_ack <= 1'b0;
end

always @(posedge clk) begin
    if( ram_rd_data_vld ) begin
        r_ram_rd_data_hi <= i_ram_rd_data[RAM_ONE_DW-1:DW];
    end
end

//instance----
assign u_out_i_wr_fast_en = ram_rd_en || rd_req_hi_en || pack_drain_en || out_direct_wr_en;
assign u_out_i_wr_fast_data_vld = pack_drain_en || out_direct_wr_en;
assign u_out_i_wr_fast_data = pack_drain_en ? r_pack_data : i_wr_data;
assign u_out_i_wr_slow_en = out_ram_hi_wr_en || out_ram_lo_wr_en;
assign u_out_i_wr_slow_data = out_ram_hi_wr_en ? r_ram_rd_data_hi : i_ram_rd_data[DW-1:0];
assign u_out_i_rd_en = rd_hs;

com_sync_fifo_reg_2w1r #(
    .DW                   ( DW                       ), //8
    .DEPTH                ( OUT_DEPTH                )  //4
)u_com_sync_fifo_reg_2w1r_out
(
    .clk                  ( clk                      ), //i
    .rst_n                ( rst_n                    ), //i
    .clear                ( clear                    ), //i

    .i_wr_fast_en         ( u_out_i_wr_fast_en       ), //i
    .i_wr_fast_data_vld   ( u_out_i_wr_fast_data_vld ), //i
    .i_wr_fast_data       ( u_out_i_wr_fast_data     ), //i
    .o_wr_full            ( u_out_o_wr_full          ), //o

    .i_wr_slow_en         ( u_out_i_wr_slow_en       ), //i
    .i_wr_slow_data       ( u_out_i_wr_slow_data     ), //i
    .o_wr_slow_avl_flag   ( u_out_o_wr_slow_avl_flag ), //o

    .i_rd_en              ( u_out_i_rd_en            ), //i
    .o_rd_data            ( u_out_o_rd_data          ), //o
    .o_rd_empty           ( u_out_o_rd_empty         ), //o
    .o_water_level        ( u_out_o_water_level      )  //o
);

//assert--------------------------------------
`COM_PARAM_ASSERT( RAM_DEPTH>=2, "fifo ram depth must larger than 1" )
`COM_PARAM_ASSERT( RAM_DEPTH%2==0, "fifo ram depth must be even" )
`COM_PARAM_ASSERT( RAM_RD_DELAY>=1 && RAM_RD_DELAY<=16, "ram read delay range is [1:16]" )
`COM_PARAM_ASSERT( OUT_DEPTH>=(RAM_RD_DELAY+3), "fifo out depth must cover ram read delay and one write conflict" )
`COM_SIGNAL_ASSERT_LITE( a0, i_wr_en,!o_wr_full, "fifo write when full" )
`COM_SIGNAL_ASSERT_LITE( a1, i_rd_en,!o_rd_empty, "fifo read when empty" )
`COM_SIGNAL_ASSERT_LITE( a2, ram_ack_ilgl,1'b0, "ram read ack without output slot" )
`COM_SIGNAL_ASSERT_LITE( a3, ram_ack_high_ilgl,1'b0, "ram read high data without output slot" )
`COM_SIGNAL_ASSERT_LITE( a4, ram_otf_underflow_ilgl,1'b0, "ram otf count underflow" )
`COM_SIGNAL_ASSERT_LITE( a5, wr_path_miss,1'b0, "fifo ram write path unavailable" )

endmodule //end of com_sync_fifo_ram_1p1bank
