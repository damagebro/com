/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2022/02/26-15:05:05
*
*  Description:
*   -single-channael input and muti-channel output handshake
*   -ivld->ovld no delay;
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_simo_no_delay_v
`define com_simo_no_delay_v
module com_simo_no_delay #( parameter
    CH = 1//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     ivld                ,
output wire                     irdy                ,
output wire [CH-1:0]            ovld                ,
input  wire [CH-1:0]            ordy                //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  [CH-1:0] arc_outed_flag;
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

wire ihs = ivld && irdy;
wire [CH-1:0] arr_ohs = ovld & ordy;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_outed_flag <= 'b0;
    else if( clear || ihs )
        arc_outed_flag <= 'b0;
    else begin
        for( int i=0; i<CH; i++ )begin
            if( arr_ohs[i] )
                arc_outed_flag[i] <= 1'b1;
        end
    end
end

assign ovld = {CH{ivld}} & ~arc_outed_flag;
assign irdy = &(ordy | arc_outed_flag);

endmodule //end of com_simo_no_delay
`endif //end of com_simo_no_delay_v

