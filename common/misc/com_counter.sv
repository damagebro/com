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

input  wire [DW-1:0]            i_cnt_max_m1        , //minus 1
input  wire                     i_cnt_en            ,
output wire [DW-1:0]            o_cnt               ,
output wire                     o_cnt_last          //,
);
//localparam-----------------------------------------------------------------
//reg/wire  declare----------------------------------------------------------
reg  [DW-1:0] r_cnt;
wire [DW-0:0] cnt_nxt;
//statement------------------------------------------------------------------
assign cnt = r_cnt;
assign o_cnt_last = cnt_nxt>{1'b0,i_cnt_max_m1};

wire cnt_done = i_cnt_en && o_cnt_last;
assign cnt_nxt = r_cnt + STEP[DW-1:0];
always @(posedge clk or negedge rst_n)
begin
    if( !rst_n )
        r_cnt <= INIT[DW-1:0];
    else if( clear || cnt_done )
        r_cnt <= INIT[DW-1:0];
    else if( i_cnt_en )
        r_cnt <= cnt_nxt;
end

endmodule //end of com_counter
`endif //end of com_counter_v

