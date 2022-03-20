/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/17-17:53:13
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include "com_dp_buffer.sv"

`ifndef com_emi_wch_ext_v
`define com_emi_wch_ext_v
module com_emi_wch_ext #( parameter
    AW      = 32        ,
    DW      = 128       ,
    MAX_WCH = 16        ,
    MAX_OSD = 16        ,
    USR_W   = 0         ,

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_WCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//dp---
input  wire                     rx_awvalid          ,
output wire                     rx_awready          ,
input  wire [IW-1:0]            rx_awid             ,
input  wire [AW-1:0]            rx_awaddr           ,
input  wire [7:0]               rx_awlen            ,
input  wire [UW-1:0]            rx_awuser           ,

input  wire                     rx_wvalid           ,
output wire                     rx_wready           ,
input  wire [IW-1:0]            rx_wid              ,
input  wire [DW-1:0]            rx_wdata            ,
input  wire [SW-1:0]            rx_wstrb            ,
input  wire                     rx_wlast            ,
input  wire [UW-1:0]            rx_wuser            ,

output wire                     rx_bvalid           ,
input  wire                     rx_bready           ,
output wire [IW-1:0]            rx_bid              ,
output wire [UW-1:0]            rx_buser            ,

com_emi_if.ext_wch_tx           ext_emi_ifm         //,
);
//localparam-----------------------------------------------------------------
localparam WA_FIFO_DW = USR_W + 8 + IW + AW   ; //{user,alen,awid,addr}
localparam WD_FIFO_DW = USR_W + 1 + IW + SW+DW; //{user,wlast,wid,strb+data}
localparam WB_FIFO_DW = USR_W + IW; //{user,bid}
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire           tx_awvalid ;
wire           tx_awready ;
wire [IW-1:0]  tx_awid    ;
wire [AW-1:0]  tx_awaddr  ;
wire [7:0]     tx_awlen   ;
wire [UW-1:0]  tx_awuser  ;
wire           tx_wvalid  ;
wire           tx_wready  ;
wire [IW-1:0]  tx_wid     ;
wire [DW-1:0]  tx_wdata   ;
wire [SW-1:0]  tx_wstrb   ;
wire           tx_wlast   ;
wire [UW-1:0]  tx_wuser   ;
wire           tx_bvalid  ;
wire           tx_bready  ;
wire [IW-1:0]  tx_bid     ;
wire [UW-1:0]  tx_buser   ;
//statement------------------------------------------------------------------

wire                  ext_wa_ivld  = rx_awvalid;
wire                  ext_wa_irdy  ;
wire [WA_FIFO_DW-1:0] ext_wa_idata ;
wire                  ext_wa_ovld  ;
wire                  ext_wa_ordy  ;
wire [WA_FIFO_DW-1:0] ext_wa_odata ;
com_dp_buffer #(
    .DW         ( WA_FIFO_DW  ), //8
    .DEPTH      ( 2           )  //2
)r_com_dp_buffer_ext_wa
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( ext_wa_ivld          ), //i
    .irdy                 ( ext_wa_irdy          ), //o
    .idata                ( ext_wa_idata         ), //i
    .ovld                 ( ext_wa_ovld          ), //o
    .ordy                 ( ext_wa_ordy          ), //i
    .odata                ( ext_wa_odata         )  //o
);
assign rx_awready = ext_wa_irdy;
assign tx_awvalid = ext_wa_ovld;
assign ext_wa_ordy= tx_awready ;


wire                  ext_wd_ivld  = rx_wvalid;
wire                  ext_wd_irdy  ;
wire [WD_FIFO_DW-1:0] ext_wd_idata ;
wire                  ext_wd_ovld  ;
wire                  ext_wd_ordy  ;
wire [WD_FIFO_DW-1:0] ext_wd_odata ;
com_dp_buffer #(
    .DW         ( WD_FIFO_DW  ), //8
    .DEPTH      ( 2           )  //4
)r_com_dp_buffer_ext_wd
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( ext_wd_ivld          ), //i
    .irdy                 ( ext_wd_irdy          ), //o
    .idata                ( ext_wd_idata         ), //i
    .ovld                 ( ext_wd_ovld          ), //o
    .ordy                 ( ext_wd_ordy          ), //i
    .odata                ( ext_wd_odata         )  //o
);
assign rx_wready = ext_wd_irdy;
assign tx_wvalid = ext_wd_ovld;
assign ext_wd_ordy= tx_wready ;

