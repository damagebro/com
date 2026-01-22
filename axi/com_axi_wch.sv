/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/18-09:42:38
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_wch #( parameter
    AW      = 32        ,
    DW      = 128       ,
    IW      = 4         ,
    LW      = 8         , //range=[1:8]
    UW      = 1         ,
    WCH     = 4         ,
    MAX_OSD = 16        ,
    MAX_LEN = 4         ,
    localparam SW = DW/8           //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//cfg&status---
output wire                     o_sta_clr_ongoing   , //level signal
//axi
input  wire [WCH-1:0][AW-1:0]   i_rx_axi_awaddr     ,
input  wire [WCH-1:0][LW-1:0]   i_rx_axi_awlen      ,
input  wire [WCH-1:0][UW-1:0]   i_rx_axi_awuser     ,
input  wire [WCH-1:0]           i_rx_axi_awvalid    ,
output wire [WCH-1:0]           o_rx_axi_awready    ,
input  wire [WCH-1:0][DW-1:0]   i_rx_axi_wdata      ,
input  wire [WCH-1:0][DW/8-1:0] i_rx_axi_wstrb      ,
input  wire [WCH-1:0]           i_rx_axi_wlast      ,
input  wire [WCH-1:0]           i_rx_axi_wvalid     ,
output wire [WCH-1:0]           o_rx_axi_wready     ,
output wire [WCH-1:0][1:0]      o_rx_axi_bresp      ,
output wire [WCH-1:0]           o_rx_axi_bvalid     ,
input  wire [WCH-1:0]           i_rx_axi_bready     ,

output wire [IW-1:0]            o_tx_axi_awid       ,
output wire [AW-1:0]            o_tx_axi_awaddr     ,
output wire [LW-1:0]            o_tx_axi_awlen      ,
output wire [UW-1:0]            o_tx_axi_awuser     ,
output wire                     o_tx_axi_awvalid    ,
input  wire                     i_tx_axi_awready    ,
output wire [DW-1:0]            o_tx_axi_wdata      ,
output wire [DW/8-1:0]          o_tx_axi_wstrb      ,
output wire                     o_tx_axi_wlast      ,
output wire                     o_tx_axi_wvalid     ,
input  wire                     i_tx_axi_wready     ,
input  wire [1:0]               i_tx_axi_bresp      ,
input  wire [IW-1:0]            i_tx_axi_bid        ,
input  wire                     i_tx_axi_bvalid     ,
output wire                     o_tx_axi_bready     //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire [WCH-1:0][AW-1:0]   u_arb_i_rx_axi_awaddr    ;
wire [WCH-1:0][LW-1:0]   u_arb_i_rx_axi_awlen     ;
wire [WCH-1:0][UW-1:0]   u_arb_i_rx_axi_awuser    ;
wire [WCH-1:0]           u_arb_i_rx_axi_awvalid   ;
wire [WCH-1:0]           u_arb_o_rx_axi_awready   ;
wire [WCH-1:0][DW-1:0]   u_arb_i_rx_axi_wdata     ;
wire [WCH-1:0][DW/8-1:0] u_arb_i_rx_axi_wstrb     ;
wire [WCH-1:0]           u_arb_i_rx_axi_wlast     ;
wire [WCH-1:0]           u_arb_i_rx_axi_wvalid    ;
wire [WCH-1:0]           u_arb_o_rx_axi_wready    ;
wire [WCH-1:0][1:0]      u_arb_o_rx_axi_bresp     ;
wire [WCH-1:0]           u_arb_o_rx_axi_bvalid    ;
wire [WCH-1:0]           u_arb_i_rx_axi_bready    ;
wire [IW-1:0]            u_arb_o_tx_axi_awid      ;
wire [AW-1:0]            u_arb_o_tx_axi_awaddr    ;
wire [LW-1:0]            u_arb_o_tx_axi_awlen     ;
wire [UW-1:0]            u_arb_o_tx_axi_awuser    ;
wire                     u_arb_o_tx_axi_awvalid   ;
wire                     u_arb_i_tx_axi_awready   ;
wire [DW-1:0]            u_arb_o_tx_axi_wdata     ;
wire [DW/8-1:0]          u_arb_o_tx_axi_wstrb     ;
wire                     u_arb_o_tx_axi_wlast     ;
wire                     u_arb_o_tx_axi_wvalid    ;
wire                     u_arb_i_tx_axi_wready    ;
wire [1:0]               u_arb_i_tx_axi_bresp     ;
wire [IW-1:0]            u_arb_i_tx_axi_bid       ;
wire                     u_arb_i_tx_axi_bvalid    ;
wire                     u_arb_o_tx_axi_bready    ;

