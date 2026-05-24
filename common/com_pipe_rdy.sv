/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:55:11
*
*  Description:
*   ready-only single-stage pipeline with data;
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_rdy #( parameter
    DW = 8  //range=[1:]
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [DW-1:0]            i_rx_dat            ,
input  wire                     i_rx_vld            ,
output wire                     o_rx_rdy            ,
output wire [DW-1:0]            o_tx_dat            ,
output wire                     o_tx_vld            ,
input  wire                     i_tx_rdy            //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg           r_rdy_flag;
reg  [DW-1:0] r_rdy_buf;
//statement------------------------------------------------------------------
//output assign---
assign o_tx_dat = !r_rdy_flag ? r_rdy_buf : i_rx_dat;
assign o_tx_vld = !r_rdy_flag || i_rx_vld;
assign o_rx_rdy = r_rdy_flag;

//body---
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rdy_flag <= 1'b1;
    else if( clear )
        r_rdy_flag <= 1'b1;
    else if( r_rdy_flag && i_rx_vld && !i_tx_rdy )
        r_rdy_flag <= 1'b0;
    else if( !r_rdy_flag && i_tx_rdy )
        r_rdy_flag <= 1'b1;
end
always @(posedge clk) begin
    if( r_rdy_flag && i_rx_vld && !i_tx_rdy )
        r_rdy_buf <= i_rx_dat;
end

endmodule //end of com_pipe_rdy
