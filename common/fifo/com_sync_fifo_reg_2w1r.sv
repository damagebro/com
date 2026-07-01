/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/05/30
*
*  Description:
*  -
*
*  Modify:
*
*
*
******************************************************************************/

module com_sync_fifo_reg_2w1r #( parameter
    DW    = 8, //range=[1::]
    DEPTH = 4, //range=[1:256:]  //fast write reserves fifo entry, slow write fills reserved entry later
    localparam CW = $clog2(DEPTH+1)
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     i_wr_fast_en        ,
input  wire                     i_wr_fast_data_vld  ,
input  wire [DW-1:0]            i_wr_fast_data      ,
output wire                     o_wr_full           ,

input  wire                     i_wr_slow_en        ,
input  wire [DW-1:0]            i_wr_slow_data      ,
output wire                     o_wr_slow_avl_flag  ,

input  wire                     i_rd_en             ,
output wire [DW-1:0]            o_rd_data           ,
output wire                     o_rd_empty          ,
output wire [CW-1:0]            o_water_level       //,
);
//localparam-----------------------------------------------------------------
localparam AW = $clog2(DEPTH>2?DEPTH:2);
//signal declare-------------------------------------------------------------
reg  [AW-1:0] r_wr_fast_addr;
reg  [AW-1:0] r_slow_ptr;
reg  [AW-1:0] r_rd_addr;
reg  [CW-1:0] r_slow_pend_cnt;
reg           r_slow_avl_flag;
reg           r_wr_fast_hit_again_flag;
reg           r_wr_full;
reg           r_rd_empty;
reg  [CW-1:0] r_water_level;
reg  [DEPTH-1:0][DW-1:0] r_mem;

wire             wr_fast_hs;
wire             wr_fast_data_hs;
wire             wr_fast_miss_hs;
wire             wr_slow_hs;
wire             rd_hs;
wire             wr_fast_miss_ilgl;
wire [AW-0:0]    wr_fast_addr_p1;
wire [AW-0:0]    slow_ptr_p1;
wire [AW-0:0]    rd_addr_p1;
wire [AW-1:0]    wr_fast_addr_nxt;
wire [AW-1:0]    slow_ptr_nxt;
wire [AW-1:0]    rd_addr_nxt;
wire [AW-1:0]    slow_ptr_do_nxt;
wire [AW-1:0]    rd_addr_do_nxt;
wire [CW-1:0]    water_level_nxt;
wire [CW-1:0]    slow_pend_cnt_nxt;
wire             slow_avl_flag_nxt;
wire             wr_fast_hit_again_flag_nxt;
wire             real_full_nxt;
wire             rd_empty_nxt;
//statement------------------------------------------------------------------
//output assign---
assign o_wr_full = r_wr_full;
assign o_wr_slow_avl_flag = r_slow_avl_flag;
assign o_rd_empty = r_rd_empty;
assign o_water_level = r_water_level;
assign o_rd_data = r_mem[r_rd_addr];

//body---
assign wr_fast_hs = i_wr_fast_en && !r_wr_full;
assign wr_fast_data_hs = wr_fast_hs && i_wr_fast_data_vld;
assign wr_fast_miss_hs = wr_fast_hs && !i_wr_fast_data_vld;
assign wr_slow_hs = i_wr_slow_en && o_wr_slow_avl_flag;
assign rd_hs = i_rd_en && !r_rd_empty;