wire [IW-1:0]            u_clr_i_rx_axi_awid     ;
wire [AW-1:0]            u_clr_i_rx_axi_awaddr   ;
wire [LW-1:0]            u_clr_i_rx_axi_awlen    ;
wire [UW-1:0]            u_clr_i_rx_axi_awuser   ;
wire                     u_clr_i_rx_axi_awvalid  ;
wire                     u_clr_o_rx_axi_awready  ;
wire [DW-1:0]            u_clr_i_rx_axi_wdata    ;
wire [DW/8-1:0]          u_clr_i_rx_axi_wstrb    ;
wire                     u_clr_i_rx_axi_wvalid   ;
wire                     u_clr_o_rx_axi_wready   ;
wire [1:0]               u_clr_o_rx_axi_bresp    ;
wire [IW-1:0]            u_clr_o_rx_axi_bid      ;
wire                     u_clr_o_rx_axi_bvalid   ;
wire                     u_clr_i_rx_axi_bready   ;
wire [IW-1:0]            u_clr_o_tx_axi_awid     ;
wire [AW-1:0]            u_clr_o_tx_axi_awaddr   ;
wire [LW-1:0]            u_clr_o_tx_axi_awlen    ;
wire [UW-1:0]            u_clr_o_tx_axi_awuser   ;
wire                     u_clr_o_tx_axi_awvalid  ;
wire                     u_clr_i_tx_axi_awready  ;
wire [DW-1:0]            u_clr_o_tx_axi_wdata    ;
wire [DW/8-1:0]          u_clr_o_tx_axi_wstrb    ;
wire                     u_clr_o_tx_axi_wvalid   ;
wire                     u_clr_i_tx_axi_wready   ;
wire [1:0]               u_clr_i_tx_axi_bresp    ;
wire [IW-1:0]            u_clr_i_tx_axi_bid      ;
wire                     u_clr_i_tx_axi_bvalid   ;
wire                     u_clr_o_tx_axi_bready   ;

wire [IW-1:0]            u_regslice_i_rx_axi_awid     ;
wire [AW-1:0]            u_regslice_i_rx_axi_awaddr   ;
wire [LW-1:0]            u_regslice_i_rx_axi_awlen    ;
wire [UW-1:0]            u_regslice_i_rx_axi_awuser   ;
wire                     u_regslice_i_rx_axi_awvalid  ;
wire                     u_regslice_o_rx_axi_awready  ;
wire [DW-1:0]            u_regslice_i_rx_axi_wdata    ;
wire [DW/8-1:0]          u_regslice_i_rx_axi_wstrb    ;
wire                     u_regslice_i_rx_axi_wvalid   ;
wire                     u_regslice_o_rx_axi_wready   ;
wire [1:0]               u_regslice_o_rx_axi_bresp    ;
wire [IW-1:0]            u_regslice_o_rx_axi_bid      ;
wire                     u_regslice_o_rx_axi_bvalid   ;
wire                     u_regslice_i_rx_axi_bready   ;
wire [IW-1:0]            u_regslice_o_tx_axi_awid     ;
wire [AW-1:0]            u_regslice_o_tx_axi_awaddr   ;
wire [LW-1:0]            u_regslice_o_tx_axi_awlen    ;
wire [UW-1:0]            u_regslice_o_tx_axi_awuser   ;
wire                     u_regslice_o_tx_axi_awvalid  ;
wire                     u_regslice_i_tx_axi_awready  ;
wire [DW-1:0]            u_regslice_o_tx_axi_wdata    ;
wire [DW/8-1:0]          u_regslice_o_tx_axi_wstrb    ;
wire                     u_regslice_o_tx_axi_wlast    ;
wire                     u_regslice_o_tx_axi_wvalid   ;
wire                     u_regslice_i_tx_axi_wready   ;
wire [1:0]               u_regslice_i_tx_axi_bresp    ;
wire [IW-1:0]            u_regslice_i_tx_axi_bid      ;
wire                     u_regslice_i_tx_axi_bvalid   ;
wire                     u_regslice_o_tx_axi_bready   ;
//statement------------------------------------------------------------------
//out---
assign o_tx_axi_awid     = u_regslice_o_tx_axi_awid   ;
assign o_tx_axi_awaddr   = u_regslice_o_tx_axi_awaddr ;
assign o_tx_axi_awlen    = u_regslice_o_tx_axi_awlen  ;
assign o_tx_axi_awuser   = u_regslice_o_tx_axi_awuser ;
assign o_tx_axi_awvalid  = u_regslice_o_tx_axi_awvalid;
assign o_tx_axi_wdata    = u_regslice_o_tx_axi_wdata  ;
assign o_tx_axi_wstrb    = u_regslice_o_tx_axi_wstrb  ;
assign o_tx_axi_wlast    = u_regslice_o_tx_axi_wlast  ;
assign o_tx_axi_wvalid   = u_regslice_o_tx_axi_wvalid ;
assign o_tx_axi_bready   = u_regslice_o_tx_axi_bready ;
assign o_rx_axi_awready  = u_arb_o_rx_axi_awready ;
assign o_rx_axi_wready   = u_arb_o_rx_axi_wready  ;
assign o_rx_axi_bresp    = u_arb_o_rx_axi_bresp   ;
assign o_rx_axi_bvalid   = u_arb_o_rx_axi_bvalid  ;


