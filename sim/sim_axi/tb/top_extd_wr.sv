`timescale 1ns/1ps

module top_extd_wr;

localparam AW = 16;
localparam DW = 32;
localparam EBUS_LW = 16;
localparam LW = 4;
localparam UW = 2;

logic clk;
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

initial begin
    clk = 1'b0;
    forever #5 clk = ~clk;
end

initial begin
    wait(test_done);
    $display("SIM_AXI_EXTD_WR PASS");
    $finish;
end

axi_case_prog #(
    .CASE_KIND ( 0       ),
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

com_axi_extd_wr #(
    .AW          ( AW      ),
    .DW          ( DW      ),
    .EBUS_LW     ( EBUS_LW ),
    .LW          ( LW      ),
    .UW          ( UW      ),
    .BOUND_BYTES ( 512     ),
    .MAX_OSD     ( 8       ),
    .BUF_DEPTH   ( 8       )
)u_com_axi_extd_wr
(
    .clk                  ( clk                     ),
    .rst_n                ( axi_bus.rst_n           ),
    .clear                ( axi_bus.clear           ),
    .i_cfg_max_blen_m1    ( axi_bus.cfg_max_blen_m1 ),
    .i_rx_ebus_wa_user    ( axi_bus.wa_user[0]       ),
    .i_rx_ebus_wa_addr    ( axi_bus.wa_addr[0]       ),
    .i_rx_ebus_wa_bytelen ( axi_bus.wa_bytelen[0]    ),
    .i_rx_ebus_wa_valid   ( axi_bus.wa_valid[0]      ),
    .o_rx_ebus_wa_ready   ( axi_bus.wa_ready[0]      ),
    .i_rx_ebus_wd_data    ( axi_bus.wd_data[0]       ),
    .i_rx_ebus_wd_valid   ( axi_bus.wd_valid[0]      ),
    .o_rx_ebus_wd_ready   ( axi_bus.wd_ready[0]      ),
    .o_rx_ebus_wb_valid   ( axi_bus.wb_valid[0]      ),
    .o_tx_axi_awaddr      ( axi_bus.axi_awaddr       ),
    .o_tx_axi_awlen       ( axi_bus.axi_awlen        ),
    .o_tx_axi_awuser      ( axi_bus.axi_awuser       ),
    .o_tx_axi_awvalid     ( axi_bus.axi_awvalid      ),
    .i_tx_axi_awready     ( axi_bus.axi_awready      ),
    .o_tx_axi_wdata       ( axi_bus.axi_wdata        ),
    .o_tx_axi_wstrb       ( axi_bus.axi_wstrb        ),
    .o_tx_axi_wlast       ( axi_bus.axi_wlast        ),
    .o_tx_axi_wvalid      ( axi_bus.axi_wvalid       ),
    .i_tx_axi_wready      ( axi_bus.axi_wready       ),
    .i_tx_axi_bvalid      ( axi_bus.axi_bvalid       ),
    .o_tx_axi_bready      ( axi_bus.axi_bready       )
);

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top_extd_wr);
end
`endif

endmodule
