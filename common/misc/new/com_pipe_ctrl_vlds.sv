/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:50:52
*
*  Description:
*  -
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_ctrl_vlds #( parameter
    PIPE_NUM = 2   //range=[1:]
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     ivld                ,
output wire                     irdy                ,
output wire                     ovld                ,
input  wire                     ordy                ,
output wire [PIPE_NUM-1:0]      pipe_upen           //, // pipeline[idx] update enable, idx0=ivld&&irdy
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire [PIPE_NUM-0:0] arr_ivld;
wire [PIPE_NUM-0:0] arr_irdy;
//statement------------------------------------------------------------------

assign arr_ivld[0] = ivld;
assign irdy = arr_ivld[0];
assign ovld = arr_ivld[PIPE_NUM];
assign arr_irdy[PIPE_NUM] = ordy;
assign pipe_upen = arr_ivld[PIPE_NUM-1:0] & arr_irdy[PIPE_NUM-1:0];

generate
for( genvar gi=0; gi<PIPE_NUM; gi++ )begin:gen_each_pipe
com_pipe_ctrl_vld u_com_pipe_ctrl_vld
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .ivld                 ( arr_ivld[gi]         ), //i
    .irdy                 ( arr_irdy[gi]         ), //o
    .ovld                 ( arr_ivld[gi+1]       ), //o
    .ordy                 ( arr_irdy[gi+1]       ), //i
    .pipe_upen            (                      )  //o
);
end:gen_each_pipe
endgenerate

endmodule //end of com_pipe_ctrl_vlds

