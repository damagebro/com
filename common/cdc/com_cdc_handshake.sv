/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/21
*
*  Description:
*  - Transfer one request pulse with a two-phase toggle handshake.
*  - Destination acknowledges automatically when the request pulse is issued.
*  - Only one request can be outstanding.
*
******************************************************************************/

module com_cdc_handshake #( parameter
    SYNC_S = 3 //freq>1.5G ? 4 : freq>1G ? 3 : 2
)
(
input  wire                     i_src_clk           ,
input  wire                     i_src_rst_n         ,
input  wire                     i_dst_clk           ,
input  wire                     i_dst_rst_n         ,

input  wire                     i_src_req_pulse     ,
output wire                     o_src_ack_pulse     ,
output wire                     o_src_busy_level    ,
output wire                     o_dst_req_pulse     //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg                      r_cksrc_req_toggle;
reg                      r_cksrc_ack_toggle_d;
reg                      r_ckdst_ack_toggle;
reg                      r_ckdst_req_pulse;

wire                     cksrc_req_hs;
wire                     cksrc_ack_toggle_sync;
wire                     ckdst_req_toggle_sync;
wire                     ckdst_req_new;

//instance signal--
wire                     u_ckdst_req_sync_i_src_data;
wire                     u_ckdst_req_sync_o_dst_data;
wire                     u_cksrc_ack_sync_i_src_data;
wire                     u_cksrc_ack_sync_o_dst_data;
//statement------------------------------------------------------------------
//output assign---
assign o_src_ack_pulse = cksrc_ack_toggle_sync ^ r_cksrc_ack_toggle_d;
assign o_src_busy_level = r_cksrc_req_toggle!=cksrc_ack_toggle_sync;
assign o_dst_req_pulse = r_ckdst_req_pulse;

//body---
assign cksrc_req_hs = i_src_req_pulse && !o_src_busy_level;
assign cksrc_ack_toggle_sync = u_cksrc_ack_sync_o_dst_data;
assign ckdst_req_toggle_sync = u_ckdst_req_sync_o_dst_data;
assign ckdst_req_new = ckdst_req_toggle_sync!=r_ckdst_ack_toggle;

//source request toggle
always @(posedge i_src_clk or negedge i_src_rst_n) begin
    if( !i_src_rst_n )
        r_cksrc_req_toggle <= 1'b0;
    else if( cksrc_req_hs )
        r_cksrc_req_toggle <= !r_cksrc_req_toggle;
end

//source acknowledge delay
always @(posedge i_src_clk or negedge i_src_rst_n) begin
    if( !i_src_rst_n )
        r_cksrc_ack_toggle_d <= 1'b0;
    else
        r_cksrc_ack_toggle_d <= cksrc_ack_toggle_sync;
end

//destination request and automatic acknowledge
always @(posedge i_dst_clk or negedge i_dst_rst_n) begin
    if( !i_dst_rst_n ) begin
        r_ckdst_ack_toggle <= 1'b0;
        r_ckdst_req_pulse <= 1'b0;
    end
    else begin
        r_ckdst_req_pulse <= ckdst_req_new;
        if( ckdst_req_new )
            r_ckdst_ack_toggle <= ckdst_req_toggle_sync;
    end
end

//instance----
assign u_ckdst_req_sync_i_src_data = r_cksrc_req_toggle;
com_cdc_sig #(
    .SYNC_S              ( SYNC_S                         ), //3
    .DATA_W              ( 1                              )  //1
)u_com_cdc_sig_ckdst_req_sync
(
    .i_dst_clk           ( i_dst_clk                         ), //i
    .i_dst_rst_n         ( i_dst_rst_n                       ), //i
    .i_src_data          ( u_ckdst_req_sync_i_src_data       ), //i
    .o_dst_data          ( u_ckdst_req_sync_o_dst_data       )  //o
);

assign u_cksrc_ack_sync_i_src_data = r_ckdst_ack_toggle;
com_cdc_sig #(
    .SYNC_S              ( SYNC_S                         ), //3
    .DATA_W              ( 1                              )  //1
)u_com_cdc_sig_cksrc_ack_sync
(
    .i_dst_clk           ( i_src_clk                         ), //i
    .i_dst_rst_n         ( i_src_rst_n                       ), //i
    .i_src_data          ( u_cksrc_ack_sync_i_src_data       ), //i
    .o_dst_data          ( u_cksrc_ack_sync_o_dst_data       )  //o
);

//assert--------------------------------------------------------------------
`COM_PARAM_ASSERT( SYNC_S>=2, "cdc sync stage must larger than 1" );
`COM_SIGNAL_ASSERT( a0, i_src_clk,i_src_rst_n,i_src_req_pulse,!o_src_busy_level, "cdc handshake request when busy" );

endmodule //end of com_cdc_handshake
