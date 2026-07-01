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

module com_sync_fifo_reg_fullbyp #( parameter
    DW    = 8, //range=[1::]
    DEPTH = 4, //range=[1:256:]  //write is allowed when fifo is full and read happens in the same cycle
    localparam CW = $clog2(DEPTH+1)
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
output wire [CW-1:0]            o_water_level       //,
);
//localparam-----------------------------------------------------------------
localparam AW = $clog2(DEPTH>2?DEPTH:2);
//signal declare-------------------------------------------------------------
reg  [AW-1:0] r_wr_addr;
reg  [AW-1:0] r_rd_addr;
reg           r_wr_full;
reg           r_rd_empty;
reg  [CW-1:0] r_water_level;
reg  [DEPTH-1:0][DW-1:0] r_mem;

wire          b_wr_full;
wire          wr_hs;
wire          rd_hs;
wire [AW-0:0] wr_addr_p1;
wire [AW-0:0] rd_addr_p1;
wire [AW-1:0] wr_addr_nxt;
wire [AW-1:0] rd_addr_nxt;
wire [CW-1:0] water_level_nxt;
//statement------------------------------------------------------------------
//output assign---
assign o_wr_full = b_wr_full;
assign o_rd_empty = r_rd_empty;
assign o_water_level = r_water_level;
assign o_rd_data = r_mem[r_rd_addr];

//body---
assign rd_hs = i_rd_en && !r_rd_empty;
assign b_wr_full = r_wr_full && !rd_hs;
assign wr_hs = i_wr_en && !b_wr_full;

assign wr_addr_p1 = {1'b0,r_wr_addr} + 1'b1;
assign rd_addr_p1 = {1'b0,r_rd_addr} + 1'b1;
assign wr_addr_nxt = wr_addr_p1==DEPTH[AW:0] ? '0 : wr_addr_p1[AW-1:0];
assign rd_addr_nxt = rd_addr_p1==DEPTH[AW:0] ? '0 : rd_addr_p1[AW-1:0];
assign water_level_nxt = r_water_level - CW'(wr_hs) + CW'(rd_hs);

//wr_addr
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_wr_addr <= '0;
    else if( clear )
        r_wr_addr <= '0;
    else if( wr_hs )
        r_wr_addr <= wr_addr_nxt;
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
    else if( i_wr_en || i_rd_en ) begin
        r_wr_full <= water_level_nxt=='0;
        r_rd_empty <= water_level_nxt==DEPTH[CW-1:0];
        r_water_level <= water_level_nxt;
    end
end

//fifo_mem
always @(posedge clk) begin
    if( wr_hs ) begin
        r_mem[r_wr_addr] <= i_wr_data;
    end
end

//assert--------------------------------------
`COM_PARAM_ASSERT( DEPTH>0, "fifo depth must larger than 0" )
`COM_SIGNAL_ASSERT_LITE( a0, i_wr_en,!o_wr_full , "fifo write when full"  )
`COM_SIGNAL_ASSERT_LITE( a1, i_rd_en,!o_rd_empty, "fifo read when empty"  )

endmodule //end of com_sync_fifo_reg_fullbyp
