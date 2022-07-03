/******************************************************************************
*
*  Authors:   dmg
*    Email:   dmg@sensetime.com
*     Date:   2021/06/07-14:43:10
*
*  Description:
*  -bus bridge axi4 to emi;
*  -TBD:(1)deal resp error; (2)axi's user and emi's user connect; (3)qos
*
*  Modify:
*  -
*
******************************************************************************/

`ifndef com_emi_bridge_x2e_v
`define com_emi_bridge_x2e_v
module com_emi_bridge_x2e #( parameter
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
input  wire [IW-1:0]            xs_arid             ,
input  wire [AW-1:0]            xs_araddr           ,
input  wire [7:0]               xs_arlen            ,
input  wire [UW-1:0]            xs_aruser           ,
input  wire [2:0]               xs_arsize           ,
input  wire [1:0]               xs_arbusrt          ,//2'b01:INCR
input  wire [3:0]               xs_arcache          ,//4'b0000: non-cache
input  wire [2:0]               xs_arprot           ,//[0]0=non-private, [1]0=securty, [2]0=data/1=instruction
input  wire [3:0]               xs_arqos            ,//priority, larger number high pri.
input  wire [3:0]               xs_arregion         ,//fix 4'b0000
input  wire                     xs_arvalid          ,
output wire                     xs_arready          ,
output wire [IW-1:0]            xs_rid              ,
output wire [DW-1:0]            xs_rdata            ,
output wire                     xs_rlast            ,
output wire [UW-1:0]            xs_ruser            ,
output wire [1:0]               xs_rresp            ,//0:OKAY, 1:EXOKAY, 2:SVLERR, 3:DECERR
output wire                     xs_rvalid           ,
input  wire                     xs_rready           ,
input  wire [IW-1:0]            xs_awid             ,
input  wire [AW-1:0]            xs_awaddr           ,
input  wire [7:0]               xs_awlen            ,
input  wire [UW-1:0]            xs_awuser           ,
input  wire [2:0]               xs_awsize           ,
input  wire [1:0]               xs_awbusrt          ,//2'b01:INCR
input  wire [3:0]               xs_awcache          ,//4'b0000: non-cache
input  wire [2:0]               xs_awprot           ,//[0]0=non-private, [1]0=securty, [2]0=data/1=instruction
input  wire [3:0]               xs_awqos            ,//priority, larger number high pri.
input  wire [3:0]               xs_awregion         ,//fix 4'b0000
input  wire                     xs_awvalid          ,
output wire                     xs_awready          ,
input  wire [DW-1:0]            xs_wdata            ,
input  wire [DW/8-1:0]          xs_wstrb            ,
input  wire                     xs_wlast            ,
input  wire [UW-1:0]            xs_wuser            ,
input  wire                     xs_wvalid           ,
output wire                     xs_wready           ,
output wire [IW-1:0]            xs_bid              ,
output wire [UW-1:0]            xs_buser            ,
output wire [1:0]               xs_bresp            ,//0:OKAY, 1:EXOKAY, 2:SVLERR, 3:DECERR
output wire                     xs_bvalid           ,
input  wire                     xs_bready           ,
//emi if
com_emi_if.tx                   ext_emi_ifm         //,
);
//localparam-----------------------------------------------------------------
localparam SW = DW/8;
//reg  declare---------------------------------------------------------------
//wire declare---------------------------------------------------------------
//statement------------------------------------------------------------------
//wch--
assign ext_emi_ifm.emi_awvalid = xs_awvalid;
assign ext_emi_ifm.emi_awid    = xs_awid   ;
assign ext_emi_ifm.emi_awaddr  = xs_awaddr ;
assign ext_emi_ifm.emi_awlen   = xs_awlen  ;
assign xs_awready = ext_emi_ifm.emi_awready;
// assign ext_emi_ifm.emi_awuser  = xs_awuser ;
assign ext_emi_ifm.emi_awuser  = UW'(0) ;

assign ext_emi_ifm.emi_wvalid = xs_wvalid ;
// assign ext_emi_ifm.emi_wid    = IW'(0)    ;
assign ext_emi_ifm.emi_wdata  = xs_wdata  ;
assign ext_emi_ifm.emi_wstrb  = xs_wstrb  ;
assign ext_emi_ifm.emi_wlast  = xs_wlast  ;
assign xs_wready = ext_emi_ifm.emi_wready ;
// assign ext_emi_ifm.emi_wuser  = xs_wuser  ;
assign ext_emi_ifm.emi_wuser  = UW'(0)  ;

assign xs_bvalid = ext_emi_ifm.emi_bvalid ;
assign xs_bid    = ext_emi_ifm.emi_bid    ;
assign ext_emi_ifm.emi_bready = xs_bready ;
// assign xs_buser  = ext_emi_ifm.emi_buser  ;
assign xs_buser  = UW'(0);

//rch--
assign ext_emi_ifm.emi_arvalid = xs_arvalid ;
assign ext_emi_ifm.emi_arid    = xs_arid    ;
assign ext_emi_ifm.emi_araddr  = xs_araddr  ;
assign ext_emi_ifm.emi_arlen   = xs_arlen   ;
assign xs_arready = ext_emi_ifm.emi_arready ;
// assign ext_emi_ifm.emi_aruser  = xs_aruser  ;
assign ext_emi_ifm.emi_aruser  = UW'(0)  ;

assign xs_rvalid = ext_emi_ifm.emi_rvalid ;
assign xs_rid    = ext_emi_ifm.emi_rid    ;
assign xs_rdata  = ext_emi_ifm.emi_rdata  ;
assign xs_rlast  = ext_emi_ifm.emi_rlast  ;
assign ext_emi_ifm.emi_rready = xs_rready ;
// assign xs_ruser  = ext_emi_ifm.emi_ruser  ;
assign xs_ruser  = UW'(0)  ;

endmodule //end of com_emi_bridge_x2e
`endif //end of com_emi_bridge_x2e_v

