/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:50:45
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_ctrl_vld
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     ivld                ,
output wire                     irdy                ,
output wire                     ovld                ,
input  wire                     ordy                ,
output wire                     pipe_upen           //, // pipe_upen = ivld && irdy;
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg  r_vld_flag;
//statement------------------------------------------------------------------
assign ovld = r_vld_flag;
assign irdy = ordy || !r_vld_flag;
assign pipe_upen = ivld && irdy;

wire ihs = ivld && irdy;
wire ohs = ovld && ordy;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_vld_flag <= 1'b0;
    else if( clear )
        r_vld_flag <= 1'b0;
    else if( ihs )
        r_vld_flag <= 1'b1;
    else if( ohs )
        r_vld_flag <= 1'b0;
end

endmodule //end of com_pipe_ctrl_vld

