`timescale 1ns/1ps

interface ram_if #( parameter
    AW      = 4,
    DW      = 16,
    STRB_W  = 2
)
(
input logic clk
);

logic rst_n;
logic clear;

logic [1:0][AW-1:0]      arb_wr_addr;
logic [1:0][DW-1:0]      arb_wr_data;
logic [1:0][STRB_W-1:0]  arb_wr_vld;
logic [1:0][AW-1:0]      arb_rd_addr;
logic [1:0]              arb_rd_vld;

logic [AW-1:0]           sp_wr_addr;
logic [DW-1:0]           sp_wr_data;
logic [STRB_W-1:0]       sp_wr_vld;
logic [AW-1:0]           sp_rd_addr;
logic                    sp_rd_vld;

logic [AW-1:0]           rmw_wr_addr;
logic [DW-1:0]           rmw_wr_data;
logic [STRB_W-1:0]       rmw_wr_vld;
logic [AW-1:0]           rmw_rd_addr;
logic                    rmw_rd_vld;

logic [AW-1:0]           sp2_wr_addr;
logic [DW-1:0]           sp2_wr_data;
logic [STRB_W-1:0]       sp2_wr_vld;
logic [AW-1:0]           sp2_rd_addr;
logic                    sp2_rd_vld;

clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output rst_n;
    output clear;
    output arb_wr_addr;
    output arb_wr_data;
    output arb_wr_vld;
    output arb_rd_addr;
    output arb_rd_vld;
    output sp_wr_addr;
    output sp_wr_data;
    output sp_wr_vld;
    output sp_rd_addr;
    output sp_rd_vld;
    output rmw_wr_addr;
    output rmw_wr_data;
    output rmw_wr_vld;
    output rmw_rd_addr;
    output rmw_rd_vld;
    output sp2_wr_addr;
    output sp2_wr_data;
    output sp2_wr_vld;
    output sp2_rd_addr;
    output sp2_rd_vld;
endclocking

modport drv(clocking drv_cb);

endinterface