//instance---
assign u_arb_i_rx_axi_awaddr   = i_rx_axi_awaddr ;
assign u_arb_i_rx_axi_awlen    = i_rx_axi_awlen  ;
assign u_arb_i_rx_axi_awuser   = i_rx_axi_awuser ;
assign u_arb_i_rx_axi_awvalid  = i_rx_axi_awvalid;
assign u_arb_i_rx_axi_wdata    = i_rx_axi_wdata  ;
assign u_arb_i_rx_axi_wstrb    = i_rx_axi_wstrb  ;
assign u_arb_i_rx_axi_wlast    = i_rx_axi_wlast  ;
assign u_arb_i_rx_axi_wvalid   = i_rx_axi_wvalid ;
assign u_arb_i_rx_axi_bready   = i_rx_axi_bready ;
assign u_arb_i_tx_axi_awready = u_clr_o_rx_axi_awready ;
assign u_arb_i_tx_axi_wready  = u_clr_o_rx_axi_wready  ;
assign u_arb_i_tx_axi_bresp   = u_clr_o_rx_axi_bresp   ;
assign u_arb_i_tx_axi_bvalid  = u_clr_o_rx_axi_bvalid  ;
com_axi_wch_arb #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .IW                             ( IW                            ), //4
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .WCH                            ( WCH                           )  //4
)u_com_axi_wch_arb(
    .clk                 ( clk                    ), //i
    .rst_n               ( rst_n                  ), //i
    .clear               ( clear                  ), //i
    .i_rx_axi_awaddr     ( u_arb_i_rx_axi_awaddr  ), //i
    .i_rx_axi_awlen      ( u_arb_i_rx_axi_awlen   ), //i
    .i_rx_axi_awuser     ( u_arb_i_rx_axi_awuser  ), //i
    .i_rx_axi_awvalid    ( u_arb_i_rx_axi_awvalid ), //i
    .o_rx_axi_awready    ( u_arb_o_rx_axi_awready ), //o
    .i_rx_axi_wdata      ( u_arb_i_rx_axi_wdata   ), //i
    .i_rx_axi_wstrb      ( u_arb_i_rx_axi_wstrb   ), //i
    .i_rx_axi_wlast      ( u_arb_i_rx_axi_wlast   ), //i
    .i_rx_axi_wvalid     ( u_arb_i_rx_axi_wvalid  ), //i
    .o_rx_axi_wready     ( u_arb_o_rx_axi_wready  ), //o
    .o_rx_axi_bresp      ( u_arb_o_rx_axi_bresp   ), //o
    .o_rx_axi_bvalid     ( u_arb_o_rx_axi_bvalid  ), //o
    .i_rx_axi_bready     ( u_arb_i_rx_axi_bready  ), //i
    .o_tx_axi_awid       ( u_arb_o_tx_axi_awid    ), //o
    .o_tx_axi_awaddr     ( u_arb_o_tx_axi_awaddr  ), //o
    .o_tx_axi_awlen      ( u_arb_o_tx_axi_awlen   ), //o
    .o_tx_axi_awuser     ( u_arb_o_tx_axi_awuser  ), //o
    .o_tx_axi_awvalid    ( u_arb_o_tx_axi_awvalid ), //o
    .i_tx_axi_awready    ( u_arb_i_tx_axi_awready ), //i
    .o_tx_axi_wdata      ( u_arb_o_tx_axi_wdata   ), //o
    .o_tx_axi_wstrb      ( u_arb_o_tx_axi_wstrb   ), //o
    .o_tx_axi_wlast      ( u_arb_o_tx_axi_wlast   ), //o
    .o_tx_axi_wvalid     ( u_arb_o_tx_axi_wvalid  ), //o
    .i_tx_axi_wready     ( u_arb_i_tx_axi_wready  ), //i
    .i_tx_axi_bresp      ( u_arb_i_tx_axi_bresp   ), //i
    .i_tx_axi_bid        ( u_arb_i_tx_axi_bid     ), //i
    .i_tx_axi_bvalid     ( u_arb_i_tx_axi_bvalid  ), //i
    .o_tx_axi_bready     ( u_arb_o_tx_axi_bready  )  //o
);

