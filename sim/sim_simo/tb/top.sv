`timescale 1ns/1ps

module top;

logic clk;
logic rst_n;
logic clear;
logic i_rx_vld;
wire  o_rx_rdy;
wire [2:0] o_tx_vld;
logic [2:0] i_tx_rdy;

clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output rst_n;
    output clear;
    output i_rx_vld;
    output i_tx_rdy;
    input  o_rx_rdy;
    input  o_tx_vld;
endclocking

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    clear = 1'b0;
    i_rx_vld = 1'b0;
    i_tx_rdy = 3'b000;
    repeat(5) @(drv_cb);
    drv_cb.rst_n <= 1'b1;
    @(drv_cb);
    drv_cb.i_rx_vld <= 1'b1;
    drv_cb.i_tx_rdy <= 3'b001;
    @(drv_cb);
    drv_cb.i_tx_rdy <= 3'b010;
    @(drv_cb);
    drv_cb.i_tx_rdy <= 3'b000;
    repeat(2) @(drv_cb);
    drv_cb.i_tx_rdy <= 3'b100;
    @(drv_cb);
    if( !drv_cb.o_rx_rdy )
        $fatal(1, "simo should finish all outputs");
    drv_cb.i_rx_vld <= 1'b0;
    drv_cb.i_tx_rdy <= 3'b000;
    repeat(5) @(drv_cb);
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

for( genvar gi=0; gi<3; gi++ ) begin:gen_tx_vld_hold_assert
    a_tx_vld_hold: assert property (@(posedge clk) disable iff(!rst_n || clear)
        o_tx_vld[gi] && !i_tx_rdy[gi] |=> o_tx_vld[gi]);
end

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

endmodule
