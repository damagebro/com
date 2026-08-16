`timescale 1ns/1ps

interface fifo_if #( parameter
    DW = 16,
    CW = 3
)
(
input logic clk
);

logic          rst_n;
logic          clear;
logic          i_wr_en;
logic [DW-1:0] i_wr_data;
logic          o_wr_full;
logic          i_rd_en;
logic [DW-1:0] o_rd_data;
logic          o_rd_empty;
logic [CW-1:0] o_water_level;

modport dut
(
input  clk,
input  rst_n,
input  clear,
input  i_wr_en,
input  i_wr_data,
output o_wr_full,
input  i_rd_en,
output o_rd_data,
output o_rd_empty,
output o_water_level
);

endinterface