assign u_clr_i_rx_axi_awaddr   = u_arb_o_tx_axi_awaddr ;
assign u_clr_i_rx_axi_awlen    = u_arb_o_tx_axi_awlen  ;
assign u_clr_i_rx_axi_awuser   = u_arb_o_tx_axi_awuser ;
assign u_clr_i_rx_axi_awvalid  = u_arb_o_tx_axi_awvalid;
assign u_clr_i_rx_axi_wdata    = u_arb_o_tx_axi_wdata  ;
assign u_clr_i_rx_axi_wstrb    = u_arb_o_tx_axi_wstrb  ;
assign u_clr_i_rx_axi_wlast    = u_arb_o_tx_axi_wlast  ;
assign u_clr_i_rx_axi_wvalid   = u_arb_o_tx_axi_wvalid ;
assign u_clr_i_rx_axi_bready   = u_arb_o_tx_axi_bready ;
assign u_clr_i_tx_axi_awready = u_regslice_o_rx_axi_awready ;
assign u_clr_i_tx_axi_wready  = u_regslice_o_rx_axi_wready  ;
assign u_clr_i_tx_axi_bresp   = u_regslice_o_rx_axi_bresp   ;
assign u_clr_i_tx_axi_bvalid  = u_regslice_o_rx_axi_bvalid  ;
com_axi_wch_clr #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .IW                             ( IW                            ), //4
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .MAX_LEN                        ( MAX_LEN                       ), //4
    .MAX_OSD                        ( MAX_OSD                       )  //16
)u_com_axi_wch_clr(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .i_ps_axi_terminate  ( clear                ), //i
    .o_sta_clr_ongoing   ( o_sta_clr_ongoing    ), //o
    .i_rx_axi_awid       ( u_clr_i_rx_axi_awid    ), //i
    .i_rx_axi_awaddr     ( u_clr_i_rx_axi_awaddr  ), //i
    .i_rx_axi_awlen      ( u_clr_i_rx_axi_awlen   ), //i
    .i_rx_axi_awuser     ( u_clr_i_rx_axi_awuser  ), //i
    .i_rx_axi_awvalid    ( u_clr_i_rx_axi_awvalid ), //i
    .o_rx_axi_awready    ( u_clr_o_rx_axi_awready ), //o
    .i_rx_axi_wdata      ( u_clr_i_rx_axi_wdata   ), //i
    .i_rx_axi_wstrb      ( u_clr_i_rx_axi_wstrb   ), //i
    .i_rx_axi_wvalid     ( u_clr_i_rx_axi_wvalid  ), //i
    .o_rx_axi_wready     ( u_clr_o_rx_axi_wready  ), //o
    .o_rx_axi_bresp      ( u_clr_o_rx_axi_bresp   ), //o
    .o_rx_axi_bid        ( u_clr_o_rx_axi_bid     ), //o
    .o_rx_axi_bvalid     ( u_clr_o_rx_axi_bvalid  ), //o
    .i_rx_axi_bready     ( u_clr_i_rx_axi_bready  ), //i
    .o_tx_axi_awid       ( u_clr_o_tx_axi_awid    ), //o
    .o_tx_axi_awaddr     ( u_clr_o_tx_axi_awaddr  ), //o
    .o_tx_axi_awlen      ( u_clr_o_tx_axi_awlen   ), //o
    .o_tx_axi_awuser     ( u_clr_o_tx_axi_awuser  ), //o
    .o_tx_axi_awvalid    ( u_clr_o_tx_axi_awvalid ), //o
    .i_tx_axi_awready    ( u_clr_i_tx_axi_awready ), //i
    .o_tx_axi_wdata      ( u_clr_o_tx_axi_wdata   ), //o
    .o_tx_axi_wstrb      ( u_clr_o_tx_axi_wstrb   ), //o
    .o_tx_axi_wvalid     ( u_clr_o_tx_axi_wvalid  ), //o
    .i_tx_axi_wready     ( u_clr_i_tx_axi_wready  ), //i
    .i_tx_axi_bresp      ( u_clr_i_tx_axi_bresp   ), //i
    .i_tx_axi_bid        ( u_clr_i_tx_axi_bid     ), //i
    .i_tx_axi_bvalid     ( u_clr_i_tx_axi_bvalid  ), //i
    .o_tx_axi_bready     ( u_clr_o_tx_axi_bready  )  //o
);

