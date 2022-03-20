`ifndef FIFO_PKG_SV
`define FIFO_PKG_SV
package FifoPkg;

localparam FIFO_DW    = 16;
localparam FIFO_DEPTH = 4;
localparam FIFO_AW    = $clog2(FIFO_DEPTH>2?FIFO_DEPTH:2);

endpackage
`endif //FIFO_PKG_SV
