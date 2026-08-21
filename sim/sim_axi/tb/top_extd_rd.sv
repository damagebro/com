`timescale 1ns/1ps

module top_extd_rd;

localparam AW = 16;
localparam DW = 32;
localparam EBUS_LW = 16;
localparam LW = 4;
localparam UW = 2;
localparam RAM_DW = DW+1;

logic clk;
wire [15:0] o_sta_rdbuf_wl;
wire [1:0] o_rdfifo_ram_ce_n;
wire [1:0] o_rdfifo_ram_we_n;
wire [1:0][0:0] o_rdfifo_ram_addr;
wire [1:0][RAM_DW-1:0] o_rdfifo_ram_wr_data;
wire [1:0][RAM_DW-1:0] i_rdfifo_ram_rd_data;
wire test_done;

axi_if #(
    .WCH     ( 1       ),
    .RCH     ( 1       ),
    .AW      ( AW      ),
    .DW      ( DW      ),
    .EBUS_LW ( EBUS_LW ),
    .LW      ( LW      ),
    .IW      ( 1       ),
    .UW      ( UW      )
)axi_bus
(
    .clk ( clk )
);
assign i_rdfifo_ram_rd_data = '0;

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    wait(test_done);
    $display("SIM_AXI_EXTD_RD PASS");
    $finish;
end

axi_case_prog #(
    .CASE_KIND ( 1       ),
    .WCH       ( 1       ),
    .RCH       ( 1       ),
    .AW        ( AW      ),
    .DW        ( DW      ),
    .EBUS_LW   ( EBUS_LW ),
    .LW        ( LW      ),
    .IW        ( 1       ),
    .UW        ( UW      )
)u_case
(
    .axi_bus ( axi_bus   ),
    .o_done  ( test_done )
);

com_axi_extd_rd #(
    .AW          ( AW      ),
    .DW          ( DW      ),
    .EBUS_LW     ( EBUS_LW ),
    .LW          ( LW      ),
    .UW          ( UW      ),
    .BOUND_BYTES ( 512     ),
    .MAX_OSD     ( 8       ),
    .BUF_DEPTH   ( 0       )
)u_com_axi_extd_rd
(
    .clk                   ( clk                   ),
    .rst_n                 ( axi_bus.rst_n             ),
    .clear                 ( axi_bus.clear             ),
    .i_cfg_max_blen_m1     ( axi_bus.cfg_max_blen_m1   ),
    .i_cfg_max_rdcmd_osd   ( axi_bus.cfg_rch_max_rdcmd_osd[0] ),
    .o_sta_rdbuf_wl        ( o_sta_rdbuf_wl        ),
    .o_rdfifo_ram_ce_n     ( o_rdfifo_ram_ce_n     ),
    .o_rdfifo_ram_we_n     ( o_rdfifo_ram_we_n     ),
    .o_rdfifo_ram_addr     ( o_rdfifo_ram_addr     ),
    .o_rdfifo_ram_wr_data  ( o_rdfifo_ram_wr_data  ),
    .i_rdfifo_ram_rd_data  ( i_rdfifo_ram_rd_data  ),
    .i_rx_ebus_ra_user     ( axi_bus.ra_user[0]         ),
    .i_rx_ebus_ra_addr     ( axi_bus.ra_addr[0]         ),
    .i_rx_ebus_ra_bytelen  ( axi_bus.ra_bytelen[0]      ),
    .i_rx_ebus_ra_valid    ( axi_bus.ra_valid[0]        ),
    .o_rx_ebus_ra_ready    ( axi_bus.ra_ready[0]        ),
    .o_rx_ebus_rd_data     ( axi_bus.rd_data[0]         ),
    .o_rx_ebus_rd_last     ( axi_bus.rd_last[0]         ),
    .o_rx_ebus_rd_valid    ( axi_bus.rd_valid[0]        ),
    .i_rx_ebus_rd_ready    ( axi_bus.rd_ready[0]        ),
    .o_tx_axi_araddr       ( axi_bus.axi_araddr         ),
    .o_tx_axi_arlen        ( axi_bus.axi_arlen          ),
    .o_tx_axi_aruser       ( axi_bus.axi_aruser         ),
    .o_tx_axi_arvalid      ( axi_bus.axi_arvalid       ),
    .i_tx_axi_arready      ( axi_bus.axi_arready       ),
    .i_tx_axi_rdata        ( axi_bus.axi_rdata         ),
    .i_tx_axi_rlast        ( axi_bus.axi_rlast         ),
    .i_tx_axi_rvalid       ( axi_bus.axi_rvalid        ),
    .o_tx_axi_rready       ( axi_bus.axi_rready         )
);

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top_extd_rd);
end
`endif

endmodule