assign u_regslice_i_rx_axi_awaddr   = u_clr_o_tx_axi_awaddr ;
assign u_regslice_i_rx_axi_awlen    = u_clr_o_tx_axi_awlen  ;
assign u_regslice_i_rx_axi_awuser   = u_clr_o_tx_axi_awuser ;
assign u_regslice_i_rx_axi_awvalid  = u_clr_o_tx_axi_awvalid;
assign u_regslice_i_rx_axi_wdata    = u_clr_o_tx_axi_wdata  ;
assign u_regslice_i_rx_axi_wstrb    = u_clr_o_tx_axi_wstrb  ;
assign u_regslice_i_rx_axi_wlast    = 1'b0                  ; //if(WA_BEFORE_WD_EN=1), rx_wlast unused; tie 0;
assign u_regslice_i_rx_axi_wvalid   = u_clr_o_tx_axi_wvalid ;
assign u_regslice_i_rx_axi_bready   = u_clr_o_tx_axi_bready ;
assign u_regslice_i_tx_axi_awready = i_tx_axi_awready ;
assign u_regslice_i_tx_axi_wready  = i_tx_axi_wready  ;
assign u_regslice_i_tx_axi_bresp   = i_tx_axi_bresp   ;
assign u_regslice_i_tx_axi_bvalid  = i_tx_axi_bvalid  ;
com_axi_wch_regslice #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .IW                             ( IW                            ), //4
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .WA_BEFORE_WD_EN                ( 1                             )  //0
)u_com_axi_wch_regslice(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( 1'b0                 ), //i
    .i_rx_axi_awid       ( u_regslice_i_rx_axi_awid      ), //i
    .i_rx_axi_awaddr     ( u_regslice_i_rx_axi_awaddr    ), //i
    .i_rx_axi_awlen      ( u_regslice_i_rx_axi_awlen     ), //i
    .i_rx_axi_awuser     ( u_regslice_i_rx_axi_awuser    ), //i
    .i_rx_axi_awvalid    ( u_regslice_i_rx_axi_awvalid   ), //i
    .o_rx_axi_awready    ( u_regslice_o_rx_axi_awready   ), //o
    .i_rx_axi_wdata      ( u_regslice_i_rx_axi_wdata     ), //i
    .i_rx_axi_wstrb      ( u_regslice_i_rx_axi_wstrb     ), //i
    .i_rx_axi_wlast      ( u_regslice_i_rx_axi_wlast     ), //i
    .i_rx_axi_wvalid     ( u_regslice_i_rx_axi_wvalid    ), //i
    .o_rx_axi_wready     ( u_regslice_o_rx_axi_wready    ), //o
    .o_rx_axi_bresp      ( u_regslice_o_rx_axi_bresp     ), //o
    .o_rx_axi_bid        ( u_regslice_o_rx_axi_bid       ), //o
    .o_rx_axi_bvalid     ( u_regslice_o_rx_axi_bvalid    ), //o
    .i_rx_axi_bready     ( u_regslice_i_rx_axi_bready    ), //i
    .o_tx_axi_awid       ( u_regslice_o_tx_axi_awid      ), //o
    .o_tx_axi_awaddr     ( u_regslice_o_tx_axi_awaddr    ), //o
    .o_tx_axi_awlen      ( u_regslice_o_tx_axi_awlen     ), //o
    .o_tx_axi_awuser     ( u_regslice_o_tx_axi_awuser    ), //o
    .o_tx_axi_awvalid    ( u_regslice_o_tx_axi_awvalid   ), //o
    .i_tx_axi_awready    ( u_regslice_i_tx_axi_awready   ), //i
    .o_tx_axi_wdata      ( u_regslice_o_tx_axi_wdata     ), //o
    .o_tx_axi_wstrb      ( u_regslice_o_tx_axi_wstrb     ), //o
    .o_tx_axi_wlast      ( u_regslice_o_tx_axi_wlast     ), //o
    .o_tx_axi_wvalid     ( u_regslice_o_tx_axi_wvalid    ), //o
    .i_tx_axi_wready     ( u_regslice_i_tx_axi_wready    ), //i
    .i_tx_axi_bresp      ( u_regslice_i_tx_axi_bresp     ), //i
    .i_tx_axi_bid        ( u_regslice_i_tx_axi_bid       ), //i
    .i_tx_axi_bvalid     ( u_regslice_i_tx_axi_bvalid    ), //i
    .o_tx_axi_bready     ( u_regslice_o_tx_axi_bready    )  //o
);

endmodule //end of com_axi_wch


