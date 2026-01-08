/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/03/31-17:17:29
*
*  Description:
*   single input channel, muti output channel, ivld->ovld no delay
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_simo_no_delay_v
`define com_simo_no_delay_v
module com_simo_no_delay #( parameter
    OCH = 1
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     ivld                ,
output wire                     irdy                ,
output wire [OCH-1:0]           ovld                ,
input  wire [OCH-1:0]           ordy                //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  [OCH-1:0] arc_outed_flag;
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

wire ihs = ivld && irdy;
wire [OCH-1:0] arr_ohs = ovld & ordy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_outed_flag <= 'b0;
    else if( clear || ihs  )
        arc_outed_flag <= 'b0;
    else begin
        for( int i=0; i<OCH; i++ )
            if( arr_ohs[i] )
                arc_outed_flag[i] <= 1'b1;
    end
end
assign ovld = {OCH{ivld}} & ~arc_outed_flag;

wire [OCH-1:0] out_all_hs = arc_outed_flag | {OCH{ivld}}&ordy;
assign irdy = &out_all_hs;

endmodule //end of com_simo_no_delay
`endif //end of com_simo_no_delay_v

