/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:50:45
*
*  Description:
*   single-stage valid pipeline, signal 'pipe_upen' is used by data update enable;
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_vld_single
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     i_rx_vld            ,
output wire                     o_rx_rdy            ,
output wire                     o_tx_vld            ,
input  wire                     i_tx_rdy            ,
output wire                     o_rx_pipe_upen      //, // o_rx_pipe_upen = i_rx_vld && o_rx_rdy;
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg  r_vld_flag;
//statement------------------------------------------------------------------
//output assign---
assign o_tx_vld = r_vld_flag;
assign o_rx_rdy = i_tx_rdy || !r_vld_flag;
assign o_rx_pipe_upen = i_rx_vld && o_rx_rdy;

//body---
wire rx_hs = o_rx_pipe_upen;
wire tx_hs = o_tx_vld && i_tx_rdy;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_vld_flag <= 1'b0;
    else if( clear )
        r_vld_flag <= 1'b0;
    else if( rx_hs )
        r_vld_flag <= 1'b1;
    else if( tx_hs )
        r_vld_flag <= 1'b0;
end

endmodule //end of com_pipe_vld_single
