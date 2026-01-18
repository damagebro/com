/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/16-14:45:55
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_rch #( parameter
    AW      = 32        ,
    DW      = 128       ,
    IW      = 4         ,
    LW      = 8         , //range=[1:8]
    UW      = 1         ,
    RCH     = 4         ,
    MAX_OSD = 16        ,
    MAX_LEN = 4         //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//cfg&status---
output wire                     o_sta_clr_ongoing   , //level signal
//axi
input  wire [RCH-1:0][AW-1:0]   i_rx_axi_araddr     ,
input  wire [RCH-1:0][LW-1:0]   i_rx_axi_arlen      ,
input  wire [RCH-1:0][UW-1:0]   i_rx_axi_aruser     ,
input  wire [RCH-1:0]           i_rx_axi_arvalid    ,
output wire [RCH-1:0]           o_rx_axi_arready    ,
output wire [RCH-1:0][1:0]      o_rx_axi_rresp      ,
output wire [RCH-1:0][DW-1:0]   o_rx_axi_rdata      ,
output wire [RCH-1:0]           o_rx_axi_rlast      ,
output wire [RCH-1:0]           o_rx_axi_rvalid     ,
input  wire [RCH-1:0]           i_rx_axi_rready     ,

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
//signal declare-------------------------------------------------------------
wire [RCH-1:0][AW-1:0]   u_arb_i_rx_axi_araddr     ;
wire [RCH-1:0][LW-1:0]   u_arb_i_rx_axi_arlen      ;
wire [RCH-1:0][UW-1:0]   u_arb_i_rx_axi_aruser     ;
wire [RCH-1:0]           u_arb_i_rx_axi_arvalid    ;
wire [RCH-1:0]           u_arb_o_rx_axi_arready    ;
wire [RCH-1:0][1:0]      u_arb_o_rx_axi_rresp      ;
wire [RCH-1:0][DW-1:0]   u_arb_o_rx_axi_rdata      ;
wire [RCH-1:0]           u_arb_o_rx_axi_rlast      ;
wire [RCH-1:0]           u_arb_o_rx_axi_rvalid     ;
wire [RCH-1:0]           u_arb_i_rx_axi_rready     ;
wire [IW-1:0]            u_arb_o_tx_axi_arid       ;
wire [AW-1:0]            u_arb_o_tx_axi_araddr     ;
wire [LW-1:0]            u_arb_o_tx_axi_arlen      ;
wire [UW-1:0]            u_arb_o_tx_axi_aruser     ;
wire                     u_arb_o_tx_axi_arvalid    ;
wire                     u_arb_i_tx_axi_arready    ;
wire [1:0]               u_arb_i_tx_axi_rresp      ;
wire [IW-1:0]            u_arb_i_tx_axi_rid        ;
wire [DW-1:0]            u_arb_i_tx_axi_rdata      ;
wire                     u_arb_i_tx_axi_rlast      ;
wire                     u_arb_i_tx_axi_rvalid     ;
wire                     u_arb_o_tx_axi_rready     ;

wire [AW-1:0]            u_clr_i_rx_axi_araddr     ;
wire [LW-1:0]            u_clr_i_rx_axi_arlen      ;
wire [UW-1:0]            u_clr_i_rx_axi_aruser     ;
wire                     u_clr_i_rx_axi_arvalid    ;
wire                     u_clr_o_rx_axi_arready    ;
wire [1:0]               u_clr_o_rx_axi_rresp      ;
wire [DW-1:0]            u_clr_o_rx_axi_rdata      ;
wire                     u_clr_o_rx_axi_rlast      ;
wire                     u_clr_o_rx_axi_rvalid     ;
wire                     u_clr_i_rx_axi_rready     ;
wire [IW-1:0]            u_clr_o_tx_axi_arid       ;
wire [AW-1:0]            u_clr_o_tx_axi_araddr     ;
wire [LW-1:0]            u_clr_o_tx_axi_arlen      ;
wire [UW-1:0]            u_clr_o_tx_axi_aruser     ;
wire                     u_clr_o_tx_axi_arvalid    ;
wire                     u_clr_i_tx_axi_arready    ;
wire [1:0]               u_clr_i_tx_axi_rresp      ;
wire [IW-1:0]            u_clr_i_tx_axi_rid        ;
wire [DW-1:0]            u_clr_i_tx_axi_rdata      ;
wire                     u_clr_i_tx_axi_rlast      ;
wire                     u_clr_i_tx_axi_rvalid     ;
wire                     u_clr_o_tx_axi_rready     ;

