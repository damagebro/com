`timescale 1ns/1ps

module top;

localparam AW = 4;
localparam DW = 16;
localparam STRB_W = 2;

logic clk;

wire  [1:0]               arb_o_rx_wr_rdy;
wire  [1:0]               arb_o_rx_rd_rdy;
wire  [1:0]               arb_o_rx_rd_ack;
wire  [1:0][DW-1:0]       arb_o_rx_rd_data;
wire  [AW-1:0]            arb_o_tx_wr_addr;
wire  [DW-1:0]            arb_o_tx_wr_data;
wire  [STRB_W-1:0]        arb_o_tx_wr_vld;
wire  [AW-1:0]            arb_o_tx_rd_addr;
wire                      arb_o_tx_rd_vld;

wire                      sp_o_rx_wr_rdy;
wire                      sp_o_rx_rd_rdy;
wire                      sp_o_rx_rd_ack;
wire [DW-1:0]             sp_o_rx_rd_data;
wire                      sp_o_sram_ce_n;
wire [STRB_W-1:0]         sp_o_sram_we_n;
wire [AW-1:0]             sp_o_sram_addr;
wire [DW-1:0]             sp_o_sram_wr_data;
wire [DW-1:0]             sp_i_sram_rd_data;

wire                      rmw_o_rx_wr_rdy;
wire                      rmw_o_rx_rd_rdy;
wire                      rmw_o_rx_rd_ack;
wire [DW-1:0]             rmw_o_rx_rd_data;
wire [AW-1:0]             rmw_o_tx_wr_addr;
wire [DW-1:0]             rmw_o_tx_wr_data;
wire                      rmw_o_tx_wr_vld;
wire [AW-1:0]             rmw_o_tx_rd_addr;
wire                      rmw_o_tx_rd_vld;

wire                      sp2_o_rx_wr_rdy;
wire                      sp2_o_rx_rd_rdy;
wire                      sp2_o_rx_rd_ack;
wire [DW-1:0]             sp2_o_rx_rd_data;
wire [1:0]                sp2_o_ram_ce_n;
wire [1:0][STRB_W-1:0]    sp2_o_ram_we_n;
wire [1:0][AW-2:0]        sp2_o_ram_addr;
wire [1:0][DW-1:0]        sp2_o_ram_wr_data;
wire [1:0][DW-1:0]        sp2_i_ram_rd_data;
wire                      test_done;

ram_if #(
    .AW     ( AW     ),
    .DW     ( DW     ),
    .STRB_W ( STRB_W )
)ram_bus
(
    .clk ( clk )
);

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    wait(test_done);
    $display("SIM_RAM PASS");
    $finish;
end

ram_case_prog #(
    .AW     ( AW     ),
    .DW     ( DW     ),
    .STRB_W ( STRB_W )
)u_case
(
    .ram_bus ( ram_bus   ),
    .o_done  ( test_done )
);

com_ram_arbiter #(
    .WCH          ( 2            ),
    .RCH          ( 2            ),
    .AW           ( AW           ),
    .DW           ( DW           ),
    .STRB_W       ( STRB_W       ),
    .RAM_RD_DELAY ( 1            )
)u_com_ram_arbiter
(
    .clk             ( clk                 ),
    .rst_n           ( ram_bus.rst_n       ),
    .clear           ( ram_bus.clear       ),
    .i_rx_wr_addr    ( ram_bus.arb_wr_addr ),
    .i_rx_wr_data    ( ram_bus.arb_wr_data ),
    .i_rx_wr_vld     ( ram_bus.arb_wr_vld  ),
    .o_rx_wr_rdy     ( arb_o_rx_wr_rdy     ),
    .i_rx_rd_addr    ( ram_bus.arb_rd_addr ),
    .i_rx_rd_vld     ( ram_bus.arb_rd_vld  ),
    .o_rx_rd_rdy     ( arb_o_rx_rd_rdy     ),
    .o_rx_rd_ack     ( arb_o_rx_rd_ack     ),
    .o_rx_rd_data    ( arb_o_rx_rd_data    ),
    .o_tx_wr_addr    ( arb_o_tx_wr_addr    ),
    .o_tx_wr_data    ( arb_o_tx_wr_data    ),
    .o_tx_wr_vld     ( arb_o_tx_wr_vld     ),
    .i_tx_wr_rdy     ( 1'b1                ),
    .o_tx_rd_addr    ( arb_o_tx_rd_addr    ),
    .o_tx_rd_vld     ( arb_o_tx_rd_vld     ),
    .i_tx_rd_rdy     ( 1'b1                ),
    .i_tx_rd_ack     ( arb_o_tx_rd_vld     ),
    .i_tx_rd_data    ( 16'ha55a            )
);

com_ram_adp_sp #(
    .AW           ( AW           ),
    .DW           ( DW           ),
    .STRB_W       ( STRB_W       ),
    .RAM_RD_DELAY ( 1            )
)u_com_ram_adp_sp
(
    .clk             ( clk                ),
    .rst_n           ( ram_bus.rst_n      ),
    .clear           ( ram_bus.clear      ),
    .i_rx_wr_addr    ( ram_bus.sp_wr_addr ),
    .i_rx_wr_data    ( ram_bus.sp_wr_data ),
    .i_rx_wr_vld     ( ram_bus.sp_wr_vld  ),
    .o_rx_wr_rdy     ( sp_o_rx_wr_rdy     ),
    .i_rx_rd_addr    ( ram_bus.sp_rd_addr ),
    .i_rx_rd_vld     ( ram_bus.sp_rd_vld  ),
    .o_rx_rd_rdy     ( sp_o_rx_rd_rdy     ),
    .o_rx_rd_ack     ( sp_o_rx_rd_ack     ),
    .o_rx_rd_data    ( sp_o_rx_rd_data    ),
    .o_sram_ce_n     ( sp_o_sram_ce_n     ),
    .o_sram_we_n     ( sp_o_sram_we_n     ),
    .o_sram_addr     ( sp_o_sram_addr     ),
    .o_sram_wr_data  ( sp_o_sram_wr_data  ),
    .i_sram_rd_data  ( sp_i_sram_rd_data  )
);

com_spram_shell #(
    .DATA_W ( DW     ),
    .DEPTH  ( 16     ),
    .STRB_W ( STRB_W )
)u_com_spram_shell_sp
(
    .clk            ( clk               ),
    .i_cfg_mem_ctrl ( '0                ),
    .i_ce_n         ( sp_o_sram_ce_n    ),
    .i_we_n         ( sp_o_sram_we_n    ),
    .i_addr         ( sp_o_sram_addr    ),
    .i_wr_data      ( sp_o_sram_wr_data ),
    .o_rd_data      ( sp_i_sram_rd_data )
);

com_ram_adp_rmw #(
    .AW           ( AW           ),
    .DW           ( DW           ),
    .STRB_W       ( STRB_W       ),
    .RAM_RD_DELAY ( 1            )
)u_com_ram_adp_rmw
(
    .clk             ( clk                 ),
    .rst_n           ( ram_bus.rst_n       ),
    .clear           ( ram_bus.clear       ),
    .i_rx_wr_addr    ( ram_bus.rmw_wr_addr ),
    .i_rx_wr_data    ( ram_bus.rmw_wr_data ),
    .i_rx_wr_vld     ( ram_bus.rmw_wr_vld  ),
    .o_rx_wr_rdy     ( rmw_o_rx_wr_rdy     ),
    .i_rx_rd_addr    ( ram_bus.rmw_rd_addr ),
    .i_rx_rd_vld     ( ram_bus.rmw_rd_vld  ),
    .o_rx_rd_rdy     ( rmw_o_rx_rd_rdy     ),
    .o_rx_rd_ack     ( rmw_o_rx_rd_ack     ),
    .o_rx_rd_data    ( rmw_o_rx_rd_data    ),
    .o_tx_wr_addr    ( rmw_o_tx_wr_addr    ),
    .o_tx_wr_data    ( rmw_o_tx_wr_data    ),
    .o_tx_wr_vld     ( rmw_o_tx_wr_vld     ),
    .i_tx_wr_rdy     ( 1'b1                ),
    .o_tx_rd_addr    ( rmw_o_tx_rd_addr    ),
    .o_tx_rd_vld     ( rmw_o_tx_rd_vld     ),
    .i_tx_rd_rdy     ( 1'b1                ),
    .i_tx_rd_ack     ( rmw_o_tx_rd_vld     ),
    .i_tx_rd_data    ( 16'h0f0f            )
);

com_ram_adp_2sp #(
    .AW           ( AW           ),
    .DW           ( DW           ),
    .STRB_W       ( STRB_W       ),
    .RAM_RD_DELAY ( 1            )
)u_com_ram_adp_2sp
(
    .clk             ( clk                 ),
    .rst_n           ( ram_bus.rst_n       ),
    .clear           ( ram_bus.clear       ),
    .i_rx_wr_addr    ( ram_bus.sp2_wr_addr ),
    .i_rx_wr_data    ( ram_bus.sp2_wr_data ),
    .i_rx_wr_vld     ( ram_bus.sp2_wr_vld  ),
    .o_rx_wr_rdy     ( sp2_o_rx_wr_rdy     ),
    .i_rx_rd_addr    ( ram_bus.sp2_rd_addr ),
    .i_rx_rd_vld     ( ram_bus.sp2_rd_vld  ),
    .o_rx_rd_rdy     ( sp2_o_rx_rd_rdy     ),
    .o_rx_rd_ack     ( sp2_o_rx_rd_ack     ),
    .o_rx_rd_data    ( sp2_o_rx_rd_data    ),
    .o_ram_ce_n      ( sp2_o_ram_ce_n      ),
    .o_ram_we_n      ( sp2_o_ram_we_n      ),
    .o_ram_addr      ( sp2_o_ram_addr      ),
    .o_ram_wr_data   ( sp2_o_ram_wr_data   ),
    .i_ram_rd_data   ( sp2_i_ram_rd_data   )
);

for( genvar gi=0; gi<2; gi++ ) begin:gen_sp2_bank
    com_spram_shell #(
        .DATA_W ( DW     ),
        .DEPTH  ( 8      ),
        .STRB_W ( STRB_W )
    )u_com_spram_shell_bank
    (
        .clk            ( clk                     ),
        .i_cfg_mem_ctrl ( '0                      ),
        .i_ce_n         ( sp2_o_ram_ce_n[gi]      ),
        .i_we_n         ( sp2_o_ram_we_n[gi]      ),
        .i_addr         ( sp2_o_ram_addr[gi]      ),
        .i_wr_data      ( sp2_o_ram_wr_data[gi]   ),
        .o_rd_data      ( sp2_i_ram_rd_data[gi]   )
    );
end

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top);
end
`endif

endmodule
