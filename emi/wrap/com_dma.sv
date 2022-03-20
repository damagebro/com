/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/08/30-11:31:12
*
*  Description:
*   ${PRJ_NAME}_dma, each project have their own xx_dma file;
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_dma_v
`define com_dma_v
module com_dma #( parameter
    BUS_AW = 32,
    BUS_DW = 128,
    BUS_LW = 32,
    WCH    = 5,
    RCH    = 6,
    MAX_CH = 16, //number of max (write||read) channels

    AXI_IW = $clog2(MAX_CH),
    AXI_UW = 4//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
`COM_DFT_IF                     dft_cfg             ,
//cfg&status---
input  wire [WCH-1:0][7:0]      wdma_burst_len      ,
input  wire [RCH-1:0][7:0]      rdma_burst_len      ,
input  wire [7:0]               axi_burst_len       ,
output wire                     clr_ongoing         ,
//bus
input  wire [WCH-1:0]             bus_wa_valid        ,
output wire [WCH-1:0]             bus_wa_ready        ,
input  wire [WCH-1:0][BUS_AW-1:0] bus_wa_addr         ,
input  wire [WCH-1:0][BUS_LW-1:0] bus_wa_bytelen      ,
input  wire [WCH-1:0]             bus_wd_valid        ,
output wire [WCH-1:0]             bus_wd_ready        ,
input  wire [WCH-1:0][BUS_DW-1:0] bus_wd_data         ,
output wire [WCH-1:0]             bus_wb_resp         ,
input  wire [RCH-1:0]             bus_ra_valid        ,
output wire [RCH-1:0]             bus_ra_ready        ,
input  wire [RCH-1:0][BUS_AW-1:0] bus_ra_addr         ,
input  wire [RCH-1:0][BUS_LW-1:0] bus_ra_bytelen      ,
output wire [RCH-1:0]             bus_rd_valid        ,
input  wire [RCH-1:0]             bus_rd_ready        ,
output wire [RCH-1:0][BUS_DW-1:0] bus_rd_data         ,
output wire [RCH-1:0]             bus_rd_done         ,
//axi
output wire                     xm_arvalid          ,
input  wire                     xm_arready          ,
output wire [AXI_IW-1:0]        xm_arid             ,
output wire [BUS_AW-1:0]        xm_araddr           ,
output wire [7:0]               xm_arlen            ,
output wire [AXI_UW-1:0]        xm_aruser           ,
output wire [2:0]               xm_arsize           ,
output wire [1:0]               xm_arbusrt          ,//2'b01:INCR
output wire [3:0]               xm_arcache          ,//4'b0000: non-cache
output wire [2:0]               xm_arprot           ,//[0]0=non-private, [1]0=securty, [2]0=data/1=instruction
output wire [3:0]               xm_arqos            ,//priority, larger number high pri.
output wire [3:0]               xm_arregion         ,//fix 4'b0000
input  wire                     xm_rvalid           ,
output wire                     xm_rready           ,
input  wire [AXI_IW-1:0]        xm_rid              ,
input  wire [BUS_DW-1:0]        xm_rdata            ,
input  wire                     xm_rlast            ,
input  wire [AXI_UW-1:0]        xm_ruser            ,
input  wire [1:0]               xm_rresp            ,//0:OKAY, 1:EXOKAY, 2:SVLERR, 3:DECERR
output wire                     xm_awvalid          ,
input  wire                     xm_awready          ,
output wire [AXI_IW-1:0]        xm_awid             ,
output wire [BUS_AW-1:0]        xm_awaddr           ,
output wire [7:0]               xm_awlen            ,
output wire [AXI_UW-1:0]        xm_awuser           ,
output wire [2:0]               xm_awsize           ,
output wire [1:0]               xm_awbusrt          ,//2'b01:INCR
output wire [3:0]               xm_awcache          ,//4'b0000: non-cache
output wire [2:0]               xm_awprot           ,//[0]0=non-private, [1]0=securty, [2]0=data/1=instruction
output wire [3:0]               xm_awqos            ,//priority, larger number high pri.
output wire [3:0]               xm_awregion         ,//fix 4'b0000
output wire                     xm_wvalid           ,
input  wire                     xm_wready           ,
output wire [BUS_DW-1:0]        xm_wdata            ,
output wire [BUS_DW/8-1:0]      xm_wstrb            ,
output wire                     xm_wlast            ,
output wire [AXI_UW-1:0]        xm_wuser            ,
input  wire                     xm_bvalid           ,
output wire                     xm_bready           ,
input  wire [AXI_IW-1:0]        xm_bid              ,
input  wire [AXI_UW-1:0]        xm_buser            ,
input  wire [1:0]               xm_bresp            //,//0:OKAY, 1:EXOKAY, 2:SVLERR, 3:DECERR
);
//localparam-----------------------------------------------------------------
localparam PRJ_NAME = "";

