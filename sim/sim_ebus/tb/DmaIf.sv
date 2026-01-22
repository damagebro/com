interface DmaIf(
    input clk
);
    import DmaPkg::*;

    //cfg&status---
    logic [WCH-1:0][7:0]      wdma_burst_len     ;
    logic [RCH-1:0][7:0]      rdma_burst_len     ;
    logic [7:0]               axi_burst_len      ;
    logic                     clr_ongoing        ;
    //bus
    logic [WCH-1:0]             bus_wa_valid     ;
    logic [WCH-1:0]             bus_wa_ready     ;
    logic [WCH-1:0][BUS_AW-1:0] bus_wa_addr      ;
    logic [WCH-1:0][BUS_LW-1:0] bus_wa_bytelen   ;
    logic [WCH-1:0]             bus_wd_valid     ;
    logic [WCH-1:0]             bus_wd_ready     ;
    logic [WCH-1:0][BUS_DW-1:0] bus_wd_data      ;
    logic [WCH-1:0]             bus_wb_resp      ;
    logic [RCH-1:0]             bus_ra_valid     ;
    logic [RCH-1:0]             bus_ra_ready     ;
    logic [RCH-1:0][BUS_AW-1:0] bus_ra_addr      ;
    logic [RCH-1:0][BUS_LW-1:0] bus_ra_bytelen   ;
    logic [RCH-1:0]             bus_rd_valid     ;
    logic [RCH-1:0]             bus_rd_ready     ;
    logic [RCH-1:0][BUS_DW-1:0] bus_rd_data      ;
    logic [RCH-1:0]             bus_rd_done      ;

    clocking cb @ (posedge clk);
        output wdma_burst_len,rdma_burst_len,axi_burst_len;
        input  clr_ongoing;

        output bus_wa_addr,bus_wa_bytelen,bus_wa_valid,  bus_wd_data,bus_wd_valid;
        input  bus_wa_ready,  bus_wd_ready,  bus_wb_resp;

        output bus_ra_addr,bus_ra_bytelen,bus_ra_valid,  bus_rd_ready;
        input  bus_ra_ready,  bus_rd_data,bus_rd_valid,  bus_rd_done;
    endclocking
    // modport tx(clocking cb);
endinterface //DmaIf
typedef virtual DmaIf vDmaIf;