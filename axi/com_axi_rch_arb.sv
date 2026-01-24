/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/11-15:35:37
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_rch_arb #( parameter
    AW      = 32        ,
    DW      = 128       ,
    IW      = 4         ,
    LW      = 8         , //range=[1:8]
    UW      = 1         ,
    RCH     = 4         //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

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
localparam RCH_L2 = $clog2(RCH>2?RCH:2);
//signal declare-------------------------------------------------------------
wire [RCH-1:0]       u_arb_i_req_vld  ;
wire [RCH-1:0]       u_arb_o_req_rdy  ;
wire [RCH_L2-1:0]    u_arb_o_gnt_idx  ;
wire                 u_arb_o_gnt_vld  ;
wire                 u_arb_i_gnt_rdy  ;
//statement------------------------------------------------------------------
//output---
assign o_tx_axi_arid     = IW'(u_arb_o_gnt_idx);
assign o_tx_axi_araddr   = i_rx_axi_araddr [u_arb_o_gnt_idx];
assign o_tx_axi_arlen    = i_rx_axi_arlen  [u_arb_o_gnt_idx];
assign o_tx_axi_aruser   = i_rx_axi_aruser [u_arb_o_gnt_idx];
assign o_tx_axi_arvalid  = u_arb_o_gnt_vld;
assign o_rx_axi_arready  = u_arb_o_req_rdy;
wire [RCH_L2-1:0] tmp_rid = RCH_L2'(i_tx_axi_rid);
wire [RCH-1:0] rid_onehot = RCH'('b1)<<tmp_rid;
assign o_rx_axi_rresp  = {RCH{i_tx_axi_rresp}};
assign o_rx_axi_rdata  = {RCH{i_tx_axi_rdata}};
assign o_rx_axi_rlast  = {RCH{i_tx_axi_rlast}};
assign o_rx_axi_rvalid = {RCH{i_tx_axi_rvalid}} & rid_onehot[tmp_rid];
assign o_tx_axi_rready = i_rx_axi_rready[tmp_rid];

//ra channel---
assign u_arb_i_req_vld = i_rx_axi_arvalid;
assign u_arb_i_gnt_rdy = i_tx_axi_arready;
com_arbiter_rr #(
    .REQ_N    ( RCH )  //2
)zr_com_arbiter_rr(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( clear                ), //i
    .i_req_vld           ( u_arb_i_req_vld      ), //i
    .o_req_rdy           ( u_arb_o_req_rdy      ), //o
    .o_gnt_onehot        (                      ), //o
    .o_gnt_idx           ( u_arb_o_gnt_idx      ), //o
    .o_gnt_vld           ( u_arb_o_gnt_vld      ), //o
    .i_gnt_rdy           ( u_arb_i_gnt_rdy      )  //i
);

endmodule //end of com_axi_rch_arb


