//-------------------------------------------------------
//FifoPkg
//-------------------------------------------------------
`ifndef FIFO_PKG_SV
`define FIFO_PKG_SV
package FifoPkg;

localparam FIFO_DW    = 16;
localparam FIFO_DEPTH = 6;
localparam FIFO_AW    = $clog2(FIFO_DEPTH+1);

localparam FIFO_RAM1P_DW    = 20;
localparam FIFO_RAM1P_DEPTH = 64;
localparam FIFO_RAM1P_ONE_DEPTH = FIFO_RAM1P_DEPTH/2;
localparam FIFO_RAM1P_ONE_AW= $clog2(FIFO_RAM1P_ONE_DEPTH);

localparam FIFO_RAM2P_DW    = 30;
localparam FIFO_RAM2P_DEPTH = 64;
localparam FIFO_RAM2P_AW = $clog2(FIFO_RAM2P_DEPTH);
localparam FIFO_RAM2P_CW = $clog2(FIFO_RAM2P_DEPTH+1);
localparam FIFO_RAM2P_TOL_AW = $clog2(FIFO_RAM2P_DEPTH+3+1);

endpackage
`endif //FIFO_PKG_SV


//-------------------------------------------------------
//AFifoPkg
//-------------------------------------------------------
`ifndef AFIFO_PKG_SV
`define AFIFO_PKG_SV
package AFifoPkg;

localparam AFIFO_DW    = 16;
localparam AFIFO_DEPTH = 8;
localparam AFIFO_AW    = $clog2(AFIFO_DEPTH+1);

localparam AFIFO_RAM1CK_DW    = 20;
localparam AFIFO_RAM1CK_DEPTH = 33;//can be any integer;
localparam AFIFO_RAM1CK_AW    = $clog2(AFIFO_RAM1CK_DEPTH);
localparam AFIFO_RAM1CK_CW    = $clog2(AFIFO_RAM1CK_DEPTH+1);
localparam AFIFO_RAM1CK_OUT_DEPTH = 4;
localparam AFIFO_RAM1CK_TOL_AW= $clog2(AFIFO_RAM1CK_DEPTH+AFIFO_RAM1CK_OUT_DEPTH+1);

localparam AFIFO_RAM2CK_DW    = 30;
localparam AFIFO_RAM2CK_DEPTH = 64;//must be 2*n
localparam AFIFO_RAM2CK_AW    = $clog2(AFIFO_RAM2CK_DEPTH);
localparam AFIFO_RAM2CK_CW    = $clog2(AFIFO_RAM2CK_DEPTH+1);

endpackage
`endif //AFIFO_PKG_SV
