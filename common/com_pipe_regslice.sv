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

module com_pipe_regslice #( parameter
    PIPE_NUM = 2, //range=[1:]
    DW       = 8  //range=[1:]
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,

input  wire [DW-1:0]            i_rx_dat            ,
input  wire                     i_rx_vld            ,
output wire                     o_rx_rdy            ,
output wire [DW-1:0]            o_tx_dat            ,
output wire                     o_tx_vld            ,
input  wire                     i_tx_rdy            //,
);
//localparam-----------------------------------------------------------------
//signal declare-------------------------------------------------------------
wire [PIPE_NUM-0:0][DW-1:0]  u_pip_i_rx_dat;
wire [PIPE_NUM-0:0]          u_pip_i_rx_vld;
wire [PIPE_NUM-0:0]          u_pip_o_rx_rdy;
wire [PIPE_NUM-0:0][DW-1:0]  u_pip_o_tx_dat;
wire [PIPE_NUM-0:0]          u_pip_o_tx_vld;
wire [PIPE_NUM-0:0]          u_pip_i_tx_rdy;
//statement------------------------------------------------------------------
assign o_rx_rdy = u_pip_o_rx_rdy[0];
assign o_tx_vld = u_pip_o_tx_vld[PIPE_NUM];
assign o_tx_dat = u_pip_o_tx_dat[PIPE_NUM];

assign u_pip_i_rx_dat[0] = i_rx_dat;
assign u_pip_i_rx_vld[0] = i_rx_vld;
assign u_pip_i_tx_rdy[PIPE_NUM] = i_tx_rdy;
generate
for( genvar gi=0; gi<PIPE_NUM; gi++ )begin:gen_pipe_regslice
    com_pipe_vld_rdy #(
        .VLD_PIPE_EN( 1          ), //1
        .RDY_PIPE_EN( 1          ), //1
        .DW         ( DW         )  //8
    )u_com_pipe_vld_rdy
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i

        .i_rx_dat             ( u_pip_i_rx_dat[gi+0] ), //i
        .i_rx_vld             ( u_pip_i_rx_vld[gi+0] ), //i
        .o_rx_rdy             ( u_pip_o_rx_rdy[gi+0] ), //o
        .o_tx_dat             ( u_pip_o_tx_dat[gi+1] ), //o
        .o_tx_vld             ( u_pip_o_tx_vld[gi+1] ), //o
        .i_tx_rdy             ( u_pip_i_tx_rdy[gi+1] )  //i
    );
end:gen_pipe_regslice
endgenerate

endmodule //end of com_pipe_regslice

