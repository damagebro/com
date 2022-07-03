/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/10/21-11:34:58
*
*  Description:
*  -water_level means (async_fifo_depth, only in wr_clk domain)
*  -when wr_full, the storeged data tol_num=(RAM_DEPTH+2);
*  -the ram's wr/rd clk in the different clock domain
*--------------
*  -advantage: whether wr_clk faster than rd_clk, or wr_clk slower than rd_clk, the performance is ok;
*  -disadvantage: the RAM_DEPTH must be 2^n
*
*  Modify:
*  -
*
******************************************************************************/

//`include "com_cdc_hs.v"
//`include "com_cdc_rstn.v"
//`include "com_cdc_sig.v"

`ifndef com_async_fifo_ram_2p2ck_v
`define com_async_fifo_ram_2p2ck_v
module com_async_fifo_ram_2p2ck #( parameter
    DW        = 8,
    RAM_DEPTH = 4, //ram_depth must be 2^n
    RAM_AW    = $clog2(  RAM_DEPTH>2?RAM_DEPTH:2),
    AW        = $clog2( (RAM_DEPTH>2?RAM_DEPTH:2) +1 ) //,
)
(
input  wire                     wr_clk              ,
input  wire                     wr_rst_n            ,
input  wire                     wr_clear            ,
input  wire                     rd_clk              ,
input  wire                     rd_rst_n            ,
input  wire                     rd_clear            ,

input  wire                     wr_en               ,
input  wire [DW-1:0]            wr_data             ,
output wire                     wr_full             ,
input  wire                     rd_en               ,
output wire [DW-1:0]            rd_data             ,
output wire                     rd_empty            ,
output wire [AW-1:0]            water_level         ,

output wire                     ram_wr_en           ,
output wire [RAM_AW-1:0]        ram_wr_addr         ,
output wire [DW-1:0]            ram_wr_data         ,
output wire                     ram_rd_en           ,
output wire [RAM_AW-1:0]        ram_rd_addr         ,
input  wire [DW-1:0]            ram_rd_data         //,
);
//localparam-----------------------------------------------------------------
// integer i;
localparam DEPTH  = RAM_DEPTH;
localparam SYNC_N = 2;

localparam CW = $clog2( (RAM_DEPTH>2?RAM_DEPTH:2) +1 );
//reg  declare---------------------------------------------------------------
reg  [AW-0:0] rc_wrcnt;
reg  [AW-0:0] rc_wrcnt_gray;
reg  [AW-0:0] rc_rdcnt;
reg  [AW-0:0] rc_rdcnt_gray;
//wire declare---------------------------------------------------------------
//src_clk domain---
wire clk_s   = wr_clk   ;
wire rst_n_s = wr_rst_n ;
wire clear_s = wr_clear ;
//dst_clk domain---
wire clk_d   = rd_clk   ;
wire rst_n_d = rd_rst_n ;
wire clear_d = rd_clear ;

wire [1:0] afifo_wr_reset_signals; //0:sync_wr_rst_n, 1:sync_wr_clear;
wire [1:0] afifo_rd_reset_signals; //0:sync_rd_rst_n, 1:sync_rd_clear;
wire sync_wr_rst_n = afifo_wr_reset_signals[0]; //wr clk domain
wire sync_wr_clear = afifo_wr_reset_signals[1]; //wr clk domain
wire sync_rd_rst_n = afifo_rd_reset_signals[0]; //rd clk domain
wire sync_rd_clear = afifo_rd_reset_signals[1]; //rd clk domain
//statement------------------------------------------------------------------

wire          afifo_wr_en   = wr_en;
wire          afifo_wr_full ;
wire [AW-1:0] afifo_wr_addr ;
wire          afifo_rd_en   ;
wire          afifo_rd_empty;
wire [AW-1:0] afifo_rd_addr ;
com_async_fifo_ctrl #(
    .DEPTH      ( DEPTH      )  //4
)u_com_async_fifo_ctrl
(
    .wr_clk               ( wr_clk               ), //i
    .wr_rst_n             ( wr_rst_n             ), //i
    .wr_clear             ( wr_clear             ), //i
    .rd_clk               ( rd_clk               ), //i
    .rd_rst_n             ( rd_rst_n             ), //i
    .rd_clear             ( rd_clear             ), //i
    .wr_reset_signals     ( afifo_wr_reset_signals ), //o
    .rd_reset_signals     ( afifo_rd_reset_signals ), //o

    .wr_en                ( afifo_wr_en          ), //i
    .wr_addr              ( afifo_wr_addr        ), //o
    .wr_full              ( afifo_wr_full        ), //o
    .rd_en                ( afifo_rd_en          ), //i
    .rd_addr              ( afifo_rd_addr        ), //o
    .rd_empty             ( afifo_rd_empty       ), //o
    .water_level          ( water_level          )  //o
);

//wr clk domain---
assign ram_wr_en   = afifo_wr_en && !afifo_wr_full;
assign ram_wr_addr = afifo_wr_addr;
assign ram_wr_data = wr_data;
assign wr_full     = afifo_wr_full;
//rd clk domain---
assign ram_rd_en   = afifo_rd_en;
assign ram_rd_addr = afifo_rd_addr;
reg  ram_rd_ack;
always @(posedge rd_clk or negedge sync_rd_rst_n)
begin
    if( !sync_rd_rst_n )
        ram_rd_ack <= 1'b0;
    else
        ram_rd_ack <= ram_rd_en;
end

wire          out_wr_en       = ram_rd_ack;
wire [DW-1:0] out_wr_data     = ram_rd_data;
wire          out_wr_full     ;
wire          out_rd_en       ;
wire [DW-1:0] out_rd_data     ;
wire          out_rd_empty    ;
wire [1:0]    out_water_level ;
com_sync_fifo_reg #(
    .DW         ( DW         ), //8
    .DEPTH      ( 2          )  //4
)u_com_sync_fifo_reg_out
(
    .clk                  ( rd_clk                  ), //i
    .rst_n                ( sync_rd_rst_n           ), //i
    .clear                ( sync_rd_clear           ), //i

    .wr_en                ( out_wr_en               ), //i
    .wr_data              ( out_wr_data             ), //i
    .wr_full              ( out_wr_full             ), //o
    .rd_en                ( out_rd_en               ), //i
    .rd_data              ( out_rd_data             ), //o
    .rd_empty             ( out_rd_empty            ), //o
    .water_level          ( out_water_level         )  //o
);
assign out_rd_en = rd_en && !out_rd_empty;
assign afifo_rd_en = !afifo_rd_empty && (out_water_level>2'd1 || rd_en);

assign rd_empty = out_rd_empty;
assign rd_data  = out_rd_data;

//assert--------------------------


endmodule //end of com_async_fifo_ram_2p2ck
`endif //end of com_async_fifo_ram_2p2ck_v

