/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/17-17:23:42
*
*  Description:
*  - for i_rx_axi_awvalid/i_rx_axi_wvalid + o_tx_axi_awvalid/o_tx_axi_wvalid, allow "wa_before_wd"; not allow "wa_with_wd+wa_after_wd";
*  - no axi_wlast, depend "com_axi_wch_regslice" module to recover wlast signal;
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_wch_clr #( parameter
    AW      = 32        ,
    DW      = 128       ,
    IW      = 4         ,
    LW      = 8         ,  //range=[1:8]
    UW      = 1         ,
    MAX_LEN = 4         ,   //range=[1:256], max burst_len, not minus 1;
    MAX_OSD = 16        , //max burst(cmd) outstandint;
    localparam SW = DW/8//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
//cfg&status---
input  wire                     i_ps_axi_terminate  , //pulse signal
output wire                     o_sta_clr_ongoing   , //level signal
//dp---
input  wire [IW-1:0]            i_rx_axi_awid       ,
input  wire [AW-1:0]            i_rx_axi_awaddr     ,
input  wire [LW-1:0]            i_rx_axi_awlen      ,
input  wire [UW-1:0]            i_rx_axi_awuser     ,
input  wire                     i_rx_axi_awvalid    ,
output wire                     o_rx_axi_awready    ,
input  wire [DW-1:0]            i_rx_axi_wdata      ,
input  wire [DW/8-1:0]          i_rx_axi_wstrb      ,
input  wire                     i_rx_axi_wvalid     , //allow "wa_before_wd"; not allow "wa_with_wd+wa_after_wd";
output wire                     o_rx_axi_wready     ,
output wire [1:0]               o_rx_axi_bresp      ,
output wire [IW-1:0]            o_rx_axi_bid        ,
output wire                     o_rx_axi_bvalid     ,
input  wire                     i_rx_axi_bready     ,

output wire [IW-1:0]            o_tx_axi_awid       ,
output wire [AW-1:0]            o_tx_axi_awaddr     ,
output wire [LW-1:0]            o_tx_axi_awlen      ,
output wire [UW-1:0]            o_tx_axi_awuser     ,
output wire                     o_tx_axi_awvalid    ,
input  wire                     i_tx_axi_awready    ,
output wire [DW-1:0]            o_tx_axi_wdata      ,
output wire [DW/8-1:0]          o_tx_axi_wstrb      ,
output wire                     o_tx_axi_wvalid     , //allow "wa_before_wd"; not allow "wa_with_wd+wa_after_wd";
input  wire                     i_tx_axi_wready     ,
input  wire [1:0]               i_tx_axi_bresp      ,
input  wire [IW-1:0]            i_tx_axi_bid        ,
input  wire                     i_tx_axi_bvalid     ,
output wire                     o_tx_axi_bready     //,
);
//localparam-----------------------------------------------------------------
localparam MAX_OSD_DAT = MAX_OSD*MAX_LEN;
localparam MAX_OSD_DAT_L2 = $clog2(MAX_OSD_DAT);
localparam MAX_OSD_L2 = $clog2(MAX_OSD);
//signal declare-------------------------------------------------------------
reg                       r_clr_flag;
reg  [MAX_OSD_DAT_L2-0:0] r_dat_cnt;  //aw->w
reg  [MAX_OSD_L2-1:0]     r_cmd_cnt; //aw->b

wire tx_awhs = o_tx_axi_awvalid && i_tx_axi_awready;
wire tx_whs  = o_tx_axi_wvalid && i_tx_axi_wready;
wire tx_bhs  = i_tx_axi_bvalid && o_tx_axi_bready;
wire b_wa_before_wd_flag = r_dat_cnt>'0;
wire b_dat_flush_flag = r_clr_flag && r_dat_cnt>'0;
wire clr_done;
//statement------------------------------------------------------------------
//out---
assign o_sta_clr_ongoing = r_clr_flag;
assign o_tx_axi_awid     = i_rx_axi_awid    ;
assign o_tx_axi_awaddr   = i_rx_axi_awaddr  ;
assign o_tx_axi_awlen    = i_rx_axi_awlen   ;
assign o_tx_axi_awuser   = i_rx_axi_awuser  ;
assign o_tx_axi_awvalid  = r_clr_flag ? 1'b0 : i_rx_axi_awvalid ;
assign o_rx_axi_awready  = r_clr_flag ? 1'b0 : i_tx_axi_awready ;

assign o_tx_axi_wdata    = i_rx_axi_wdata ;
assign o_tx_axi_wstrb    = i_rx_axi_wstrb ;
assign o_tx_axi_wvalid   = b_dat_flush_flag ? 1'b1 : b_wa_before_wd_flag ? i_rx_axi_wvalid : 1'b0;
assign o_rx_axi_wready   = r_clr_flag       ? 1'b0 : b_wa_before_wd_flag ? i_tx_axi_wready : 1'b0;

assign o_rx_axi_bid     = i_tx_axi_bid   ;
assign o_rx_axi_bresp   = i_tx_axi_bresp ;
assign o_rx_axi_bvalid  = r_clr_flag ? 1'b0 : i_tx_axi_bvalid;
assign o_tx_axi_bready  = r_clr_flag ? 1'b0 : i_rx_axi_bready;


always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        r_clr_flag <= 1'b0;
    else if( clr_done )
        r_clr_flag <= 1'b0;
    else if( i_ps_axi_terminate )
        r_clr_flag <= 1'b1;
end

wire [LW-0:0] tx_awlen_p1 = tx_awhs ? (o_tx_axi_awlen+1'b1) : '0;
wire [MAX_OSD_DAT_L2-0:0] w_dat_cnt_nxt = r_dat_cnt + tx_awlen_p1 - tx_whs;
wire [MAX_OSD_L2-1:0] w_cmd_cnt_nxt = r_cmd_cnt + tx_awhs - tx_bhs;
assign clr_done = r_clr_flag && w_cmd_cnt_nxt=='0 && tx_bhs;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        r_dat_cnt <= '0;
    else if( tx_awhs || tx_whs )
        r_dat_cnt <= w_dat_cnt_nxt[MAX_OSD_DAT_L2-1:0];
end
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        r_cmd_cnt <= '0;
    else if( tx_awhs || tx_bhs )
        r_cmd_cnt <= w_cmd_cnt_nxt[MAX_OSD_L2-1:0];
end

endmodule //end of com_axi_wch_clr


