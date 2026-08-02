`timescale 1ns/1ps

module top;

logic clk;
logic rst_n;
logic clear;
logic i_rx_vld;
wire  o_rx_rdy;
wire [2:0] o_tx_vld;
logic [2:0] i_tx_rdy;

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    clear = 1'b0;
    i_rx_vld = 1'b0;
    i_tx_rdy = 3'b000;
    repeat(5) @(posedge clk);
    rst_n = 1'b1;
    @(posedge clk);
    i_rx_vld = 1'b1;
    i_tx_rdy = 3'b001;
    @(posedge clk);
    i_tx_rdy = 3'b101;
    @(posedge clk);
    i_tx_rdy = 3'b111;
    @(posedge clk);
    if( !o_rx_rdy )
        $fatal(1, "simo should finish all outputs");
    i_rx_vld = 1'b0;
    repeat(5) @(posedge clk);
    $display("SIM_SIMO PASS");
    $finish;
end

com_simo_no_delay #(
    .CH_NUM ( 3 )
)u_com_simo_no_delay
(
    .clk       ( clk       ),
    .rst_n     ( rst_n     ),
    .clear     ( clear     ),
    .i_rx_vld  ( i_rx_vld  ),
    .o_rx_rdy  ( o_rx_rdy  ),
    .o_tx_vld  ( o_tx_vld  ),
    .i_tx_rdy  ( i_tx_rdy  )
);

endmodule
