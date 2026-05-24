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
//instance signal--
wire [PIPE_NUM-1:0] u_pipe_i_rx_vld;
wire [PIPE_NUM-1:0] u_pipe_o_rx_rdy;
wire [PIPE_NUM-1:0] u_pipe_o_tx_vld;
wire [PIPE_NUM-1:0] u_pipe_i_tx_rdy;
wire [PIPE_NUM-1:0] u_pipe_o_rx_pipe_upen;
//statement------------------------------------------------------------------
//output assign---
assign o_rx_rdy = u_pipe_o_rx_rdy[0];
assign o_tx_vld = u_pipe_o_tx_vld[PIPE_NUM-1];
assign o_rx_pipe_upen = u_pipe_o_rx_pipe_upen;

//instance----
assign u_pipe_i_rx_vld[0] = i_rx_vld;
assign u_pipe_i_tx_rdy[PIPE_NUM-1] = i_tx_rdy;
generate
    if( PIPE_NUM > 1 ) begin:gen_pipe_chain
        assign u_pipe_i_rx_vld[PIPE_NUM-1:1] = u_pipe_o_tx_vld[PIPE_NUM-2:0];
        assign u_pipe_i_tx_rdy[PIPE_NUM-2:0] = u_pipe_o_rx_rdy[PIPE_NUM-1:1];
    end

    for( genvar gi=0; gi<PIPE_NUM; gi++ ) begin:gen_each_pipe
        com_pipe_vld_single u_com_pipe_vld_single_pipe
        (
            .clk                  ( clk                         ), //i
            .rst_n                ( rst_n                       ), //i
            .clear                ( clear                       ), //i

            .i_rx_vld             ( u_pipe_i_rx_vld[gi]         ), //i
            .o_rx_rdy             ( u_pipe_o_rx_rdy[gi]         ), //o
            .o_tx_vld             ( u_pipe_o_tx_vld[gi]         ), //o
            .i_tx_rdy             ( u_pipe_i_tx_rdy[gi]         ), //i
            .o_rx_pipe_upen       ( u_pipe_o_rx_pipe_upen[gi]   )  //o
        );
    end:gen_each_pipe
endgenerate

endmodule //end of com_pipe_vld
