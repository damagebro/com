/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/05-17:08:12
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_reg_ce_v
`define com_reg_ce_v
module com_reg_ce #( parameter
    DW   = 1,
    INIT = 0//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     e                   ,
input  wire [DW-1:0]            d                   ,
output wire [DW-1:0]            q                   //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------
reg  [DW-1:0] rc_q;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_q <= INIT[DW-1:0];
    else if( clear )
        rc_q <= INIT[DW-1:0];
    else if( e )
        rc_q <= d;
end
assign q = rc_q;

endmodule //end of com_reg_ce
`endif //end of com_reg_ce_v

