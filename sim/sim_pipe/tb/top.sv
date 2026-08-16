`timescale 1ns/1ps

module top;

logic clk;
logic rst_n;
logic clear;
logic [7:0] i_rx_dat;
logic i_rx_vld;
logic i_tx_rdy;
wire vld_single_o_rx_rdy;
wire vld_single_o_tx_vld;
wire vld_single_o_rx_pipe_upen;
wire vld_o_rx_rdy;
wire vld_o_tx_vld;
wire [2:0] vld_o_rx_pipe_upen;
wire [7:0] rdy_o_tx_dat;
wire rdy_o_rx_rdy;
wire rdy_o_tx_vld;
wire [7:0] vld_rdy_o_tx_dat;
wire vld_rdy_o_rx_rdy;
wire vld_rdy_o_tx_vld;
wire [7:0] regslice_o_tx_dat;
wire regslice_o_rx_rdy;
wire regslice_o_tx_vld;

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    rst_n = 1'b0;
    clear = 1'b0;
    i_rx_dat = '0;
    i_rx_vld = 1'b0;
    i_tx_rdy = 1'b0;
    repeat(5) @(posedge clk);
    rst_n <= 1'b1;
    repeat(2) @(posedge clk);
    for( int i=0; i<12; i++ ) begin
        @(posedge clk);
        i_rx_vld <= 1'b1;
        i_rx_dat <= i[7:0];
        i_tx_rdy <= i[1] || i[0];
    end
    @(posedge clk);
    i_rx_vld <= 1'b0;
    i_tx_rdy <= 1'b1;
    repeat(12) @(posedge clk);
    $display("SIM_PIPE PASS");
    $finish;
end

com_pipe_vld_single u_com_pipe_vld_single
(
    .clk             ( clk                       ),
    .rst_n           ( rst_n                     ),
    .clear           ( clear                     ),
    .i_rx_vld        ( i_rx_vld                  ),
    .o_rx_rdy        ( vld_single_o_rx_rdy       ),
    .o_tx_vld        ( vld_single_o_tx_vld       ),
    .i_tx_rdy        ( i_tx_rdy                  ),
    .o_rx_pipe_upen  ( vld_single_o_rx_pipe_upen )
);

com_pipe_vld #(
    .PIPE_NUM ( 3 )
)u_com_pipe_vld
(
    .clk             ( clk                ),
    .rst_n           ( rst_n              ),
    .clear           ( clear              ),
    .i_rx_vld        ( i_rx_vld           ),
    .o_rx_rdy        ( vld_o_rx_rdy       ),
    .o_tx_vld        ( vld_o_tx_vld       ),
    .i_tx_rdy        ( i_tx_rdy           ),
    .o_rx_pipe_upen  ( vld_o_rx_pipe_upen )
);

com_pipe_rdy #(
    .DW ( 8 )
)u_com_pipe_rdy
(
    .clk       ( clk          ),
    .rst_n     ( rst_n        ),
    .clear     ( clear        ),
    .i_rx_dat  ( i_rx_dat     ),
    .i_rx_vld  ( i_rx_vld     ),
    .o_rx_rdy  ( rdy_o_rx_rdy ),
    .o_tx_dat  ( rdy_o_tx_dat ),
    .o_tx_vld  ( rdy_o_tx_vld ),
    .i_tx_rdy  ( i_tx_rdy     )
);

com_pipe_vld_rdy #(
    .VLD_PIPE_EN ( 1 ),
    .RDY_PIPE_EN ( 1 ),
    .DW          ( 8 )
)u_com_pipe_vld_rdy
(
    .clk       ( clk              ),
    .rst_n     ( rst_n            ),
    .clear     ( clear            ),
    .i_rx_dat  ( i_rx_dat         ),
    .i_rx_vld  ( i_rx_vld         ),
    .o_rx_rdy  ( vld_rdy_o_rx_rdy ),
    .o_tx_dat  ( vld_rdy_o_tx_dat ),
    .o_tx_vld  ( vld_rdy_o_tx_vld ),
    .i_tx_rdy  ( i_tx_rdy         )
);

com_pipe_regslice #(
    .PIPE_NUM ( 2 ),
    .DW       ( 8 )
)u_com_pipe_regslice
(
    .clk       ( clk                 ),
    .rst_n     ( rst_n               ),
    .clear     ( clear               ),
    .i_rx_dat  ( i_rx_dat            ),
    .i_rx_vld  ( i_rx_vld            ),
    .o_rx_rdy  ( regslice_o_rx_rdy   ),
    .o_tx_dat  ( regslice_o_tx_dat   ),
    .o_tx_vld  ( regslice_o_tx_vld   ),
    .i_tx_rdy  ( i_tx_rdy            )
);

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

endmodule
