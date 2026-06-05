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

module com_sync_fifo_reg_pfetch #( parameter
    DW    = 8, //range=[1::]
    DEPTH = 4, //range=[2:256:]  //total fifo depth; one entry is the output prefetch register
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
localparam ARRAY_DEPTH = DEPTH-1;
localparam AW = $clog2(ARRAY_DEPTH>2?ARRAY_DEPTH:2);
localparam [CW-1:0] ARRAY_EMPTY_WL = DEPTH[CW-1:0] - CW'(1);
//signal declare-------------------------------------------------------------
reg  [AW-1:0] r_wr_addr;
reg  [AW-1:0] r_rd_addr;
reg           r_wr_full;
reg           r_rd_empty;
reg  [CW-1:0] r_water_level;
reg  [DW-1:0] r_rd_data;
reg  [ARRAY_DEPTH-1:0][DW-1:0] r_mem;

wire          wr_hs;
wire          rd_hs;
wire          array_has_data;
wire          rd_data_load_from_array;
wire          rd_data_load_from_input;
wire          array_wr_en;
wire [AW-0:0] wr_addr_p1;
wire [AW-0:0] rd_addr_p1;
wire [AW-1:0] wr_addr_nxt;
wire [AW-1:0] rd_addr_nxt;
wire [CW-1:0] water_level_nxt;
//statement------------------------------------------------------------------
//output assign---
assign o_wr_full = r_wr_full;
assign o_rd_empty = r_rd_empty;
assign o_water_level = r_water_level;
assign o_rd_data = r_rd_data;

//body---
assign wr_hs = i_wr_en && !r_wr_full;
assign rd_hs = i_rd_en && !r_rd_empty;
assign array_has_data = r_water_level<ARRAY_EMPTY_WL;

assign rd_data_load_from_array = rd_hs && array_has_data;
assign rd_data_load_from_input = wr_hs && (r_rd_empty || (rd_hs && !array_has_data));
assign array_wr_en = wr_hs && !rd_data_load_from_input;

assign wr_addr_p1 = {1'b0,r_wr_addr} + 1'b1;
assign rd_addr_p1 = {1'b0,r_rd_addr} + 1'b1;
assign wr_addr_nxt = wr_addr_p1==ARRAY_DEPTH[AW:0] ? '0 : wr_addr_p1[AW-1:0];
assign rd_addr_nxt = rd_addr_p1==ARRAY_DEPTH[AW:0] ? '0 : rd_addr_p1[AW-1:0];
assign water_level_nxt = r_water_level - CW'(wr_hs) + CW'(rd_hs);

//wr_addr
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_wr_addr <= '0;
    else if( clear )
        r_wr_addr <= '0;
    else if( array_wr_en )
        r_wr_addr <= wr_addr_nxt;
end

//rd_addr
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_addr <= '0;
    else if( clear )
        r_rd_addr <= '0;
    else if( rd_data_load_from_array )
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

//rd_data
always @(posedge clk) begin
    if( rd_data_load_from_array ) begin
        r_rd_data <= r_mem[r_rd_addr];
    end
    else if( rd_data_load_from_input ) begin
        r_rd_data <= i_wr_data;
    end
end

//fifo_mem
always @(posedge clk) begin
    if( array_wr_en ) begin
        r_mem[r_wr_addr] <= i_wr_data;
    end
end

//assert--------------------------------------
`COM_PARAM_ASSERT( DEPTH>=2, "fifo depth must larger than 1" );
`COM_SIGNAL_ASSERT_LITE( a0, i_wr_en,!o_wr_full , "fifo write when full"  );
`COM_SIGNAL_ASSERT_LITE( a1, i_rd_en,!o_rd_empty, "fifo read when empty"  );

endmodule //end of com_sync_fifo_reg_pfetch