wire                  ext_wb_ivld  = tx_bvalid;
wire                  ext_wb_irdy  ;
wire [WB_FIFO_DW-1:0] ext_wb_idata ;
wire                  ext_wb_ovld  ;
wire                  ext_wb_ordy  ;
wire [WB_FIFO_DW-1:0] ext_wb_odata ;
com_dp_buffer #(
    .DW         ( WB_FIFO_DW  ), //8
    .DEPTH      ( 2           )  //4
)r_com_dp_buffer_ext_wb
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( ext_wb_ivld          ), //i
    .irdy                 ( ext_wb_irdy          ), //o
    .idata                ( ext_wb_idata         ), //i
    .ovld                 ( ext_wb_ovld          ), //o
    .ordy                 ( ext_wb_ordy          ), //i
    .odata                ( ext_wb_odata         )  //o
);
assign tx_bready  = ext_wb_irdy;
assign rx_bvalid  = ext_wb_ovld;
assign ext_wb_ordy= rx_bready ;

generate
  if( USR_W==0 ) begin:gen_no_usr
      assign ext_wa_idata = {rx_awlen,rx_awid,rx_awaddr};
      assign {tx_awlen,tx_awid,tx_awaddr} = ext_wa_odata;
      assign tx_awuser = UW'(0);

      assign ext_wd_idata = {rx_wlast,rx_wid,rx_wstrb,rx_wdata};
      assign {tx_wlast,tx_wid,tx_wstrb,tx_wdata} = ext_wd_odata;
      assign tx_wuser = UW'(0);

      assign ext_wb_idata = {tx_bid};
      assign {rx_bid} = ext_wb_odata;
      assign rx_buser = UW'(0);
  end
  else begin:gen_with_usr
      assign ext_wa_idata = {rx_awuser,rx_awlen,rx_awid,rx_awaddr};
      assign {tx_awuser,tx_awlen,tx_awid,tx_awaddr} = ext_wa_odata;

      assign ext_wd_idata = {rx_wuser,rx_wlast,rx_wid,rx_wstrb,rx_wdata};
      assign {rx_wuser,tx_wlast,tx_wid,tx_wstrb,tx_wdata} = ext_wd_odata;

      assign ext_wb_idata = {tx_buser,tx_bid};
      assign {rx_buser,rx_bid} = ext_wb_odata;
  end
endgenerate

//wd after wa---
localparam WA_DEPTH = MAX_OSD+2;
localparam WA_CW    = $clog2(WA_DEPTH+1);
wire tx_awvalid_t;
wire tx_awready_t;
wire tx_wvalid_t;
wire tx_wready_t;

wire               wa_wr_en    = tx_awvalid_t && tx_awready_t;
wire [1 -1:0]      wa_wr_data  = 1'b0;
wire               wa_wr_full  ;
wire               wa_rd_en    = tx_wvalid_t&&tx_wready_t&&tx_wlast;
wire [1 -1:0]      wa_rd_data  ;
wire               wa_rd_empty ;
wire [WA_CW-1:0]   wa_wl       ;
com_sync_fifo_reg #(
    .DW         ( 1        ), //8
    .DEPTH      ( WA_DEPTH )  //4
)zr_com_sync_fifo_reg_wd_after_wa
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .wr_en                ( wa_wr_en             ), //i
    .wr_data              ( wa_wr_data           ), //i
    .wr_full              ( wa_wr_full           ), //o
    .rd_en                ( wa_rd_en             ), //i
    .rd_data              ( wa_rd_data           ), //o
    .rd_empty             ( wa_rd_empty          ), //o
    .water_level          ( wa_wl                )  //o
);
assign tx_awvalid_t = tx_awvalid && !wa_wr_full;
assign tx_awready   = tx_awready_t;
assign tx_wvalid_t  = tx_wvalid && !wa_rd_empty;
assign tx_wready    = tx_wready_t;

//out---
assign ext_emi_ifm.emi_awvalid = tx_awvalid_t;
assign ext_emi_ifm.emi_awid    = tx_awid    ;
assign ext_emi_ifm.emi_awaddr  = tx_awaddr  ;
assign ext_emi_ifm.emi_awlen   = tx_awlen   ;
assign ext_emi_ifm.emi_awuser  = tx_awuser  ;
assign tx_awready_t = wa_wr_full ? 1'b0 : ext_emi_ifm.emi_awready;

assign ext_emi_ifm.emi_wvalid = tx_wvalid_t;
assign ext_emi_ifm.emi_wid    = tx_wid    ;
assign ext_emi_ifm.emi_wdata  = tx_wdata  ;
assign ext_emi_ifm.emi_wstrb  = tx_wstrb  ;
assign ext_emi_ifm.emi_wlast  = tx_wlast  && tx_wvalid_t;
assign ext_emi_ifm.emi_wuser  = tx_wuser  ;
assign tx_wready_t = wa_rd_empty ? 1'b0 : ext_emi_ifm.emi_wready;

assign tx_bvalid = ext_emi_ifm.emi_bvalid ;
assign tx_bid    = ext_emi_ifm.emi_bid    ;
assign tx_buser  = ext_emi_ifm.emi_buser  ;
assign ext_emi_ifm.emi_bready = tx_bready ;

endmodule //end of com_emi_wch_ext
`endif //end of com_emi_wch_ext_v

