`timescale 1ns/1ps

interface afifo_if #( parameter
    DW = 8,
    CW = 3
)
(
input logic wr_clk,
input logic rd_clk
);

logic          wr_rst_n;
logic          rd_rst_n;
logic          i_wr_en;
logic [DW-1:0] i_wr_data;
logic          o_wr_full;
logic          i_rd_en;
logic [DW-1:0] o_rd_data;
logic          o_rd_empty;
logic [CW-1:0] o_water_level;

clocking ckwr_drv_cb @(posedge wr_clk);
    default input #1step output #0;
    output wr_rst_n;
    output i_wr_en;
    output i_wr_data;
    input  o_wr_full;
    input  o_water_level;
endclocking

clocking ckrd_drv_cb @(posedge rd_clk);
    default input #1step output #0;
    output rd_rst_n;
    output i_rd_en;
    input  o_rd_data;
    input  o_rd_empty;
endclocking

endinterface
