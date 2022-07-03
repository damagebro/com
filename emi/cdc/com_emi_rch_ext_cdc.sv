/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/06/22-09:56:50
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_rch_ext_cdc_v
`define com_emi_rch_ext_cdc_v
module com_emi_rch_ext_cdc #( parameter
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
input  wire                     axi_clk             ,
input  wire                     axi_rst_n           ,
input  wire                     axi_clear           ,
//dp---
input  wire [IW-1:0]            rx_arid             ,
input  wire [AW-1:0]            rx_araddr           ,
input  wire [7:0]               rx_arlen            ,
input  wire [UW-1:0]            rx_aruser           ,
input  wire                     rx_arvalid          ,
output wire                     rx_arready          ,
output wire [IW-1:0]            rx_rid              ,
output wire [DW-1:0]            rx_rdata            ,
output wire                     rx_rlast            ,
output wire [UW-1:0]            rx_ruser            ,
output wire                     rx_rvalid           ,
input  wire                     rx_rready           ,

com_emi_if.ext_rch_tx           ext_emi_ifm         //,
);
//localparam-----------------------------------------------------------------
localparam RA_FIFO_DW = USR_W + 8 + IW + AW; //{user,alen,arid,addr}
localparam RD_FIFO_DW = USR_W + 1 + IW + DW; //{user,rlast,rid,data}
localparam REQ_DEPTH = 4;  //[2::2]
localparam DAT_DEPTH = 10; //[2::2]
localparam REQ_AW = $clog2( REQ_DEPTH+1 );
localparam DAT_AW = $clog2( DAT_DEPTH+1 );
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

wire [REQ_AW-1:0]      ext_ra_water_level;
wire                   ext_ra_wr_en      = rx_arvalid && rx_arready;
wire [RA_FIFO_DW-1:0]  ext_ra_wr_data    ;
wire                   ext_ra_wr_full    ;
wire                   ext_ra_rd_en      = tx_arvalid && tx_arready;
wire [RA_FIFO_DW-1:0]  ext_ra_rd_data    ;
wire                   ext_ra_rd_empty   ;
com_async_fifo_reg #(
    .DW         ( RA_FIFO_DW    ), //8
    .DEPTH      ( REQ_DEPTH  )  //4
)u_com_async_fifo_reg_ext_ra
(
    .wr_clk               ( clk                  ), //i
    .wr_rst_n             ( rst_n                ), //i
    .wr_clear             ( clear                ), //i
    .rd_clk               ( axi_clk              ), //i
    .rd_rst_n             ( axi_rst_n            ), //i
    .rd_clear             ( axi_clear            ), //i

    .wr_en                ( ext_ra_wr_en         ), //i
    .wr_data              ( ext_ra_wr_data       ), //i
    .wr_full              ( ext_ra_wr_full       ), //o
    .rd_en                ( ext_ra_rd_en         ), //i
    .rd_data              ( ext_ra_rd_data       ), //o
    .rd_empty             ( ext_ra_rd_empty      ), //o
    .water_level          ( ext_ra_water_level   )  //o
);
assign rx_arready = !ext_ra_wr_full;
assign tx_arvalid = !ext_ra_rd_empty;

wire [DAT_AW-1:0]      ext_rd_water_level;
wire                   ext_rd_wr_en      = tx_rvalid && tx_rready;
wire [RD_FIFO_DW-1:0]  ext_rd_wr_data    ;
wire                   ext_rd_wr_full    ;
wire                   ext_rd_rd_en      = rx_rvalid && rx_rready;
wire [RD_FIFO_DW-1:0]  ext_rd_rd_data    ;
wire                   ext_rd_rd_empty   ;
com_async_fifo_reg #(
    .DW         ( RD_FIFO_DW  ), //8
    .DEPTH      ( DAT_DEPTH   )  //4
)u_com_async_fifo_reg_ext_rd
(
    .wr_clk               ( axi_clk              ), //i
    .wr_rst_n             ( axi_rst_n            ), //i
    .wr_clear             ( axi_clear            ), //i
    .rd_clk               ( clk                  ), //i
    .rd_rst_n             ( rst_n                ), //i
    .rd_clear             ( clear                ), //i

    .wr_en                ( ext_rd_wr_en         ), //i
    .wr_data              ( ext_rd_wr_data       ), //i
    .wr_full              ( ext_rd_wr_full       ), //o
    .rd_en                ( ext_rd_rd_en         ), //i
    .rd_data              ( ext_rd_rd_data       ), //o
    .rd_empty             ( ext_rd_rd_empty      ), //o
    .water_level          ( ext_rd_water_level   )  //o
);
assign tx_rready  = !ext_rd_wr_full;
assign rx_rvalid  = !ext_rd_rd_empty;

wire rx_rlast_t;
assign rx_rlast = rx_rlast_t && rx_rvalid;
generate
  if( USR_W==0 ) begin:gen_no_usr
      assign ext_ra_wr_data = {rx_arlen,rx_arid,rx_araddr};
      assign {tx_arlen,tx_arid,tx_araddr} = ext_ra_rd_data;
      assign tx_aruser = UW'(0);

      assign ext_rd_wr_data = {tx_rlast,tx_rid,tx_rdata};
      assign {rx_rlast_t,rx_rid,rx_rdata} = ext_rd_rd_data;
      assign rx_ruser = UW'(0);
  end
  else begin:gen_with_usr
      assign ext_ra_wr_data = {rx_aruser,rx_arlen,rx_arid,rx_araddr};
      assign {tx_aruser,tx_arlen,tx_arid,tx_araddr} = ext_ra_rd_data;

      assign ext_rd_wr_data = {tx_ruser,tx_rlast,tx_rid,tx_rdata};
      assign {rx_ruser,rx_rlast_t,rx_rid,rx_rdata} = ext_rd_rd_data;
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

endmodule //end of com_emi_rch_ext_cdc
`endif //end of com_emi_rch_ext_cdc_v

