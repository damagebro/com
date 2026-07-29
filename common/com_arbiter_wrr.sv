/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/28
*
*  Description:
*  - Weighted round-robin arbiter with consecutive quota service.
*  - The service quota of each request is i_cfg_weight plus one.
*
******************************************************************************/

module com_arbiter_wrr #( parameter
    REQ_N = 2, //range=[1::]
    localparam REQ_N_L2 = $clog2(REQ_N>2 ? REQ_N : 2)
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [REQ_N-1:0][3:0]    i_cfg_weight        ,
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
reg                     r_owner_vld;
reg  [REQ_N_L2-1:0]     r_owner_idx;
reg  [3:0]              r_quota_m1;
reg                     r_req_active;
reg  [REQ_N-1:0][3:0]   r_cfg_weight;
reg  [REQ_N-1:0]        r_lock_req;
reg                     r_lock_flag;

wire [REQ_N-1:0]        owner_onehot;
wire                    owner_req_vld;
wire                    owner_keep;
wire [REQ_N-1:0]        masked_req;
wire                    masked_req_none_flag;
wire [REQ_N-1:0]        select_req_t;
wire [REQ_N-1:0]        select_req;
wire                    gnt_hs;
wire [REQ_N-1:0][3:0]   arb_weight;
wire [3:0]              select_weight;
wire [REQ_N_L2-1:0]     tie_req_num_m1;
wire [REQ_N_L2-1:0]     nxt_gnt_idx;
wire [REQ_N-1:0]        nxt_bitmap_t;
wire [REQ_N-1:0]        nxt_bitmap;

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
assign owner_onehot = REQ_N'(1'b1) << r_owner_idx;
assign owner_req_vld = |(i_req_vld & owner_onehot);
assign owner_keep = r_owner_vld && owner_req_vld;

//Keep the current owner until its quota is consumed or its request drops.
assign masked_req = i_req_vld & r_avl_bitmap;
assign masked_req_none_flag = !(|masked_req);
assign select_req_t = owner_keep ? owner_onehot :
                      (masked_req_none_flag ? i_req_vld : masked_req);
assign select_req = r_lock_flag ? r_lock_req : select_req_t;
assign gnt_hs = o_gnt_vld && i_gnt_rdy;
assign arb_weight = r_req_active ? r_cfg_weight : i_cfg_weight;
assign select_weight = arb_weight[o_gnt_idx];

assign tie_req_num_m1 = REQ_N[REQ_N_L2-1:0] - 1'b1;
assign nxt_gnt_idx = o_gnt_idx>=tie_req_num_m1 ? '0 : (o_gnt_idx + 1'b1);
assign nxt_bitmap_t = (REQ_N'(1'b1) << nxt_gnt_idx) - 1'b1;
assign nxt_bitmap = ~nxt_bitmap_t;

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_req_active <= 1'b0;
    else
        r_req_active <= |i_req_vld;
end

//Capture quasi-static weights only at a safe arbitration boundary.
always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_cfg_weight <= '0;
    else if( !r_req_active )
        r_cfg_weight <= i_cfg_weight;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_lock_flag <= 1'b0;
    else if( clear || gnt_hs )
        r_lock_flag <= 1'b0;
    else if( o_gnt_vld && !i_gnt_rdy && !r_lock_flag )
        r_lock_flag <= 1'b1;
end

always @(posedge clk) begin
    if( o_gnt_vld && !i_gnt_rdy && !r_lock_flag )
        r_lock_req <= select_req_t;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_avl_bitmap <= '1;
    else if( clear )
        r_avl_bitmap <= '1;
    else if( gnt_hs && !owner_keep )
        r_avl_bitmap <= nxt_bitmap;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_owner_vld <= 1'b0;
    else if( clear )
        r_owner_vld <= 1'b0;
    else if( gnt_hs && !owner_keep && (select_weight!='0) )
        r_owner_vld <= 1'b1;
    else if( (gnt_hs && r_quota_m1=='0) || (r_owner_vld && !owner_req_vld) )
        r_owner_vld <= 1'b0;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_owner_idx <= '0;
    else if( clear )
        r_owner_idx <= '0;
    else if( gnt_hs && !owner_keep )
        r_owner_idx <= o_gnt_idx;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_quota_m1 <= '0;
    else if( clear )
        r_quota_m1 <= '0;
    else if( gnt_hs && !owner_keep && (select_weight!='0) )
        r_quota_m1 <= select_weight - 1'b1;
    else if( gnt_hs && owner_keep && (r_quota_m1!='0) )
        r_quota_m1 <= r_quota_m1 - 1'b1;
    else if( r_owner_vld && !owner_req_vld )
        r_quota_m1 <= '0;
end

//instance----
assign u_gnt_i_req_val = select_req;
com_find_lsb_first_one #(
    .N                    ( REQ_N                         )  //8
)u_com_find_lsb_first_one_gnt
(
    .i_req_val            ( u_gnt_i_req_val              ), //i
    .o_res_onehot         ( u_gnt_o_res_onehot           ), //o
    .o_res_idx            ( u_gnt_o_res_idx              ), //o
    .o_res_none_flag      ( u_gnt_o_res_none_flag        )  //o
);

//assert---------------------------------------------------------------------
`COM_PARAM_ASSERT( REQ_N>=1, "request number must larger than 0" )

endmodule //end of com_arbiter_wrr
