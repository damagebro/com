`ifndef DMA_PKG_SV
`define DMA_PKG_SV
package DmaPkg;

localparam BUS_AW = 32  ;
localparam BUS_DW = 128 ;
localparam BUS_LW = 32  ;
localparam WCH    = 1   ; //only 1 support in tb
localparam RCH    = 1   ; //only 1 support in tb
localparam MAX_CH = 16  ;

endpackage
`endif //DMA_PKG_SV
