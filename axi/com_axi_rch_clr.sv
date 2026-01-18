/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2020/11/13-09:42:42
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_axi_rch_clr #( parameter
    AW      = 32        ,
    DW      = 128       ,
    IW      = 4         ,
    LW      = 8         , //range=[1:8]
    UW      = 1         ,
    MAX_LEN = 4         ,   //range=[1:256], max burst_len, not minus 1;
    MAX_OSD = 16        //, //max burst(cmd) outstandint;
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
//cfg&status---
input  wire                     i_ps_axi_terminate  , //pulse signal
output wire                     o_sta_clr_ongoing   , //level signal
//axi
input  wire [AW-1:0]            i_rx_axi_araddr     ,
input  wire [LW-1:0]            i_rx_axi_arlen      ,
input  wire [UW-1:0]            i_rx_axi_aruser     ,
input  wire                     i_rx_axi_arvalid    ,
output wire                     o_rx_axi_arready    ,
output wire [1:0]               o_rx_axi_rresp      ,
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
localparam MAX_OSD_DAT = MAX_OSD*MAX_LEN;
localparam MAX_OSD_DAT_L2 = $clog2(MAX_OSD_DAT);
localparam MAX_OSD_L2 = $clog2(MAX_OSD);
//signal declare-------------------------------------------------------------
reg                       r_clr_flag;
reg  [MAX_OSD_L2-1:0]     r_cmd_cnt;  //ar->rlast

wire tx_arhs = o_tx_axi_arvalid && i_tx_axi_arready;
wire tx_rhs  = i_tx_axi_rvalid && o_tx_axi_rready;
wire clr_done;
//statement------------------------------------------------------------------
//out---
assign o_sta_clr_ongoing = r_clr_flag;
assign o_tx_axi_arid     = i_rx_axi_arid    ;
assign o_tx_axi_araddr   = i_rx_axi_araddr  ;
assign o_tx_axi_arlen    = i_rx_axi_arlen   ;
assign o_tx_axi_aruser   = i_rx_axi_aruser  ;
assign o_tx_axi_arvalid  = r_clr_flag ? 1'b0 : i_rx_axi_arvalid ;
assign o_rx_axi_arready  = r_clr_flag ? 1'b0 : i_tx_axi_arready ;

assign o_rx_axi_rid     = i_tx_axi_rid   ;
assign o_rx_axi_rresp   = i_tx_axi_rresp ;
assign o_rx_axi_rdata   = i_tx_axi_rdata ;
assign o_rx_axi_rvalid  = r_clr_flag ? 1'b0 : i_tx_axi_rvalid;
assign o_tx_axi_rready  = r_clr_flag ? 1'b0 : i_rx_axi_rready;


always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        r_clr_flag <= 1'b0;
    else if( clr_done )
        r_clr_flag <= 1'b0;
    else if( i_ps_axi_terminate )
        r_clr_flag <= 1'b1;
end

wire tx_rhs_last = (tx_rhs&&i_tx_axi_rlast);
wire [MAX_OSD_L2-1:0] w_cmd_cnt_nxt = r_cmd_cnt + tx_arhs - tx_rhs_last;
assign clr_done = r_clr_flag && w_cmd_cnt_nxt=='0 && tx_rhs;  //also w_dat_cnt_nxt=='0;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        r_cmd_cnt <= '0;
    else if( tx_arhs || tx_rhs_last )
        r_cmd_cnt <= w_cmd_cnt_nxt[MAX_OSD_L2-1:0];
end

//synopsys translate_off
reg  [MAX_OSD_DAT_L2-0:0] r_dat_cnt;  //ar->r;  //maybe unused;
wire [LW-0:0] tx_arlen_p1 = tx_arhs ? (o_tx_axi_arlen+1'b1) : '0;
wire [MAX_OSD_DAT_L2-0:0] w_dat_cnt_nxt = r_dat_cnt + tx_arlen_p1 - tx_rhs;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        r_dat_cnt <= '0;
    else if( tx_arhs || tx_rhs )
        r_dat_cnt <= w_dat_cnt_nxt[MAX_OSD_DAT_L2-1:0];
end
//synopsys translate_on

endmodule //end of com_axi_rch_clr


