/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/10/21-11:35:17
*
*  Description:
*  - Synchronous FIFO with two 1-port SRAM banks.
*  - SRAM read/write same-bank conflict is resolved by write priority.
*  - Read reserve and physical SRAM read are decoupled by rd_hold.
*
*  Modify:
*  2026/06/02, rewrite with two 1-port SRAM banks and 2w1r output FIFO.
*
******************************************************************************/

module com_sync_fifo_ram_1p2bank #( parameter
    DW           = 8,
    RAM_DEPTH    = 4, //range=[2::2], total depth of 2 single-port SRAM banks
    OUT_DEPTH    = 4, //range=[2::], output fifo depth
    RAM_RD_DELAY = 1, //range=[1:16:], fixed SRAM read data latency
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

output wire [1:0]                 o_ram_ce_n        ,
output wire [1:0]                 o_ram_we_n        ,
output wire [1:0][RAM_ONE_AW-1:0] o_ram_addr        ,
output wire [1:0][DW-1:0]         o_ram_wr_data     ,
input  wire [1:0][DW-1:0]         i_ram_rd_data     //,
);
//localparam-----------------------------------------------------------------
localparam RAM_AW = $clog2(RAM_DEPTH>2?RAM_DEPTH:2);
localparam RAM_CW = $clog2(RAM_DEPTH+1);
localparam OUT_CW = $clog2(OUT_DEPTH+1);
//signal declare-------------------------------------------------------------
reg  [RAM_AW-1:0] r_ram_wr_addr;
reg  [RAM_AW-1:0] r_ram_rd_addr;
reg               r_ram_wr_full;
reg               r_ram_rd_empty;
reg  [RAM_CW-1:0] r_ram_water_level;
reg  [RAM_CW-1:0] r_ram_otf_cnt;
reg               r_rd_hold_vld;
reg               r_ibuf_vld;
reg  [DW-1:0]     r_ibuf_data;
reg               r_wr_full;
reg  [TOL_CW-1:0] r_tol_water_level;
reg  [RAM_RD_DELAY-1:0] r_ram_rd_vld_pipe;
reg  [RAM_RD_DELAY-1:0] r_ram_rd_bank_pipe;

wire              wr_hs;
wire              rd_hs;
wire              wr_full_nxt;
wire [TOL_CW-1:0] tol_water_level_nxt;
wire              direct_order_avl;
wire              out_direct_wr_en;
wire              ram_wr_req;
wire              rd_resv_req;
wire              ibuf_first_push;
wire              ibuf_refill;
wire              ibuf_push_en;
wire              ibuf_drain_en;
wire              port_ram_wr_en;
wire              ram_wr_en;
wire              rd_resv_en;
wire              rd_issue_req;
wire              ram_wr_bank_conflict;
wire              rd_hold_issue_en;
wire              ram_rd_conflict;
wire              ram_rd_en;
wire              ram_rd_ack;
wire [DW-1:0]     ram_rd_ack_data;
wire              wr_path_miss;
wire [RAM_AW-0:0] ram_wr_addr_p1;
wire [RAM_AW-0:0] ram_rd_addr_p1;
wire [RAM_AW-1:0] ram_wr_addr_nxt;
wire [RAM_AW-1:0] ram_rd_addr_nxt;
wire [RAM_CW-1:0] ram_water_level_nxt;
wire [RAM_CW-1:0] ram_otf_cnt_nxt;

wire              bank0_ram_wr_en;
wire              bank1_ram_wr_en;
wire              bank0_ram_rd_en;
wire              bank1_ram_rd_en;
wire              bank0_wr_en;
wire              bank1_wr_en;
wire [RAM_AW:0]   ram_wr_addr_ext;
wire [RAM_AW:0]   ram_rd_addr_ext;
wire [RAM_ONE_AW-1:0] ram_wr_bank_addr;
wire [RAM_ONE_AW-1:0] ram_rd_bank_addr;
wire [DW-1:0]     ram_wr_data;

//instance signal--
wire              u_out_i_wr_fast_en;
wire              u_out_i_wr_fast_data_vld;
wire [DW-1:0]     u_out_i_wr_fast_data;
wire              u_out_o_wr_full;
wire              u_out_i_wr_slow_en;
wire [DW-1:0]     u_out_i_wr_slow_data;
wire              u_out_o_wr_slow_avl_flag;
wire              u_out_i_rd_en;
wire [DW-1:0]     u_out_o_rd_data;
wire              u_out_o_rd_empty;
wire [OUT_CW-1:0] u_out_o_water_level;
//statement------------------------------------------------------------------
//output assign---
assign o_wr_full = r_wr_full;
assign o_rd_data = u_out_o_rd_data;
assign o_rd_empty = u_out_o_rd_empty;
assign o_water_level = r_tol_water_level;

