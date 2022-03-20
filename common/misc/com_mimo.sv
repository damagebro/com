/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/04/16-14:06:05
*
*  Description:
*   -muti-channael input and muti-channel output handshake
*   -similar with com_pipe_ctrl, ivld->ovld have 1 cycle delay;
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_mimo_v
`define com_mimo_v
module com_mimo #( parameter
    ICH = 1,
    OCH = 2//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [ICH-1:0]           arr_ivld            ,
output wire [ICH-1:0]           arr_irdy            ,
output wire [OCH-1:0]           arr_ovld            ,
input  wire [OCH-1:0]           arr_ordy            //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
reg  [ICH-1:0] arc_ibusy;
reg  [OCH-1:0] arc_obusy;
//wire declare---------------------------------------------------------------
wire all_ihs;
wire all_ohs;
//statement------------------------------------------------------------------

//input handshake---
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_ibusy <= 'b0;
    else if( clear )
        arc_ibusy <= 'b0;
    else begin
        for( int i=0; i<ICH; i++ )begin
            if( arr_ivld[i]&&arr_irdy[i] )
                arc_ibusy[i] <= 1'b1;
            else if( all_ohs )
                arc_ibusy[i] <= 1'b0;
        end
    end
end

wire b_all_ihs_port = &(arr_ivld&arr_irdy);
wire b_all_ihs_hold = &arc_ibusy;
wire [ICH-1:0] arr_ihs_mix = arc_ibusy | (arr_ivld&arr_irdy);
assign all_ihs = (&arr_ihs_mix && !b_all_ihs_hold) || b_all_ihs_port;

reg  [ICH-1:0] arb_irdy; //array register blocking
always @*
begin
    for( int i=0; i<ICH; i++ )begin
        arb_irdy[i] = !arc_ibusy[i] || all_ohs;
    end
end
assign arr_irdy = arb_irdy;

//output handshake---
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        arc_obusy <= 'b0;
    else if( clear )
        arc_obusy <= 'b0;
    else begin
        for( int i=0; i<OCH; i++ )begin
            if( all_ihs )
                arc_obusy[i] <= 1'b1;
            else if( arr_ovld[i]&&arr_ordy[i] )
                arc_obusy[i] <= 1'b0;
        end
    end
end
wire [OCH-1:0] arr_ohs = (~arc_obusy) | (arr_ovld&arr_ordy); //all output done;
assign all_ohs = (&arr_ohs) && (|arc_obusy); //|arc_obusy, still have out_vld

assign arr_ovld = arc_obusy;

endmodule //end of com_mimo
`endif //end of com_mimo_v

