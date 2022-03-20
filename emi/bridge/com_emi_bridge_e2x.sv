/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/06/07-14:43:05
*
*  Description:
*  -bus bridge emi to axi4;
*  -axi4 no wid; maybe emi will delete wid later;20210607, add by ty;
*  -TBD:(1)deal resp error; (2)axi's user and emi's user connect; (3)qos
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_bridge_e2x_v
`define com_emi_bridge_e2x_v
module com_emi_bridge_e2x #( parameter
    AW      = 32        , //emi&axi bus addr bit_width
    DW      = 128       , //emi&axi bus data bit_width
    USR_W   = 0         , //emi&axi bus user signal bit_width, typical value=0; maybe used by cache control, and any DIY functions
    MAX_CH  = 16        , //number of max (write||read) channels

    UW =(USR_W>0?USR_W:1),
    IW = $clog2(MAX_CH)  //,
)
(
input  wire                     clk                 ,
input  wire                     rst_n               ,
input  wire                     clear               ,
//axi
output wire                     xm_arvalid          ,
input  wire                     xm_arready          ,
output wire [IW-1:0]            xm_arid             ,
output wire [AW-1:0]            xm_araddr           ,
output wire [7:0]               xm_arlen            ,
output wire [UW-1:0]            xm_aruser           ,
output wire [2:0]               xm_arsize           ,
output wire [1:0]               xm_arbusrt          ,//2'b01:INCR
output wire [3:0]               xm_arcache          ,//4'b0000: non-cache
output wire [2:0]               xm_arprot           ,//[0]0=non-private, [1]0=securty, [2]0=data/1=instruction
output wire [3:0]               xm_arqos            ,//priority, larger number high pri.
output wire [3:0]               xm_arregion         ,//fix 4'b0000

input  wire                     xm_rvalid           ,
output wire                     xm_rready           ,
input  wire [IW-1:0]            xm_rid              ,
input  wire [DW-1:0]            xm_rdata            ,
input  wire                     xm_rlast            ,
input  wire [UW-1:0]            xm_ruser            ,
input  wire [1:0]               xm_rresp            ,//0:OKAY, 1:EXOKAY, 2:SVLERR, 3:DECERR

output wire                     xm_awvalid          ,
input  wire                     xm_awready          ,
output wire [IW-1:0]            xm_awid             ,
output wire [AW-1:0]            xm_awaddr           ,
output wire [7:0]               xm_awlen            ,
output wire [UW-1:0]            xm_awuser           ,
output wire [2:0]               xm_awsize           ,
output wire [1:0]               xm_awbusrt          ,//2'b01:INCR
output wire [3:0]               xm_awcache          ,//4'b0000: non-cache
output wire [2:0]               xm_awprot           ,//[0]0=non-private, [1]0=securty, [2]0=data/1=instruction
output wire [3:0]               xm_awqos            ,//priority, larger number high pri.
output wire [3:0]               xm_awregion         ,//fix 4'b0000

output wire                     xm_wvalid           ,
input  wire                     xm_wready           ,
output wire [DW-1:0]            xm_wdata            ,
output wire [DW/8-1:0]          xm_wstrb            ,
output wire                     xm_wlast            ,
output wire [UW-1:0]            xm_wuser            ,

input  wire                     xm_bvalid           ,
output wire                     xm_bready           ,
input  wire [IW-1:0]            xm_bid              ,
input  wire [UW-1:0]            xm_buser            ,
input  wire [1:0]               xm_bresp            ,//0:OKAY, 1:EXOKAY, 2:SVLERR, 3:DECERR
//emi if
com_emi_if.rx                   ext_emi_ifs         //,
);
//localparam-----------------------------------------------------------------
localparam SW = DW/8;
localparam SW_L2 = $clog2(SW);
localparam SW_L2_M1 = SW_L2-1;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------

//wch--
assign xm_awvalid = ext_emi_ifs.emi_awvalid;
assign xm_awid    = ext_emi_ifs.emi_awid   ;
assign xm_awaddr  = ext_emi_ifs.emi_awaddr ;
assign xm_awlen   = ext_emi_ifs.emi_awlen  ;
assign ext_emi_ifs.emi_awready = xm_awready;
// assign xm_awuser  = ext_emi_ifs.emi_awuser ;
assign xm_awuser   = UW'(0)   ; //TBD
assign xm_awsize   = SW_L2    ;
assign xm_awbusrt  = 2'b01    ;//2'b01:INCR
assign xm_awcache  = 4'b0     ;//4'b0000: non-cache
assign xm_awprot   = 3'b0     ;//[0]0=non-private, [1]0=securty, [2]0=data/1=instruction
assign xm_awqos    = 4'b0     ;//priority, larger number high pri.  TBD
assign xm_awregion = 4'b0     ;//fix 4'b0000

assign xm_wvalid  = ext_emi_ifs.emi_wvalid;
assign xm_wdata   = ext_emi_ifs.emi_wdata ;
assign xm_wstrb   = ext_emi_ifs.emi_wstrb ;
assign xm_wlast   = ext_emi_ifs.emi_wlast ;
assign ext_emi_ifs.emi_wready = xm_wready ;
// assign xm_wid     = ext_emi_ifs.emi_wid   ; //TBD
// assign xm_wuser   = ext_emi_ifs.emi_wuser ;
assign xm_wuser = UW'(0); //TBD

assign ext_emi_ifs.emi_bvalid = xm_bvalid;
assign ext_emi_ifs.emi_bid    = xm_bid   ;
assign xm_bready = ext_emi_ifs.emi_bready;
// assign ext_emi_ifs.emi_buser  = xm_buser ; //TBD
assign ext_emi_ifs.emi_buser  = UW'(0);
// assign xx = xm_bresp; TBD

//rch--
assign xm_arvalid = ext_emi_ifs.emi_arvalid;
assign xm_arid    = ext_emi_ifs.emi_arid   ;
assign xm_araddr  = ext_emi_ifs.emi_araddr ;
assign xm_arlen   = ext_emi_ifs.emi_arlen  ;
assign ext_emi_ifs.emi_arready = xm_arready;
// assign ext_emi_ifs.emi_aruser  = xm_aruser  ;
assign xm_aruser   = UW'(0)   ; //TBD
assign xm_arsize   = SW_L2    ;
assign xm_arbusrt  = 2'b01    ;//2'b01:INCR
assign xm_arcache  = 4'b0     ;//4'b0000: non-cache
assign xm_arprot   = 3'b0     ;//[0]0=non-private, [1]0=securty, [2]0=data/1=instruction
assign xm_arqos    = 4'b0     ;//priority, larger number high pri.  TBD
assign xm_arregion = 4'b0     ;//fix 4'b0000

assign ext_emi_ifs.emi_rvalid = xm_rvalid ;
assign ext_emi_ifs.emi_rid    = xm_rid    ;
assign ext_emi_ifs.emi_rdata  = xm_rdata  ;
assign ext_emi_ifs.emi_rlast  = xm_rlast  ;
assign xm_rready = ext_emi_ifs.emi_rready ;
// assign xm_ruser  = ext_emi_ifs.emi_ruser  ; TBD
assign xm_ruser = UW'(0);

endmodule //end of com_emi_bridge_e2x
`endif //end of com_emi_bridge_e2x_v