//body---
assign wr_hs = i_wr_en && !o_wr_full;
assign rd_hs = i_rd_en && !o_rd_empty;
assign tol_water_level_nxt = r_tol_water_level - TOL_CW'(wr_hs) + TOL_CW'(rd_hs);
assign wr_full_nxt = tol_water_level_nxt=='0;
assign ram_rd_ack = r_ram_rd_vld_pipe[RAM_RD_DELAY-1];
assign ram_rd_ack_data = r_ram_rd_bank_pipe[RAM_RD_DELAY-1] ? i_ram_rd_data[1] : i_ram_rd_data[0];

assign direct_order_avl = r_ram_rd_empty && !r_rd_hold_vld && !r_ibuf_vld;
assign out_direct_wr_en = wr_hs && direct_order_avl && !u_out_o_wr_full;
assign ram_wr_req = wr_hs && !out_direct_wr_en;
assign rd_resv_req = !r_ram_rd_empty && !u_out_o_wr_full;
assign ibuf_first_push = ram_wr_req && !r_ibuf_vld && r_ram_wr_full;
assign ibuf_refill = ram_wr_req && r_ibuf_vld && !r_ram_wr_full;
assign ibuf_push_en = ibuf_first_push || ibuf_refill;
assign ibuf_drain_en = r_ibuf_vld;
assign port_ram_wr_en = ram_wr_req && !r_ram_wr_full && !ibuf_push_en;
assign ram_wr_en = ibuf_drain_en || port_ram_wr_en;
assign ram_wr_bank_conflict = ram_wr_en && (r_ram_wr_addr[0]==r_ram_rd_addr[0]);
assign rd_hold_issue_en = r_rd_hold_vld && !ram_wr_bank_conflict;
assign rd_resv_en = rd_resv_req && (!r_rd_hold_vld || rd_hold_issue_en);
assign rd_issue_req = r_rd_hold_vld || rd_resv_en;
assign ram_rd_conflict = rd_issue_req && ram_wr_bank_conflict;
assign ram_rd_en = rd_issue_req && !ram_rd_conflict;
assign wr_path_miss = wr_hs && !(out_direct_wr_en || port_ram_wr_en || ibuf_push_en);

