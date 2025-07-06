/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:55:18
*
*  Description:
*   data valid/ready regslice
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_data_regslice #( parameter
    PIPE_NUM = 2, //range=[1:]
    DW       = 8  //range=[1:]
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [DW-1:0]            idat                ,
input  wire                     ivld                ,
output wire                     irdy                ,
output wire [DW-1:0]            odat                ,
output wire                     ovld                ,
input  wire                     ordy                //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire [PIPE_NUM-1:0][DW-1:0] w_arr_bwd_idat;  //bwd=rdy_pipe
wire [PIPE_NUM-1:0]         w_arr_bwd_ivld;
wire [PIPE_NUM-1:0]         w_arr_bwd_irdy;
wire [PIPE_NUM-1:0][DW-1:0] w_arr_fwd_odat;  //fwd=vld_pipe
wire [PIPE_NUM-1:0]         w_arr_fwd_ovld;
wire [PIPE_NUM-1:0]         w_arr_fwd_ordy;
//statement------------------------------------------------------------------

assign w_arr_bwd_idat[0] = idat;
assign w_arr_bwd_ivld[0] = ivld;
assign irdy = w_arr_bwd_irdy[0];
assign odat = w_arr_fwd_odat[PIPE_NUM-1];
assign ovld = w_arr_fwd_ovld[PIPE_NUM-1];
assign w_arr_fwd_ordy[PIPE_NUM-1] = ordy;
generate
for ( genvar gi=0; gi<PIPE_NUM; gi++ ) begin:gen_each_regslice
if( gi>0 )begin
    assign w_arr_bwd_idat[gi] = w_arr_fwd_odat[gi-1];
    assign w_arr_bwd_ivld[gi] = w_arr_fwd_ovld[gi-1];
    assign w_arr_fwd_ordy[gi-1] = w_arr_bwd_irdy[gi];
end
wire [DW-1:0] w_mid_bwd_dat;
wire          w_mid_bwd_vld;
wire          w_mid_bwd_rdy;
com_pipe_data_rdy #(
    .DW         ( DW         )  //8
)u_com_pipe_data_rdy
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .idat                 ( w_arr_bwd_idat[gi]   ), //i
    .ivld                 ( w_arr_bwd_ivld[gi]   ), //i
    .irdy                 ( w_arr_bwd_irdy[gi]   ), //o
    .odat                 ( w_mid_bwd_dat        ), //o
    .ovld                 ( w_mid_bwd_vld        ), //o
    .ordy                 ( w_mid_bwd_rdy        )  //i
);
com_pipe_data_vlds #(
    .PIPE_NUM   ( 1          ), //1
    .DW         ( DW         )  //8
)u_com_pipe_data_vlds
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .idat                 ( w_mid_bwd_dat        ), //i
    .ivld                 ( w_mid_bwd_vld        ), //i
    .irdy                 ( w_mid_bwd_rdy        ), //o
    .odat                 ( w_arr_fwd_odat[gi]   ), //o
    .ovld                 ( w_arr_fwd_ovld[gi]   ), //o
    .ordy                 ( w_arr_fwd_ordy[gi]   )  //i
);
end:gen_each_regslice
endgenerate

endmodule //end of com_pipe_data_regslice

