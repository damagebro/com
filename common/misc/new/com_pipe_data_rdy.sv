/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:55:11
*
*  Description:
*   data ready-only pipe
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_data_rdy #( parameter
    DW = 8  //range=[1:]
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [DW-1:0]            idat                ,
input  wire                     ivld                ,
output wire                     irdy                ,
output wire [DW-1:0]            odat                ,
output wire                     ovld                ,
input  wire                     ordy                //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg           r_rdy_flag;
reg  [DW-1:0] r_rdy_buf;
//statement------------------------------------------------------------------

assign odat = !r_rdy_flag ? r_rdy_buf : idat;
assign ovld = !r_rdy_flag || ivld;
assign irdy = r_rdy_flag;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_rdy_flag <= 1'b1;
    else if( clear )
        r_rdy_flag <= 1'b1;
    else if( r_rdy_flag && ivld && !ordy )
        r_rdy_flag <= 1'b0;
    else if( !r_rdy_flag && ordy )
        r_rdy_flag <= 1'b1;
end
always @(posedge clk)begin
    if( r_rdy_flag && ivld && !ordy )
        r_rdy_buf <= idat;
end

endmodule //end of com_pipe_data_rdy

