/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2025/07/05-21:55:11
*
*  Description:
*   valid/ready bi_ward single-stage pipeline with data;
*
*  Modify:
*  -
*
******************************************************************************/

module com_pipe_vld_rdy #( parameter
    VLD_PIPE_EN = 1,
    RDY_PIPE_EN = 1,
    DW = 8  //range=[1:]
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
wire [DW-1:0]  w_vld_tx_dat;

wire [DW-1:0]  u_rdy_i_rx_dat;
wire           u_rdy_i_rx_vld;
wire           u_rdy_o_rx_rdy;
wire [DW-1:0]  u_rdy_o_tx_dat;
wire           u_rdy_o_tx_vld;
wire           u_rdy_i_tx_rdy;
wire           u_vld_i_rx_vld;
wire           u_vld_o_rx_rdy;
wire           u_vld_o_tx_vld;
wire           u_vld_i_tx_rdy;
//statement------------------------------------------------------------------
//out signae----
assign o_rx_rdy = u_rdy_o_rx_rdy;
assign o_tx_vld = u_vld_o_tx_vld;
assign o_tx_dat = w_vld_tx_dat;


assign u_rdy_i_rx_dat = i_rx_dat;
assign u_rdy_i_rx_vld = i_rx_vld;
assign u_vld_i_rx_vld = u_rdy_o_tx_vld;
assign u_rdy_i_tx_rdy = u_vld_o_rx_rdy;
generate
if( RDY_PIPE_EN )begin:gen_rdy_pipe
    com_pipe_rdy #(
        .DW         ( DW         )  //8
    )u_com_pipe_rdy
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i

        .i_rx_dat             ( u_rdy_i_rx_dat       ), //i
        .i_rx_vld             ( u_rdy_i_rx_vld       ), //i
        .o_rx_rdy             ( u_rdy_o_rx_rdy       ), //o
        .o_tx_dat             ( u_rdy_o_tx_dat       ), //o
        .o_tx_vld             ( u_rdy_o_tx_vld       ), //o
        .i_tx_rdy             ( u_rdy_i_tx_rdy       )  //i
    );
end:gen_rdy_pipe
else begin:gen_no_rdy_pipe
    assign u_rdy_o_tx_dat = u_rdy_i_rx_dat;
    assign u_rdy_o_tx_vld = u_rdy_i_rx_vld;
    assign u_rdy_o_rx_rdy = u_rdy_i_tx_rdy;
end:gen_no_rdy_pipe
if( VLD_PIPE_EN )begin:gen_vld_pipe
    reg  [DW-1:0] r_vld_rx_dat;
    assign w_vld_tx_dat = r_vld_rx_dat;
    always@( posedge clk )begin
        if(u_vld_i_rx_vld&&u_vld_o_rx_rdy)
            r_vld_rx_dat <= u_rdy_o_tx_dat;
    end
    com_pipe_vld #(
        .PIPE_NUM (1)
    )u_com_pipe_vld
    (
        .clk                  ( clk                  ), //i
        .rst_n                ( rst_n                ), //i
        .clear                ( clear                ), //i

        .i_rx_vld             ( u_vld_i_rx_vld       ), //i
        .o_rx_rdy             ( u_vld_o_rx_rdy       ), //o
        .o_tx_vld             ( u_vld_o_tx_vld       ), //o
        .i_tx_rdy             ( u_vld_i_tx_rdy       ), //i
        .o_pipe_upen          (                      )  //o
    );
end:gen_vld_pipe
else begin:gen_no_vld_pipe
    assign u_vld_o_tx_vld = u_vld_i_rx_vld;
    assign u_vld_o_rx_rdy = u_vld_i_tx_rdy;
    assign w_vld_tx_dat = u_rdy_o_tx_dat;
end:gen_no_vld_pipe
endgenerate

endmodule //end of com_pipe_vld_rdy

