/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/17-10:54:12
*
*  Description:
*  - for o_tx_axi_awvalid/o_tx_axi_wvalid, allow "wa_before_wd"; not allow "wa_with_wd+wa_after_wd";
*  - for i_rx_axi_awvalid/i_rx_axi_wvalid, not required;
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_wch_arb #( parameter
    AW      = 32        ,
    DW      = 128       ,
    IW      = 4         ,
    LW      = 8         , //range=[1:8]
    UW      = 1         ,
    WCH     = 4         ,
    localparam SW = DW/8           //,
)
(
input  wire clk   ,
input  wire rst_n ,
input  wire clear ,

input  wire [WCH-1:0][AW-1:0]   i_rx_axi_awaddr  ,
input  wire [WCH-1:0][LW-1:0]   i_rx_axi_awlen   ,
input  wire [WCH-1:0][UW-1:0]   i_rx_axi_awuser  ,
input  wire [WCH-1:0]           i_rx_axi_awvalid ,
output wire [WCH-1:0]           o_rx_axi_awready ,
input  wire [WCH-1:0][DW-1:0]   i_rx_axi_wdata   ,
input  wire [WCH-1:0][DW/8-1:0] i_rx_axi_wstrb   ,
input  wire [WCH-1:0]           i_rx_axi_wlast   ,
input  wire [WCH-1:0]           i_rx_axi_wvalid  ,
output wire [WCH-1:0]           o_rx_axi_wready  ,
output wire [WCH-1:0][1:0]      o_rx_axi_bresp   ,
output wire [WCH-1:0]           o_rx_axi_bvalid  , //pure comb_logic, together with i_tx_axi_bvalid
input  wire [WCH-1:0]           i_rx_axi_bready  ,

output wire [IW-1:0]   o_tx_axi_awid    ,
output wire [AW-1:0]   o_tx_axi_awaddr  ,
output wire [LW-1:0]   o_tx_axi_awlen   ,
output wire [UW-1:0]   o_tx_axi_awuser  ,
output wire            o_tx_axi_awvalid , //pure comb_logic, together with i_rx_axi_awvalid
input  wire            i_tx_axi_awready ,
output wire [DW-1:0]   o_tx_axi_wdata   ,
output wire [DW/8-1:0] o_tx_axi_wstrb   ,
output wire            o_tx_axi_wlast   , //pure comb_logic, together with i_rx_axi_wvalid
output wire            o_tx_axi_wvalid  , //allow "wa_before_wd"; not allow "wa_with_wd+wa_after_wd";
input  wire            i_tx_axi_wready  ,
input  wire [1:0]      i_tx_axi_bresp   ,
input  wire [IW-1:0]   i_tx_axi_bid     ,
input  wire            i_tx_axi_bvalid  ,
output wire            o_tx_axi_bready   //,
);
//localparam-----------------------------------------------------------------
localparam WCH_L2 = $clog2(WCH>2?WCH:2);
localparam WA2WD_DEPTH = 4;
//signal declare-------------------------------------------------------------
wire  [WCH-1:0]    u_arb_i_req_vld    ;
wire  [WCH-1:0]    u_arb_o_req_rdy    ;
wire  [WCH_L2-1:0] u_arb_o_gnt_idx    ;
wire               u_arb_o_gnt_vld    ;
wire               u_arb_i_gnt_rdy    ;
wire               u_wa2wd_i_wr_en    ;
wire  [WCH_L2-1:0] u_wa2wd_i_wr_data  ;
wire               u_wa2wd_o_wr_full  ;
wire               u_wa2wd_i_rd_en    ;
wire  [WCH_L2-1:0] u_wa2wd_o_rd_data  ;
wire               u_wa2wd_o_rd_empty ;
//statement------------------------------------------------------------------

