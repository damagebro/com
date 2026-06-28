/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2026/06/28
*
*  Description:
*  - Interleaved weighted round-robin arbiter.
*  - The service quota of each request is i_cfg_weight plus one.
*
******************************************************************************/

module com_arbiter_iwrr #( parameter
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
reg  [3:0]              r_subround;
reg                     r_req_active;
reg  [REQ_N-1:0][3:0]   r_cfg_weight;

reg  [REQ_N-1:0]        w_cur_req;
reg  [3:0]              w_step_subround;
reg  [REQ_N-1:0]        w_step_req;
reg  [REQ_N-1:0]        w_select_req;
reg  [3:0]              w_select_subround;

wire                    gnt_hs;
wire [REQ_N-1:0][3:0]   arb_weight;
wire [REQ_N-1:0]        nxt_gnt_bitmap_t;
wire [REQ_N-1:0]        nxt_gnt_bitmap;

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
assign gnt_hs = o_gnt_vld && i_gnt_rdy;
assign arb_weight = r_req_active ? r_cfg_weight : i_cfg_weight;
assign nxt_gnt_bitmap_t = (o_gnt_onehot << 1'b1) - 1'b1;
assign nxt_gnt_bitmap = ~nxt_gnt_bitmap_t;

//Search the unserved ports in the current sub-round.
always @* begin
    w_cur_req = '0;
    for( int i=0; i<REQ_N; i++ ) begin
        w_cur_req[i] = i_req_vld[i] &&
                       (arb_weight[i]>=r_subround) &&
                       r_avl_bitmap[i];
    end
end

//Advance one sub-round, or wrap to zero when no request is eligible.
always @* begin
    w_step_subround = r_subround + 1'b1;
    w_step_req = '0;
    for( int i=0; i<REQ_N; i++ ) begin
        w_step_req[i] = i_req_vld[i] &&
                        (arb_weight[i]>=w_step_subround);
    end
    if( !(|w_step_req) ) begin
        w_step_subround = '0;
        w_step_req = i_req_vld;
    end
end

//Select between the current and next sub-round.
always @* begin
    if( |w_cur_req ) begin
        w_select_req = w_cur_req;
        w_select_subround = r_subround;
    end
    else begin
        w_select_req = w_step_req;
        w_select_subround = w_step_subround;
    end
end

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
        r_avl_bitmap <= '1;
    else if( clear )
        r_avl_bitmap <= '1;
    else if( gnt_hs )
        r_avl_bitmap <= nxt_gnt_bitmap;
end

always @(posedge clk or negedge rst_n) begin
    if( !rst_n )
        r_subround <= '0;
    else if( clear )
        r_subround <= '0;
    else if( gnt_hs )
        r_subround <= w_select_subround;
end

//instance----
assign u_gnt_i_req_val = w_select_req;
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
`COM_PARAM_ASSERT( REQ_N>=1, "request number must larger than 0" );

endmodule //end of com_arbiter_iwrr
