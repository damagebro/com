/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:55:05
*
*  Description:
*   data valid-only pipe
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_data_vld #( parameter
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
reg           r_vld_flag;
reg  [DW-1:0] r_vld_buf;
//statement------------------------------------------------------------------
assign odat = r_vld_buf;
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
always @(posedge clk) begin
    if( ihs )
        r_vld_buf <= idat;
end

endmodule //end of com_pipe_data_vld

