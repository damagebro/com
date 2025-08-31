/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-22:50:38
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_find_tail1 #( parameter
    N = 8, //range[1:]
    parameter N_L2 = $clog2(N>2?N:2)
)
(
input  wire [N-1:0]             i_req_val           ,
output wire [N-1:0]             o_res_onehot        ,  //timing good
output wire [N_L2-1:0]          o_res_idx           ,  //timing bad
output wire                     o_res_none_flag     //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire [N-1:0]    req_msk;
wire [N-1:0]    w_oht;
reg  [N_L2-1:0] w_idx;
//statement------------------------------------------------------------------

assign req_msk[0] = 1'b0;
generate
if( N>1 ) begin:gen_larger1
    assign req_msk[N-1:1] = req_msk[N-2:0] | i_req_val[N-2:0];  //bit by bit assign
end:gen_larger1
endgenerate
assign w_oht = ~req_msk & i_req_val;
always @(*)begin
    w_idx = '0;
    for( int i=0; i<N; i++ )
        if( w_oht[i] )
            w_idx = i[N_L2-1:0];
end

//another method, use complement---
// wire [N-1:0] w_oht = ~(i_req_val-1'b1) | i_req_val;

//out-
assign o_res_onehot = w_oht;
assign o_res_idx = w_idx;
assign o_res_none_flag = !(|i_req_val);

endmodule //com_find_lsb_fst_one

