module top();

event all_done;
bit clk   ;
bit rst_n ;
bit clear ;

always #2   clk= ~clk;

task reset();
    #10; rst_n = 1'b1;
    #15; rst_n = 1'b0;
    #20; rst_n = 1'b1;
endtask //reset_isp
task xclear();
    @( posedge clk ); clear <= 1'b0;
    @( posedge clk ); clear <= 1'b1;
    @( posedge clk ); clear <= 1'b0;
endtask //reset_isp


//-------------------------------------------------------
//dut
//-------------------------------------------------------
import DmaPkg::*;
import EmiPkg::*;
localparam AXI_IW = $clog2(EMI_MAX_CH);

DmaIf dma_if( clk );
com_emi_tbif #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH), .EMI_UW(1) )  emi_resp_if(clk);
dma_test dma_t1( emi_resp_if, dma_if );
com_axi_dma #(
    .WCH                            ( WCH                           ), //3
    .RCH                            ( RCH                           ), //5
    .AW                             ( BUS_AW                        ), //32
    .DW                             ( BUS_DW                        ), //128
    .EBUS_LW                        ( BUS_LW                        ), //32
    .LW                             ( 8                             ), //8
    .IW                             ( AXI_IW                        ), //4
    .UW                             ( 1                             ), //1
    .BOUND_BYTES                    ( 512                           ), //4096
    .MAX_OSD                        ( 128                           ), //128
    .MAX_LEN                        ( 8                             ) //4
    // .RCH_BUF_DEPTH                  ( 0                             )  //'{0}
)u_com_axi_dma(
    .clk                 ( clk                  ), //i
    .rst_n               ( rst_n                ), //i
    .clear               ( clear                ), //i
    .mem_cfg             ( mem_cfg              ), //i
    .i_cfg_max_blen_m1   ( dma_if.axi_burst_len    ), //i
    .i_cfg_rch_max_rdcmd_osd( '0 ), //i
    .o_sta_rch_rdbuf_wl   (                     ), //o
    .o_sta_rch_clr_ongoing(                     ), //o
    .o_sta_wch_clr_ongoing(                     ), //o
    .i_rx_ebus_wa_user   ( '0                   ), //i
    .i_rx_ebus_wa_addr   ( dma_if.bus_wa_addr   ), //i
    .i_rx_ebus_wa_bytelen( dma_if.bus_wa_bytelen), //i
    .i_rx_ebus_wa_valid  ( dma_if.bus_wa_valid  ), //i
    .o_rx_ebus_wa_ready  ( dma_if.bus_wa_ready  ), //o
    .i_rx_ebus_wd_data   ( dma_if.bus_wd_data   ), //i
    .i_rx_ebus_wd_valid  ( dma_if.bus_wd_valid  ), //i
    .o_rx_ebus_wd_ready  ( dma_if.bus_wd_ready  ), //o
    .o_rx_ebus_wb_valid  ( dma_if.bus_wb_resp   ), //o
    .i_rx_ebus_ra_user   ( '0                   ), //i
    .i_rx_ebus_ra_addr   ( dma_if.bus_ra_addr   ), //i
    .i_rx_ebus_ra_bytelen( dma_if.bus_ra_bytelen), //i
    .i_rx_ebus_ra_valid  ( dma_if.bus_ra_valid  ), //i
    .o_rx_ebus_ra_ready  ( dma_if.bus_ra_ready  ), //o
    .o_rx_ebus_rd_data   ( dma_if.bus_rd_data   ), //o
    .o_rx_ebus_rd_last   ( dma_if.bus_rd_last   ), //o
    .o_rx_ebus_rd_valid  ( dma_if.bus_rd_valid  ), //o
    .i_rx_ebus_rd_ready  ( dma_if.bus_rd_ready  ), //i
    .o_tx_axi_awid       ( emi_resp_if.emi_awid    ), //o
    .o_tx_axi_awaddr     ( emi_resp_if.emi_awaddr  ), //o
    .o_tx_axi_awlen      ( emi_resp_if.emi_awlen   ), //o
    .o_tx_axi_awuser     ( emi_resp_if.emi_awuser  ), //o
    .o_tx_axi_awvalid    ( emi_resp_if.emi_awvalid ), //o
    .i_tx_axi_awready    ( emi_resp_if.emi_awready ), //i
    .o_tx_axi_wdata      ( emi_resp_if.emi_wdata   ), //o
    .o_tx_axi_wstrb      ( emi_resp_if.emi_wstrb   ), //o
    .o_tx_axi_wlast      ( emi_resp_if.emi_wlast   ), //o
    .o_tx_axi_wvalid     ( emi_resp_if.emi_wvalid  ), //o
    .i_tx_axi_wready     ( emi_resp_if.emi_wready  ), //i
    .i_tx_axi_bresp      ( '0                      ), //i
    .i_tx_axi_bid        ( emi_resp_if.emi_bid     ), //i
    .i_tx_axi_bvalid     ( emi_resp_if.emi_bvalid  ), //i
    .o_tx_axi_bready     ( emi_resp_if.emi_bready  ), //o
    .o_tx_axi_arid       ( emi_resp_if.emi_arid    ), //o
    .o_tx_axi_araddr     ( emi_resp_if.emi_araddr  ), //o
    .o_tx_axi_arlen      ( emi_resp_if.emi_arlen   ), //o
    .o_tx_axi_aruser     ( emi_resp_if.emi_aruser  ), //o
    .o_tx_axi_arvalid    ( emi_resp_if.emi_arvalid ), //o
    .i_tx_axi_arready    ( emi_resp_if.emi_arready ), //i
    .i_tx_axi_rresp      ( '0                      ), //i
    .i_tx_axi_rid        ( emi_resp_if.emi_rid     ), //i
    .i_tx_axi_rdata      ( emi_resp_if.emi_rdata   ), //i
    .i_tx_axi_rlast      ( emi_resp_if.emi_rlast   ), //i
    .i_tx_axi_rvalid     ( emi_resp_if.emi_rvalid  ), //i
    .o_tx_axi_rready     ( emi_resp_if.emi_rready  )  //o
);

//-------------------------------------------------------
//dump fsdb
//-------------------------------------------------------
`ifdef DUMP_FSDB
initial begin
    $fsdbDumpfile("run.fsdb");
    $fsdbDumpMDA(0,top)  ;   //dump array
    $fsdbDumpvars(0,top) ;  //dump struct
    $fsdbDumpvars(top,"+all");  //dump struct
    $fsdbDumpon();
end
`endif

endmodule
