`timescale 1ns/1ps

module top_dma;

localparam WCH = 1;
localparam RCH = 1;
localparam AW = 16;
localparam DW = 32;
localparam EBUS_LW = 16;
localparam LW = 4;
localparam IW = 1;
localparam UW = 2;

logic clk;
wire  [RCH-1:0][15:0] o_sta_rch_rdbuf_wl;
wire  o_sta_rch_clr_ongoing;
wire  o_sta_wch_clr_ongoing;
wire test_done;

axi_if #(
    .WCH     ( WCH      ),
    .RCH     ( RCH      ),
    .AW      ( AW       ),
    .DW      ( DW       ),
    .EBUS_LW ( EBUS_LW  ),
    .LW      ( LW       ),
    .IW      ( IW       ),
    .UW      ( UW       )
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
    $display("SIM_AXI_DMA PASS");
    $finish;
end

axi_case_prog #(
    .CASE_KIND ( 2       ),
    .WCH       ( WCH     ),
    .RCH       ( RCH     ),
    .AW        ( AW      ),
    .DW        ( DW      ),
    .EBUS_LW   ( EBUS_LW ),
    .LW        ( LW      ),
    .IW        ( IW      ),
    .UW        ( UW      )
)u_case
(
    .axi_bus ( axi_bus   ),
    .o_done  ( test_done )
);

com_axi_dma #(
    .WCH         ( WCH      ),
    .RCH         ( RCH      ),
    .AW          ( AW       ),
    .DW          ( DW       ),
    .EBUS_LW     ( EBUS_LW  ),
    .LW          ( LW       ),
    .IW          ( IW       ),
    .UW          ( UW       ),
    .BOUND_BYTES ( 512      ),
    .MAX_OSD     ( 8        ),
    .MAX_LEN     ( 4        )
)u_com_axi_dma
(
    .clk                    ( clk                    ),
    .rst_n                  ( axi_bus.rst_n                  ),
    .clear                  ( axi_bus.clear                  ),
    .i_cfg_mem_ctrl         ( axi_bus.cfg_mem_ctrl           ),
    .i_cfg_max_blen_m1      ( axi_bus.cfg_max_blen_m1        ),
    .i_cfg_rch_max_rdcmd_osd( axi_bus.cfg_rch_max_rdcmd_osd  ),
    .o_sta_rch_rdbuf_wl     ( o_sta_rch_rdbuf_wl     ),
    .o_sta_rch_clr_ongoing  ( o_sta_rch_clr_ongoing  ),
    .o_sta_wch_clr_ongoing  ( o_sta_wch_clr_ongoing  ),
    .i_rx_ebus_wa_user      ( axi_bus.wa_user                ),
    .i_rx_ebus_wa_addr      ( axi_bus.wa_addr                ),
    .i_rx_ebus_wa_bytelen   ( axi_bus.wa_bytelen             ),
    .i_rx_ebus_wa_valid     ( axi_bus.wa_valid               ),
    .o_rx_ebus_wa_ready     ( axi_bus.wa_ready               ),
    .i_rx_ebus_wd_data      ( axi_bus.wd_data                ),
    .i_rx_ebus_wd_valid     ( axi_bus.wd_valid               ),
    .o_rx_ebus_wd_ready     ( axi_bus.wd_ready               ),
    .o_rx_ebus_wb_valid     ( axi_bus.wb_valid               ),
    .i_rx_ebus_ra_user      ( axi_bus.ra_user                ),
    .i_rx_ebus_ra_addr      ( axi_bus.ra_addr                ),
    .i_rx_ebus_ra_bytelen   ( axi_bus.ra_bytelen             ),
    .i_rx_ebus_ra_valid     ( axi_bus.ra_valid               ),
    .o_rx_ebus_ra_ready     ( axi_bus.ra_ready               ),
    .o_rx_ebus_rd_data      ( axi_bus.rd_data                ),
    .o_rx_ebus_rd_last      ( axi_bus.rd_last                ),
    .o_rx_ebus_rd_valid     ( axi_bus.rd_valid               ),
    .i_rx_ebus_rd_ready     ( axi_bus.rd_ready               ),
    .o_tx_axi_awid          ( axi_bus.axi_awid               ),
    .o_tx_axi_awaddr        ( axi_bus.axi_awaddr             ),
    .o_tx_axi_awlen         ( axi_bus.axi_awlen              ),
    .o_tx_axi_awuser        ( axi_bus.axi_awuser             ),
    .o_tx_axi_awvalid       ( axi_bus.axi_awvalid            ),
    .i_tx_axi_awready       ( axi_bus.axi_awready            ),
    .o_tx_axi_wdata         ( axi_bus.axi_wdata              ),
    .o_tx_axi_wstrb         ( axi_bus.axi_wstrb              ),
    .o_tx_axi_wlast         ( axi_bus.axi_wlast              ),
    .o_tx_axi_wvalid        ( axi_bus.axi_wvalid             ),
    .i_tx_axi_wready        ( axi_bus.axi_wready             ),
    .i_tx_axi_bresp         ( axi_bus.axi_bresp              ),
    .i_tx_axi_bid           ( axi_bus.axi_bid                ),
    .i_tx_axi_bvalid        ( axi_bus.axi_bvalid             ),
    .o_tx_axi_bready        ( axi_bus.axi_bready             ),
    .o_tx_axi_arid          ( axi_bus.axi_arid               ),
    .o_tx_axi_araddr        ( axi_bus.axi_araddr             ),
    .o_tx_axi_arlen         ( axi_bus.axi_arlen              ),
    .o_tx_axi_aruser        ( axi_bus.axi_aruser             ),
    .o_tx_axi_arvalid       ( axi_bus.axi_arvalid            ),
    .i_tx_axi_arready       ( axi_bus.axi_arready            ),
    .i_tx_axi_rresp         ( axi_bus.axi_rresp              ),
    .i_tx_axi_rid           ( axi_bus.axi_rid                ),
    .i_tx_axi_rdata         ( axi_bus.axi_rdata              ),
    .i_tx_axi_rlast         ( axi_bus.axi_rlast              ),
    .i_tx_axi_rvalid        ( axi_bus.axi_rvalid             ),
    .o_tx_axi_rready        ( axi_bus.axi_rready             )
);

`ifdef DUMP_FST
initial begin
    $dumpfile("run.fst");
    $dumpvars(0, top_dma);
end
`endif

endmodule
