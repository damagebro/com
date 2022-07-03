module top();

event all_done;
bit clk   ;
bit rst_n ;
bit clear ;
bit axi_clk   ;

always #2   clk= ~clk;
always #3   axi_clk= ~axi_clk;

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

DmaIf dma_if( clk );
com_emi_tbif #( .EMI_AW(EMI_AW), .EMI_DW(EMI_DW), .EMI_MAX_CH(EMI_MAX_CH), .EMI_UW(4) )  emi_resp_if(axi_clk);
dma_test dma_t1( emi_resp_if, dma_if );
com_dma_cdc #(
    .BUS_AW     ( BUS_AW     ), //32
    .BUS_DW     ( BUS_DW     ), //128
    .BUS_LW     ( BUS_LW     ), //32
    .WCH        ( WCH        ), //5
    .RCH        ( RCH        ), //6
    .MAX_CH     ( 16         ), //16
    .AXI_UW     ( 4          )  //4
)u_com_dma_cdc
(
    .clk                  ( clk                  ), //i
    .rst_n                ( rst_n                ), //i
    .clear                ( clear                ), //i
    .axi_clk              ( axi_clk              ), //i
    .axi_rst_n            ( rst_n                ), //i
    .sys_cfg              (                      ), //i
    //cfg&status---
    .wdma_burst_len       ( dma_if.wdma_burst_len ), //i
    .rdma_burst_len       ( dma_if.rdma_burst_len ), //i
    .axi_burst_len        ( dma_if.axi_burst_len  ), //i
    .clr_ongoing          ( dma_if.clr_ongoing    ), //o
    //bus
    .bus_wa_valid         ( dma_if.bus_wa_valid   ), //i
    .bus_wa_ready         ( dma_if.bus_wa_ready   ), //o
    .bus_wa_addr          ( dma_if.bus_wa_addr    ), //i
    .bus_wa_bytelen       ( dma_if.bus_wa_bytelen ), //i
    .bus_wd_valid         ( dma_if.bus_wd_valid   ), //i
    .bus_wd_ready         ( dma_if.bus_wd_ready   ), //o
    .bus_wd_data          ( dma_if.bus_wd_data    ), //i
    .bus_wb_resp          ( dma_if.bus_wb_resp    ), //o
    .bus_ra_valid         ( dma_if.bus_ra_valid   ), //i
    .bus_ra_ready         ( dma_if.bus_ra_ready   ), //o
    .bus_ra_addr          ( dma_if.bus_ra_addr    ), //i
    .bus_ra_bytelen       ( dma_if.bus_ra_bytelen ), //i
    .bus_rd_valid         ( dma_if.bus_rd_valid   ), //o
    .bus_rd_ready         ( dma_if.bus_rd_ready   ), //i
    .bus_rd_data          ( dma_if.bus_rd_data    ), //o
    .bus_rd_done          ( dma_if.bus_rd_done    ), //o
    //axi
    .xm_arvalid           ( emi_resp_if.emi_arvalid ), //o
    .xm_arready           ( emi_resp_if.emi_arready ), //i
    .xm_arid              ( emi_resp_if.emi_arid    ), //o
    .xm_araddr            ( emi_resp_if.emi_araddr  ), //o
    .xm_arlen             ( emi_resp_if.emi_arlen   ), //o
    .xm_aruser            ( emi_resp_if.emi_aruser  ), //o
    .xm_arsize            (                         ), //o
    .xm_arbusrt           (                         ), //o
    .xm_arcache           (                         ), //o
    .xm_arprot            (                         ), //o
    .xm_arqos             (                         ), //o
    .xm_arregion          (                         ), //o
    .xm_rvalid            ( emi_resp_if.emi_rvalid  ), //i
    .xm_rready            ( emi_resp_if.emi_rready  ), //o
    .xm_rid               ( emi_resp_if.emi_rid     ), //i
    .xm_rdata             ( emi_resp_if.emi_rdata   ), //i
    .xm_rlast             ( emi_resp_if.emi_rlast   ), //i
    .xm_ruser             ( emi_resp_if.emi_ruser   ), //i
    .xm_rresp             ( 2'b0                    ), //i
    .xm_awvalid           ( emi_resp_if.emi_awvalid ), //o
    .xm_awready           ( emi_resp_if.emi_awready ), //i
    .xm_awid              ( emi_resp_if.emi_awid    ), //o
    .xm_awaddr            ( emi_resp_if.emi_awaddr  ), //o
    .xm_awlen             ( emi_resp_if.emi_awlen   ), //o
    .xm_awuser            ( emi_resp_if.emi_awuser  ), //o
    .xm_awsize            (                         ), //o
    .xm_awbusrt           (                         ), //o
    .xm_awcache           (                         ), //o
    .xm_awprot            (                         ), //o
    .xm_awqos             (                         ), //o
    .xm_awregion          (                         ), //o
    .xm_wvalid            ( emi_resp_if.emi_wvalid  ), //o
    .xm_wready            ( emi_resp_if.emi_wready  ), //i
    .xm_wdata             ( emi_resp_if.emi_wdata   ), //o
    .xm_wstrb             ( emi_resp_if.emi_wstrb   ), //o
    .xm_wlast             ( emi_resp_if.emi_wlast   ), //o
    .xm_wuser             ( emi_resp_if.emi_wuser   ), //o
    .xm_bvalid            ( emi_resp_if.emi_bvalid  ), //i
    .xm_bready            ( emi_resp_if.emi_bready  ), //o
    .xm_bid               ( emi_resp_if.emi_bid     ), //i
    .xm_buser             ( emi_resp_if.emi_buser   ), //i
    .xm_bresp             ( 2'b0                    )  //i
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