wire [AW-1:0]            u_regslice_i_rx_axi_araddr   ;
wire [LW-1:0]            u_regslice_i_rx_axi_arlen    ;
wire [UW-1:0]            u_regslice_i_rx_axi_aruser   ;
wire                     u_regslice_i_rx_axi_arvalid  ;
wire                     u_regslice_o_rx_axi_arready  ;
wire [1:0]               u_regslice_o_rx_axi_rresp    ;
wire [DW-1:0]            u_regslice_o_rx_axi_rdata    ;
wire                     u_regslice_o_rx_axi_rlast    ;
wire                     u_regslice_o_rx_axi_rvalid   ;
wire                     u_regslice_i_rx_axi_rready   ;
wire [IW-1:0]            u_regslice_o_tx_axi_arid     ;
wire [AW-1:0]            u_regslice_o_tx_axi_araddr   ;
wire [LW-1:0]            u_regslice_o_tx_axi_arlen    ;
wire [UW-1:0]            u_regslice_o_tx_axi_aruser   ;
wire                     u_regslice_o_tx_axi_arvalid  ;
wire                     u_regslice_i_tx_axi_arready  ;
wire [1:0]               u_regslice_i_tx_axi_rresp    ;
wire [IW-1:0]            u_regslice_i_tx_axi_rid      ;
wire [DW-1:0]            u_regslice_i_tx_axi_rdata    ;
wire                     u_regslice_i_tx_axi_rlast    ;
wire                     u_regslice_i_tx_axi_rvalid   ;
wire                     u_regslice_o_tx_axi_rready   ;
//statement------------------------------------------------------------------
//out---
assign o_rx_axi_arready = u_arb_o_rx_axi_arready;
assign o_rx_axi_rresp   = u_arb_o_rx_axi_rresp  ;
assign o_rx_axi_rdata   = u_arb_o_rx_axi_rdata  ;
assign o_rx_axi_rlast   = u_arb_o_rx_axi_rlast  ;
assign o_rx_axi_rvalid  = u_arb_o_rx_axi_rvalid ;
assign o_tx_axi_arid    = u_regslice_o_tx_axi_arid   ;
assign o_tx_axi_araddr  = u_regslice_o_tx_axi_araddr ;
assign o_tx_axi_arlen   = u_regslice_o_tx_axi_arlen  ;
assign o_tx_axi_aruser  = u_regslice_o_tx_axi_aruser ;
assign o_tx_axi_arvalid = u_regslice_o_tx_axi_arvalid;
assign o_tx_axi_rready  = u_regslice_o_tx_axi_rready ;

//instance---
assign u_arb_i_rx_axi_araddr   = i_rx_axi_araddr       ;
assign u_arb_i_rx_axi_arlen    = i_rx_axi_arlen        ;
assign u_arb_i_rx_axi_aruser   = i_rx_axi_aruser       ;
assign u_arb_i_rx_axi_arvalid  = i_rx_axi_arvalid      ;
assign u_arb_i_rx_axi_rready   = i_rx_axi_rready       ;
assign u_arb_i_tx_axi_arready  = u_clr_o_rx_axi_arready;
assign u_arb_i_tx_axi_rresp    = u_clr_o_rx_axi_rresp  ;
assign u_arb_i_tx_axi_rid      = u_clr_o_rx_axi_rid    ;
assign u_arb_i_tx_axi_rdata    = u_clr_o_rx_axi_rdata  ;
assign u_arb_i_tx_axi_rlast    = u_clr_o_rx_axi_rlast  ;
assign u_arb_i_tx_axi_rvalid   = u_clr_o_rx_axi_rvalid ;
com_axi_rch_arb #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .IW                             ( IW                            ), //4
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .RCH                            ( RCH                           )  //4
)u_com_axi_rch_arb(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( clear                ), //i
    .i_rx_axi_araddr     ( u_arb_i_rx_axi_araddr  ), //i
    .i_rx_axi_arlen      ( u_arb_i_rx_axi_arlen   ), //i
    .i_rx_axi_aruser     ( u_arb_i_rx_axi_aruser  ), //i
    .i_rx_axi_arvalid    ( u_arb_i_rx_axi_arvalid ), //i
    .o_rx_axi_arready    ( u_arb_o_rx_axi_arready ), //o
    .o_rx_axi_rresp      ( u_arb_o_rx_axi_rresp   ), //o
    .o_rx_axi_rdata      ( u_arb_o_rx_axi_rdata   ), //o
    .o_rx_axi_rlast      ( u_arb_o_rx_axi_rlast   ), //o
    .o_rx_axi_rvalid     ( u_arb_o_rx_axi_rvalid  ), //o
    .i_rx_axi_rready     ( u_arb_i_rx_axi_rready  ), //i
    .o_tx_axi_arid       ( u_arb_o_tx_axi_arid    ), //o
    .o_tx_axi_araddr     ( u_arb_o_tx_axi_araddr  ), //o
    .o_tx_axi_arlen      ( u_arb_o_tx_axi_arlen   ), //o
    .o_tx_axi_aruser     ( u_arb_o_tx_axi_aruser  ), //o
    .o_tx_axi_arvalid    ( u_arb_o_tx_axi_arvalid ), //o
    .i_tx_axi_arready    ( u_arb_i_tx_axi_arready ), //i
    .i_tx_axi_rresp      ( u_arb_i_tx_axi_rresp   ), //i
    .i_tx_axi_rid        ( u_arb_i_tx_axi_rid     ), //i
    .i_tx_axi_rdata      ( u_arb_i_tx_axi_rdata   ), //i
    .i_tx_axi_rlast      ( u_arb_i_tx_axi_rlast   ), //i
    .i_tx_axi_rvalid     ( u_arb_i_tx_axi_rvalid  ), //i
    .o_tx_axi_rready     ( u_arb_o_tx_axi_rready  )  //o
);

