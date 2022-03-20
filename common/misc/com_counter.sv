/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/05-17:08:18
*
*  Description:
*   counter [0,cnt_max]
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_counter_v
`define com_counter_v
module com_counter #( parameter
    DW   = 8,
    STEP = 1,
    INIT = 0//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [DW-1:0]            cnt_max             , //minus 1
input  wire                     cnt_en              ,
output wire [DW-1:0]            cnt                 ,
output wire                     cnt_done            //,
);
//localparam-----------------------------------------------------------------
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
wire [DW-1:0] init = INIT;
wire [DW-1:0] step = STEP;
//statement------------------------------------------------------------------

reg  [DW-1:0] rc_cnt;
wire [DW-0:0] cnt_nxt = rc_cnt + step;
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        rc_cnt <= init;
    else if( clear )
        rc_cnt <= init;
    else if( cnt_en )
        rc_cnt <= cnt_nxt;
end
assign cnt = rc_cnt;
assign cnt_done = cnt_en && cnt_nxt>{1'b0,cnt_max};

endmodule //end of com_counter
`endif //end of com_counter_v

