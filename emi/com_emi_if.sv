interface com_emi_if;
    parameter  EMI_AW   = 32;
    parameter  EMI_DW   = 128;
    parameter  EMI_UW   = 1;
    parameter  EMI_SW   = EMI_DW/8;

    parameter  EMI_MAX_CH  = 16;
    localparam EMI_IW = $clog2(EMI_MAX_CH);
    // parameter  EMI_MAX_OSD = 16;//outstanding
    // parameter  EMI_MAX_LEN = 16;
    // localparam EMI_LW = $clog2(EMI_MAX_LEN);

    wire              emi_arvalid ;
    wire              emi_arready ;
    wire [EMI_IW-1:0] emi_arid    ;
    wire [EMI_AW-1:0] emi_araddr  ;
    wire [7:0]        emi_arlen   ;
    wire [EMI_UW-1:0] emi_aruser  ;

    wire              emi_rvalid  ;
    wire              emi_rready  ;
    wire [EMI_IW-1:0] emi_rid     ;
    wire [EMI_DW-1:0] emi_rdata   ;
    wire              emi_rlast   ;
    wire [EMI_UW-1:0] emi_ruser   ;

    wire              emi_awvalid ;
    wire              emi_awready ;
    wire [EMI_IW-1:0] emi_awid    ;
    wire [EMI_AW-1:0] emi_awaddr  ;
    wire [7:0]        emi_awlen   ;
    wire [EMI_UW-1:0] emi_awuser  ;

    wire              emi_wvalid  ;
    wire              emi_wready  ;
    wire [EMI_IW-1:0] emi_wid     ;
    wire [EMI_DW-1:0] emi_wdata   ;
    wire [EMI_SW-1:0] emi_wstrb   ;
    wire              emi_wlast   ;
    wire [EMI_UW-1:0] emi_wuser   ;

    wire              emi_bvalid  ;
    wire              emi_bready  ;
    wire [EMI_IW-1:0] emi_bid     ;
    wire [EMI_UW-1:0] emi_buser   ;

    //emi_std_if---
    modport tx(
        output emi_arvalid,emi_arid,emi_araddr,emi_arlen,emi_aruser,
        input  emi_arready,
        output emi_rready,
        input  emi_rvalid,emi_rid,emi_rdata,emi_rlast,emi_ruser,

        output emi_awvalid,emi_awid,emi_awaddr,emi_awlen,emi_awuser,
        input  emi_awready,
        output emi_wvalid,emi_wid,emi_wdata,emi_wstrb,emi_wlast,emi_wuser,
        input  emi_wready,
        input  emi_bvalid,emi_bid,emi_buser,
        output emi_bready
        );
    modport rx(
        input  emi_arvalid,emi_arid,emi_araddr,emi_arlen,emi_aruser,
        output emi_arready,
        input  emi_rready,
        output emi_rvalid,emi_rid,emi_rdata,emi_rlast,emi_ruser,

        input  emi_awvalid,emi_awid,emi_awaddr,emi_awlen,emi_awuser,
        output emi_awready,
        input  emi_wvalid,emi_wid,emi_wdata,emi_wstrb,emi_wlast,emi_wuser,
        output emi_wready,
        output emi_bvalid,emi_bid,emi_buser,
        input  emi_bready
        );

    //emi_ext_if---
    modport ext_rch_tx(
        output emi_arvalid,emi_arid,emi_araddr,emi_arlen,emi_aruser,
        input  emi_arready,
        output emi_rready,
        input  emi_rvalid,emi_rid,emi_rdata,emi_rlast,emi_ruser
        );
    modport ext_rch_rx(
        input  emi_arvalid,emi_arid,emi_araddr,emi_arlen,emi_aruser,
        output emi_arready,
        input  emi_rready,
        output emi_rvalid,emi_rid,emi_rdata,emi_rlast,emi_ruser
        );
    modport ext_rch_dbg(
        input  emi_arvalid,emi_arid,emi_araddr,emi_arlen,
        input  emi_arready,
        input  emi_rready,
        input  emi_rvalid,emi_rid,emi_rdata,emi_rlast
        );

    modport ext_wch_tx(
        output emi_awvalid,emi_awid,emi_awaddr,emi_awlen,emi_awuser,
        input  emi_awready,
        output emi_wvalid,emi_wid,emi_wdata,emi_wstrb,emi_wlast,emi_wuser,
        input  emi_wready,
        input  emi_bvalid,emi_bid,emi_buser,
        output emi_bready
        );
    modport ext_wch_rx(
        input  emi_awvalid,emi_awid,emi_awaddr,emi_awlen,emi_awuser,
        output emi_awready,
        input  emi_wvalid,emi_wid,emi_wdata,emi_wstrb,emi_wlast,emi_wuser,
        output emi_wready,
        output emi_bvalid,emi_bid,emi_buser,
        input  emi_bready
        );
    modport ext_wch_dbg(
        input  emi_awvalid,emi_awid,emi_awaddr,emi_awlen,
        input  emi_awready,
        input  emi_wvalid,emi_wid,emi_wdata,emi_wstrb,emi_wlast,
        input  emi_wready,
        input  emi_bvalid,emi_bid,
        input  emi_bready
        );

    //emi_usr_if---
    modport usr_rch_tx(
        output emi_arvalid,emi_araddr,emi_arlen,emi_aruser,
        input  emi_arready,
        // output emi_rready,
        input  emi_rvalid,emi_rdata,emi_rlast,emi_ruser
        );
    modport usr_rch_rx(
        input  emi_arvalid,emi_araddr,emi_arlen,emi_aruser,
        output emi_arready,
        // input  emi_rready,
        output emi_rvalid,emi_rdata,emi_rlast,emi_ruser
        );

    modport usr_wch_tx(
        output emi_awvalid,emi_awaddr,emi_awlen,emi_awuser,
        input  emi_awready,
        output emi_wvalid,emi_wdata,emi_wstrb,emi_wlast,emi_wuser,
        input  emi_wready,
        input  emi_bvalid,emi_buser
        );
    modport usr_wch_rx(
        input  emi_awvalid,emi_awaddr,emi_awlen,emi_awuser,
        output emi_awready,
        input  emi_wvalid,emi_wdata,emi_wstrb,emi_wlast,emi_wuser,
        output emi_wready,
        output emi_bvalid,emi_buser
        );
endinterface //com_emi_if