assign u_clr_i_rx_axi_araddr   = u_arb_o_tx_axi_araddr       ;
assign u_clr_i_rx_axi_arlen    = u_arb_o_tx_axi_arlen        ;
assign u_clr_i_rx_axi_aruser   = u_arb_o_tx_axi_aruser       ;
assign u_clr_i_rx_axi_arvalid  = u_arb_o_tx_axi_arvalid      ;
assign u_clr_i_rx_axi_rready   = u_arb_o_tx_axi_rready       ;
assign u_clr_i_tx_axi_arready  = u_regslice_o_rx_axi_arready ;
assign u_clr_i_tx_axi_rresp    = u_regslice_o_rx_axi_rresp   ;
assign u_clr_i_tx_axi_rid      = u_regslice_o_rx_axi_rid     ;
assign u_clr_i_tx_axi_rdata    = u_regslice_o_rx_axi_rdata   ;
assign u_clr_i_tx_axi_rlast    = u_regslice_o_rx_axi_rlast   ;
assign u_clr_i_tx_axi_rvalid   = u_regslice_o_rx_axi_rvalid  ;
com_axi_rch_clr #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .IW                             ( IW                            ), //4
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .MAX_LEN                        ( MAX_LEN                       ), //4
    .MAX_OSD                        ( MAX_OSD                       )  //16
)u_com_axi_rch_clr(
    .clk                 ( clk                    ), //i
    .rst_n               ( rst_n                  ), //i
    .i_ps_axi_terminate  ( clear                  ), //i
    .o_sta_clr_ongoing   ( o_sta_clr_ongoing      ), //o
    .i_rx_axi_araddr     ( u_clr_i_rx_axi_araddr  ), //i
    .i_rx_axi_arlen      ( u_clr_i_rx_axi_arlen   ), //i
    .i_rx_axi_aruser     ( u_clr_i_rx_axi_aruser  ), //i
    .i_rx_axi_arvalid    ( u_clr_i_rx_axi_arvalid ), //i
    .o_rx_axi_arready    ( u_clr_o_rx_axi_arready ), //o
    .o_rx_axi_rresp      ( u_clr_o_rx_axi_rresp   ), //o
    .o_rx_axi_rdata      ( u_clr_o_rx_axi_rdata   ), //o
    .o_rx_axi_rlast      ( u_clr_o_rx_axi_rlast   ), //o
    .o_rx_axi_rvalid     ( u_clr_o_rx_axi_rvalid  ), //o
    .i_rx_axi_rready     ( u_clr_i_rx_axi_rready  ), //i
    .o_tx_axi_arid       ( u_clr_o_tx_axi_arid    ), //o
    .o_tx_axi_araddr     ( u_clr_o_tx_axi_araddr  ), //o
    .o_tx_axi_arlen      ( u_clr_o_tx_axi_arlen   ), //o
    .o_tx_axi_aruser     ( u_clr_o_tx_axi_aruser  ), //o
    .o_tx_axi_arvalid    ( u_clr_o_tx_axi_arvalid ), //o
    .i_tx_axi_arready    ( u_clr_i_tx_axi_arready ), //i
    .i_tx_axi_rresp      ( u_clr_i_tx_axi_rresp   ), //i
    .i_tx_axi_rid        ( u_clr_i_tx_axi_rid     ), //i
    .i_tx_axi_rdata      ( u_clr_i_tx_axi_rdata   ), //i
    .i_tx_axi_rlast      ( u_clr_i_tx_axi_rlast   ), //i
    .i_tx_axi_rvalid     ( u_clr_i_tx_axi_rvalid  ), //i
    .o_tx_axi_rready     ( u_clr_o_tx_axi_rready  )  //o
);

