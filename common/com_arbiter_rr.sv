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
    REQ_N = 2, //range=[1:]
    localparam REQ_N_L2 = $clog2(REQ_N>2 ? REQ_N : 2)
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
reg  [REQ_N-1:0]        r_avl_bitmap;

//instance signal--
wire [REQ_N-1:0]        u_gnt_i_req_val;
wire [REQ_N-1:0]        u_gnt_o_res_onehot;
wire [REQ_N_L2-1:0]     u_gnt_o_res_idx;
wire                    u_gnt_o_res_none_flag;
//statement------------------------------------------------------------------
//output assign---
assign o_req_rdy = (o_gnt_vld && i_gnt_rdy) ? o_gnt_onehot : '0;
assign o_gnt_onehot = u_gnt_o_res_onehot;
assign o_gnt_idx = u_gnt_o_res_idx;
assign o_gnt_vld = !u_gnt_o_res_none_flag;

//body---
wire [REQ_N-1:0] masked_req = i_req_vld & r_avl_bitmap;
wire masked_req_none_flag = !(|masked_req);
wire [REQ_N-1:0] select_req = masked_req_none_flag ? i_req_vld : masked_req;
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

//instance----
assign u_gnt_i_req_val = select_req;
com_find_lsb_first_one #(
    .N          ( REQ_N         )  //8
)u_com_find_lsb_first_one_gnt
(
    .i_req_val            ( u_gnt_i_req_val          ), //i
    .o_res_onehot         ( u_gnt_o_res_onehot       ), //o
    .o_res_idx            ( u_gnt_o_res_idx          ), //o
    .o_res_none_flag      ( u_gnt_o_res_none_flag    )  //o
);

endmodule //end of com_arbiter_rr
