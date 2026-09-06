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

module com_axi_rch_regslice #( parameter
    AW      = 32        ,
    DW      = 128       ,
    IW      = 4         ,
    LW      = 8         , //range=[1:8]
    UW      = 1         ,
    RCH     = 4         ,
    MAX_LEN = 4         ,   //range=[1:256], max burst_len, not minus 1;
    MAX_OSD = 16        //, //max burst(cmd) outstandint;
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//axi
input  wire [IW-1:0]            i_rx_axi_arid       ,
input  wire [AW-1:0]            i_rx_axi_araddr     ,
input  wire [LW-1:0]            i_rx_axi_arlen      ,
input  wire [UW-1:0]            i_rx_axi_aruser     ,
input  wire                     i_rx_axi_arvalid    ,
output wire                     o_rx_axi_arready    ,
output wire [1:0]               o_rx_axi_rresp      ,
output wire [IW-1:0]            o_rx_axi_rid        ,
output wire [DW-1:0]            o_rx_axi_rdata      ,
output wire                     o_rx_axi_rlast      ,
output wire                     o_rx_axi_rvalid     ,
input  wire                     i_rx_axi_rready     ,

output wire [IW-1:0]            o_tx_axi_arid       ,
output wire [AW-1:0]            o_tx_axi_araddr     ,
output wire [LW-1:0]            o_tx_axi_arlen      ,
output wire [UW-1:0]            o_tx_axi_aruser     ,
output wire                     o_tx_axi_arvalid    ,
input  wire                     i_tx_axi_arready    ,
input  wire [1:0]               i_tx_axi_rresp      ,
input  wire [IW-1:0]            i_tx_axi_rid        ,
input  wire [DW-1:0]            i_tx_axi_rdata      ,
input  wire                     i_tx_axi_rlast      ,
input  wire                     i_tx_axi_rvalid     ,
output wire                     o_tx_axi_rready     //,
);
//localparam-----------------------------------------------------------------
localparam RA_FIFO_DW = UW + LW + IW + AW; //{aruser,arlen,arid,araddr}
localparam RD_FIFO_DW = 2 + 1 + IW + DW; //{rresp,rlast,rid,rdata}
//signal declare-------------------------------------------------------------
wire                   u_ra_i_wr_en    ;
wire [RA_FIFO_DW-1:0]  u_ra_i_wr_data  ;
wire                   u_ra_o_wr_full  ;
wire                   u_ra_i_rd_en    ;
wire [RA_FIFO_DW-1:0]  u_ra_o_rd_data  ;
wire                   u_ra_o_rd_empty ;

wire                   u_rd_i_wr_en    ;
wire [RD_FIFO_DW-1:0]  u_rd_i_wr_data  ;
wire                   u_rd_o_wr_full  ;
wire                   u_rd_i_rd_en    ;
wire [RD_FIFO_DW-1:0]  u_rd_o_rd_data  ;
wire                   u_rd_o_rd_empty ;
//statement------------------------------------------------------------------
//out---
assign {o_tx_axi_aruser,o_tx_axi_arlen,o_tx_axi_arid,o_tx_axi_araddr} = u_ra_o_rd_data;
assign o_tx_axi_arvalid = !u_ra_o_rd_empty;
assign o_rx_axi_arready = !u_ra_o_wr_full;

assign {o_rx_axi_rresp,o_rx_axi_rlast,o_rx_axi_rid,o_rx_axi_rdata} = u_rd_o_rd_data;
assign o_rx_axi_rvalid = !u_rd_o_rd_empty;
assign o_tx_axi_rready = !u_rd_o_wr_full;

//instance--
assign u_ra_i_wr_en   = i_rx_axi_arvalid && o_rx_axi_arready;
assign u_ra_i_wr_data = {i_rx_axi_aruser,i_rx_axi_arlen,i_rx_axi_arid,i_rx_axi_araddr};
assign u_ra_i_rd_en   = o_tx_axi_arvalid && i_tx_axi_arready;
com_sync_fifo_reg #(
    .DW    ( RA_FIFO_DW ), //8
    .DEPTH ( 2          )  //2
)u_com_sync_fifo_reg_ra
(
    .clk           ( clk                 ), //i
    .rst_n         ( rst_n               ), //i
    .clear         ( clear               ), //i
    .i_wr_en       ( u_ra_i_wr_en        ), //i
    .i_wr_data     ( u_ra_i_wr_data      ), //i
    .o_wr_full     ( u_ra_o_wr_full      ), //o
    .i_rd_en       ( u_ra_i_rd_en        ), //i
    .o_rd_data     ( u_ra_o_rd_data      ), //o
    .o_rd_empty    ( u_ra_o_rd_empty     ), //o
    .o_water_level (                     )  //o
);

assign u_rd_i_wr_en   = i_tx_axi_rvalid && o_tx_axi_rready;
assign u_rd_i_wr_data = {i_tx_axi_rresp,i_tx_axi_rlast,i_tx_axi_rid,i_tx_axi_rdata};
assign u_rd_i_rd_en   = o_rx_axi_rvalid && i_rx_axi_rready;
com_sync_fifo_reg #(
    .DW    ( RD_FIFO_DW ), //8
    .DEPTH ( 2          )  //2
)u_com_sync_fifo_reg_rd
(
    .clk           ( clk                 ), //i
    .rst_n         ( rst_n               ), //i
    .clear         ( clear               ), //i
    .i_wr_en       ( u_rd_i_wr_en        ), //i
    .i_wr_data     ( u_rd_i_wr_data      ), //i
    .o_wr_full     ( u_rd_o_wr_full      ), //o
    .i_rd_en       ( u_rd_i_rd_en        ), //i
    .o_rd_data     ( u_rd_o_rd_data      ), //o
    .o_rd_empty    ( u_rd_o_rd_empty     ), //o
    .o_water_level (                     )  //o
);

endmodule //end of com_axi_rch_regslice
