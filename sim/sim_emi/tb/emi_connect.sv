// import EmiPkg::*;

//-------------------------------------------------------
//define
//-------------------------------------------------------
`define EMI_TOP top

//-------------------------------------------------------
//parameter
//-------------------------------------------------------


//tbtx + usr_emi----
//wr
generate
for( genvar gi=0; gi<EMI_WCH; gi++ )begin
    assign `EMI_TOP.usr_emi_wrif[gi].emi_awvalid = `EMI_TOP.wch_if[gi].emi_awvalid ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_awid    = `EMI_TOP.wch_if[gi].emi_awid    ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_awaddr  = `EMI_TOP.wch_if[gi].emi_awaddr  ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_awlen   = `EMI_TOP.wch_if[gi].emi_awlen   ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_awuser  = `EMI_TOP.wch_if[gi].emi_awuser  ;
    assign `EMI_TOP.wch_if[gi].emi_awready = `EMI_TOP.usr_emi_wrif[gi].emi_awready ;

    assign `EMI_TOP.usr_emi_wrif[gi].emi_wvalid = `EMI_TOP.wch_if[gi].emi_wvalid ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_wid    = `EMI_TOP.wch_if[gi].emi_wid    ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_wdata  = `EMI_TOP.wch_if[gi].emi_wdata  ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_wstrb  = `EMI_TOP.wch_if[gi].emi_wstrb  ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_wlast  = `EMI_TOP.wch_if[gi].emi_wlast  ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_wuser  = `EMI_TOP.wch_if[gi].emi_wuser  ;
    assign `EMI_TOP.wch_if[gi].emi_wready = `EMI_TOP.usr_emi_wrif[gi].emi_wready ;

    assign `EMI_TOP.wch_if[gi].emi_bvalid = `EMI_TOP.usr_emi_wrif[gi].emi_bvalid ;
    assign `EMI_TOP.wch_if[gi].emi_bid    = `EMI_TOP.usr_emi_wrif[gi].emi_bid    ;
    assign `EMI_TOP.wch_if[gi].emi_buser  = `EMI_TOP.usr_emi_wrif[gi].emi_buser  ;
    assign `EMI_TOP.usr_emi_wrif[gi].emi_bready = `EMI_TOP.wch_if[gi].emi_bready ;
end
endgenerate
generate
for( genvar gi=0; gi<EMI_RCH; gi++ )begin
    assign `EMI_TOP.usr_emi_rdif[gi].emi_arvalid = `EMI_TOP.rch_if[gi].emi_arvalid ;
    assign `EMI_TOP.usr_emi_rdif[gi].emi_arid    = `EMI_TOP.rch_if[gi].emi_arid    ;
    assign `EMI_TOP.usr_emi_rdif[gi].emi_araddr  = `EMI_TOP.rch_if[gi].emi_araddr  ;
    assign `EMI_TOP.usr_emi_rdif[gi].emi_arlen   = `EMI_TOP.rch_if[gi].emi_arlen   ;
    assign `EMI_TOP.usr_emi_rdif[gi].emi_aruser  = `EMI_TOP.rch_if[gi].emi_aruser  ;
    assign `EMI_TOP.rch_if[gi].emi_arready = `EMI_TOP.usr_emi_rdif[gi].emi_arready ;

    assign `EMI_TOP.rch_if[gi].emi_rvalid = `EMI_TOP.usr_emi_rdif[gi].emi_rvalid ;
    assign `EMI_TOP.rch_if[gi].emi_rid    = `EMI_TOP.usr_emi_rdif[gi].emi_rid    ;
    assign `EMI_TOP.rch_if[gi].emi_rdata  = `EMI_TOP.usr_emi_rdif[gi].emi_rdata  ;
    assign `EMI_TOP.rch_if[gi].emi_rlast  = `EMI_TOP.usr_emi_rdif[gi].emi_rlast  ;
    assign `EMI_TOP.rch_if[gi].emi_ruser  = `EMI_TOP.usr_emi_rdif[gi].emi_ruser  ;
    assign `EMI_TOP.usr_emi_rdif[gi].emi_rready = `EMI_TOP.rch_if[gi].emi_rready ;