localparam BUS_SW = BUS_DW/8;

localparam BUF_BYTES_WCH0 = 1024;
localparam BUF_BYTES_WCH1 = 1024;
localparam BUF_BYTES_WCH2 = 1024;
localparam BUF_BYTES_WCH3 = 1024;
localparam BUF_BYTES_WCH4 = 1024;
localparam BUF_BYTES_WCH5 = 1024;
localparam BUF_BYTES_WCH6 = 1024;
localparam BUF_BYTES_WCH7 = 1024;
localparam BUF_BYTES_WCH8 = 1024;
localparam BUF_BYTES_WCH9 = 1024;
localparam BUF_BYTES_WCH10= 1024;

localparam BUF_BYTES_RCH0 = 1024;
localparam BUF_BYTES_RCH1 = 1024;
localparam BUF_BYTES_RCH2 = 1024;
localparam BUF_BYTES_RCH3 = 1024;
localparam BUF_BYTES_RCH4 = 1024;
localparam BUF_BYTES_RCH5 = 1024;
localparam BUF_BYTES_RCH6 = 1024;
localparam BUF_BYTES_RCH7 = 1024;
localparam BUF_BYTES_RCH8 = 1024;
localparam BUF_BYTES_RCH9 = 1024;
localparam BUF_BYTES_RCH10= 1024;

localparam EMI_UW = 0;
localparam EMI_IF_UW = EMI_UW<1 ? 1 : EMI_UW;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
com_emi_if #( .EMI_AW(BUS_AW), .EMI_DW(BUS_DW), .EMI_UW(EMI_IF_UW), .EMI_MAX_CH(MAX_CH) )  emi_usr_wrif[WCH-1:0] ();
com_emi_if #( .EMI_AW(BUS_AW), .EMI_DW(BUS_DW), .EMI_UW(EMI_IF_UW), .EMI_MAX_CH(MAX_CH) )  emi_usr_rdif[RCH-1:0] ();
com_emi_if #( .EMI_AW(BUS_AW), .EMI_DW(BUS_DW), .EMI_UW(EMI_IF_UW), .EMI_MAX_CH(MAX_CH) )  emi_std_if();
//statement------------------------------------------------------------------

//buswch 2 emi
generate
for( genvar gi=0; gi<WCH; gi++ )begin:gen_wch
    localparam BUF_BYTES = gi==0 ? BUF_BYTES_WCH0 :
                           gi==1 ? BUF_BYTES_WCH1 :
                           gi==2 ? BUF_BYTES_WCH2 :
                           gi==3 ? BUF_BYTES_WCH3 :
                           gi==4 ? BUF_BYTES_WCH4 :
                           gi==5 ? BUF_BYTES_WCH5 :
                                   BUF_BYTES_WCH0;
    localparam BUF_DEPTH = ((BUF_BYTES+BUS_SW-1)/BUS_SW);

    com_emi_extd_wr #(
        .AW         ( BUS_AW     ), //32
        .DW         ( BUS_DW     ), //128
        .LW         ( BUS_LW     ), //32
        .RAM_DEPTH  ( BUF_DEPTH  )  //16*16
    )u_com_emi_extd_wr
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i
        .dft_cfg              ( dft_cfg              ), //i
        .max_burst_len        ( wdma_burst_len[gi]   ), //i

        .bus_wa_valid         ( bus_wa_valid  [gi]   ), //i
        .bus_wa_ready         ( bus_wa_ready  [gi]   ), //o
        .bus_wa_addr          ( bus_wa_addr   [gi]   ), //i
        .bus_wa_bytelen       ( bus_wa_bytelen[gi]   ), //i
        .bus_wd_valid         ( bus_wd_valid  [gi]   ), //i
        .bus_wd_ready         ( bus_wd_ready  [gi]   ), //o
        .bus_wd_data          ( bus_wd_data   [gi]   ), //i
        .bus_wb_resp          ( bus_wb_resp   [gi]   ), //o
        .emi_usr_wrif         ( emi_usr_wrif  [gi]   )  //if
    );
end
endgenerate

