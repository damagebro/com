`timescale 1ns/1ps

interface axi_if #( parameter
    WCH      = 1,
    RCH      = 1,
    AW       = 16,
    DW       = 32,
    EBUS_LW  = 16,
    LW       = 4,
    IW       = 1,
    UW       = 2
)
(
input logic clk
);

logic rst_n;
logic clear;
logic [3:0]             cfg_mem_ctrl;
logic [7:0]             cfg_max_blen_m1;
logic [RCH-1:0][15:0]  cfg_rch_max_rdcmd_osd;

logic [WCH-1:0][UW-1:0]       wa_user;
logic [WCH-1:0][AW-1:0]       wa_addr;
logic [WCH-1:0][EBUS_LW-1:0]  wa_bytelen;
logic [WCH-1:0]               wa_valid;
logic [WCH-1:0]               wa_ready;
logic [WCH-1:0][DW-1:0]       wd_data;
logic [WCH-1:0]               wd_valid;
logic [WCH-1:0]               wd_ready;
logic [WCH-1:0]               wb_valid;

logic [RCH-1:0][UW-1:0]       ra_user;
logic [RCH-1:0][AW-1:0]       ra_addr;
logic [RCH-1:0][EBUS_LW-1:0]  ra_bytelen;
logic [RCH-1:0]               ra_valid;
logic [RCH-1:0]               ra_ready;
logic [RCH-1:0][DW-1:0]       rd_data;
logic [RCH-1:0]               rd_last;
logic [RCH-1:0]               rd_valid;
logic [RCH-1:0]               rd_ready;

logic [IW-1:0]    axi_awid;
logic [AW-1:0]    axi_awaddr;
logic [LW-1:0]    axi_awlen;
logic [UW-1:0]    axi_awuser;
logic             axi_awvalid;
logic             axi_awready;
logic [DW-1:0]    axi_wdata;
logic [DW/8-1:0]  axi_wstrb;
logic             axi_wlast;
logic             axi_wvalid;
logic             axi_wready;
logic [1:0]       axi_bresp;
logic [IW-1:0]    axi_bid;
logic             axi_bvalid;
logic             axi_bready;
logic [IW-1:0]    axi_arid;
logic [AW-1:0]    axi_araddr;
logic [LW-1:0]    axi_arlen;
logic [UW-1:0]    axi_aruser;
logic             axi_arvalid;
logic             axi_arready;
logic [1:0]       axi_rresp;
logic [IW-1:0]    axi_rid;
logic [DW-1:0]    axi_rdata;
logic             axi_rlast;
logic             axi_rvalid;
logic             axi_rready;

clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output rst_n;
    output clear;
    output cfg_mem_ctrl;
    output cfg_max_blen_m1;
    output cfg_rch_max_rdcmd_osd;
    output wa_user;
    output wa_addr;
    output wa_bytelen;
    output wa_valid;
    input  wa_ready;
    output wd_data;
    output wd_valid;
    input  wd_ready;
    input  wb_valid;
    output ra_user;
    output ra_addr;
    output ra_bytelen;
    output ra_valid;
    input  ra_ready;
    input  rd_data;
    input  rd_last;
    input  rd_valid;
    output rd_ready;
    input  axi_awid;
    input  axi_awaddr;
    input  axi_awlen;
    input  axi_awuser;
    input  axi_awvalid;
    output axi_awready;
    input  axi_wdata;
    input  axi_wstrb;
    input  axi_wlast;
    input  axi_wvalid;
    output axi_wready;
    output axi_bresp;
    output axi_bid;
    output axi_bvalid;
    input  axi_bready;
    input  axi_arid;
    input  axi_araddr;
    input  axi_arlen;
    input  axi_aruser;
    input  axi_arvalid;
    output axi_arready;
    output axi_rresp;
    output axi_rid;
    output axi_rdata;
    output axi_rlast;
    output axi_rvalid;
    input  axi_rready;
endclocking

modport drv(clocking drv_cb);

endinterface
