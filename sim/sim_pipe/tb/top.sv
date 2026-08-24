`timescale 1ns/1ps

module top;

logic clk;
logic rst_n;

logic vld_clear;
logic vld_i_rx_vld;
logic vld_i_tx_rdy;
wire  vld_o_rx_rdy;
wire  vld_o_tx_vld;
wire  vld_o_rx_pipe_upen;
logic vld_done;

logic       rdy_clear;
logic [7:0] rdy_i_rx_dat;
logic       rdy_i_rx_vld;
logic       rdy_i_tx_rdy;
wire        rdy_o_rx_rdy;
wire [7:0]  rdy_o_tx_dat;
wire        rdy_o_tx_vld;
logic       rdy_done;

clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output rst_n;
    output vld_clear;
    output vld_i_rx_vld;
    output vld_i_tx_rdy;
    input  vld_o_rx_rdy;
    input  vld_o_tx_vld;
    input  vld_o_rx_pipe_upen;
    output rdy_clear;
    output rdy_i_rx_dat;
    output rdy_i_rx_vld;
    output rdy_i_tx_rdy;
    input  rdy_o_rx_rdy;
    input  rdy_o_tx_dat;
    input  rdy_o_tx_vld;
endclocking

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    repeat(5) @(drv_cb);
    drv_cb.rst_n <= 1'b1;
end

initial begin
    vld_clear    = 1'b0;
    vld_i_rx_vld = 1'b0;
    vld_i_tx_rdy = 1'b0;
    vld_done     = 1'b0;
    wait(rst_n);

    @(drv_cb);
    drv_cb.vld_i_rx_vld <= 1'b1;
    @(drv_cb);
    drv_cb.vld_i_rx_vld <= 1'b0;
    repeat(2) @(drv_cb);
    drv_cb.vld_i_tx_rdy <= 1'b1;
    @(drv_cb);
    drv_cb.vld_i_tx_rdy <= 1'b0;
    drv_cb.vld_i_rx_vld <= 1'b1;
    repeat(2) @(drv_cb);
    drv_cb.vld_i_tx_rdy <= 1'b1;
    @(drv_cb);
    drv_cb.vld_i_rx_vld <= 1'b0;
    @(drv_cb);
    drv_cb.vld_i_tx_rdy <= 1'b0;
    repeat(3) @(drv_cb);
    vld_done = 1'b1;
end

initial begin
    rdy_clear    = 1'b0;
    rdy_i_rx_dat = '0;
    rdy_i_rx_vld = 1'b0;
    rdy_i_tx_rdy = 1'b0;
    rdy_done     = 1'b0;
    wait(rst_n);

    @(drv_cb);
    drv_cb.rdy_i_rx_dat <= 8'h11;
    drv_cb.rdy_i_rx_vld <= 1'b1;
    drv_cb.rdy_i_tx_rdy <= 1'b1;
    @(drv_cb);
    drv_cb.rdy_i_rx_dat <= 8'h22;
    drv_cb.rdy_i_tx_rdy <= 1'b0;
    repeat(2) @(drv_cb);
    drv_cb.rdy_i_tx_rdy <= 1'b1;
    @(drv_cb);
    drv_cb.rdy_i_rx_dat <= 8'h33;
    @(drv_cb);
    drv_cb.rdy_i_rx_dat <= 8'h44;
    drv_cb.rdy_i_tx_rdy <= 1'b0;
    repeat(2) @(drv_cb);
    drv_cb.rdy_i_tx_rdy <= 1'b1;
    @(drv_cb);
    drv_cb.rdy_i_rx_vld <= 1'b0;
    repeat(3) @(drv_cb);
    rdy_done = 1'b1;
end

initial begin
    wait(vld_done && rdy_done);
    $display("SIM_PIPE PASS");
    $finish;
end

com_pipe_vld_single u_com_pipe_vld_single
(
    .clk            ( clk                 ),
    .rst_n          ( rst_n               ),
    .clear          ( vld_clear           ),
    .i_rx_vld       ( vld_i_rx_vld        ),
    .o_rx_rdy       ( vld_o_rx_rdy        ),
    .o_tx_vld       ( vld_o_tx_vld        ),
    .i_tx_rdy       ( vld_i_tx_rdy        ),
    .o_rx_pipe_upen ( vld_o_rx_pipe_upen  )
);

com_pipe_rdy #(
    .DW ( 8 )
)u_com_pipe_rdy
(
    .clk       ( clk          ),
    .rst_n     ( rst_n        ),
    .clear     ( rdy_clear    ),
    .i_rx_dat  ( rdy_i_rx_dat ),
    .i_rx_vld  ( rdy_i_rx_vld ),
    .o_rx_rdy  ( rdy_o_rx_rdy ),
    .o_tx_dat  ( rdy_o_tx_dat ),
    .o_tx_vld  ( rdy_o_tx_vld ),
    .i_tx_rdy  ( rdy_i_tx_rdy )
);

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

endmodule
