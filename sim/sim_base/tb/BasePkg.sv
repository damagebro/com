//-------------------------------------------------------
//ArbPkg
//-------------------------------------------------------
`ifndef ARB_PKG_SV
`define ARB_PKG_SV
package ArbPkg;

localparam PORT_N    = 3;
localparam PTID_W    = $clog2(PORT_N>2?PORT_N:2);
// localparam MODE   = "round_from_small", //small_first, large_first, round_from_small, round_from_large, round_hold_small, round_hold_large

endpackage
`endif //ARB_PKG_SV

//-------------------------------------------------------
//PipePkg
//-------------------------------------------------------
`ifndef PIPE_PKG_SV
`define PIPE_PKG_SV
package PipePkg;

localparam PIPE_N    = 3;

endpackage
`endif //PIPE_PKG_SV

//-------------------------------------------------------
//RamMatePkg
//-------------------------------------------------------
`ifndef RAM_MATE_PKG_SV
`define RAM_MATE_PKG_SV
package RamMatePkg;

localparam RAM_MATE_DEPTH   = 128 ;
localparam RAM_MATE_DW      = 32  ;
localparam RAM_MATE_WSTB    = 1   ; //strobe
localparam RAM_MATE_WCH     = 3   ; //number of write channel
localparam RAM_MATE_RCH     = 2   ; //number of read  channel
localparam RAM_MATE_WREG    = 0   ; //number of register pipeline to   ram;
localparam RAM_MATE_WRPRI   = 1   ; //1:write/read priority,  0:read, 1:write
localparam RAM_MATE_CASCADE = 0   ; //0: connect to ram, 1: connect to next ram_mate;
localparam RAM_MATE_AW      = $clog2(RAM_MATE_DEPTH>2?RAM_MATE_DEPTH:2);

localparam RAM_MATE_RREG    = 0  ; //number of register pipeline from ram;  2020/03/18, not surport now; fixed=0

endpackage
`endif //RAM_MATE_PKG_SV
