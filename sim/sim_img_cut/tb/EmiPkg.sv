`ifndef EMI_PKG_SV
`define EMI_PKG_SV
package EmiPkg;

//-------------------------------------------------------
//define
//-------------------------------------------------------
// `define EMI_TOP top

//-------------------------------------------------------
//parameter
//-------------------------------------------------------
localparam  EMI_AW      = 32        ;//emi bus addr bit_width
localparam  EMI_DW      = 128       ;//emi bus data bit_width
localparam  EMI_USR_W   = 0         ;//emi bus user signal bit_width, typical value=0; maybe used by cache control, and any DIY functions

localparam  EMI_RCH     = 16        ;//number of read channel
localparam  EMI_WCH     = 16        ;//number of write channel
localparam  EMI_MAX_CH  = 16        ;//number of max (write||read) channels

localparam STR_LOG_PREFIX = "";

//-------------------------------------------------------
//function
//-------------------------------------------------------

//-------------------------------------------------------
//task
//-------------------------------------------------------

endpackage:EmiPkg
`endif //EMI_PKG_SV