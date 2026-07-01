//////////////////////////////////////////////////////////////////////////////
//
//  Description: Reset merge and distribution for two clock domains.
//
//  Authors:   dmg
//     Date:   2026/06/28
//
//////////////////////////////////////////////////////////////////////////////

module com_cdc_rstn_pair #( parameter
    SYNC_S = 3 //freq>1.5G ? 4 : freq>1G ? 3 : 2
)
(
input  wire                     i_rx_src_clk        ,
input  wire                     i_rx_src_rst_n      ,
input  wire                     i_rx_dst_clk        ,
input  wire                     i_rx_dst_rst_n      ,

output wire                     o_tx_src_rst_n      ,
output wire                     o_tx_dst_rst_n      //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire                     async_rst_n;

//instance signal--
wire                     u_cksrc_rstn_i_dst_clk;
wire                     u_cksrc_rstn_i_async_rst_n;
wire                     u_cksrc_rstn_o_dst_rst_n;
wire                     u_ckdst_rstn_i_dst_clk;
wire                     u_ckdst_rstn_i_async_rst_n;
wire                     u_ckdst_rstn_o_dst_rst_n;
//statement------------------------------------------------------------------
//output assign---
assign o_tx_src_rst_n = u_cksrc_rstn_o_dst_rst_n;
assign o_tx_dst_rst_n = u_ckdst_rstn_o_dst_rst_n;

//body---
assign async_rst_n = i_rx_src_rst_n && i_rx_dst_rst_n;

//instance----
assign u_cksrc_rstn_i_dst_clk = i_rx_src_clk;
assign u_cksrc_rstn_i_async_rst_n = async_rst_n;
com_cdc_rstn #(
    .SYNC_S              ( SYNC_S                            )  //3
)u_com_cdc_rstn_cksrc
(
    .i_dst_clk           ( u_cksrc_rstn_i_dst_clk            ), //i
    .i_async_rst_n       ( u_cksrc_rstn_i_async_rst_n        ), //i
    .o_dst_rst_n         ( u_cksrc_rstn_o_dst_rst_n          )  //o
);

assign u_ckdst_rstn_i_dst_clk = i_rx_dst_clk;
assign u_ckdst_rstn_i_async_rst_n = async_rst_n;
com_cdc_rstn #(
    .SYNC_S              ( SYNC_S                            )  //3
)u_com_cdc_rstn_ckdst
(
    .i_dst_clk           ( u_ckdst_rstn_i_dst_clk            ), //i
    .i_async_rst_n       ( u_ckdst_rstn_i_async_rst_n        ), //i
    .o_dst_rst_n         ( u_ckdst_rstn_o_dst_rst_n          )  //o
);

// //assert---------------------------------------------------------------------
// `COM_PARAM_ASSERT( SYNC_S>=2, "cdc sync stage must larger than 1" )

endmodule //end of com_cdc_rstn_pair