//busrch 2 emi
generate
for( genvar gi=0; gi<RCH; gi++ )begin:gen_rch
    localparam BUF_BYTES = gi==0 ? BUF_BYTES_RCH0 :
                           gi==1 ? BUF_BYTES_RCH1 :
                           gi==2 ? BUF_BYTES_RCH2 :
                           gi==3 ? BUF_BYTES_RCH3 :
                           gi==4 ? BUF_BYTES_RCH4 :
                           gi==5 ? BUF_BYTES_RCH5 :
                                   BUF_BYTES_RCH0;
    localparam BUF_DEPTH = ((BUF_BYTES+BUS_SW-1)/BUS_SW);

    com_emi_extd_rd #(
        .AW        ( BUS_AW     ), //32
        .DW        ( BUS_DW     ), //128
        .LW        ( BUS_LW     ), //32
        .RAM_DEPTH ( BUF_DEPTH  )  //16*16
    )u_com_emi_extd_rd
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i
        .dft_cfg              ( dft_cfg              ), //i
        .max_burst_len        ( rdma_burst_len[gi]   ), //i
        .rd_buf_bypass        ( 1'b0                 ), //i  //0: read buffer not bypass, 1: read buffer bypass;

        .bus_ra_valid         ( bus_ra_valid  [gi]   ), //i
        .bus_ra_ready         ( bus_ra_ready  [gi]   ), //o
        .bus_ra_addr          ( bus_ra_addr   [gi]   ), //i
        .bus_ra_bytelen       ( bus_ra_bytelen[gi]   ), //i
        .bus_rd_valid         ( bus_rd_valid  [gi]   ), //o
        .bus_rd_ready         ( bus_rd_ready  [gi]   ), //i
        .bus_rd_data          ( bus_rd_data   [gi]   ), //o
        .bus_rd_done          ( bus_rd_done   [gi]   ), //o

        .emi_usr_rdif         ( emi_usr_rdif  [gi]   )  //if
    );
end
endgenerate

com_emi_wrap #(
    .AW         ( BUS_AW     ), //32
    .DW         ( BUS_DW     ), //128
    .USR_W      ( EMI_UW     ), //0
    .RCH        ( RCH        ), //4
    .WCH        ( WCH        ), //4
    .MAX_CH     ( MAX_CH     ), //16
    .STR_LOG_PREFIX ( PRJ_NAME     )//, //""
)u_com_emi_wrap
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    .dft_cfg              ( dft_cfg              ), //i
    //cfg&status---
    .max_burst_len        ( axi_burst_len        ), //i
    .clr_ongoing          ( clr_ongoing          ), //o
    //if--
    .usr_emi_rdifs        ( emi_usr_rdif         ), //if
    .usr_emi_wrifs        ( emi_usr_wrif         ), //if
    .ext_emi_ifm          ( emi_std_if           )//, //if
);

com_emi_bridge_e2x #(
    .AW         ( BUS_AW     ), //32
    .DW         ( BUS_DW     ), //128
    .USR_W      ( AXI_UW     ), //0
    .MAX_CH     ( MAX_CH     )  //16
)u_com_emi_bridge_e2x
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    //axi
    .xm_arvalid           ( xm_arvalid           ), //o
    .xm_arready           ( xm_arready           ), //i
    .xm_arid              ( xm_arid              ), //o
    .xm_araddr            ( xm_araddr            ), //o
    .xm_arlen             ( xm_arlen             ), //o
    .xm_aruser            ( xm_aruser            ), //o
    .xm_arsize            ( xm_arsize            ), //o
    .xm_arbusrt           ( xm_arbusrt           ), //o
    .xm_arcache           ( xm_arcache           ), //o
    .xm_arprot            ( xm_arprot            ), //o
    .xm_arqos             ( xm_arqos             ), //o
    .xm_arregion          ( xm_arregion          ), //o

    .xm_rvalid            ( xm_rvalid            ), //i
    .xm_rready            ( xm_rready            ), //o
    .xm_rid               ( xm_rid               ), //i
    .xm_rdata             ( xm_rdata             ), //i
    .xm_rlast             ( xm_rlast             ), //i
    .xm_ruser             ( xm_ruser             ), //i
    .xm_rresp             ( xm_rresp             ), //i

    .xm_awvalid           ( xm_awvalid           ), //o
    .xm_awready           ( xm_awready           ), //i
    .xm_awid              ( xm_awid              ), //o
    .xm_awaddr            ( xm_awaddr            ), //o
    .xm_awlen             ( xm_awlen             ), //o
    .xm_awuser            ( xm_awuser            ), //o
    .xm_awsize            ( xm_awsize            ), //o
    .xm_awbusrt           ( xm_awbusrt           ), //o
    .xm_awcache           ( xm_awcache           ), //o
    .xm_awprot            ( xm_awprot            ), //o
    .xm_awqos             ( xm_awqos             ), //o
    .xm_awregion          ( xm_awregion          ), //o

    .xm_wvalid            ( xm_wvalid            ), //o
    .xm_wready            ( xm_wready            ), //i
    .xm_wdata             ( xm_wdata             ), //o
    .xm_wstrb             ( xm_wstrb             ), //o
    .xm_wlast             ( xm_wlast             ), //o
    .xm_wuser             ( xm_wuser             ), //o

    .xm_bvalid            ( xm_bvalid            ), //i
    .xm_bready            ( xm_bready            ), //o
    .xm_bid               ( xm_bid               ), //i
    .xm_buser             ( xm_buser             ), //i
    .xm_bresp             ( xm_bresp             ), //i
    //emi if
    .ext_emi_ifs          ( emi_std_if           )  //if
);

endmodule //end of com_dma
`endif //end of com_dma_v

