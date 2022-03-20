/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/05-17:08:09
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_reg_e_v
`define com_reg_e_v
module com_reg_e #( parameter
    DW   = 1,
    INIT = 0//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,

input  wire                     e                   ,
input  wire [DW-1:0]            d                   ,
output wire [DW-1:0]            q                   //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------
wire [DW-1:0] const_init = DW'(INIT);
reg  [DW-1:0] rc_q;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_q <= const_init;
    else if( e )
        rc_q <= d;
end
assign q = rc_q;

endmodule //end of com_reg_e
`endif //end of com_reg_e_v

