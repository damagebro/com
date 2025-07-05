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
wire req_none_flag;
//statement------------------------------------------------------------------

assign o_gnt_vld = !req_none_flag;
assign o_req_rdy =(!req_none_flag && i_gnt_rdy) ? o_gnt_onehot : 1'b0;
com_find_lsb_fst_one #(
    .N          ( REQ_N         )  //8
)u_com_find_lsb_fst_one
(
    .i_req_dat            ( i_req_vld            ), //i
    .o_res_onehot         ( o_gnt_onehot         ), //o
    .o_res_idx            ( o_gnt_idx            ), //o
    .o_res_none_flag      ( req_none_flag        )  //o
);

endmodule //com_arbiter_rr

