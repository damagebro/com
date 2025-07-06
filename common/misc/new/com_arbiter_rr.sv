/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-22:46:32
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_arbiter_rr #( parameter
    REQ_N = 2, //[1:]
    //localparam in param_list feature support after verilog2009, need verdi "-2009" option; to prevant localparam ambiguous in eda software, still use parameter bellow:
    parameter REQ_N_L2 = $clog2(REQ_N>2?REQ_N:2)
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [REQ_N-1:0]         i_req_vld           ,
output wire [REQ_N-1:0]         o_req_rdy           ,
output wire [REQ_N-1:0]         o_gnt_onehot        ,
output wire [REQ_N_L2-1:0]      o_gnt_idx           ,
output wire                     o_gnt_vld           ,
input  wire                     i_gnt_rdy           //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
reg  [REQ_N_L2-1:0] r_prev_gnt_nxt_idx;
reg  [REQ_N-1:0] r_avl_bitmap;
wire [REQ_N-1:0] masked_req;
wire             masked_req_none_flag;
wire [REQ_N-1:0] select_req;
//statement------------------------------------------------------------------
wire b_req_avl = |i_req_vld;
assign o_gnt_vld = b_req_avl;
assign o_req_rdy =(b_req_avl && i_gnt_rdy) ? o_gnt_onehot : '0;

assign masked_req_none_flag = !(|masked_req);
assign masked_req = i_req_vld & r_avl_bitmap;
assign select_req = masked_req_none_flag ? i_req_vld : masked_req;
wire gnt_hs = o_gnt_vld && i_gnt_rdy;
wire [REQ_N_L2-1:0] tie_req_num_m1 = REQ_N[REQ_N_L2-1:0] - 1'b1;
wire [REQ_N_L2-1:0] nxt_gnt_idx = o_gnt_idx>=tie_req_num_m1 ? '0 : (o_gnt_idx + 1'b1);
wire [REQ_N-1:0]    nxt_bitmap_t= (REQ_N'('b1)<<nxt_gnt_idx) - 1'b1;
wire [REQ_N-1:0]    nxt_bitmap  = ~nxt_bitmap_t;
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_avl_bitmap <= '1;
    else if( clear )
        r_avl_bitmap <= '1;
    else if( gnt_hs )
        r_avl_bitmap <= nxt_bitmap;
end
com_find_tail1 #(
    .N          ( REQ_N         )  //8
)u_com_find_tail1
(
    .i_req_val            ( select_req           ), //i
    .o_res_onehot         ( o_gnt_onehot         ), //o
    .o_res_idx            ( o_gnt_idx            ), //o
    .o_res_none_flag      (                      )  //o
);

endmodule //com_arbiter_rr

