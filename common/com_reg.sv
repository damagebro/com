/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/05-17:08:02
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_reg #( parameter
    DW   = 1,
    INIT = 0//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,

input  wire [DW-1:0]            i_d                 ,
output wire [DW-1:0]            o_q                 //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg  [DW-1:0] r_q;
//statement------------------------------------------------------------------
//output assign---
assign o_q = r_q;

//body---
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_q <= INIT[DW-1:0];
    else
        r_q <= i_d;
end

endmodule //end of com_reg
