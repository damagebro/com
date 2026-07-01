//////////////////////////////////////////////////////////////////////////////
//
//  Description: Asynchronous reset assertion and synchronous deassertion.
//
//  Authors:   wwq
//  Version:   2.0
//
//////////////////////////////////////////////////////////////////////////////

module com_cdc_rstn #( parameter
    SYNC_S = 3 //freq>1.5G ? 4 : freq>1G ? 3 : 2
)
(
input  wire                     i_dst_clk           ,
input  wire                     i_async_rst_n       ,
output wire                     o_dst_rst_n         //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
//instance signal--
wire                     u_sync_i_src_data;
wire                     u_sync_o_dst_data;
//statement------------------------------------------------------------------
//output assign---
assign o_dst_rst_n = u_sync_o_dst_data;

//body---

//instance----
assign u_sync_i_src_data = 1'b1;
com_cdc_sig #(
    .SYNC_S              ( SYNC_S                 ), //3
    .DATA_W              ( 1                      )  //1
)u_com_cdc_sig_sync
(
    .i_dst_clk           ( i_dst_clk              ), //i
    .i_dst_rst_n         ( i_async_rst_n          ), //i
    .i_src_data          ( u_sync_i_src_data      ), //i
    .o_dst_data          ( u_sync_o_dst_data      )  //o
);

// //assert---------------------------------------------------------------------
// `COM_PARAM_ASSERT( SYNC_S>=2, "cdc sync stage must larger than 1" )

endmodule //end of com_cdc_rstn
