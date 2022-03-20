/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/17-17:23:42
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include com_sync_fifo_reg.sv

`ifndef com_emi_wch_clr_v
`define com_emi_wch_clr_v
module com_emi_wch_clr #( parameter
    MAX_OSD = 16        //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     ps_emi_terminate    ,
//cfg&status---
output wire                     clr_ongoing         ,
//dp---
input  wire                     rx_awvalid          ,
output wire                     rx_awready          ,
input  wire [7:0]               rx_awlen            ,
input  wire                     rx_wvalid           ,
output wire                     rx_wready           ,
input  wire                     rx_wlast            ,
output wire                     rx_bvalid           ,
input  wire                     rx_bready           ,

output wire                     tx_awvalid          ,
input  wire                     tx_awready          ,
output wire                     tx_wvalid           ,
input  wire                     tx_wready           ,
output wire                     tx_wlast            ,
input  wire                     tx_bvalid           ,
output wire                     tx_bready           //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  rc_clr_flag;
reg  [7:0] rc_wcnt;
//wire declare---------------------------------------------------------------
wire otf_wch_full ;
wire otf_wch_empty;
//statement------------------------------------------------------------------
wire clr_done = rc_clr_flag && otf_wch_empty;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )begin
        rc_clr_flag <= 1'b0;
    end
    else if( clr_done )begin
        rc_clr_flag <= 1'b0;
    end
    else if( ps_emi_terminate )begin
        rc_clr_flag <= 1'b1;
    end
end

wire       otf_wd_wr_en    = rx_awvalid && rx_awready;
wire [7:0] otf_wd_wr_data  = rx_awlen;
wire       otf_wd_wr_full  ;
wire       otf_wd_rd_en    = tx_wvalid&&tx_wready&&tx_wlast;
wire [7:0] otf_wd_rd_data  ;
wire       otf_wd_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 8        ), //8
    .DEPTH      ( MAX_OSD+2)  //4
)r_com_sync_fifo_reg_clr_wd
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( 1'b0                 ), //i

    .wr_en                ( otf_wd_wr_en         ), //i
    .wr_data              ( otf_wd_wr_data       ), //i
    .wr_full              ( otf_wd_wr_full       ), //o
    .rd_en                ( otf_wd_rd_en         ), //i
    .rd_data              ( otf_wd_rd_data       ), //o
    .rd_empty             ( otf_wd_rd_empty      ), //o
    .water_level          (                      )  //o
);
wire [7:0] clr_wlen = otf_wd_rd_data;

wire otf_wb_wr_en    = rx_awvalid && rx_awready;
wire otf_wb_wr_data  = 1'b0;
wire otf_wb_wr_full  ;
wire otf_wb_rd_en    = tx_bvalid&&tx_bready;
wire otf_wb_rd_data  ;
wire otf_wb_rd_empty ;
com_sync_fifo_reg #(
    .DW         ( 1        ), //8
    .DEPTH      ( MAX_OSD+2)  //4
)r_com_sync_fifo_reg_clr_wb
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( 1'b0                 ), //i

    .wr_en                ( otf_wb_wr_en         ), //i
    .wr_data              ( otf_wb_wr_data       ), //i
    .wr_full              ( otf_wb_wr_full       ), //o
    .rd_en                ( otf_wb_rd_en         ), //i
    .rd_data              ( otf_wb_rd_data       ), //o
    .rd_empty             ( otf_wb_rd_empty      ), //o
    .water_level          (                      )  //o
);
assign otf_wch_empty = otf_wd_rd_empty && otf_wb_rd_empty;
assign otf_wch_full  = otf_wd_wr_full  || otf_wb_wr_full ;
//assert( !otf_wch_full );

wire tx_whs = tx_wvalid && tx_wready;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_wcnt <= 'b0;
    else if( tx_whs && tx_wlast )
        rc_wcnt <= 'b0;
    else if( tx_whs )
        rc_wcnt <= rc_wcnt + 1'b1;
end
wire wlast = tx_wvalid && rc_wcnt==clr_wlen;

//out--
assign clr_ongoing = rc_clr_flag;
assign tx_awvalid  = rc_clr_flag ? 1'b0 : rx_awvalid && !otf_wch_full;
assign rx_awready  = rc_clr_flag ? 1'b0 : tx_awready && !otf_wch_full;

assign tx_wvalid   = rc_clr_flag ? !otf_wd_rd_empty : rx_wvalid;
assign tx_wlast    = rc_clr_flag ? wlast : rx_wlast;
assign rx_wready   = rc_clr_flag ? 1'b0 : tx_wready;

assign rx_bvalid   = rc_clr_flag ? 1'b0 : tx_bvalid;
assign tx_bready   = rc_clr_flag ? 1'b1 : rx_bready;

endmodule //end of com_emi_wch_clr
`endif //end of com_emi_wch_clr_v

