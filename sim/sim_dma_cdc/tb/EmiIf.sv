interface com_emi_tbif( input bit clk );
    parameter  EMI_AW   = 32;
    parameter  EMI_DW   = 128;
    parameter  EMI_UW   = 1;
    parameter  EMI_SW   = EMI_DW/8;

    parameter  EMI_MAX_CH  = 16;
    localparam EMI_IW = $clog2(EMI_MAX_CH);
    // parameter  EMI_MAX_OSD = 16;//outstanding
    // parameter  EMI_MAX_LEN = 16;
    // localparam EMI_LW = $clog2(EMI_MAX_LEN);

    logic              emi_arvalid ;
    logic              emi_arready ;
    logic [EMI_IW-1:0] emi_arid    ;
    logic [EMI_AW-1:0] emi_araddr  ;
    logic [7:0]        emi_arlen   ;
    logic [EMI_UW-1:0] emi_aruser  ;

    logic              emi_rvalid  ;
    logic              emi_rready  ;
    logic [EMI_IW-1:0] emi_rid     ;
    logic [EMI_DW-1:0] emi_rdata   ;
    logic              emi_rlast   ;
    logic [EMI_UW-1:0] emi_ruser   ;

    logic              emi_awvalid ;
    logic              emi_awready ;
    logic [EMI_IW-1:0] emi_awid    ;
    logic [EMI_AW-1:0] emi_awaddr  ;
    logic [7:0]        emi_awlen   ;
    logic [EMI_UW-1:0] emi_awuser  ;

    logic              emi_wvalid  ;
    logic              emi_wready  ;
    logic [EMI_DW-1:0] emi_wdata   ;
    logic [EMI_SW-1:0] emi_wstrb   ;
    logic              emi_wlast   ;
    logic [EMI_UW-1:0] emi_wuser   ;

    logic              emi_bvalid  ;
    logic              emi_bready  ;
    logic [EMI_IW-1:0] emi_bid     ;
    logic [EMI_UW-1:0] emi_buser   ;

    //emi_std_if---
    clocking cb @ (posedge clk);
        input  emi_arvalid,emi_arid,emi_araddr,emi_arlen,emi_aruser;
        output emi_arready;
        input  emi_rready;
        output emi_rvalid,emi_rid,emi_rdata,emi_rlast,emi_ruser;

        input  emi_awvalid,emi_awid,emi_awaddr,emi_awlen,emi_awuser;
        output emi_awready;
        input  emi_wvalid,emi_wdata,emi_wstrb,emi_wlast,emi_wuser;
        output emi_wready;
        output emi_bvalid,emi_bid,emi_buser;
    endclocking
    // modport resp(clocking cb);

    //emi_usr_if---
    clocking rcb @ (posedge clk);
        output emi_arvalid,emi_araddr,emi_arlen,emi_aruser;
        input  emi_arready;
        // output emi_rready;
        input  emi_rvalid,emi_rdata,emi_rlast,emi_ruser;
    endclocking
    clocking wcb @ (posedge clk);
        output emi_awvalid,emi_awaddr,emi_awlen,emi_awuser;
        input  emi_awready;
        output emi_wvalid,emi_wdata,emi_wstrb,emi_wlast,emi_wuser;
        input  emi_wready;
        input  emi_bvalid,emi_buser;
    endclocking
    // modport rch_tx(clocking rcb);
    // modport wch_tx(clocking wcb);
endinterface //com_emi_tbif

typedef virtual com_emi_tbif vEmiIf;
// typedef virtual com_emi_tbif.resp   vEmiRespIf;
// typedef virtual com_emi_tbif.wch_tx vEmiWchIf;
// typedef virtual com_emi_tbif.rch_tx vEmiRchIf;