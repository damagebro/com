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

module com_find_lsb_first_one #(
    parameter N = 8, //range=[1:]
    localparam N_L2 = $clog2(N>2 ? N : 2) //,
)
(
input  wire [N-1:0]             i_req_val           ,
output wire [N-1:0]             o_res_onehot        ,  //timing good
output wire [N_L2-1:0]          o_res_idx           ,  //timing bad
output wire                     o_res_none_flag     //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire [N-1:0]    w_req_mask;
wire [N-1:0]    w_res_onehot;
reg  [N_L2-1:0] w_res_idx;
//statement------------------------------------------------------------------
//output assign---
assign o_res_onehot = w_res_onehot;
assign o_res_idx = w_res_idx;
assign o_res_none_flag = !(|i_req_val);

//body---
assign w_req_mask[0] = 1'b0;
generate
    if( N > 1 ) begin:gen_req_mask
        assign w_req_mask[N-1:1] = w_req_mask[N-2:0] | i_req_val[N-2:0]; //bit by bit assign
    end
endgenerate
assign w_res_onehot = ~w_req_mask & i_req_val;
always @* begin
    w_res_idx = '0;
    for( int i=0; i<N; i++ ) begin
        if( w_res_onehot[i] )
            w_res_idx = i[N_L2-1:0];
    end
end

//another method, use complement---
// wire [N-1:0] w_res_onehot = ~(i_req_val-1'b1) | i_req_val;

endmodule //end of com_find_lsb_first_one
