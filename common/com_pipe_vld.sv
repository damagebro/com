/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:50:52
*
*  Description:
*   mult-stage pipeline, only ctrl flow, signal 'pipe_upen' to used by data_flow;
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_vld #( parameter
    PIPE_NUM = 2   //range=[1:]
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire                     i_rx_vld            ,
output wire                     o_rx_rdy            ,
output wire                     o_tx_vld            ,
input  wire                     i_tx_rdy            ,
output wire [PIPE_NUM-1:0]      o_rx_pipe_upen      //, // pipeline[idx] update enable, idx0=i_rx_vld&&o_rx_rdy
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire [PIPE_NUM-0:0] arr_vld;
wire [PIPE_NUM-0:0] arr_rdy;
//statement------------------------------------------------------------------
assign o_rx_rdy = arr_rdy[0];
assign o_tx_vld = arr_vld[PIPE_NUM];

assign arr_vld[0] = i_rx_vld;
assign arr_rdy[PIPE_NUM] = i_tx_rdy;
generate
for( genvar gi=0; gi<PIPE_NUM; gi++ )begin:gen_each_pipe
com_pipe_vld_single u_com_pipe_vld_single
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i

    .i_rx_vld             ( arr_vld[gi]          ), //i
    .o_rx_rdy             ( arr_rdy[gi]          ), //o
    .o_tx_vld             ( arr_vld[gi+1]        ), //o
    .i_tx_rdy             ( arr_rdy[gi+1]        ), //i
    .o_rx_pipe_upen       ( o_rx_pipe_upen[gi]   )  //o
);
end:gen_each_pipe
endgenerate

endmodule //end of com_pipe_vld

