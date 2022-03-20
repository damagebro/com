/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/16-14:06:01
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

//`include com_dp_buffer.sv

`ifndef com_emi_rch_ext_v
`define com_emi_rch_ext_v
module com_emi_rch_ext #( parameter
    AW      = 32        ,
    DW      = 128       ,
    MAX_RCH = 16        ,
    MAX_OSD = 16        ,
    USR_W   = 0         ,

    UW =(USR_W>0?USR_W:1),
    SW = DW/8            ,
    IW = $clog2(MAX_RCH) //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//dp---
input  wire                     rx_arvalid          ,
output wire                     rx_arready          ,
input  wire [IW-1:0]            rx_arid             ,
input  wire [AW-1:0]            rx_araddr           ,
input  wire [7:0]               rx_arlen            ,
input  wire [UW-1:0]            rx_aruser           ,

output wire                     rx_rvalid           ,
input  wire                     rx_rready           ,
output wire [IW-1:0]            rx_rid              ,
output wire [DW-1:0]            rx_rdata            ,
output wire                     rx_rlast            ,
output wire [UW-1:0]            rx_ruser            ,

com_emi_if.ext_rch_tx           ext_emi_ifm         //,
);
//localparam-----------------------------------------------------------------
localparam RA_FIFO_DW = USR_W + 8 + IW + AW; //{user,alen,arid,addr}
localparam RD_FIFO_DW = USR_W + 1 + IW + DW; //{user,rlast,rid,data}
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire          tx_arvalid  ;
wire          tx_arready  ;
wire [IW-1:0] tx_arid     ;
wire [AW-1:0] tx_araddr   ;
wire [7:0]    tx_arlen    ;
wire [UW-1:0] tx_aruser   ;
wire          tx_rvalid   ;
wire          tx_rready   ;
wire [IW-1:0] tx_rid      ;
wire [DW-1:0] tx_rdata    ;
wire          tx_rlast    ;
wire [UW-1:0] tx_ruser    ;
//statement------------------------------------------------------------------

wire                  ext_ra_ivld  = rx_arvalid;
wire                  ext_ra_irdy  ;
wire [RA_FIFO_DW-1:0] ext_ra_idata ;
wire                  ext_ra_ovld  ;
wire                  ext_ra_ordy  ;
wire [RA_FIFO_DW-1:0] ext_ra_odata ;
com_dp_buffer #(
    .DW         ( RA_FIFO_DW  ), //8
    .DEPTH      ( 2           )  //4
)r_com_dp_buffer_ext_ra
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( ext_ra_ivld          ), //i
    .irdy                 ( ext_ra_irdy          ), //o
    .idata                ( ext_ra_idata         ), //i
    .ovld                 ( ext_ra_ovld          ), //o
    .ordy                 ( ext_ra_ordy          ), //i
    .odata                ( ext_ra_odata         )  //o
);
assign rx_arready = ext_ra_irdy;
assign tx_arvalid = ext_ra_ovld;
assign ext_ra_ordy= tx_arready ;

wire                  ext_rd_ivld  = tx_rvalid;
wire                  ext_rd_irdy  ;
wire [RD_FIFO_DW-1:0] ext_rd_idata ;
wire                  ext_rd_ovld  ;
wire                  ext_rd_ordy  ;
wire [RD_FIFO_DW-1:0] ext_rd_odata ;
com_dp_buffer #(
    .DW         ( RD_FIFO_DW  ), //8
    .DEPTH      ( 2           )  //4
)r_com_dp_buffer_ext_rd
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( ext_rd_ivld          ), //i
    .irdy                 ( ext_rd_irdy          ), //o
    .idata                ( ext_rd_idata         ), //i
    .ovld                 ( ext_rd_ovld          ), //o
    .ordy                 ( ext_rd_ordy          ), //i
    .odata                ( ext_rd_odata         )  //o
);
assign tx_rready  = ext_rd_irdy;
assign rx_rvalid  = ext_rd_ovld;
assign ext_rd_ordy= rx_rready ;

wire rx_rlast_t;
assign rx_rlast = rx_rlast_t && rx_rvalid;
generate
  if( USR_W==0 ) begin:gen_no_usr
      assign ext_ra_idata = {rx_arlen,rx_arid,rx_araddr};
      assign {tx_arlen,tx_arid,tx_araddr} = ext_ra_odata;
      assign tx_aruser = UW'(0);

      assign ext_rd_idata = {tx_rlast,tx_rid,tx_rdata};
      assign {rx_rlast_t,rx_rid,rx_rdata} = ext_rd_odata;
      assign rx_ruser = UW'(0);
  end
  else begin:gen_with_usr
      assign ext_ra_idata = {rx_aruser,rx_arlen,rx_arid,rx_araddr};
      assign {tx_aruser,tx_arlen,tx_arid,tx_araddr} = ext_ra_odata;

      assign ext_rd_idata = {tx_ruser,tx_rlast,tx_rid,tx_rdata};
      assign {rx_ruser,rx_rlast_t,rx_rid,rx_rdata} = ext_rd_odata;
  end
endgenerate

//out---
assign ext_emi_ifm.emi_arvalid = tx_arvalid ;
assign ext_emi_ifm.emi_arid    = tx_arid    ;
assign ext_emi_ifm.emi_araddr  = tx_araddr  ;
assign ext_emi_ifm.emi_arlen   = tx_arlen   ;
assign ext_emi_ifm.emi_aruser  = tx_aruser  ;
assign tx_arready = ext_emi_ifm.emi_arready ;

assign tx_rvalid = ext_emi_ifm.emi_rvalid ;
assign tx_rid    = ext_emi_ifm.emi_rid    ;
assign tx_rdata  = ext_emi_ifm.emi_rdata  ;
assign tx_rlast  = ext_emi_ifm.emi_rlast  ;
assign tx_ruser  = ext_emi_ifm.emi_ruser  ;
assign ext_emi_ifm.emi_rready = tx_rready ;

endmodule //end of com_emi_rch_ext
`endif //end of com_emi_rch_ext_v