assign wr_fast_addr_p1 = {1'b0,r_wr_fast_addr} + 1'b1;
assign slow_ptr_p1 = {1'b0,r_slow_ptr} + 1'b1;
assign rd_addr_p1 = {1'b0,r_rd_addr} + 1'b1;
assign wr_fast_addr_nxt = wr_fast_addr_p1==DEPTH[AW:0] ? '0 : wr_fast_addr_p1[AW-1:0];
assign slow_ptr_nxt = slow_ptr_p1==DEPTH[AW:0] ? '0 : slow_ptr_p1[AW-1:0];
assign rd_addr_nxt = rd_addr_p1==DEPTH[AW:0] ? '0 : rd_addr_p1[AW-1:0];
assign wr_fast_miss_ilgl = wr_fast_miss_hs && r_wr_fast_hit_again_flag;
assign slow_ptr_do_nxt = !slow_avl_flag_nxt ? (wr_fast_hs ? wr_fast_addr_nxt : r_wr_fast_addr) :
                                               (wr_slow_hs ? slow_ptr_nxt : r_slow_ptr);
assign rd_addr_do_nxt = rd_hs ? rd_addr_nxt : r_rd_addr;
assign water_level_nxt = r_water_level - CW'(wr_fast_hs) + CW'(rd_hs);
assign slow_pend_cnt_nxt = r_slow_pend_cnt + CW'(wr_fast_miss_hs) - CW'(wr_slow_hs);
assign slow_avl_flag_nxt = slow_pend_cnt_nxt!='0;
assign wr_fast_hit_again_flag_nxt = slow_avl_flag_nxt && (r_wr_fast_hit_again_flag || (wr_fast_data_hs && r_slow_avl_flag));
assign real_full_nxt = (water_level_nxt=='0) && !slow_avl_flag_nxt;
assign rd_empty_nxt = (rd_addr_do_nxt==slow_ptr_do_nxt) && !real_full_nxt;

//wr_fast_addr
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_wr_fast_addr <= '0;
    else if( clear )
        r_wr_fast_addr <= '0;
    else if( wr_fast_hs )
        r_wr_fast_addr <= wr_fast_addr_nxt;
end

//slow_ptr
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_slow_ptr <= '0;
    else if( clear )
        r_slow_ptr <= '0;
    else if( wr_fast_hs || wr_slow_hs )
        r_slow_ptr <= slow_ptr_do_nxt;
end

//rd_addr
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_addr <= '0;
    else if( clear )
        r_rd_addr <= '0;
    else if( rd_hs )
        r_rd_addr <= rd_addr_nxt;
end

//slow_pend_cnt&slow_avl_flag&wr_fast_hit_again_flag
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_slow_pend_cnt <= '0;
        r_slow_avl_flag <= 1'b0;
        r_wr_fast_hit_again_flag <= 1'b0;
    end
    else if( clear ) begin
        r_slow_pend_cnt <= '0;
        r_slow_avl_flag <= 1'b0;
        r_wr_fast_hit_again_flag <= 1'b0;
    end
    else if( wr_fast_hs || wr_slow_hs ) begin
        r_slow_pend_cnt <= slow_pend_cnt_nxt;
        r_slow_avl_flag <= slow_avl_flag_nxt;
        r_wr_fast_hit_again_flag <= wr_fast_hit_again_flag_nxt;
    end
end

//full&empty
always @(posedge clk or negedge rst_n) begin
    if( !rst_n ) begin
        r_wr_full <= 1'b0;
        r_rd_empty <= 1'b1;
        r_water_level <= DEPTH[CW-1:0];
    end
    else if( clear ) begin
        r_wr_full <= 1'b0;
        r_rd_empty <= 1'b1;
        r_water_level <= DEPTH[CW-1:0];
    end
    else if( i_wr_fast_en || i_wr_slow_en || i_rd_en ) begin
        r_wr_full <= water_level_nxt=='0;
        r_rd_empty <= rd_empty_nxt;
        r_water_level <= water_level_nxt;
    end
end

//fifo_mem
always @(posedge clk) begin
    if( wr_fast_data_hs ) begin
        r_mem[r_wr_fast_addr] <= i_wr_fast_data;
    end
    if( wr_slow_hs ) begin
        r_mem[r_slow_ptr] <= i_wr_slow_data;
    end
end

//assert--------------------------------------
`COM_PARAM_ASSERT( DEPTH>0, "fifo depth must larger than 0" )
`COM_SIGNAL_ASSERT_LITE( a0, i_wr_fast_en,!o_wr_full , "fifo write when full"  )
`COM_SIGNAL_ASSERT_LITE( a1, i_rd_en,!o_rd_empty, "fifo read when empty"  )
`COM_SIGNAL_ASSERT_LITE( a2, i_wr_slow_en,o_wr_slow_avl_flag, "slow write out of reserved range" )
`COM_SIGNAL_ASSERT_LITE( a3, wr_fast_miss_ilgl,1'b0, "unsupported fast miss condition" )

endmodule //end of com_sync_fifo_reg_2w1r
