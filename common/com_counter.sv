/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/07/05-17:08:18
*
*  Description:
*   counter [0,cnt_max)
*
*  Modify:
*  -
*
******************************************************************************/

module com_counter #( parameter
    CW   = 8,
    STEP = 1,
    INIT = 0//,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [CW-1:0]            i_cnt_max_m1        , //minus 1
input  wire                     i_cnt_start         ,
output wire [CW-1:0]            o_cnt               ,
output wire                     o_cnt_en            ,
output wire                     o_cnt_last          //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg           r_cnt_en;
reg  [CW-1:0] r_cnt;
reg  [CW-1:0] r_cnt_max_m1;
wire [CW-0:0] cnt_nxt;
//statement------------------------------------------------------------------
//output assign---
assign o_cnt = r_cnt;
assign o_cnt_en = r_cnt_en;
assign o_cnt_last = r_cnt_en && (cnt_nxt>{1'b0,r_cnt_max_m1});

//body---
assign cnt_nxt = r_cnt + STEP[CW-1:0];
wire cnt_done = o_cnt_last;
always @(posedge clk) begin
    if( i_cnt_start )
        r_cnt_max_m1 <= i_cnt_max_m1;
end
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_cnt_en <= 1'b0;
    else if( clear )
        r_cnt_en <= 1'b0;
    else if( i_cnt_start )
        r_cnt_en <= 1'b1;
    else if( cnt_done )
        r_cnt_en <= 1'b0;
end
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_cnt <= INIT[CW-1:0];
    else if( clear || i_cnt_start )
        r_cnt <= INIT[CW-1:0];
    else if( o_cnt_en )
        r_cnt <= cnt_nxt;
end

endmodule //end of com_counter