assign u_regslice_i_rx_axi_araddr   = u_clr_o_tx_axi_araddr       ;
assign u_regslice_i_rx_axi_arlen    = u_clr_o_tx_axi_arlen        ;
assign u_regslice_i_rx_axi_aruser   = u_clr_o_tx_axi_aruser       ;
assign u_regslice_i_rx_axi_arvalid  = u_clr_o_tx_axi_arvalid      ;
assign u_regslice_i_rx_axi_rready   = u_clr_o_tx_axi_rready       ;
assign u_regslice_i_tx_axi_arready  = i_tx_axi_arready ;
assign u_regslice_i_tx_axi_rresp    = i_tx_axi_rresp   ;
assign u_regslice_i_tx_axi_rid      = i_tx_axi_rid     ;
assign u_regslice_i_tx_axi_rdata    = i_tx_axi_rdata   ;
assign u_regslice_i_tx_axi_rlast    = i_tx_axi_rlast   ;
assign u_regslice_i_tx_axi_rvalid   = i_tx_axi_rvalid  ;
com_axi_rch_regslice #(
    .AW                             ( AW                            ), //32
    .DW                             ( DW                            ), //128
    .IW                             ( IW                            ), //4
    .LW                             ( LW                            ), //8
    .UW                             ( UW                            ), //1
    .RCH                            ( RCH                           ), //4
    .MAX_LEN                        ( MAX_LEN                       ), //4
    .MAX_OSD                        ( MAX_OSD                       )  //16
)u_com_axi_rch_regslice(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( 1'b0                 ), //i
    .i_rx_axi_araddr     ( u_regslice_i_rx_axi_araddr      ), //i
    .i_rx_axi_arlen      ( u_regslice_i_rx_axi_arlen       ), //i
    .i_rx_axi_aruser     ( u_regslice_i_rx_axi_aruser      ), //i
    .i_rx_axi_arvalid    ( u_regslice_i_rx_axi_arvalid     ), //i
    .o_rx_axi_arready    ( u_regslice_o_rx_axi_arready     ), //o
    .o_rx_axi_rresp      ( u_regslice_o_rx_axi_rresp       ), //o
    .o_rx_axi_rdata      ( u_regslice_o_rx_axi_rdata       ), //o
    .o_rx_axi_rlast      ( u_regslice_o_rx_axi_rlast       ), //o
    .o_rx_axi_rvalid     ( u_regslice_o_rx_axi_rvalid      ), //o
    .i_rx_axi_rready     ( u_regslice_i_rx_axi_rready      ), //i
    .o_tx_axi_arid       ( u_regslice_o_tx_axi_arid        ), //o
    .o_tx_axi_araddr     ( u_regslice_o_tx_axi_araddr      ), //o
    .o_tx_axi_arlen      ( u_regslice_o_tx_axi_arlen       ), //o
    .o_tx_axi_aruser     ( u_regslice_o_tx_axi_aruser      ), //o
    .o_tx_axi_arvalid    ( u_regslice_o_tx_axi_arvalid     ), //o
    .i_tx_axi_arready    ( u_regslice_i_tx_axi_arready     ), //i
    .i_tx_axi_rresp      ( u_regslice_i_tx_axi_rresp       ), //i
    .i_tx_axi_rid        ( u_regslice_i_tx_axi_rid         ), //i
    .i_tx_axi_rdata      ( u_regslice_i_tx_axi_rdata       ), //i
    .i_tx_axi_rlast      ( u_regslice_i_tx_axi_rlast       ), //i
    .i_tx_axi_rvalid     ( u_regslice_i_tx_axi_rvalid      ), //i
    .o_tx_axi_rready     ( u_regslice_o_tx_axi_rready      )  //o
);

endmodule //end of com_axi_rch