//output---
assign o_tx_axi_awid     = IW'(u_arb_o_gnt_idx);
assign o_tx_axi_awaddr   = i_rx_axi_awaddr [u_arb_o_gnt_idx];
assign o_tx_axi_awlen    = i_rx_axi_awlen  [u_arb_o_gnt_idx];
assign o_tx_axi_awuser   = i_rx_axi_awuser [u_arb_o_gnt_idx];
assign o_tx_axi_awvalid  = u_wa2wd_o_wr_full ? 1'b0 : u_arb_o_gnt_vld;
assign o_rx_axi_awready  = u_wa2wd_o_wr_full ?   '0 : u_arb_o_req_rdy;
wire [WCH_L2-1:0] tmp_wid = u_wa2wd_o_rd_data;
wire [WCH-1:0] wid_onehot = WCH'('b1)<<tmp_wid;;
assign o_tx_axi_wdata = i_rx_axi_wdata[tmp_wid];
assign o_tx_axi_wstrb = i_rx_axi_wstrb[tmp_wid];
assign o_tx_axi_wlast = i_rx_axi_wlast[tmp_wid];
assign o_tx_axi_wvalid = (u_wa2wd_o_wr_full||u_wa2wd_o_rd_empty) ? 1'b0 : i_rx_axi_wvalid[tmp_wid];
assign o_rx_axi_wready = (u_wa2wd_o_wr_full||u_wa2wd_o_rd_empty) ? '0 : ({WCH{i_tx_axi_wready}}&wid_onehot);
wire [WCH_L2-1:0] tmp_bid = WCH_L2'(i_tx_axi_bid);
wire [WCH-1:0] bid_onehot = WCH'('b1)<<tmp_bid;
assign o_rx_axi_bresp  = {WCH{i_tx_axi_bresp}};
assign o_rx_axi_bvalid = {WCH{i_tx_axi_bvalid}} & bid_onehot[tmp_bid];
assign o_tx_axi_bready = i_rx_axi_bready[tmp_bid];


//wa channel---
assign u_arb_i_req_vld = i_rx_axi_awvalid;
assign u_arb_i_gnt_rdy = i_tx_axi_awready;
com_arbiter_rr #(
    .REQ_N ( WCH )  //2
)zr_com_arbiter_rr(
    .clk          ( clk             ),   //i
    .rst_n        ( rst_n           ),   //i
    .clear        ( clear           ),   //i
    .i_req_vld    ( u_arb_i_req_vld ),   //i
    .o_req_rdy    ( u_arb_o_req_rdy ),   //o
    .o_gnt_onehot (                 ),   //o
    .o_gnt_idx    ( u_arb_o_gnt_idx ),   //o
    .o_gnt_vld    ( u_arb_o_gnt_vld ),   //o
    .i_gnt_rdy    ( u_arb_i_gnt_rdy )  //i
);

//wd channel----
assign u_wa2wd_i_wr_en   = o_tx_axi_awvalid && i_tx_axi_awready;
assign u_wa2wd_i_wr_data = u_arb_o_gnt_idx;
assign u_wa2wd_i_rd_en   = o_tx_axi_wvalid && i_tx_axi_wready && o_tx_axi_wlast;
com_sync_fifo_reg #(
    .DW    ( WCH_L2      ),   //8
    .DEPTH ( WA2WD_DEPTH )  //4
)r_com_sync_fifo_reg_wa2wd
(
    .clk   ( clk   ),   //i
    .rst_n ( rst_n ),   //i
    .clear ( clear ),   //i

    .i_wr_en       ( u_wa2wd_i_wr_en    ),   //i
    .i_wr_data     ( u_wa2wd_i_wr_data  ),   //i
    .o_wr_full     ( u_wa2wd_o_wr_full  ),   //o
    .i_rd_en       ( u_wa2wd_i_rd_en    ),   //i
    .o_rd_data     ( u_wa2wd_o_rd_data  ),   //o
    .o_rd_empty    ( u_wa2wd_o_rd_empty ),   //o
    .o_water_level (                    )  //o
);

endmodule //end of com_axi_wch_arb


