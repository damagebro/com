/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/28
*
*  Description:
*  - Independently arbitrate multiple RAM write and read request channels.
*  - Route fixed-latency read responses back to the granted read channel.
*
******************************************************************************/

module com_ram_arbiter #( parameter
    WCH          = 2, //range=[1::]
    RCH          = 2, //range=[1::]
    AW           = 8,
    DW           = 8,
    STRB_W       = 1,
    RAM_RD_DELAY = 1  //range=[1:16:], fixed delay from tx rd_hs to tx rd_ack
)
(
input  wire                         clk                 ,
input  wire                         rst_n               ,
input  wire                         clear               ,

input  wire [WCH-1:0][AW-1:0]       i_rx_wr_addr        ,
input  wire [WCH-1:0][DW-1:0]       i_rx_wr_data        ,
input  wire [WCH-1:0][STRB_W-1:0]   i_rx_wr_vld         ,
output wire [WCH-1:0]               o_rx_wr_rdy         ,

input  wire [RCH-1:0][AW-1:0]       i_rx_rd_addr        ,
input  wire [RCH-1:0]               i_rx_rd_vld         ,
output wire [RCH-1:0]               o_rx_rd_rdy         ,
output wire [RCH-1:0]               o_rx_rd_ack         ,
output wire [RCH-1:0][DW-1:0]       o_rx_rd_data        ,

output wire [AW-1:0]                o_tx_wr_addr        ,
output wire [DW-1:0]                o_tx_wr_data        ,
output wire [STRB_W-1:0]            o_tx_wr_vld         ,
input  wire                         i_tx_wr_rdy         ,

output wire [AW-1:0]                o_tx_rd_addr        ,
output wire                         o_tx_rd_vld         ,
input  wire                         i_tx_rd_rdy         ,
input  wire                         i_tx_rd_ack         ,
input  wire [DW-1:0]                i_tx_rd_data        //,
);
//localparam-----------------------------------------------------------------
localparam WCH_L2 = $clog2(WCH>2 ? WCH : 2);
localparam RCH_L2 = $clog2(RCH>2 ? RCH : 2);
//signal declare-------------------------------------------------------------
reg  [RAM_RD_DELAY-1:0][RCH-1:0] r_rd_gnt_pipe;

wire [WCH-1:0]                   wr_req_vld;
wire [RCH-1:0]                   rd_rsp_onehot;
wire                             rd_hs;

//instance signal--
wire [WCH-1:0]                   u_wr_arb_i_req_vld;
wire [WCH-1:0]                   u_wr_arb_o_req_rdy;
wire [WCH-1:0]                   u_wr_arb_o_gnt_onehot;
wire [WCH_L2-1:0]                u_wr_arb_o_gnt_idx;
wire                             u_wr_arb_o_gnt_vld;
wire                             u_wr_arb_i_gnt_rdy;

wire [RCH-1:0]                   u_rd_arb_i_req_vld;
wire [RCH-1:0]                   u_rd_arb_o_req_rdy;
wire [RCH-1:0]                   u_rd_arb_o_gnt_onehot;
wire [RCH_L2-1:0]                u_rd_arb_o_gnt_idx;
wire                             u_rd_arb_o_gnt_vld;
wire                             u_rd_arb_i_gnt_rdy;
//statement------------------------------------------------------------------
//output assign---
assign o_rx_wr_rdy = u_wr_arb_o_req_rdy;

assign o_rx_rd_rdy = u_rd_arb_o_req_rdy;
assign o_rx_rd_ack = rd_rsp_onehot & {RCH{i_tx_rd_ack}};
assign o_rx_rd_data = {RCH{i_tx_rd_data}};

assign o_tx_wr_addr = i_rx_wr_addr[u_wr_arb_o_gnt_idx];
assign o_tx_wr_data = i_rx_wr_data[u_wr_arb_o_gnt_idx];
assign o_tx_wr_vld = u_wr_arb_o_gnt_vld ?
                     i_rx_wr_vld[u_wr_arb_o_gnt_idx] : '0;

assign o_tx_rd_addr = i_rx_rd_addr[u_rd_arb_o_gnt_idx];
assign o_tx_rd_vld = u_rd_arb_o_gnt_vld;

//body---
for( genvar gi=0; gi<WCH; gi++ ) begin:gen_wr_req_vld
    assign wr_req_vld[gi] = |i_rx_wr_vld[gi];
end

assign rd_hs = o_tx_rd_vld && i_tx_rd_rdy;
assign rd_rsp_onehot = r_rd_gnt_pipe[RAM_RD_DELAY-1];

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rd_gnt_pipe <= '0;
    else if( clear )
        r_rd_gnt_pipe <= '0;
    else begin
        r_rd_gnt_pipe[0] <= rd_hs ? u_rd_arb_o_gnt_onehot : '0;
        for( int i=1; i<RAM_RD_DELAY; i++ )
            r_rd_gnt_pipe[i] <= r_rd_gnt_pipe[i-1];
    end
end

//instance----
assign u_wr_arb_i_req_vld = wr_req_vld;
assign u_wr_arb_i_gnt_rdy = i_tx_wr_rdy;
com_arbiter_rr #(
    .REQ_N                ( WCH                           )  //2
)u_com_arbiter_rr_wr_arb
(
    .clk                  ( clk                           ), //i
    .rst_n                ( rst_n                         ), //i
    .clear                ( clear                         ), //i

    .i_req_vld            ( u_wr_arb_i_req_vld            ), //i
    .o_req_rdy            ( u_wr_arb_o_req_rdy            ), //o
    .o_gnt_onehot         ( u_wr_arb_o_gnt_onehot         ), //o
    .o_gnt_idx            ( u_wr_arb_o_gnt_idx            ), //o
    .o_gnt_vld            ( u_wr_arb_o_gnt_vld            ), //o
    .i_gnt_rdy            ( u_wr_arb_i_gnt_rdy            )  //i
);

assign u_rd_arb_i_req_vld = i_rx_rd_vld;
assign u_rd_arb_i_gnt_rdy = i_tx_rd_rdy;
com_arbiter_rr #(
    .REQ_N                ( RCH                           )  //2
)u_com_arbiter_rr_rd_arb
(
    .clk                  ( clk                           ), //i
    .rst_n                ( rst_n                         ), //i
    .clear                ( clear                         ), //i

    .i_req_vld            ( u_rd_arb_i_req_vld            ), //i
    .o_req_rdy            ( u_rd_arb_o_req_rdy            ), //o
    .o_gnt_onehot         ( u_rd_arb_o_gnt_onehot         ), //o
    .o_gnt_idx            ( u_rd_arb_o_gnt_idx            ), //o
    .o_gnt_vld            ( u_rd_arb_o_gnt_vld            ), //o
    .i_gnt_rdy            ( u_rd_arb_i_gnt_rdy            )  //i
);

//assert---------------------------------------------------------------------
`COM_PARAM_ASSERT( WCH>=1, "write channel number must larger than 0" )
`COM_PARAM_ASSERT( RCH>=1, "read channel number must larger than 0" )
`COM_PARAM_ASSERT( STRB_W>=1 && DW%STRB_W==0, "DW must be divisible by STRB_W" )
`COM_PARAM_ASSERT( RAM_RD_DELAY>=1 && RAM_RD_DELAY<=16, "ram read delay range is [1:16]" )

endmodule //end of com_ram_arbiter