assign ram_wr_addr_p1 = {1'b0,r_ram_wr_addr} + 1'b1;
assign ram_rd_addr_p1 = {1'b0,r_ram_rd_addr} + 1'b1;
assign ram_wr_addr_nxt = ram_wr_addr_p1==RAM_DEPTH[RAM_AW:0] ? '0 : ram_wr_addr_p1[RAM_AW-1:0];
assign ram_rd_addr_nxt = ram_rd_addr_p1==RAM_DEPTH[RAM_AW:0] ? '0 : ram_rd_addr_p1[RAM_AW-1:0];
assign ram_water_level_nxt = r_ram_water_level - RAM_CW'(ram_wr_en) + RAM_CW'(rd_resv_en);
assign ram_otf_cnt_nxt = r_ram_otf_cnt + RAM_CW'(ram_rd_en) - RAM_CW'(ram_rd_ack);

assign ram_wr_addr_ext = {1'b0,r_ram_wr_addr};
assign ram_rd_addr_ext = {1'b0,r_ram_rd_addr};
assign ram_wr_bank_addr = ram_wr_addr_ext[RAM_ONE_AW:1];
assign ram_rd_bank_addr = ram_rd_addr_ext[RAM_ONE_AW:1];
assign ram_wr_data = r_ibuf_vld ? r_ibuf_data : i_wr_data;

assign bank0_ram_wr_en = ram_wr_en && (r_ram_wr_addr[0]==1'b0);
assign bank1_ram_wr_en = ram_wr_en && (r_ram_wr_addr[0]==1'b1);
assign bank0_ram_rd_en = ram_rd_en && (r_ram_rd_addr[0]==1'b0);
assign bank1_ram_rd_en = ram_rd_en && (r_ram_rd_addr[0]==1'b1);
assign bank0_wr_en = bank0_ram_wr_en;
assign bank1_wr_en = bank1_ram_wr_en;

assign o_ram_ce_n[0] = !(bank0_wr_en || bank0_ram_rd_en);
assign o_ram_ce_n[1] = !(bank1_wr_en || bank1_ram_rd_en);
assign o_ram_we_n[0] = !bank0_wr_en;
assign o_ram_we_n[1] = !bank1_wr_en;
assign o_ram_addr[0] = bank0_ram_wr_en ? ram_wr_bank_addr : ram_rd_bank_addr;
assign o_ram_addr[1] = bank1_ram_wr_en ? ram_wr_bank_addr : ram_rd_bank_addr;
assign o_ram_wr_data[0] = ram_wr_data;
assign o_ram_wr_data[1] = ram_wr_data;

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
    else if( ram_wr_en || rd_resv_en ) begin
        r_ram_wr_full <= ram_water_level_nxt=='0;
        r_ram_rd_empty <= ram_water_level_nxt==RAM_DEPTH[RAM_CW-1:0];
        r_ram_water_level <= ram_water_level_nxt;
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

//rd_hold
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_hold_vld <= 1'b0;
    else if( clear )
        r_rd_hold_vld <= 1'b0;
    else if( ram_rd_conflict )
        r_rd_hold_vld <= 1'b1;
    else if( ram_rd_en )
        r_rd_hold_vld <= r_rd_hold_vld && rd_resv_en;
end

//ibuf
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_ibuf_vld <= 1'b0;
    else if( clear )
        r_ibuf_vld <= 1'b0;
    else if( ibuf_push_en )
        r_ibuf_vld <= 1'b1;
    else if( ibuf_drain_en )
        r_ibuf_vld <= 1'b0;
end

always @(posedge clk) begin
    if( ibuf_push_en )
        r_ibuf_data <= i_wr_data;
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

always @(posedge clk) begin
    r_ram_rd_bank_pipe[0] <= r_ram_rd_addr[0];
    for(int i=1; i<RAM_RD_DELAY; i++) begin
        r_ram_rd_bank_pipe[i] <= r_ram_rd_bank_pipe[i-1];
    end
end

//instance----
assign u_out_i_wr_fast_en = out_direct_wr_en || rd_resv_en;
assign u_out_i_wr_fast_data_vld = out_direct_wr_en;
assign u_out_i_wr_fast_data = i_wr_data;
assign u_out_i_wr_slow_en = ram_rd_ack;
assign u_out_i_wr_slow_data = ram_rd_ack_data;
assign u_out_i_rd_en = rd_hs;
com_sync_fifo_reg_2w1r #(
    .DW                   ( DW                  ), //8
    .DEPTH                ( OUT_DEPTH           )  //4
)u_com_sync_fifo_reg_2w1r_out
(
    .clk                  ( clk                 ), //i
    .rst_n                ( rst_n               ), //i
    .clear                ( clear               ), //i

    .i_wr_fast_en         ( u_out_i_wr_fast_en        ), //i
    .i_wr_fast_data_vld   ( u_out_i_wr_fast_data_vld  ), //i
    .i_wr_fast_data       ( u_out_i_wr_fast_data      ), //i
    .o_wr_full            ( u_out_o_wr_full           ), //o

    .i_wr_slow_en         ( u_out_i_wr_slow_en        ), //i
    .i_wr_slow_data       ( u_out_i_wr_slow_data      ), //i
    .o_wr_slow_avl_flag   ( u_out_o_wr_slow_avl_flag  ), //o

    .i_rd_en              ( u_out_i_rd_en             ), //i
    .o_rd_data            ( u_out_o_rd_data           ), //o
    .o_rd_empty           ( u_out_o_rd_empty          ), //o
    .o_water_level        ( u_out_o_water_level       )  //o
);

//assert--------------------------------------
`COM_PARAM_ASSERT( RAM_DEPTH>=2, "fifo ram depth must larger than 1" )
`COM_PARAM_ASSERT( RAM_DEPTH%2==0, "fifo ram depth must be even" )
`COM_PARAM_ASSERT( RAM_RD_DELAY>=1 && RAM_RD_DELAY<=16, "ram read delay range is [1:16]" )
`COM_PARAM_ASSERT( OUT_DEPTH>=(RAM_RD_DELAY+3), "fifo out depth must cover ram read delay and one write conflict" )
`COM_SIGNAL_ASSERT_LITE( a0, i_wr_en,!o_wr_full , "fifo write when full" )
`COM_SIGNAL_ASSERT_LITE( a1, i_rd_en,!o_rd_empty, "fifo read when empty" )
`COM_SIGNAL_ASSERT_LITE( a2, ram_rd_ack,u_out_o_wr_slow_avl_flag, "ram read ack without out fifo slow slot" )
`COM_SIGNAL_ASSERT_LITE( a3, wr_path_miss,1'b0, "fifo ram write path unavailable" )

endmodule //end of com_sync_fifo_ram_1p2bank