end
endgenerate

//tbrx + ext_emi----
//wr
assign `EMI_TOP.resp_if.emi_awvalid = `EMI_TOP.ext_emi_if.emi_awvalid ;
assign `EMI_TOP.resp_if.emi_awid    = `EMI_TOP.ext_emi_if.emi_awid    ;
assign `EMI_TOP.resp_if.emi_awaddr  = `EMI_TOP.ext_emi_if.emi_awaddr  ;
assign `EMI_TOP.resp_if.emi_awlen   = `EMI_TOP.ext_emi_if.emi_awlen   ;
assign `EMI_TOP.resp_if.emi_awuser  = `EMI_TOP.ext_emi_if.emi_awuser  ;
assign `EMI_TOP.ext_emi_if.emi_awready = `EMI_TOP.resp_if.emi_awready ;

assign `EMI_TOP.resp_if.emi_wvalid = `EMI_TOP.ext_emi_if.emi_wvalid ;
assign `EMI_TOP.resp_if.emi_wid    = `EMI_TOP.ext_emi_if.emi_wid    ;
assign `EMI_TOP.resp_if.emi_wdata  = `EMI_TOP.ext_emi_if.emi_wdata  ;
assign `EMI_TOP.resp_if.emi_wstrb  = `EMI_TOP.ext_emi_if.emi_wstrb  ;
assign `EMI_TOP.resp_if.emi_wlast  = `EMI_TOP.ext_emi_if.emi_wlast  ;
assign `EMI_TOP.resp_if.emi_wuser  = `EMI_TOP.ext_emi_if.emi_wuser  ;
assign `EMI_TOP.ext_emi_if.emi_wready = `EMI_TOP.resp_if.emi_wready ;

assign `EMI_TOP.ext_emi_if.emi_bvalid = `EMI_TOP.resp_if.emi_bvalid ;
assign `EMI_TOP.ext_emi_if.emi_bid    = `EMI_TOP.resp_if.emi_bid    ;
assign `EMI_TOP.ext_emi_if.emi_buser  = `EMI_TOP.resp_if.emi_buser  ;
assign `EMI_TOP.resp_if.emi_bready = `EMI_TOP.ext_emi_if.emi_bready ;
//rd
assign `EMI_TOP.resp_if.emi_arvalid = `EMI_TOP.ext_emi_if.emi_arvalid ;
assign `EMI_TOP.resp_if.emi_arid    = `EMI_TOP.ext_emi_if.emi_arid    ;
assign `EMI_TOP.resp_if.emi_araddr  = `EMI_TOP.ext_emi_if.emi_araddr  ;
assign `EMI_TOP.resp_if.emi_arlen   = `EMI_TOP.ext_emi_if.emi_arlen   ;
assign `EMI_TOP.resp_if.emi_aruser  = `EMI_TOP.ext_emi_if.emi_aruser  ;
assign `EMI_TOP.ext_emi_if.emi_arready = `EMI_TOP.resp_if.emi_arready ;

assign `EMI_TOP.ext_emi_if.emi_rvalid = `EMI_TOP.resp_if.emi_rvalid ;
assign `EMI_TOP.ext_emi_if.emi_rid    = `EMI_TOP.resp_if.emi_rid    ;
assign `EMI_TOP.ext_emi_if.emi_rdata  = `EMI_TOP.resp_if.emi_rdata  ;
assign `EMI_TOP.ext_emi_if.emi_rlast  = `EMI_TOP.resp_if.emi_rlast  ;
assign `EMI_TOP.ext_emi_if.emi_ruser  = `EMI_TOP.resp_if.emi_ruser  ;
assign `EMI_TOP.resp_if.emi_rready = `EMI_TOP.ext_emi_if.emi_rready ;
